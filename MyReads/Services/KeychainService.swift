//
//  KeychainService.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import Foundation
import Security

/// Service for securely storing and retrieving API keys using Keychain
final class KeychainService {
    static let shared = KeychainService()
    
    private let service = "co.jonahgozlan.MyReads"
    private let openAIKeyKey = "openai_api_key"
    private let googleBooksKeyKey = "google_books_api_key"
    
    private init() {}
    
    // MARK: - OpenAI API Key Methods
    
    /// Stores an OpenAI API key securely in Keychain
    func saveAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: openAIKeyKey)
    }
    
    /// Retrieves the stored OpenAI API key from Keychain
    func getAPIKey() -> String? {
        getAPIKey(for: openAIKeyKey)
    }
    
    /// Deletes the stored OpenAI API key from Keychain
    func deleteAPIKey() {
        deleteAPIKey(for: openAIKeyKey)
    }
    
    /// Checks if an OpenAI API key is stored
    var hasAPIKey: Bool {
        getAPIKey() != nil
    }
    
    // MARK: - Google Books API Key Methods
    
    /// Stores a Google Books API key securely in Keychain
    func saveGoogleBooksAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: googleBooksKeyKey)
    }
    
    /// Retrieves the stored Google Books API key from Keychain
    func getGoogleBooksAPIKey() -> String? {
        getAPIKey(for: googleBooksKeyKey)
    }
    
    /// Deletes the stored Google Books API key from Keychain
    func deleteGoogleBooksAPIKey() {
        deleteAPIKey(for: googleBooksKeyKey)
    }
    
    /// Checks if a Google Books API key is stored
    var hasGoogleBooksAPIKey: Bool {
        getGoogleBooksAPIKey() != nil
    }
    
    // MARK: - Private Helper Methods
    
    /// Generic method to store an API key securely in Keychain
    private func saveAPIKey(_ key: String, for account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        
        // Delete existing key if present
        deleteAPIKey(for: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveError(status)
        }
    }
    
    /// Generic method to retrieve an API key from Keychain
    private func getAPIKey(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Generic method to delete an API key from Keychain
    private func deleteAPIKey(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case encodingError
    case saveError(OSStatus)
    case retrievalError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Failed to encode API key"
        case .saveError(let status):
            return "Failed to save API key: \(status)"
        case .retrievalError(let status):
            return "Failed to retrieve API key: \(status)"
        }
    }
}
