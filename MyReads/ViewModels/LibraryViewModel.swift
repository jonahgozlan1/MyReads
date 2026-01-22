//
//  LibraryViewModel.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import SwiftData
import SwiftUI

/// ViewModel for the main library view
@Observable
final class LibraryViewModel {
    var books: [Book] = []
    var searchText: String = ""
    var isSearching: Bool = false
    var searchResults: [BookSearchResult] = []
    var isLoadingSearch: Bool = false
    var searchError: String?
    
    private let bookSearchService = BookSearchService.shared
    
    /// Searches for books using Open Library API
    func searchBooks() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isLoadingSearch = true
        searchError = nil
        
        do {
            let results = try await bookSearchService.searchBooks(query: searchText)
            await MainActor.run {
                self.searchResults = results
                self.isLoadingSearch = false
            }
        } catch {
            await MainActor.run {
                self.searchError = error.localizedDescription
                self.isLoadingSearch = false
            }
        }
    }
    
    /// Adds a book from search results to the library
    func addBook(_ searchResult: BookSearchResult, modelContext: ModelContext) async {
        // Get detailed book information including chapters
        let details = try? await bookSearchService.getBookDetails(bookId: searchResult.id)
        
        let book = Book(
            title: searchResult.title,
            author: searchResult.author,
            isbn: searchResult.isbn ?? details?.isbn,
            coverImageURL: searchResult.coverImageURL ?? details?.coverImageURL,
            totalPages: details?.numberOfPages,
            summary: details?.description,
            chapters: details?.chapters
        )
        
        modelContext.insert(book)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving book: \(error.localizedDescription)")
        }
    }
    
    /// Deletes a book from the library
    func deleteBook(_ book: Book, modelContext: ModelContext) {
        withAnimation {
            modelContext.delete(book)
            
            do {
                try modelContext.save()
            } catch {
                print("Error deleting book: \(error.localizedDescription)")
            }
        }
    }
}
