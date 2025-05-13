import SwiftUI
import PDFKit

/// Shows your “How to use calmwand.pdf” from the bundle’s files folder.
struct HowToUseView: View {
    var body: some View {
        Group {
            if let url = Bundle.main.url(
                        forResource: "How to use calmwand",
                        withExtension: "pdf",
                        subdirectory: "files"),
               let document = PDFDocument(url: url) {
                
                PDFKitView(document: document)
                    .edgesIgnoringSafeArea(.all)
            }
            else {
                Text("Unable to load guide.")
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("How to Use CalmWand")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Wraps PDFKit’s PDFView for SwiftUI.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage      // one page at a time
        pdfView.displayDirection = .horizontal // swipe left/right
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) { }
}