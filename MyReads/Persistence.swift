//
//  Persistence.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftData
import Foundation

/// Manages SwiftData persistence with CloudKit sync
final class PersistenceController {
    static let shared = PersistenceController()
    
    let container: ModelContainer
    
    init() {
        let schema = Schema([
            Book.self,
            Conversation.self,
            Message.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Preview container for SwiftUI previews
    @MainActor
    static var preview: ModelContainer = {
        let schema = Schema([
            Book.self,
            Conversation.self,
            Message.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            // Add sample data for previews
            let sampleBook = Book(
                title: "The Great Gatsby",
                author: "F. Scott Fitzgerald",
                totalPages: 180
            )
            sampleBook.currentPage = 45
            sampleBook.updateProgress(page: 45)
            
            container.mainContext.insert(sampleBook)
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error.localizedDescription)")
        }
    }()
}
