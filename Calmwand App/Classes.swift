//
//  SessionViewModelClass.swift
//  Calmwand App
//
//  Created by Paraparamid on 2024/11/5.
//

import SwiftUI
import Foundation

struct SessionModel: Identifiable, Codable{
    
    // MARK: - stored properties
    
    let sessionNumber: Int
    
    var id: Int { sessionNumber }
    
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

    // MARK: - legacy / custom CodingKeys
    private enum CodingKeys: String, CodingKey {
        // new names
        case sessionNumber, timestamp
        // unchanged
        case duration, temperatureChange, tempSetData,
             inhaleTime, exhaleTime,
             regressionA, regressionB, regressionk, score, comment
        // legacy key
        case legacyId = "id"
    }

    // MARK: - custom decode that understands BOTH versions
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // ── sessionNumber (new) or legacy id ──
        if let num = try c.decodeIfPresent(Int.self, forKey: .sessionNumber) {
            self.sessionNumber = num
        } else if let legacy = try c.decodeIfPresent(Int.self, forKey: .legacyId) {
            self.sessionNumber = legacy
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.sessionNumber,
                .init(codingPath: decoder.codingPath,
                      debugDescription: "No sessionNumber or id key")
            )
        }

        // ── assign the rest using `self.` ──
        self.duration          = try c.decode(Int.self,    forKey: .duration)
        self.temperatureChange = try c.decode(Double.self, forKey: .temperatureChange)
        self.tempSetData       = try c.decode([Double].self, forKey: .tempSetData)
        self.inhaleTime        = try c.decode(Double.self, forKey: .inhaleTime)
        self.exhaleTime        = try c.decode(Double.self, forKey: .exhaleTime)

        self.regressionA       = try c.decodeIfPresent(Double.self, forKey: .regressionA)
        self.regressionB       = try c.decodeIfPresent(Double.self, forKey: .regressionB)
        self.regressionk       = try c.decodeIfPresent(Double.self, forKey: .regressionk)
        self.score             = try c.decodeIfPresent(Double.self, forKey: .score)
        self.comment           = try c.decodeIfPresent(String.self, forKey: .comment) ?? ""
    }
    // MARK: - encoder
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sessionNumber,       forKey: .sessionNumber)
        try c.encode(duration,            forKey: .duration)
        try c.encode(temperatureChange,   forKey: .temperatureChange)
        try c.encode(tempSetData,         forKey: .tempSetData)
        try c.encode(inhaleTime,          forKey: .inhaleTime)
        try c.encode(exhaleTime,          forKey: .exhaleTime)
        try c.encodeIfPresent(regressionA, forKey: .regressionA)
        try c.encodeIfPresent(regressionB, forKey: .regressionB)
        try c.encodeIfPresent(regressionk, forKey: .regressionk)
        try c.encodeIfPresent(score,       forKey: .score)
        try c.encode(comment,             forKey: .comment)
        // no need to write legacyId
    }
    
    // MARK: - convenience init for app code
    init(sessionNumber: Int,
         duration: Int,
         temperatureChange: Double,
         tempSetData: [Double],
         inhaleTime: Double,
         exhaleTime: Double,
         regressionA: Double? = nil,
         regressionB: Double? = nil,
         regressionk: Double? = nil,
         score: Double? = nil,
         comment: String = "",
         timestamp: Date = Date()) {

        self.sessionNumber     = sessionNumber
        self.duration          = duration
        self.temperatureChange = temperatureChange
        self.tempSetData       = tempSetData
        self.inhaleTime        = inhaleTime
        self.exhaleTime        = exhaleTime
        self.regressionA       = regressionA
        self.regressionB       = regressionB
        self.regressionk       = regressionk
        self.score             = score
        self.comment           = comment
    }
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
    
    func calculateScore(A: Double, B: Double, k: Double, sessionDuration: Int) -> Double? {

        let kAbs = abs(k)                       // use magnitude
        let t    = Double(sessionDuration)

        // temperature increase cannot be negative
        let predictedIncrease = max(B * (1 - exp(-kAbs * t)), 0)

        let relaxFactor = min(pow(predictedIncrease / 5.0, 0.15), 1.0)
        let speedFactor = min(pow(kAbs / 0.0050, 0.15), 1.0)

        let maxScore = min((t / 60) * 10, 100)

        let score = maxScore * relaxFactor * speedFactor
        return score.isFinite ? score : nil
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
    
    func addSession(sessionId: Int, dur: Int, tempC: Double, inhale: Double, exhale: Double, Set: [Double]) {
        guard let (A, B, k) = calculateRegressionParameters(duration: dur, tempSet: Set) else {
            print("Failed to calculate regression parameters.")
            return
        }
        let kAbs = abs(k)
        let score = calculateScore(A: A, B: B, k: k, sessionDuration: dur)
        
        // ① compute the raw score
        let rawScore = calculateScore(A: A, B: B, k: k, sessionDuration: dur)

        // ② make it “safe” by turning any non-finite into nil
        let safeScore: Double? = (rawScore?.isFinite == true) ? rawScore : nil
        
        let newSession = SessionModel(
            sessionNumber:         sessionId,
            duration:          dur,
            temperatureChange: tempC,
            tempSetData:       Set,
            inhaleTime:        inhale,
            exhaleTime:        exhale,
            regressionA:       A,
            regressionB:       B,
            regressionk:       kAbs,
            score:             safeScore,
            comment:           ""
        )

        sessionArray.append(newSession)
    }
    
    private func saveSessions() {
        // 1) Map each session to a sanitized copy
        let sanitized = sessionArray.map { original -> SessionModel in
            var s = original
            s.score        = s.score?.finiteOrNil
            s.regressionA  = s.regressionA?.finiteOrNil
            s.regressionB  = s.regressionB?.finiteOrNil
            s.regressionk  = s.regressionk?.finiteOrNil
            return s
        }

        // 2) Encode & write
        do {
            let data = try JSONEncoder().encode(sanitized)
            UserDefaults.standard.set(data, forKey: "sessionArray")
        } catch {
            print("Failed to save sessions after sanitizing: \(error)")
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
    @Published var sessionId: Int? = nil
}


class UserSettingsModel: ObservableObject {
    static let shared = UserSettingsModel()
    
    @Published var interval: Int = 5
    @Published var isCelcius:Bool = false
}

private extension Double {
    /// Returns `nil` if the value is not a finite number.
    var finiteOrNil: Double? { isFinite ? self : nil }
}

