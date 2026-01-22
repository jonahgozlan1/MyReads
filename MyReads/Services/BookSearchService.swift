//
//  BookSearchService.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation

/// Service for searching books using Google Books API (primary) and Open Library (for table of contents)
/// Google Books API provides better data quality for: author, title, pages, covers
/// Open Library is used as fallback for table of contents when available
@MainActor
final class BookSearchService {
    static let shared = BookSearchService()
    
    // Google Books API (primary) - Free API key recommended: https://console.cloud.google.com/apis/credentials
    // Note: Google Books API works without a key but has rate limits. API key recommended for production.
    private let googleBooksBaseURL = "https://www.googleapis.com/books/v1"
    
    // Open Library API (for table of contents fallback)
    private let openLibraryBaseURL = "https://openlibrary.org"
    
    private let keychainService = KeychainService.shared
    
    private init() {}
    
    /// Gets Google Books API key from Keychain or returns nil
    /// Google Books API works without a key but has rate limits (1000 requests/day)
    private func getGoogleBooksAPIKey() -> String? {
        return keychainService.getGoogleBooksAPIKey()
    }
    
    /// Searches for books by title and/or author using Google Books API
    func searchBooks(query: String) async throws -> [BookSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw BookSearchError.invalidURL
        }
        
        // Build Google Books API URL
        var urlString = "\(googleBooksBaseURL)/volumes?q=\(encodedQuery)&maxResults=20&printType=books"
        if let apiKey = getGoogleBooksAPIKey() {
            urlString += "&key=\(apiKey)"
        }
        
        guard let url = URL(string: urlString) else {
            throw BookSearchError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookSearchError.networkError
        }
        
        let searchResponse = try JSONDecoder().decode(GoogleBooksSearchResponse.self, from: data)
        
        return searchResponse.items?.compactMap { item in
            BookSearchResult(from: item)
        } ?? []
    }
    
    /// Gets detailed book information including cover image, pages, and table of contents
    func getBookDetails(bookId: String) async throws -> BookDetails? {
        // Try Google Books first
        var urlString = "\(googleBooksBaseURL)/volumes/\(bookId)"
        if let apiKey = getGoogleBooksAPIKey() {
            urlString += "?key=\(apiKey)"
        }
        
        guard let url = URL(string: urlString) else {
            throw BookSearchError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let volume = try JSONDecoder().decode(GoogleBooksVolume.self, from: data)
        let volumeInfo = volume.volumeInfo
        
        // Get table of contents from Open Library if available (using ISBN)
        var chapters: [String]? = nil
        if let isbn = volumeInfo.industryIdentifiers?.first(where: { $0.type == "ISBN_13" || $0.type == "ISBN_10" })?.identifier {
            chapters = try? await getTableOfContentsFromOpenLibrary(isbn: isbn)
        }
        
        return BookDetails(
            title: volumeInfo.title ?? "",
            author: volumeInfo.authors?.joined(separator: ", ") ?? "Unknown Author",
            isbn: volumeInfo.industryIdentifiers?.first(where: { $0.type == "ISBN_13" })?.identifier ?? 
                  volumeInfo.industryIdentifiers?.first(where: { $0.type == "ISBN_10" })?.identifier,
            coverImageURL: volumeInfo.imageLinks?.thumbnail?.replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "&edge=curl", with: "")
                .replacingOccurrences(of: "zoom=1", with: "zoom=2"), // Higher quality
            description: volumeInfo.description,
            numberOfPages: volumeInfo.pageCount,
            chapters: chapters
        )
    }
    
    /// Gets table of contents from Open Library (fallback when Google Books doesn't have it)
    private func getTableOfContentsFromOpenLibrary(isbn: String) async throws -> [String]? {
        // Search Open Library by ISBN
        guard let encodedISBN = isbn.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "\(openLibraryBaseURL)/search.json?q=isbn:\(encodedISBN)&limit=1") else {
            return nil
        }
        
        let (searchData, searchResponse) = try await URLSession.shared.data(from: searchURL)
        
        guard let httpResponse = searchResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        let searchResult = try? JSONDecoder().decode(OpenLibrarySearchResponse.self, from: searchData)
        guard let openLibraryKey = searchResult?.docs.first?.key else {
            return nil
        }
        
        // Get book details with table of contents
        guard let detailsURL = URL(string: "\(openLibraryBaseURL)\(openLibraryKey).json?jscmd=details") else {
            return nil
        }
        
        let (detailsData, detailsResponse) = try await URLSession.shared.data(from: detailsURL)
        
        guard let detailsHttpResponse = detailsResponse as? HTTPURLResponse,
              detailsHttpResponse.statusCode == 200 else {
            return nil
        }
        
        // Parse table of contents from Open Library response
        if let json = try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any],
           let details = json["details"] as? [String: Any],
           let tableOfContents = details["table_of_contents"] as? [[String: Any]] {
            return tableOfContents.compactMap { entry in
                entry["title"] as? String ?? entry["level"] as? String
            }
        }
        
        return nil
    }
    
    /// Legacy method for backward compatibility - converts Google Books ID to details
    func getBookDetails(openLibraryKey: String) async throws -> BookDetails? {
        // This is a legacy method - if openLibraryKey is actually a Google Books ID, use it
        // Otherwise, try to find the book by searching Open Library
        return try await getBookDetails(bookId: openLibraryKey)
    }
}

// MARK: - Data Models

struct BookSearchResult: Identifiable {
    let id: String // Google Books volume ID
    let title: String
    let author: String
    let coverImageURL: String?
    let openLibraryKey: String // Kept for backward compatibility, now stores Google Books ID
    let isbn: String?
    
    fileprivate init?(from item: GoogleBooksItem) {
        let volumeInfo = item.volumeInfo
        
        guard let title = volumeInfo.title else { return nil }
        
        self.id = item.id
        self.title = title
        self.author = volumeInfo.authors?.joined(separator: ", ") ?? "Unknown Author"
        self.openLibraryKey = item.id // Store Google Books ID for getBookDetails
        
        // Get high-quality cover image URL
        if let thumbnail = volumeInfo.imageLinks?.thumbnail {
            // Convert to higher quality and ensure HTTPS
            self.coverImageURL = thumbnail
                .replacingOccurrences(of: "http://", with: "https://")
                .replacingOccurrences(of: "&edge=curl", with: "")
                .replacingOccurrences(of: "zoom=1", with: "zoom=2")
        } else {
            self.coverImageURL = nil
        }
        
        // Get ISBN-13 first, fallback to ISBN-10
        self.isbn = volumeInfo.industryIdentifiers?.first(where: { $0.type == "ISBN_13" })?.identifier ??
                     volumeInfo.industryIdentifiers?.first(where: { $0.type == "ISBN_10" })?.identifier
    }
}

struct BookDetails {
    let title: String
    let author: String
    let isbn: String?
    let coverImageURL: String?
    let description: String?
    let numberOfPages: Int?
    let chapters: [String]? // Table of contents/chapters when available
}

// MARK: - Google Books API Models

private struct GoogleBooksSearchResponse: Codable {
    let kind: String?
    let totalItems: Int?
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Codable {
    let id: String
    let volumeInfo: GoogleBooksVolumeInfo
}

private struct GoogleBooksVolume: Codable {
    let id: String
    let volumeInfo: GoogleBooksVolumeInfo
}

private struct GoogleBooksVolumeInfo: Codable {
    let title: String?
    let authors: [String]?
    let publisher: String?
    let publishedDate: String?
    let description: String?
    let industryIdentifiers: [GoogleBooksIndustryIdentifier]?
    let pageCount: Int?
    let categories: [String]?
    let averageRating: Double?
    let ratingsCount: Int?
    let imageLinks: GoogleBooksImageLinks?
    let language: String?
}

private struct GoogleBooksIndustryIdentifier: Codable {
    let type: String // "ISBN_13" or "ISBN_10"
    let identifier: String
}

private struct GoogleBooksImageLinks: Codable {
    let smallThumbnail: String?
    let thumbnail: String?
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
}

// MARK: - Open Library API Models (for table of contents fallback)

private struct OpenLibrarySearchResponse: Codable {
    let docs: [OpenLibraryDoc]
}

private struct OpenLibraryDoc: Codable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let coverI: Int?
    let isbn: [String]?
}

enum BookSearchError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .networkError:
            return "Network error occurred"
        case .decodingError:
            return "Failed to decode search results"
        }
    }
}
