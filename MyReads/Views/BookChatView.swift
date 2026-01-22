//
//  BookChatView.swift
//  MyReads
//
//  Book detail opens straight into chat with a top expandable bar.
//  Collapsed: small cover (left) + chapter selection/update. Expanded: full book info.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - BookChatView

/// Main view when opening a book: chat first, with expandable top bar for cover + chapter/update.
struct BookChatView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [Conversation]
    
    @State private var showingProgressEditor = false
    
    private var bookConversation: Conversation? {
        conversations.first { $0.bookID == book.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ExpandableBookBar(book: book, showingProgressEditor: $showingProgressEditor, modelContext: modelContext)
            
            ChatBody(book: book, conversation: bookConversation)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(book.title)
        .sheet(isPresented: $showingProgressEditor) {
            ProgressEditorView(book: book)
        }
        .task {
            await loadCoverImageIfNeeded()
        }
    }
    
    private func loadCoverImageIfNeeded() async {
        guard book.coverImageData == nil,
              let coverURL = book.coverImageURL,
              let url = URL(string: coverURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run { book.coverImageData = data }
        } catch {
            print("[BookChatView] Error loading cover: \(error.localizedDescription)")
        }
    }
}

// MARK: - ExpandableBookBar

/// Top expandable bar: collapsed = small cover + chapter/update; expanded = full book info.
private struct ExpandableBookBar: View {
    @Bindable var book: Book
    @Binding var showingProgressEditor: Bool
    var modelContext: ModelContext
    
    @State private var isExpanded = false
    
    private var chapterList: [String] { book.chapters ?? [] }
    private var hasChapterList: Bool { !chapterList.isEmpty }
    
    private var selectedChapterIndex: Int {
        guard let ch = book.currentChapter, hasChapterList,
              let i = chapterList.firstIndex(of: ch) else { return 0 }
        return i
    }
    
    /// Estimated page for chapter index (equal distribution).
    private func estimatedPage(forChapterIndex index: Int) -> Int {
        guard let total = book.totalPages, total > 0, hasChapterList else { return 0 }
        let n = chapterList.count
        let page = (index * total) / n
        return min(max(0, page), total)
    }
    
    private func selectChapter(index: Int) {
        guard index >= 0, index < chapterList.count else { return }
        book.currentChapter = chapterList[index]
        let page = estimatedPage(forChapterIndex: index)
        book.currentPage = page
        book.updateProgress(page: page)
        do {
            try modelContext.save()
        } catch {
            print("[ExpandableBookBar] Error saving chapter selection: \(error.localizedDescription)")
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse book info" : "Expand book info")
            .accessibilityHint("Double tap to toggle")
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var collapsedContent: some View {
        HStack(spacing: 12) {
            bookCoverImage(height: 56)
            
            VStack(alignment: .leading, spacing: 6) {
                chapterSection
                if let total = book.totalPages, total > 0 {
                    HStack {
                        Text("Page \(book.currentPage) of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        updateButton
                    }
                } else {
                    HStack {
                        Spacer()
                        updateButton
                    }
                }
            }
            
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                bookCoverImage(height: 100)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let total = book.totalPages, total > 0 {
                        ProgressView(value: book.readingProgress)
                            .tint(.accentColor)
                            .frame(height: 6)
                        Text("\(book.progressPercentage)% · Page \(book.currentPage) of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            
            chapterSection
            updateButton
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
    }
    
    @ViewBuilder
    private var chapterSection: some View {
        if hasChapterList {
            Menu {
                ForEach(Array(chapterList.enumerated()), id: \.offset) { index, title in
                    Button {
                        selectChapter(index: index)
                    } label: {
                        HStack {
                            Text(title)
                                .lineLimit(1)
                            if index == selectedChapterIndex {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(book.currentChapter ?? "Chapter")
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Current chapter")
        } else {
            HStack(spacing: 4) {
                Text(book.currentChapter ?? "Set chapter")
                    .font(.subheadline)
                    .foregroundStyle(book.currentChapter != nil ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var updateButton: some View {
        Button {
            showingProgressEditor = true
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        } label: {
            Text("Update")
                .font(.subheadline.weight(.medium))
        }
        .accessibilityLabel("Update progress")
    }
    
    @ViewBuilder
    private func bookCoverImage(height: CGFloat) -> some View {
        let width = height * (2.0 / 3.0)
        Group {
            if let coverData = book.coverImageData, let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let coverURL = book.coverImageURL {
                AsyncImage(url: URL(string: coverURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    BookPlaceholderView()
                }
            } else {
                BookPlaceholderView()
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - ChatBody

/// Embedded chat UI: messages + input. No nav or sheet chrome.
private struct ChatBody: View {
    let book: Book
    let conversation: Conversation?
    
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showingAPIKeyAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.messages.isEmpty {
                            WelcomeMessageView(book: book)
                                .padding(.top, 32)
                        }
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if viewModel.isSending {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            HStack(spacing: 12) {
                TextField("Ask about the book...", text: $viewModel.currentMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .disabled(viewModel.isSending)
                
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.currentMessage.isEmpty || viewModel.isSending
                            ? .gray
                            : .accentColor
                        )
                }
                .disabled(viewModel.currentMessage.isEmpty || viewModel.isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .onAppear {
            viewModel.setup(book: book, conversation: conversation, modelContext: modelContext)
            if !KeychainService.shared.hasAPIKey {
                showingAPIKeyAlert = true
            }
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please configure your OpenAI API key in Settings to use the chat feature.")
        }
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.role == .user ? Color.accentColor : Color(.systemGray5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                if message.isStreaming {
                    ProgressView().scaleEffect(0.7).padding(.top, 4)
                }
            }
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - WelcomeMessageView

private struct WelcomeMessageView: View {
    let book: Book
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 8) {
                Text("Ask About \(book.title)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("I can help you understand characters, clarify plot points, and remind you of what happened—all without spoiling what's ahead.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let container = PersistenceController.preview
    let book = Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        totalPages: 180,
        chapters: ["Chapter 1", "Chapter 2", "Chapter 3", "Chapter 4", "Chapter 5"]
    )
    book.currentChapter = "Chapter 1"
    book.currentPage = 36
    book.updateProgress(page: 36)
    container.mainContext.insert(book)
    return NavigationStack {
        BookChatView(book: book)
    }
    .modelContainer(container)
}
