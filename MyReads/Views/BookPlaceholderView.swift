//
//  BookPlaceholderView.swift
//  MyReads
//
//  Created by Jonah Gozlan on 1/22/26.
//

import SwiftUI

/// Placeholder view for books without covers
struct BookPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "book.closed.fill")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.5))
        }
    }
}
