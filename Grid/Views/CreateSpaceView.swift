//
//  CreateSpaceView.swift
//  Grid
//
//  Created by AJ Picard on 7/31/25.
//

import SwiftUI
import CoreData

struct CreateSpaceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var gridName = ""
    @State private var navigateToHome = false
    var navigateAfterCreate: Bool = true

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
            
                Spacer()
                
                // Main content area
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Name your ")
                            .font(.title)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        + Text("Grid")
                            .font(.title)
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.8))
                        + Text(": ")
                            .font(.title)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    }
                    
                    TextField("Picard", text: $gridName)
                        .font(.title)
                        .foregroundColor(.gray)
                        .textFieldStyle(PlainTextFieldStyle())
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bottom section with continue button
                HStack {
                    Spacer()
                    
                    if !gridName.isEmpty {
                        Button(action: {
                            createSpaceAndNavigate()
                        }) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.3, green: 0.2, blue: 0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "arrow.right")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                )
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.8).opacity(0.3), radius: 50, x: 0, y: 10)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.3), value: gridName.isEmpty)
            }
        }
        .background(Color("backgroundPurple"))
        .fullScreenCover(isPresented: $navigateToHome) {
            HomeView()
        }
    }
    
    private func createSpaceAndNavigate() {
        withAnimation {
            let newSpace = Space(context: viewContext)
            newSpace.id = UUID()
            newSpace.name = gridName
            newSpace.createdAt = Date()
            
            // Create a default owner member
            let owner = Member(context: viewContext)
            owner.id = UUID()
            owner.name = "Owner"
            owner.email = "owner@example.com"
            owner.isOwner = true
            owner.joinedAt = Date()
            owner.space = newSpace
            
            do {
                try viewContext.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if navigateAfterCreate {
                        navigateToHome = true
                    } else {
                        dismiss()
                    }
                }
            } catch {
                print("Error creating space: \(error)")
            }
        }
    }
}

#Preview {
    CreateSpaceView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}