import SwiftUI
import PDFKit

struct HowToUseView: View {
    // PDF filename (top‐level bundle)
    private let pdfName = "useguide"

    var body: some View {
        Group {
            if let url = Bundle.main.url(
                        forResource: pdfName,
                        withExtension: "pdf") {
                
                PDFKitView(url: url)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Unable to load guide.")
                    .foregroundColor(.red)
            }
        }
        .navigationBarTitle("How to Use", displayMode: .inline)
        .onAppear {
            // 1) allow landscape only
            OrientationLock.mask = [.landscapeLeft, .landscapeRight]
            requestOrientationUpdate([.landscapeLeft, .landscapeRight])
        }
        .onDisappear {
            // 2) revert to portrait only
            OrientationLock.mask = .portrait
            // delay slightly so the PDF’s VC is offscreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                requestOrientationUpdate(.portrait)
            }
        }
    }
}

/// Wraps PDFKit’s PDFView into SwiftUI with two‐page horizontal swipe.
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document         = PDFDocument(url: url)
        pdfView.autoScales       = true
        pdfView.displayMode      = .twoUp
        pdfView.displaysAsBook   = true
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: nil)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

