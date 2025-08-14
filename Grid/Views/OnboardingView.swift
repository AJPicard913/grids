//
//  OnboardingView.swift
//  Grid
//
//  Created by AJ Picard on 7/31/25.
//

import SwiftUI

struct OnboardingView: View {
    @State private var navigateToCreateSpace = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // Grid Layout
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        // Left column
                        VStack(spacing: 8) {
                            // Goals card
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.7, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.5, blue: 0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: .infinity)
                                .overlay(
                                    VStack {
                                        HStack {
                                            Text("Goals")
                                                .font(.title2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding(.leading, 20)
                                        Spacer()
                                    }
                                       
                                        .padding(.top, 16)
                                    
                                )
                            
                            // Memories card
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.3, green: 0.2, blue: 0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: .infinity)
                                .overlay(
                                    VStack {
                                        HStack {
                                            Text("Memories")
                                                .font(.title2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding(.leading, 20)
                                        Spacer()
                                    }
                                       
                                        .padding(.top, 16)
                                )
                            
                            
                            // Recipes card
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.35, green: 0.25, blue: 0.75), Color(red: 0.25, green: 0.15, blue: 0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: .infinity)
                                .overlay(
                                    VStack {
                                        HStack {
                                            Text("Recipes")
                                                .font(.title2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .padding(.leading, 20)
                                        Spacer()
                                    }
                                       
                                        .padding(.top, 16)
                                )
                        }
                        
                        // Right column - Bucket List
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.8, green: 0.7, blue: 1.0), Color(red: 0.7, green: 0.6, blue: 0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: .infinity)
                            .overlay(
                                VStack {
                                    HStack {
                                        Text("Bucket List")
                                            .font(.title2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    Spacer()
                                }
                                   
                                    .padding(.top, 16)
                            )
                    }
                    
                    // Bottom wide card - Chores
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.1, blue: 0.35), Color(red: 0.1, green: 0.05, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                HStack {
                                    Text("Chores")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.leading, 20)
                                Spacer()
                            }
                               
                                .padding(.top, 16)
                        )
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 16)
                
                // Bottom section
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Welcome to ")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                            + Text("Grid")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.8))
                            + Text(".")
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                        }
                        
                        Text("Your family dashboard to manage everything or reference anything.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .lineLimit(4)
                            
                    }
                    
                    Spacer()
                    
                    // Continue button
                    Button(action: {
                        navigateToCreateSpace = true
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        .fullScreenCover(isPresented: $navigateToCreateSpace) {
            CreateSpaceView()
        }
    }
}

#Preview {
    OnboardingView()
}