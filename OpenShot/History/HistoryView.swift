// HistoryView.swift
// OpenShot
//
// SwiftUI grid view of past captures with filtering, context menus,
// and inline thumbnails. Uses SwiftData @Query for live updates.

import SwiftUI
import SwiftData

// MARK: - History View

struct HistoryView: View {

    @Query(sort: \CaptureRecord.timestamp, order: .reverse)
    private var records: [CaptureRecord]

    @Environment(\.modelContext) private var modelContext

    @State private var selectedFilter: CaptureFilter = .all
    @State private var searchText: String = ""
    @State private var selectedRecordID: UUID?

    // MARK: Filter Enum

    enum CaptureFilter: String, CaseIterable {
        case all = "All"
        case screenshots = "Screenshots"
        case recordings = "Recordings"
        case gifs = "GIFs"
        case ocr = "OCR"

        var captureType: String? {
            switch self {
            case .all: return nil
            case .screenshots: return "screenshot"
            case .recordings: return "recording"
            case .gifs: return "gif"
            case .ocr: return "ocr"
            }
        }
    }

    // MARK: Computed

    private var filteredRecords: [CaptureRecord] {
        records.filter { record in
            // Filter by type.
            if let requiredType = selectedFilter.captureType,
               record.captureType != requiredType {
                return false
            }
            // Filter by search text (match tags or file path).
            if !searchText.isEmpty {
                let lowered = searchText.lowercased()
                let matchesTags = record.tags.lowercased().contains(lowered)
                let matchesPath = record.filePath.lowercased().contains(lowered)
                if !matchesTags && !matchesPath {
                    return false
                }
            }
            return true
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(CaptureFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            .accessibilityLabel("Filter captures by type")

            Spacer()

            Text("\(filteredRecords.count) items")
                .foregroundStyle(.secondary)
                .font(.caption)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: Content

    @ViewBuilder
    private var contentArea: some View {
        if filteredRecords.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredRecords, id: \.id) { record in
                        CaptureCell(
                            record: record,
                            isSelected: record.id == selectedRecordID
                        )
                        .onTapGesture {
                            selectedRecordID = record.id
                        }
                        .onTapGesture(count: 2) {
                            openRecord(record)
                        }
                        .contextMenu {
                            contextMenu(for: record)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("No captures yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Your screenshots and recordings will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Context Menu

    @ViewBuilder
    private func contextMenu(for record: CaptureRecord) -> some View {
        Button("Open") {
            openRecord(record)
        }
        Button("Copy to Clipboard") {
            copyRecord(record)
        }
        Button("Reveal in Finder") {
            revealInFinder(record)
        }
        if record.captureType == "screenshot" {
            Button("Annotate") {
                annotateRecord(record)
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            deleteRecord(record)
        }
    }

    // MARK: Actions

    private func openRecord(_ record: CaptureRecord) {
        let url = URL(fileURLWithPath: record.filePath)
        NSWorkspace.shared.open(url)
    }

    private func copyRecord(_ record: CaptureRecord) {
        if let image = NSImage(contentsOfFile: record.filePath) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }
    }

    private func revealInFinder(_ record: CaptureRecord) {
        NSWorkspace.shared.selectFile(
            record.filePath,
            inFileViewerRootedAtPath: ""
        )
    }

    private func annotateRecord(_ record: CaptureRecord) {
        if let image = NSImage(contentsOfFile: record.filePath) {
            AnnotationWindow.show(with: image)
        }
    }

    private func deleteRecord(_ record: CaptureRecord) {
        try? CaptureHistoryManager.shared.deleteRecord(
            record,
            modelContext: modelContext
        )
        if selectedRecordID == record.id {
            selectedRecordID = nil
        }
    }
}

// MARK: - Capture Cell

struct CaptureCell: View {
    let record: CaptureRecord
    var isSelected: Bool = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnailView
            metadataView
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = NSImage(contentsOfFile: record.thumbnailPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 120)
                .overlay {
                    Image(systemName: iconForType(record.captureType))
                        .font(.largeTitle)
                        .foregroundStyle(.quaternary)
                }
        }
    }

    // MARK: Metadata

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: iconForType(record.captureType))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(record.captureType.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Text(record.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("\(record.width)\u{00D7}\(record.height)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(Self.formattedFileSize(record.fileSize))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Helpers

    private func iconForType(_ type: String) -> String {
        switch type {
        case "screenshot": return "camera"
        case "recording": return "video"
        case "gif": return "photo.stack"
        case "ocr": return "text.viewfinder"
        default: return "doc"
        }
    }

    private static func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
