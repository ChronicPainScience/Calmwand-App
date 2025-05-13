//
//  AppDelegate.swift
//  Calmwand App
//
//  Created by hansma lab on 5/13/25.
//


// AppDelegate.swift
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    OrientationLock.mask
  }
}
