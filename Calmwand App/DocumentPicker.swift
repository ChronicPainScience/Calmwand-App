//
//  DocumentPicker.swift
//  Calmwand App
//
//  Created by hansma lab on 5/12/25.
//


// DocumentPicker.swift
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
  let fileURL: URL

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    // Prepare the picker for exporting (copying) your file
    let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
    
    // Show as a page sheet and allow a medium-height detent
    picker.modalPresentationStyle = .pageSheet
    if let sheet = picker.sheetPresentationController {
      sheet.detents = [.medium()]
    }
    
    return picker
  }

  func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    // nothing to do here
  }
}