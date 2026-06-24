import Foundation

public final class LargeFilesFinderService: @unchecked Sendable {
    public init() {}
    
    public func scanLargeFiles(paths: [URL], thresholdBytes: Int64 = 100 * 1024 * 1024) async -> [JunkFile] {
        var foundFiles: [JunkFile] = []
        let fm = FileManager.default
        
        for path in paths {
            guard fm.fileExists(atPath: path.path) else { continue }
            let filesInPath = await withTaskGroup(of: [JunkFile].self) { group in
                group.addTask {
                    let localFM = FileManager.default
                    var localFiles: [JunkFile] = []
                    let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
                    
                    // Retrieve contents using an enumerator
                    guard let enumerator = localFM.enumerator(
                        at: path,
                        includingPropertiesForKeys: keys,
                        options: [.skipsPackageDescendants, .skipsHiddenFiles]
                    ) else {
                        return []
                    }
                    
                    while let fileURL = enumerator.nextObject() as? URL {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
                            if let isDirectory = resourceValues.isDirectory, !isDirectory {
                                let size = Int64(resourceValues.fileSize ?? 0)
                                if size >= thresholdBytes {
                                    localFiles.append(JunkFile(url: fileURL, size: size, isChecked: false))
                                }
                            }
                        } catch {
                            // Ignore files with error accessing attributes
                        }
                    }
                    return localFiles
                }
                
                var pathFiles: [JunkFile] = []
                for await files in group {
                    pathFiles.append(contentsOf: files)
                }
                return pathFiles
            }
            foundFiles.append(contentsOf: filesInPath)
        }
        
        return foundFiles.sorted(by: { $0.size > $1.size })
    }
}
