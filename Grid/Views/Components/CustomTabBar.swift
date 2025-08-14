import SwiftUI

struct CustomTabBar: View {
    var body: some View {
        HStack {
            // Tab Bar
            HStack(spacing: 30) {
                Button(action: {}) {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .foregroundColor(Color("primaryPurple"))
                }
                Button(action: {}) {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(30)
            .shadow(radius: 10)
            
            Spacer()
            
            // Create Button
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color("primaryPurple"))
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}