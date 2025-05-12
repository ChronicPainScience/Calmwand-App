import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]
  let applicationActivities: [UIActivity]? = nil

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: applicationActivities
    )

    // Present as a pageSheet with a medium‐height detent
    controller.modalPresentationStyle = .pageSheet
    if let sheet = controller.sheetPresentationController {
      sheet.detents = [.medium()]
      sheet.prefersGrabberVisible = true
    }

    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // nothing needed here
  }
}
