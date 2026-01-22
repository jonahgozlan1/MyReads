//
//  MyReadsApp.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI
import SwiftData

@main
struct MyReadsApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .modelContainer(persistenceController.container)
        }
    }
}
