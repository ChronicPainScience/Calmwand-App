//
//  Bundle.swift
//  Calmwand App
//
//  Created by hansma lab on 7/9/25.
//


//  Bundle+Version.swift  (any filename works)
import Foundation

extension Bundle {
    /// e.g. “1.4.2”
    var versionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// e.g. “567”
    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }
}
