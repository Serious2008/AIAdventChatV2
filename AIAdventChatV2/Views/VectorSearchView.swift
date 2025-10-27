//
//  VectorSearchView.swift
//  AIAdventChatV2
//
//  UI for vector search document indexing and search
//

import SwiftUI

struct VectorSearchView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var selectedTab: Int
    @State private var searchQuery: String = ""
    @State private var projectPath: String = ""
    @State private var showingFilePicker: Bool = false
    @State private var includeSwift: Bool = true
    @State private var includeMarkdown: Bool = true
    @State private var includeText: Bool = true
    @State private var filterFileType: String = "all" // all, swift, markdown, text

    var filteredSearchResults: [SearchResult] {
        guard filterFileType != "all" else {
            return viewModel.searchResults
        }

        return viewModel.searchResults.filter { result in
            switch filterFileType {
            case "swift":
                return result.chunk.metadata.fileType == .swift
            case "markdown":
                return result.chunk.metadata.fileType == .markdown
            case "text":
                return result.chunk.metadata.fileType == .text
            default:
                return true
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vector Search")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Index and search through your project documentation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Statistics Section
                if let stats = viewModel.indexingStatistics {
                    GroupBox(label: Label("Index Statistics", systemImage: "chart.bar.fill")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Documents:")
                                Spacer()
                                Text("\(stats.totalDocuments)")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Chunks:")
                                Spacer()
                                Text("\(stats.totalChunks)")
                                    .fontWeight(.semibold)
                            }

                            if stats.processingTime > 0 {
                                HStack {
                                    Text("Processing Time:")
                                    Spacer()
                                    Text(String(format: "%.1fs", stats.processingTime))
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .font(.body)
                    }
                    .padding(.horizontal)
                }

                // Indexing Section
                GroupBox(label: Label("Indexing", systemImage: "square.and.arrow.down.fill")) {
                    VStack(spacing: 12) {
                        // Project Path Input
                        HStack {
                            TextField("Project path", text: $projectPath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: {
                                // Set default project path
                                projectPath = "/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2"
                            }) {
                                Image(systemName: "folder.fill")
                            }
                            .buttonStyle(.bordered)
                        }

                        // File type selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("File types:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 16) {
                                Toggle("Swift", isOn: $includeSwift)
                                    .toggleStyle(.checkbox)
                                Toggle("Markdown", isOn: $includeMarkdown)
                                    .toggleStyle(.checkbox)
                                Toggle("Text", isOn: $includeText)
                                    .toggleStyle(.checkbox)
                            }
                            .font(.caption)
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                guard !projectPath.isEmpty else { return }
                                var extensions: [String] = []
                                if includeSwift { extensions.append("swift") }
                                if includeMarkdown { extensions.append("md") }
                                if includeText { extensions.append("txt") }

                                viewModel.indexDirectory(directoryPath: projectPath, fileExtensions: extensions)
                            }) {
                                Label("Index Directory", systemImage: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(projectPath.isEmpty || viewModel.isIndexing || (!includeSwift && !includeMarkdown && !includeText))

                            Button(action: {
                                viewModel.clearSearchIndex()
                            }) {
                                Label("Clear Index", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(viewModel.isIndexing)
                        }

                        if viewModel.isIndexing {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())

                                Text(viewModel.indexingProgress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if !viewModel.indexingProgress.isEmpty {
                            Text(viewModel.indexingProgress)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal)

                // Search Section
                GroupBox(label: Label("Search", systemImage: "magnifyingglass")) {
                    VStack(spacing: 12) {
                        HStack {
                            TextField("Search query...", text: $searchQuery)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Picker("Type", selection: $filterFileType) {
                                Text("All").tag("all")
                                Text("Swift").tag("swift")
                                Text("Markdown").tag("markdown")
                                Text("Text").tag("text")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)

                            Button(action: {
                                viewModel.searchDocuments(query: searchQuery)
                            }) {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(searchQuery.isEmpty || viewModel.isSearching)
                        }

                        if viewModel.isSearching {
                            ProgressView("Searching...")
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .padding(.horizontal)

                // Search Results
                if !viewModel.searchResults.isEmpty {
                    let filteredResults = filteredSearchResults
                    GroupBox(label: Label("Results (\(filteredResults.count)/\(viewModel.searchResults.count))", systemImage: "list.bullet")) {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredResults) { result in
                                    SearchResultCard(result: result, onAsk: {
                                        viewModel.askAboutSearchResult(result)
                                        selectedTab = 0 // Switch to Chat tab
                                    }, onCopy: {
                                        viewModel.copySearchResult(result)
                                    }, onUse: {
                                        viewModel.useSearchResult(result)
                                        selectedTab = 0 // Switch to Chat tab
                                    })
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 400)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Vector Search")
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    let onAsk: () -> Void
    let onCopy: () -> Void
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.chunk.fileName)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(result.rank)", systemImage: "number")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label(String(format: "%.1f%%", result.similarity * 100), systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundColor(similarityColor(result.similarity))

                        if let language = result.chunk.metadata.language {
                            Text(language.uppercased())
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onAsk) {
                        Label("Ask", systemImage: "questionmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Ask Claude about this code")

                    Button(action: onCopy) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy to clipboard")

                    Button(action: onUse) {
                        Label("Insert", systemImage: "arrow.right.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Insert into chat input")
                }
            }

            // Preview
            Text(result.preview)
                .font(.body)
                .foregroundColor(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

            // Metadata
            HStack(spacing: 12) {
                Label("\(result.chunk.content.count) chars", systemImage: "text.alignleft")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(result.chunk.metadata.tokenCount) tokens", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(result.chunk.metadata.fileType.rawValue, systemImage: "doc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func similarityColor(_ similarity: Double) -> Color {
        if similarity > 0.8 {
            return .green
        } else if similarity > 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VectorSearchView(viewModel: ChatViewModel(settings: Settings()), selectedTab: .constant(4))
}
