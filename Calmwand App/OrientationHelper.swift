import UIKit

/// After you set `OrientationLock.mask`, call this to animate into the new orientation.
func requestOrientationUpdate(_ mask: UIInterfaceOrientationMask) {
    guard #available(iOS 16.0, *),
          let scene = UIApplication.shared.connectedScenes
                         .first(where: { $0 is UIWindowScene }) as? UIWindowScene
    else { return }

    let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
    scene.requestGeometryUpdate(prefs) { error in
        // error is non-optional here
        print("Orientation update failed:", error.localizedDescription)
    }
}
