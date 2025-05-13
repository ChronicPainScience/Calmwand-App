// OrientationLock.swift
import UIKit

/// A global, mutable place to store which orientations are allowed.
struct OrientationLock {
    /// Default: portrait only
    static var mask: UIInterfaceOrientationMask = .portrait
}