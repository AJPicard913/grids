import SwiftUI

struct CustomNavBar: View {
    @ObservedObject var space: Space
    var onSpaceTapped: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {}) {
                Image("gridIcon") // Assuming you have a grid icon in your assets
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            
            Spacer()
            
            VStack {
                Button(action: onSpaceTapped) {
                    Text(space.name ?? "Space")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Grid")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top, 50)
        .padding(.bottom, 10)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.top))
    }
}