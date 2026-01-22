//
//  SettingsView.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var showingAPIKeyField = false
    @State private var saveError: String?
    @State private var saveSuccess = false
    
    private let keychainService = KeychainService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if showingAPIKeyField {
                        SecureField("OpenAI API Key", text: $apiKey)
                            .textContentType(.password)
                        
                        Button("Save API Key") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                        
                        if let error = saveError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        if saveSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("API key saved successfully")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    } else {
                        HStack {
                            Text("OpenAI API Key")
                            
                            Spacer()
                            
                            if keychainService.hasAPIKey {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Configured")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Not Set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Button(keychainService.hasAPIKey ? "Update API Key" : "Add API Key") {
                            showingAPIKeyField = true
                            if keychainService.hasAPIKey {
                                apiKey = keychainService.getAPIKey() ?? ""
                            }
                        }
                    }
                } header: {
                    Text("AI Configuration")
                } footer: {
                    Text("Your API key is stored securely in Keychain and never shared. Get your API key from platform.openai.com")
                }
                
                Section {
                    HStack {
                        Text("iCloud Sync")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    
                    Text("Your books and conversations sync automatically across your devices using iCloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Data & Sync")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if keychainService.hasAPIKey {
                    // Don't show the key, just indicate it's set
                    showingAPIKeyField = false
                }
            }
        }
    }
    
    private func saveAPIKey() {
        saveError = nil
        saveSuccess = false
        
        do {
            try keychainService.saveAPIKey(apiKey)
            saveSuccess = true
            showingAPIKeyField = false
            apiKey = ""
            
            // Clear success message after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    saveSuccess = false
                }
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
}
