import SwiftUI

struct GridTemplatesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                Text("Template Page")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .navigationTitle("Grid Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}