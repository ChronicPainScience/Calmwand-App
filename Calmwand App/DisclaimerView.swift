import SwiftUI

struct DisclaimerView: View {
    // Binding to control the presentation of the disclaimer
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Disclaimer")
                .font(.largeTitle)
                .bold()
            
            Text("This app is intended for informational purposes only and is not a substitute for professional medical advice. Always consult your doctor or other qualified health professional regarding any medical condition or treatment before making decisions based on this app's data.")
                .padding()
            
            // Additional study consent message
            Text("By using this app, you consent to be a part of the ______ study.")
                .padding()
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Button to dismiss and remember the user's choice permanently.
            Button(action: {
                UserDefaults.standard.set(true, forKey: "didAcceptDisclaimer")
                isPresented = false
            }) {
                Text("Don't show again")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Button to dismiss without saving the preference.
            Button(action: {
                isPresented = false
            }) {
                Text("I Understand")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

struct DisclaimerView_Previews: PreviewProvider {
    @State static var isPresented = true
    static var previews: some View {
        DisclaimerView(isPresented: $isPresented)
    }
}

