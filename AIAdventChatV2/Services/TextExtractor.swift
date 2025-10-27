//
//  TextExtractor.swift
//  AIAdventChatV2
//
//  Text extraction service for various file formats
//

import Foundation
import PDFKit

// MARK: - Text Extractor

class TextExtractor {

    enum ExtractionError: Error {
        case fileNotFound
        case unsupportedFormat
        case readError(String)
        case emptyContent
    }

    enum FileFormat: String {
        case swift = "swift"
        case markdown = "md"
        case text = "txt"
        case pdf = "pdf"
        case json = "json"
        case xml = "xml"
        case html = "html"

        static func from(fileExtension: String) -> FileFormat? {
            return FileFormat(rawValue: fileExtension.lowercased())
        }
    }

    // MARK: - Public Methods

    /// Extract text from a file at given path
    func extractText(from filePath: String) async throws -> ExtractedText {
        let url = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ExtractionError.fileNotFound
        }

        let fileExtension = url.pathExtension
        guard let format = FileFormat.from(fileExtension: fileExtension) else {
            throw ExtractionError.unsupportedFormat
        }

        let content: String

        switch format {
        case .swift, .markdown, .text, .json, .xml:
            content = try extractPlainText(from: url)

        case .html:
            content = try extractHTML(from: url)

        case .pdf:
            content = try extractPDF(from: url)
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.emptyContent
        }

        let metadata = FileMetadata(
            filePath: filePath,
            fileName: url.lastPathComponent,
            fileExtension: fileExtension,
            format: format,
            fileSize: getFileSize(at: filePath),
            modificationDate: getModificationDate(at: filePath)
        )

        return ExtractedText(
            content: content,
            metadata: metadata
        )
    }

    /// Extract text from multiple files
    func extractTextBatch(from filePaths: [String]) async throws -> [ExtractedText] {
        var results: [ExtractedText] = []

        for filePath in filePaths {
            do {
                let extracted = try await extractText(from: filePath)
                results.append(extracted)
            } catch {
                print("⚠️ Failed to extract text from \(filePath): \(error)")
                // Continue with other files
            }
        }

        return results
    }

    // MARK: - Private Extraction Methods

    private func extractPlainText(from url: URL) throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ExtractionError.readError("Failed to read file: \(error.localizedDescription)")
        }
    }

    private func extractHTML(from url: URL) throws -> String {
        let rawHTML = try extractPlainText(from: url)
        return cleanHTML(rawHTML)
    }

    private func extractPDF(from url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.readError("Failed to open PDF document")
        }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helper Methods

    private func cleanHTML(_ html: String) -> String {
        var text = html

        // Remove script and style tags with their content
        text = text.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )

        // Remove HTML tags
        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        let entities = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–"
        ]

        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        // Clean up whitespace
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getFileSize(at path: String) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64 else {
            return 0
        }
        return fileSize
    }

    private func getModificationDate(at path: String) -> Date {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return Date()
        }
        return modificationDate
    }
}

// MARK: - Supporting Models

struct ExtractedText {
    let content: String
    let metadata: FileMetadata

    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }

    var characterCount: Int {
        return content.count
    }

    var estimatedTokenCount: Int {
        // Rough estimate: 1 token ≈ 4 characters
        return characterCount / 4
    }
}

struct FileMetadata {
    let filePath: String
    let fileName: String
    let fileExtension: String
    let format: TextExtractor.FileFormat
    let fileSize: Int64
    let modificationDate: Date

    var language: String? {
        switch format {
        case .swift:
            return "swift"
        case .json:
            return "json"
        case .xml:
            return "xml"
        case .html:
            return "html"
        default:
            return nil
        }
    }
}
