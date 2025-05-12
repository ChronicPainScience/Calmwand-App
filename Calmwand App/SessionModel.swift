//
//  SessionModel.swift
//  Calmwand App
//
//  Created by hansma lab on 5/12/25.
//


struct SessionModel: Identifiable, Codable {
    var id        = UUID()
    var timestamp = Date()          // ← NEW field

    let duration: Int
    let temperatureChange: Double
    let tempSetData: [Double]
    let inhaleTime: Double
    let exhaleTime: Double
    // … regression stuff …
}