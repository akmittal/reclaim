import Foundation
import Observation
import SwiftUI
import UserNotifications

public enum SidebarTab: String, CaseIterable, Identifiable, Sendable {
    case dashboard = "Dashboard"
    case junkCleaner = "System Junk"
    case uninstaller = "Uninstaller"
    case spaceLens = "Space Lens"
    case largeFiles = "Large Files"
    case maintenance = "Maintenance"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .dashboard: return "speedometer"
        case .junkCleaner: return "trash.fill"
        case .uninstaller: return "xmark.app.fill"
        case .spaceLens: return "chart.pie.fill"
        case .largeFiles: return "archivebox.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

@Observable
@MainActor
public final class AppState: Sendable {
    public var selectedTab: SidebarTab = .dashboard
    
    // Status states
    public var isScanning: Bool = false
    public var isCleaning: Bool = false
    public var statusMessage: String = "Ready to scan"
    public var progress: Double = 0.0
    public var showCleanCompletedAlert: Bool = false
    public var lastReclaimedAmountString: String = ""
    
    // Scan Results
    public var junkCategories: [JunkCategory] = [
        JunkCategory(id: "user_caches", name: "User Caches", systemIcon: "folder.badge.gearshape"),
        JunkCategory(id: "user_logs", name: "User Logs", systemIcon: "doc.text"),
        JunkCategory(id: "system_caches", name: "System Caches", systemIcon: "folder.fill.badge.gearshape"),
        JunkCategory(id: "system_logs", name: "System Logs", systemIcon: "doc.text.fill"),
        JunkCategory(id: "xcode", name: "Xcode Developer Junk", systemIcon: "hammer.fill"),
        JunkCategory(id: "trash", name: "Trash Bins", systemIcon: "trash")
    ]
    
    public var installedApps: [InstalledApp] = []
    public var rootSpaceNode: DiskNode? = nil
    public var largeFiles: [JunkFile] = []
    
    public var maintenanceTasks: [MaintenanceTask] = [
        MaintenanceTask(id: "ram", name: "Free Up RAM", details: "Purges inactive memory and page caches to free up system memory.", systemIcon: "memorychip"),
        MaintenanceTask(id: "dns", name: "Flush DNS Cache", details: "Clears your local DNS cache resolver to fix connection issues.", systemIcon: "network"),
        MaintenanceTask(id: "spotlight", name: "Reindex Spotlight", details: "Rebuilds the Spotlight search metadata database for faster search.", systemIcon: "magnifyingglass")
    ]
    
    public var totalJunkSize: Int64 {
        junkCategories.reduce(0) { $0 + $1.size }
    }
    
    public var selectedJunkSize: Int64 {
        junkCategories.reduce(0) { sum, cat in
            sum + (cat.isChecked ? cat.files.filter { $0.isChecked }.reduce(0) { $0 + $1.size } : 0)
        }
    }
    
    public var totalReclaimedBytes: Int64 = 0
    
    // Services
    public let junkCleaner = JunkCleanerService()
    public let uninstaller = UninstallerService()
    public let spaceLens = SpaceLensService()
    public let largeFilesFinder = LargeFilesFinderService()
    public let maintenance = MaintenanceService()
    
    public init() {}
    
    public func startQuickScan() async {
        isScanning = true
        statusMessage = "Starting system analysis..."
        progress = 0.0
        
        do {
            // 1. Scan Junk Categories
            statusMessage = "Analyzing system junk..."
            let scannedJunk = try await junkCleaner.scanAllCategories { [weak self] currentPath in
                guard let self = self else { return }
                Task { @MainActor in
                    self.statusMessage = "Analyzing: \(currentPath)"
                }
            }
            self.junkCategories = scannedJunk
            progress = 0.25
            
            // 2. Scan Apps for Uninstaller
            statusMessage = "Scanning applications..."
            let apps = try await uninstaller.scanInstalledApps { [weak self] currentApp in
                guard let self = self else { return }
                Task { @MainActor in
                    self.statusMessage = "Scanning app: \(currentApp)"
                }
            }
            self.installedApps = apps
            progress = 0.50
            
            // 3. Scan Large Files in background in Downloads / Documents
            statusMessage = "Searching for large files..."
            let downloadsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
            let documentsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
            let large = try await largeFilesFinder.scanLargeFiles(paths: [downloadsURL, documentsURL])
            self.largeFiles = large
            progress = 0.75
            
            statusMessage = "Scan complete!"
            progress = 1.0
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
        
        isScanning = false
    }
    
    public func cleanSelectedJunk() async {
        isCleaning = true
        statusMessage = "Cleaning selected system junk..."
        
        var filesToDelete: [URL] = []
        for category in junkCategories where category.isChecked {
            for file in category.files where file.isChecked {
                filesToDelete.append(file.url)
            }
        }
        
        // Capture old selections to preserve them after re-scan
        let oldCategorySelections = junkCategories.reduce(into: [String: Bool]()) { dict, cat in
            dict[cat.id] = cat.isChecked
        }
        var oldFileSelections: [String: Bool] = [:]
        for cat in junkCategories {
            for file in cat.files {
                oldFileSelections[file.url.path] = file.isChecked
            }
        }
        
        let debugLogURL = URL(fileURLWithPath: "/Users/akmittal/projects/reclaim/app_debug.log")
        var log = "--- Clean Started ---\n"
        log += "Files selected to delete: \(filesToDelete.count)\n"
        for f in filesToDelete {
            log += " - Path: \(f.path)\n"
        }
        
        let result = await junkCleaner.deleteFiles(filesToDelete)
        
        let deletedBytes = result.deletedBytes
        log += "Deleted bytes: \(deletedBytes)\n"
        if !result.errors.isEmpty {
            log += "Errors encountered:\n"
            for err in result.errors {
                log += "  [ERROR] \(err)\n"
            }
        }
        
        self.totalReclaimedBytes += deletedBytes
        
        // Re-scan to update sizes
        statusMessage = "Re-indexing..."
        if var scannedJunk = try? await junkCleaner.scanAllCategories(progressHandler: nil) {
            // Restore previous isChecked states
            for i in scannedJunk.indices {
                let catId = scannedJunk[i].id
                if let wasCatChecked = oldCategorySelections[catId] {
                    scannedJunk[i].isChecked = wasCatChecked
                }
                
                for j in scannedJunk[i].files.indices {
                    let filePath = scannedJunk[i].files[j].url.path
                    if let wasFileChecked = oldFileSelections[filePath] {
                        scannedJunk[i].files[j].isChecked = wasFileChecked
                    }
                }
            }
            self.junkCategories = scannedJunk
        }
        
        let reclaimedString = ByteCountFormatter.string(fromByteCount: deletedBytes, countStyle: .file)
        statusMessage = "Clean completed! Reclaimed \(reclaimedString)"
        self.lastReclaimedAmountString = reclaimedString
        self.showCleanCompletedAlert = true
        isCleaning = false
        
        // Send a native notification
        let content = UNMutableNotificationContent()
        content.title = "Cleanup Complete"
        content.body = "Successfully reclaimed \(reclaimedString) of disk space."
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        
        log += "Clean finished. Status: \(statusMessage)\n"
        if let fileHandle = try? FileHandle(forWritingTo: debugLogURL) {
            fileHandle.seekToEndOfFile()
            if let data = log.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } else {
            try? log.write(to: debugLogURL, atomically: true, encoding: .utf8)
        }
    }
}
