//
//  GridApp.swift
//  Grid
//
//  Created by AJ Picard on 7/31/25.
//

import SwiftUI

@main
struct GridApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    print("App launched successfully!")
                }
        }
    }
}
