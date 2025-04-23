//
//  InfoView.swift
//  Calmwand App
//
//  Created by hansma lab on 2/24/25.
//


import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Contact")) {
                    Text("For any issues or inquiries, please contact:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("chronicpainscience@ucsb.edu")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            if let url = URL(string: "mailto: chronicpainscience@ucsb.edu") {
                                UIApplication.shared.open(url)
                            }
                        }
                }
                
                Section(header: Text("Extended Medical Disclaimer")) {
                    // Placeholder for your extended disclaimer text.
                    Text("This application is provided solely as a viewing platform for biofeedback data collected by the CalmWand. This application does not gather, process, or analyze any personal medical data, and it does not offer clinical diagnostic or therapeutic services.\nThe information displayed within this application is intended for research and informational purposes only. It is not intended to substitute for professional medical advice, diagnosis, or treatment. Under no circumstances should the data provided be used as the sole basis for any medical decision-making or changes to your treatment regimen. All data is derived from an external device subject to inherent technological limitations, and the interpretation of such data requires a nuanced understanding that only a qualified healthcare professional can provide. \nUsers are strongly advised to consult with their doctor or another licensed healthcare provider before making any decisions related to their health or treatment based on the information presented by this application. Should you experience any adverse health symptoms or require immediate medical assistance, please contact a healthcare professional without delay. Participation in this study and the use of this application indicate that you fully understand and accept these limitations. \nBy using this application, you acknowledge that it is part of an ongoing study and that you are not relying on it for any clinical or diagnostic purposes. The developers, study organizers, and any affiliated parties disclaim any liability for any actions taken based on the information displayed herein. It is your responsibility to consult a qualified healthcare provider regarding any medical concerns or conditions. \nYour continued use of this application confirms your consent to participate in the study under the terms outlined above, and your agreement that the data provided is for informational purposes only, not as a substitute for professional medical judgment.")
                        .foregroundColor(.primary)
                        .padding(.vertical, 10)
                }
                
                Section(header: Text("Use Guide")) {
                    // Placeholder for your use guide text.
                    Text("Use guide information goes here.")
                        .foregroundColor(.primary)
                        .padding(.vertical, 10)
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Info")
        }
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}
