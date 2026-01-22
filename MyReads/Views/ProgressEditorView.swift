//
//  ProgressEditorView.swift
//  MyReads
//
//  View for editing reading progress.
//  Supports chapter picker (when available), numeric page entry, and read-only total pages.
//

import SwiftUI
import SwiftData
import UIKit

/// View for editing reading progress.
/// Supports chapter picker (when available), numeric page entry, and read-only total pages.
/// Selecting a chapter auto-updates the page estimate when total pages are known.
struct ProgressEditorView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isPageFieldFocused: Bool
    
    @State private var currentPage: Int
    @State private var pageInputText: String
    @State private var selectedChapterIndex: Int
    @State private var manualChapterText: String
    @State private var validationError: String?
    
    private var totalPages: Int? { book.totalPages }
    private var chapterList: [String] { book.chapters ?? [] }
    private var hasChapterList: Bool { !chapterList.isEmpty }
    
    init(book: Book) {
        self.book = book
        _currentPage = State(initialValue: book.currentPage)
        _pageInputText = State(initialValue: String(book.currentPage))
        _manualChapterText = State(initialValue: book.currentChapter ?? "")
        let idx: Int = {
            guard let ch = book.currentChapter, let list = book.chapters, !list.isEmpty,
                  let i = list.firstIndex(of: ch) else { return 0 }
            return i
        }()
        _selectedChapterIndex = State(initialValue: idx)
    }
    
    /// Estimated start page for chapter at given index (equal distribution).
    private func estimatedPage(forChapterIndex index: Int) -> Int {
        guard let total = totalPages, total > 0, !chapterList.isEmpty else { return 0 }
        let n = chapterList.count
        let page = (index * total) / n
        return min(max(0, page), total)
    }
    
    /// Page value used for progress display (parsed from input, else currentPage).
    private var effectivePage: Int {
        guard let v = Int(pageInputText.trimmingCharacters(in: .whitespaces)), v >= 0 else {
            return currentPage
        }
        return v
    }
    
    private var progressFooter: String? {
        guard let total = totalPages, total > 0 else { return nil }
        let p = min(max(0, effectivePage), total)
        let progress = Double(p) / Double(total)
        return "\(Int(progress * 100))% complete"
    }
    
    private func validateAndSave() {
        validationError = nil
        let page: Int
        if let v = Int(pageInputText.trimmingCharacters(in: .whitespaces)), v >= 0 {
            page = v
        } else {
            validationError = "Enter a valid page number."
            return
        }
        if let total = totalPages, total > 0, page > total {
            validationError = "Page cannot exceed \(total)."
            return
        }
        book.currentPage = page
        if hasChapterList, selectedChapterIndex >= 0, selectedChapterIndex < chapterList.count {
            book.currentChapter = chapterList[selectedChapterIndex]
        } else {
            let trimmed = manualChapterText.trimmingCharacters(in: .whitespacesAndNewlines)
            book.currentChapter = trimmed.isEmpty ? nil : trimmed
        }
        book.updateProgress(page: page)
        do {
            try modelContext.save()
        } catch {
            print("[ProgressEditorView] Error saving progress: \(error.localizedDescription)")
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasChapterList {
                        Picker("Chapter", selection: $selectedChapterIndex) {
                            ForEach(Array(chapterList.enumerated()), id: \.offset) { index, title in
                                Text(title).tag(index)
                                    .lineLimit(1)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityLabel("Current chapter")
                        .onChange(of: selectedChapterIndex) { _, newIndex in
                            guard totalPages != nil, hasChapterList else { return }
                            let estimated = estimatedPage(forChapterIndex: newIndex)
                            currentPage = estimated
                            pageInputText = String(estimated)
                        }
                    } else {
                        HStack {
                            Text("Chapter")
                            Spacer()
                            TextField("e.g. Chapter 5", text: $manualChapterText)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Current chapter")
                        }
                    }
                    
                    HStack {
                        Text("Page")
                        Spacer()
                        TextField("0", text: $pageInputText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($isPageFieldFocused)
                            .onChange(of: pageInputText) { _, newValue in
                                if let v = Int(newValue), v >= 0 {
                                    currentPage = v
                                }
                            }
                            .accessibilityLabel("Current page number")
                    }
                    
                    if let total = totalPages, total > 0 {
                        HStack {
                            Text("Total Pages")
                            Spacer()
                            Text("\(total)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let err = validationError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Reading Progress")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !hasChapterList {
                            Text("No chapter list is available for this book. You can type your current chapter above.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let footer = progressFooter {
                            Text(footer)
                        }
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        validateAndSave()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isPageFieldFocused = false
                    }
                }
            }
        }
        .onAppear {
            pageInputText = String(currentPage)
        }
    }
}
