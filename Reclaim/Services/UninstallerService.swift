import Foundation
import AppKit

public final class UninstallerService: @unchecked Sendable {
    public init() {}
    
    public func scanInstalledApps(progressHandler: (@Sendable (String) -> Void)?) async throws -> [InstalledApp] {
        let fm = FileManager.default
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        var appsList: [InstalledApp] = []
        
        for dir in appDirs {
            guard fm.fileExists(atPath: dir.path) else { continue }
            do {
                let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isPackageKey], options: [.skipsSubdirectoryDescendants])
                
                // Run scan in parallel
                let results = await withTaskGroup(of: InstalledApp?.self) { group in
                    for appURL in contents {
                        if appURL.pathExtension == "app" {
                            group.addTask {
                                progressHandler?(appURL.deletingPathExtension().lastPathComponent)
                                return self.scanAppDetails(at: appURL)
                            }
                        }
                    }
                    
                    var list: [InstalledApp] = []
                    for await case let appInfo? in group {
                        list.append(appInfo)
                    }
                    return list
                }
                appsList.append(contentsOf: results)
            } catch {
                // Ignore folder listing error
            }
        }
        
        return appsList.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
    }
    
    private func scanAppDetails(at url: URL) -> InstalledApp? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        
        let appName = url.deletingPathExtension().lastPathComponent
        let bundleId = getBundleIdentifier(for: url)
        
        // Size of the application bundle itself
        let appSize = calculateDirectorySize(at: url)
        
        // Associated files
        let associated = findAssociatedFiles(forAppName: appName, bundleId: bundleId)
        let associatedSize = associated.reduce(0) { $0 + $1.size }
        
        return InstalledApp(
            name: appName,
            bundleId: bundleId,
            bundleURL: url,
            appSize: appSize,
            associatedSize: associatedSize,
            isChecked: false,
            associatedFiles: associated
        )
    }
    
    private func getBundleIdentifier(for appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            return plist["CFBundleIdentifier"] as? String
        }
        return nil
    }
    
    private func findAssociatedFiles(forAppName name: String, bundleId: String?) -> [AppAssociatedFile] {
        var associated: [AppAssociatedFile] = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        
        let searchPaths: [(path: URL, type: String)] = [
            (home.appendingPathComponent("Library/Application Support"), "Application Support"),
            (home.appendingPathComponent("Library/Caches"), "Caches"),
            (home.appendingPathComponent("Library/Preferences"), "Preferences"),
            (home.appendingPathComponent("Library/Saved Application State"), "Saved State"),
            (home.appendingPathComponent("Library/Containers"), "Containers"),
            (home.appendingPathComponent("Library/Group Containers"), "Group Containers"),
            (home.appendingPathComponent("Library/Logs"), "Logs"),
            (home.appendingPathComponent("Library/LaunchAgents"), "Launch Agents")
        ]
        
        let sanitizedName = name.lowercased()
        
        for (folderURL, typeDesc) in searchPaths {
            guard fm.fileExists(atPath: folderURL.path) else { continue }
            do {
                let items = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
                for item in items {
                    let itemName = item.lastPathComponent.lowercased()
                    var match = false
                    
                    if let bundleId = bundleId, !bundleId.isEmpty {
                        let cleanedId = bundleId.lowercased()
                        if itemName.contains(cleanedId) || cleanedId.contains(itemName) {
                            match = true
                        }
                    }
                    
                    if !match && itemName.contains(sanitizedName) {
                        match = true
                    }
                    
                    if match {
                        var isDir: ObjCBool = false
                        let size: Int64
                        if fm.fileExists(atPath: item.path, isDirectory: &isDir) {
                            size = isDir.boolValue ? calculateDirectorySize(at: item) : calculateFileSize(at: item)
                            associated.append(AppAssociatedFile(url: item, size: size, typeDescription: typeDesc, isChecked: true))
                        }
                    }
                }
            } catch {
                // Ignore folder read errors
            }
        }
        
        return associated
    }
    
    private func calculateFileSize(at url: URL) -> Int64 {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(values.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return 0
        }
        while let fileURL = enumerator.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                if let isDirectory = resourceValues.isDirectory, !isDirectory {
                    size += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                // Ignore inaccessible file
            }
        }
        return size
    }
    
    public func uninstallApp(_ app: InstalledApp) async -> Bool {
        let fm = FileManager.default
        var success = true
        
        // 1. Delete associated files
        for assocFile in app.associatedFiles where assocFile.isChecked {
            do {
                if fm.fileExists(atPath: assocFile.url.path) {
                    try fm.removeItem(at: assocFile.url)
                }
            } catch {
                success = false
            }
        }
        
        // 2. Delete main app bundle
        do {
            if fm.fileExists(atPath: app.bundleURL.path) {
                try fm.removeItem(at: app.bundleURL)
            }
        } catch {
            success = false
        }
        
        return success
    }
}
