import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            List {
                Section("Analyze") {
                    SidebarRow(tab: .dashboard, currentTab: $state.selectedTab)
                }
                
                Section("Clean & Optimize") {
                    SidebarRow(tab: .junkCleaner, currentTab: $state.selectedTab)
                    SidebarRow(tab: .uninstaller, currentTab: $state.selectedTab)
                    SidebarRow(tab: .spaceLens, currentTab: $state.selectedTab)
                    SidebarRow(tab: .largeFiles, currentTab: $state.selectedTab)
                }
                
                Section("Maintain") {
                    SidebarRow(tab: .maintenance, currentTab: $state.selectedTab)
                }
                
                Section("Manage") {
                    SidebarRow(tab: .settings, currentTab: $state.selectedTab)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
            .safeAreaInset(edge: .bottom) {
                // Total Reclaimed footer card
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.bottom, 4)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text("Reclaimed Space")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(ByteCountFormatter.string(fromByteCount: appState.totalReclaimedBytes, countStyle: .file))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        } detail: {
            Group {
                switch appState.selectedTab {
                case .dashboard:
                    DashboardView()
                case .junkCleaner:
                    JunkCleanerView()
                case .uninstaller:
                    UninstallerView()
                case .spaceLens:
                    SpaceLensView()
                case .largeFiles:
                    LargeFilesFinderView()
                case .maintenance:
                    MaintenanceView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RadialGradient(
                    colors: [Color(red: 0.12, green: 0.10, blue: 0.20), Color(red: 0.05, green: 0.05, blue: 0.08)],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 900
                )
                .ignoresSafeArea()
            )
        }
        .navigationTitle("Reclaim")
    }
}

// Simple Settings view stub
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text("Reclaim Settings")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Auto-empty Trash Bins", isOn: .constant(true))
                Toggle("Scan System Log Files (requires FDA)", isOn: .constant(true))
                Toggle("Enable daily cleaning reminders", isOn: .constant(false))
            }
            .frame(width: 320)
            .padding()
            .background(.white.opacity(0.05))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(40)
    }
}

struct SidebarRow: View {
    let tab: SidebarTab
    @Binding var currentTab: SidebarTab
    
    var isSelected: Bool {
        currentTab == tab
    }
    
    var accentColor: Color {
        switch tab {
        case .dashboard: return .blue
        case .junkCleaner: return .orange
        case .uninstaller: return .red
        case .spaceLens: return .purple
        case .largeFiles: return .green
        case .maintenance: return .teal
        case .settings: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tab.iconName)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? accentColor : .secondary)
                .frame(width: 24, alignment: .leading)
            
            Text(tab.rawValue)
                .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            currentTab = tab
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    MainView()
        .environment(AppState())
}
