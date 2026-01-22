//
//  Book.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import SwiftData

/// Represents a book in the user's library
@Model
final class Book {
    // Basic Information
    var id: UUID
    var title: String
    var author: String
    var isbn: String?
    var coverImageURL: String?
    var coverImageData: Data? // Cached cover image
    
    // Reading Progress
    var currentPage: Int
    var currentChapter: String?
    var totalPages: Int?
    var readingProgress: Double // 0.0 to 1.0
    
    // Dates
    var dateAdded: Date
    var dateStarted: Date?
    var dateFinished: Date?
    
    // Book Content (for AI context)
    var fullText: String? // Full book text for AI reference
    var summary: String? // Book summary/description
    var chapters: [String]? // Table of contents/chapters list
    
    // Relationships
    @Relationship(deleteRule: .cascade) var conversations: [Conversation]?
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageURL: String? = nil,
        totalPages: Int? = nil,
        summary: String? = nil,
        chapters: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageURL = coverImageURL
        self.totalPages = totalPages
        self.summary = summary
        self.chapters = chapters
        self.currentPage = 0
        self.readingProgress = 0.0
        self.dateAdded = Date()
        self.conversations = []
    }
    
    /// Updates reading progress based on current page
    func updateProgress(page: Int) {
        self.currentPage = page
        if let totalPages = totalPages, totalPages > 0 {
            self.readingProgress = min(1.0, Double(page) / Double(totalPages))
        }
    }
    
    /// Gets text content up to current reading position (for spoiler prevention)
    func getTextUpToCurrentPosition() -> String? {
        guard let fullText = fullText else { return nil }
        guard currentPage > 0, let totalPages = totalPages, totalPages > 0 else {
            return nil
        }
        
        // Calculate approximate position in text
        let progressRatio = Double(currentPage) / Double(totalPages)
        let textLength = fullText.count
        let cutoffIndex = Int(Double(textLength) * progressRatio)
        
        return String(fullText.prefix(cutoffIndex))
    }
    
    /// Computed property for display
    var displayTitle: String {
        title
    }
    
    /// Computed property for author display
    var displayAuthor: String {
        author
    }
    
    /// Computed property for progress percentage
    var progressPercentage: Int {
        Int(readingProgress * 100)
    }
}
