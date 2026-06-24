import SwiftUI
import AppKit

struct UninstallerView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedAppURL: URL? = nil
    @State private var searchText: String = ""
    @State private var isUninstalling: Bool = false
    @State private var statusMsg: String = ""
    
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return appState.installedApps
        } else {
            return appState.installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Uninstaller")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Completely delete applications along with their hidden configuration and caches.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
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
                        Text("Reload Apps")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.isScanning)
            }
            .padding()
            .background(.white.opacity(0.01))
            
            Divider()
            
            if appState.installedApps.isEmpty && !appState.isScanning {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "app.badge.xmark.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red.opacity(0.8))
                    Text("No Apps Loaded")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Run the system analyzer to populate the applications inventory.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 0) {
                    // Apps List (Left Panel)
                    VStack(spacing: 0) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search applications...", text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(.white.opacity(0.05))
                        .cornerRadius(8)
                        .padding()
                        
                        List(selection: $selectedAppURL) {
                            ForEach(filteredApps) { app in
                                HStack(spacing: 12) {
                                    // Fetch actual app icon
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .fontWeight(.semibold)
                                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .tag(app.bundleURL)
                            }
                        }
                    }
                    .frame(width: 300)
                    
                    Divider()
                    
                    // App Details & Cleanup (Right Panel)
                    VStack(spacing: 0) {
                        if let selectedURL = selectedAppURL,
                           let appIndex = state.installedApps.firstIndex(where: { $0.bundleURL == selectedURL }) {
                            
                            let app = state.installedApps[appIndex]
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    // App Summary Header
                                    HStack(spacing: 20) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                                            .resizable()
                                            .frame(width: 64, height: 64)
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(app.name)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                            Text(app.bundleId ?? "Unknown Bundle ID")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 10)
                                    
                                    Divider()
                                    
                                    // File associations
                                    Text("Files associated with this application:")
                                        .font(.headline)
                                    
                                    // Row for the application binary bundle itself (cannot be deselected)
                                    HStack {
                                        Image(systemName: "app.fill")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Application Executable (\(app.name).app)")
                                                .fontWeight(.medium)
                                            Text(app.bundleURL.path)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    .padding()
                                    .background(.white.opacity(0.03))
                                    .cornerRadius(8)
                                    
                                    // Rows for cache, settings, container files
                                    ForEach($state.installedApps[appIndex].associatedFiles) { $assoc in
                                        HStack(spacing: 12) {
                                            Toggle("", isOn: $assoc.isChecked)
                                                .labelsHidden()
                                                .toggleStyle(.checkbox)
                                            
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.orange)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(assoc.typeDescription)
                                                    .fontWeight(.medium)
                                                Text(assoc.url.path)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            .help(assoc.url.path)
                                            
                                            Spacer()
                                            
                                            Text(ByteCountFormatter.string(fromByteCount: assoc.size, countStyle: .file))
                                                .font(.system(.body, design: .monospaced))
                                        }
                                        .padding()
                                        .background(.white.opacity(0.02))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding()
                            }
                            
                            // Uninstall bar
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Space to reclaim:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(ByteCountFormatter.string(fromByteCount: app.totalSize, countStyle: .file))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        isUninstalling = true
                                        statusMsg = "Uninstalling \(app.name)..."
                                        let deletedBytes = app.totalSize
                                        let success = await state.uninstaller.uninstallApp(app)
                                        
                                        // Always clear selection and reload apps list to match disk state
                                        selectedAppURL = nil
                                        if let refreshed = try? await state.uninstaller.scanInstalledApps(progressHandler: nil) {
                                            state.installedApps = refreshed
                                        }
                                        
                                        if success {
                                            state.totalReclaimedBytes += deletedBytes
                                        }
                                        isUninstalling = false
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isUninstalling {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        Text(isUninstalling ? "Uninstalling..." : "Complete Uninstallation")
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .disabled(isUninstalling)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Select an application to view details")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    UninstallerView()
        .environment(AppState())
        .background(.black)
}
