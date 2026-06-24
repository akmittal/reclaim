import SwiftUI
import AppKit

struct LargeFilesFinderView: View {
    @Environment(AppState.self) private var appState
    @State private var sortOrder: SortOrder = .sizeDescending
    @State private var isDeleting: Bool = false
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case sizeDescending = "Largest First"
        case sizeAscending = "Smallest First"
        case name = "Name"
        
        var id: String { rawValue }
    }
    
    private func sortLargeFiles() {
        switch sortOrder {
        case .sizeDescending:
            appState.largeFiles.sort(by: { $0.size > $1.size })
        case .sizeAscending:
            appState.largeFiles.sort(by: { $0.size < $1.size })
        case .name:
            appState.largeFiles.sort(by: { $0.url.lastPathComponent.localizedCompare($1.url.lastPathComponent) == .orderedAscending })
        }
    }
    
    var selectedSize: Int64 {
        appState.largeFiles.filter { $0.isChecked }.reduce(0) { $0 + $1.size }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large & Old Files Finder")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Locate large files on your drive that haven't been accessed recently.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .frame(width: 150)
                
                Button {
                    Task {
                        await appState.startQuickScan()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if appState.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Rescan")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.isScanning)
            }
            .padding()
            .background(.white.opacity(0.01))
            
            Divider()
            
            if appState.largeFiles.isEmpty && !appState.isScanning {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "doc.folder.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green.opacity(0.8))
                    Text("No large files found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("No files exceeding 100MB were detected in your Downloads or Documents folders.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach($state.largeFiles) { $file in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $file.isChecked)
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            
                            Image(systemName: fileIconName(for: file.url))
                                .font(.title3)
                                .foregroundColor(fileIconColor(for: file.url))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.url.lastPathComponent)
                                    .fontWeight(.medium)
                                Text(file.url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .help(file.url.path)
                            
                            Spacer()
                            
                            // Reveal in Finder button
                            Button {
                                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Image(systemName: "magnifyingglass.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("Reveal in Finder")
                            .padding(.horizontal, 8)
                            
                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Delete Bar
            if !appState.largeFiles.isEmpty && appState.largeFiles.contains(where: { $0.isChecked }) {
                Divider()
                HStack {
                    Text("Selected files:")
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            isDeleting = true
                            await Task.yield()
                            deleteSelectedFiles()
                            isDeleting = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isDeleting ? "Deleting..." : "Delete Permanently")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isDeleting)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            sortLargeFiles()
        }
        .onChange(of: sortOrder) { _, _ in
            sortLargeFiles()
        }
        .onChange(of: appState.isScanning) { _, isScanning in
            if !isScanning {
                sortLargeFiles()
            }
        }
    }
    
    private func fileIconName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dmg", "pkg", "iso": return "square.and.arrow.down.fill"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "mp4", "mkv", "mov", "avi": return "video.fill"
        case "mp3", "wav", "flac", "m4a": return "music.note"
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }
    
    private func fileIconColor(for url: URL) -> Color {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dmg", "pkg", "iso": return .blue
        case "zip", "tar", "gz", "rar", "7z": return .yellow
        case "mp4", "mkv", "mov", "avi": return .purple
        case "mp3", "wav", "flac", "m4a": return .pink
        case "pdf": return .red
        default: return .secondary
        }
    }
    
    private func deleteSelectedFiles() {
        let fm = FileManager.default
        var deletedCount: Int64 = 0
        
        let toDelete = appState.largeFiles.filter { $0.isChecked }
        
        for file in toDelete {
            do {
                if fm.fileExists(atPath: file.url.path) {
                    try fm.removeItem(at: file.url)
                    deletedCount += file.size
                }
            } catch {
                print("Could not delete large file: \(error.localizedDescription)")
            }
        }
        
        appState.totalReclaimedBytes += deletedCount
        
        // Remove from local list
        appState.largeFiles.removeAll(where: { $0.isChecked })
    }
}

#Preview {
    LargeFilesFinderView()
        .environment(AppState())
        .background(.black)
}
