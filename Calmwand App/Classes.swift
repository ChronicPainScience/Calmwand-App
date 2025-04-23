//
//  SessionViewModelClass.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/11/5.
//

import SwiftUI
import Foundation

struct SessionModel: Identifiable, Codable{
    var id = UUID()
    let duration: Int // session time in seconds
    let temperatureChange: Double // temperature change during the session in Fahrenheit
    let tempSetData: [Double] // Array of temp data in Fahrenheit
    
    let inhaleTime: Double
    let exhaleTime: Double
    
    var regressionA: Double?
    var regressionB: Double?
    var regressionk: Double?
    var score: Double?
    
    var comment: String = ""
}

class SessionViewModel: ObservableObject {
    
    @Published var sessionArray: [SessionModel] = [] {
        didSet {
            saveSessions()
        }
    }
    
    @ObservedObject var userSettingsModel: UserSettingsModel = UserSettingsModel.shared
    
    init() {
        loadSessions()
    }
    
    func calculateRegressionParameters(duration: Int, tempSet: [Double]) -> (A: Double, B: Double, k: Double)? {
        guard tempSet.count > 1 else {
            print("Temperature set must contain at least two points.")
            return nil
        }
        
        // Step 1: Generate time array
        let timeArray = stride(from: userSettingsModel.interval, to: duration, by: userSettingsModel.interval).map { Double($0) }

        // Ensure timeArray and tempSet are aligned in size
        guard timeArray.count == tempSet.count else {
            print("Mismatch between time array and temperature set.")
            return nil
        }
        
        // Step 2: Calculate A, B, k
        let epsilon = 0.1
        let A = (tempSet.max() ?? 0) + epsilon

        var sumX = 0.0
        var sumLnAminusY = 0.0
        var sumX_LnAminusY = 0.0
        var sumXSquare = 0.0
        let n = Double(tempSet.count)

        for (index, temperature) in tempSet.enumerated() {
            let AminusY = A - temperature
            // Ensure A - y > 0
            guard AminusY > 0 else { continue }
            let lnAminusY = log(AminusY)            // Calculate ln(A-y) >> y'
            sumX += timeArray[index]                // Calculate sum(x)
            sumLnAminusY += lnAminusY               // Calculate sum(ln(A-y)) >> sum(y')
            sumX_LnAminusY += timeArray[index] * lnAminusY // Calculate sum(x·ln(A-y)) >> sum(x·y')
            sumXSquare += timeArray[index] * timeArray[index] // Calculate sum(x^2)
        }

        let denominator = n * sumXSquare - sumX * sumX // Calculate denominator = n·sum(x^2) - (sumx)^2
        guard denominator != 0 else {
            print("Denominator is zero, regression calculation failed.")
            return nil
        }

        let k = -(n * sumX_LnAminusY - sumX * sumLnAminusY) / denominator
        let lnB = (sumLnAminusY + k * sumX) / n
        let B = exp(lnB)

        // Return calculated parameters
        return (A, B, k)
    }
    
    func calculateScore(A: Double, B: Double, k: Double, sessionDuration: Int) -> Double {
        let t = Double(sessionDuration) // session time
        // predicted temp increase
        let predictedIncrease = B * (1 - exp(-k * t))
        
        // ideal temp increment
        let idealIncrease = 5.0
        let powerIndexforTemp = 0.15 //as power index becomes smaller, the score will vary less
        
        let relaxFactor = min(pow(predictedIncrease / idealIncrease, powerIndexforTemp), 1.0)
        
        let idealk = 0.0050
        let powerIndexfork = 0.15
        let speedFactor = min(pow(k / idealk, powerIndexfork), 1.0)
        
        // maximum score (user must do as least 10 min session)
        let sessionMinutes = t / 60.0
        let maxScore = min(sessionMinutes * 10, 100)
        
        return maxScore * relaxFactor * speedFactor
    }
    
    func updateAllSessions() {
        for index in sessionArray.indices {
            updateRegressionParametersAndScore(for: &sessionArray[index])
        }
    }
    
    func updateRegressionParametersAndScore(for session: inout SessionModel) {
        if let (A, B, k) = calculateRegressionParameters(duration: session.duration, tempSet: session.tempSetData) {
            session.regressionA = A
            session.regressionB = B
            session.regressionk = k
            session.score = calculateScore(A: A, B: B, k: k, sessionDuration: session.duration)
        } else {
            print("Failed to calculate regression parameters for session \(session.id)")
            session.regressionA = nil
            session.regressionB = nil
            session.regressionk = nil
            session.score = nil
        }
    }
    
    func addSession(dur: Int, tempC: Double, inhale: Double, exhale: Double, Set: [Double]) {
        guard let (A, B, k) = calculateRegressionParameters(duration: dur, tempSet: Set) else {
            print("Failed to calculate regression parameters.")
            return
        }
        
        let score = calculateScore(A: A, B: B, k: k, sessionDuration: dur)
        
        let userInputSession = SessionModel(
            duration: dur,
            temperatureChange: tempC,
            tempSetData: Set,
            inhaleTime: inhale,
            exhaleTime: exhale,
            regressionA: A,
            regressionB: B,
            regressionk: k,
            score: score
        )
        sessionArray.append(userInputSession)
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessionArray)
            UserDefaults.standard.set(data, forKey: "sessionArray")
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: "sessionArray") else { return }
        do {
            sessionArray = try JSONDecoder().decode([SessionModel].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    func removeSession() {
        if !sessionArray.isEmpty {
            sessionArray.removeLast()
        }
    }
}




class CurrentSessionModel: ObservableObject {
    @Published var temperatureSet: [Double] = []
    @Published var timeElapsed: Int = 0
}


class UserSettingsModel: ObservableObject {
    static let shared = UserSettingsModel()
    
    @Published var interval: Int = 5
    @Published var isCelcius:Bool = false
}

