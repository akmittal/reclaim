import SwiftUI
import AppKit

struct SpaceLensView: View {
    @Environment(AppState.self) private var appState
    
    @State private var selectedFolder: URL? = nil
    @State private var navigationHistory: [DiskNode] = []
    @State private var currentNode: DiskNode? = nil
    @State private var isScanning: Bool = false
    @State private var scanPath: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header & Folder Picker
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Space Lens")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Visualize your storage density as a tree map and drill down to find large folders.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: selectFolder) {
                    Label(selectedFolder == nil ? "Select Folder" : "Change Folder", systemImage: "folder.badge.plus")
                        .font(.headline)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.white.opacity(0.01))
            
            Divider()
            
            // Breadcrumbs Navigation Bar
            if !navigationHistory.isEmpty || currentNode != nil {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            if let root = navigationHistory.first {
                                navigateToNode(root, clearHistory: true)
                            }
                        }
                    
                    ForEach(navigationHistory) { node in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(node.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                if let idx = navigationHistory.firstIndex(where: { $0.id == node.id }) {
                                    navigationHistory = Array(navigationHistory.prefix(upTo: idx))
                                    navigateToNode(node, clearHistory: false)
                                }
                            }
                    }
                    
                    if let current = currentNode {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(current.name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if !navigationHistory.isEmpty {
                        Button {
                            if let last = navigationHistory.popLast() {
                                navigateToNode(last, clearHistory: false)
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .help("Go up one folder")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.white.opacity(0.02))
                
                Divider()
            }
            
            // Core Area
            if isScanning {
                VStack(spacing: 24) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.purple)
                    Text("Scanning storage structure...")
                        .font(.headline)
                    Text(scanPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(width: 500)
                    Spacer()
                }
            } else if let node = currentNode {
                if let children = node.children, !children.isEmpty {
                    GeometryReader { geo in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Click folders to inspect, double-click to drill down.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top)
                                
                                // Render children as interactive grid blocks
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 16)], spacing: 16) {
                                    ForEach(children) { child in
                                        LensBlock(node: child, totalSize: node.size) {
                                            if child.isDirectory {
                                                navigationHistory.append(node)
                                                navigateToNode(child, clearHistory: false)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("Folder is Empty")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("No nested storage items detected inside \(node.name).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } else {
                // Welcome screen
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "circle.grid.cross.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.linearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .purple.opacity(0.4), radius: 15)
                    
                    Text("Scan a folder to build Space Lens")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Discover what is occupying your hard drive using a visual directory chart.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 380)
                    
                    Button(action: selectFolder) {
                        Text("Choose Directory...")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose folder to analyze"
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url
            navigationHistory.removeAll()
            startScan(for: url)
        }
    }
    
    private func startScan(for url: URL) {
        isScanning = true
        scanPath = url.path
        
        Task {
            do {
                let node = try await appState.spaceLens.scanDirectory(at: url) { path in
                    Task { @MainActor in
                        self.scanPath = path
                    }
                }
                self.currentNode = node
            } catch {
                print("Error scanning path: \(error.localizedDescription)")
            }
            isScanning = false
        }
    }
    
    private func navigateToNode(_ node: DiskNode, clearHistory: Bool) {
        if clearHistory {
            navigationHistory.removeAll()
        }
        
        // If the node has no children populated yet (meaning we stopped depth-first search earlier), scan it dynamically
        if node.isDirectory && (node.children == nil || node.children!.isEmpty) {
            startScan(for: node.url)
        } else {
            self.currentNode = node
        }
    }
}

// Proportional visual block representing a directory or file
struct LensBlock: View {
    let node: DiskNode
    let totalSize: Int64
    let action: () -> Void
    
    var percentageOfParent: Double {
        guard totalSize > 0 else { return 0 }
        return Double(node.size) / Double(totalSize)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundColor(node.isDirectory ? .purple : .cyan)
                    Spacer()
                    Text(String(format: "%.1f%%", percentageOfParent * 100))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(node.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(14)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(node.isDirectory ?
                          LinearGradient(colors: [Color.purple.opacity(0.2), Color.indigo.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [Color.blue.opacity(0.15), Color.teal.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                         )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SpaceLensView()
        .environment(AppState())
        .background(.black)
}
