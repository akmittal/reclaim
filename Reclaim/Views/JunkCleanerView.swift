import SwiftUI

struct JunkCleanerView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCategoryId: String = "user_caches"
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Junk Cleaner")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Optimize disk space by removing caches, logs, and development files.")
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
                        Text("Scan System")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.isScanning)
            }
            .padding()
            .background(.white.opacity(0.01))
            
            Divider()
            
            if appState.totalJunkSize == 0 && !appState.isScanning {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    Text("Your Mac is clean!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("No system junk or temporary cache logs detected.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Master-Detail Split Layout
                HStack(spacing: 0) {
                    // Category List (Left Master Pane)
                    List {
                        ForEach($state.junkCategories) { $cat in
                            HStack(spacing: 12) {
                                Toggle("", isOn: $cat.isChecked)
                                    .labelsHidden()
                                    .toggleStyle(.checkbox)
                                
                                Image(systemName: cat.systemIcon)
                                    .font(.title3)
                                    .frame(width: 24)
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedCategoryId == cat.id ? .primary : .primary.opacity(0.85))
                                    Text(ByteCountFormatter.string(fromByteCount: cat.size, countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCategoryId = cat.id
                            }
                            .listRowBackground(selectedCategoryId == cat.id ? Color.white.opacity(0.06) : Color.clear)
                        }
                    }
                    .frame(width: 260)
                    
                    Divider()
                    
                    // File details (Right Detail Pane)
                    VStack(alignment: .leading, spacing: 0) {
                        if let categoryIndex = state.junkCategories.firstIndex(where: { $0.id == selectedCategoryId }) {
                            let category = state.junkCategories[categoryIndex]
                            
                            HStack {
                                Text(category.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(category.files.count) subfolders found")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(.white.opacity(0.02))
                            
                            Divider()
                            
                            if category.files.isEmpty {
                                VStack {
                                    Spacer()
                                    Text("This category is empty.")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                List {
                                    ForEach($state.junkCategories[categoryIndex].files) { $file in
                                        HStack(spacing: 12) {
                                            Toggle("", isOn: $file.isChecked)
                                                .labelsHidden()
                                                .toggleStyle(.checkbox)
                                            
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(.orange.opacity(0.8))
                                            
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
                                            
                                            Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        } else {
                            VStack {
                                Spacer()
                                Text("Select a category to inspect files.")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Cleaning Bar
            if appState.totalJunkSize > 0 {
                Divider()
                HStack {
                    Text("Total Selected:")
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: appState.selectedJunkSize, countStyle: .file))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await appState.cleanSelectedJunk()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if appState.isCleaning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(appState.isCleaning ? "Cleaning..." : "Clean Junk")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(appState.isCleaning)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $state.showCleanCompletedAlert) {
            VStack(spacing: 24) {
                Spacer()
                
                // Circle with a green checkmark
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.2), Color.green.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .strokeBorder(Color.green.opacity(0.4), lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 8) {
                    Text("Cleanup Complete!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Your Mac is optimized and ready.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(width: 250)
                
                VStack(spacing: 4) {
                    Text("Reclaimed Storage Space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(appState.lastReclaimedAmountString)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                Button {
                    appState.showCleanCompletedAlert = false
                } label: {
                    Text("Done")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 16)
            }
            .padding(40)
            .frame(width: 420, height: 480)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if appState.junkCategories.isEmpty && !appState.isScanning {
                Task {
                    await appState.startQuickScan()
                }
            }
        }
    }
}

#Preview {
    JunkCleanerView()
        .environment(AppState())
        .background(.black)
}
