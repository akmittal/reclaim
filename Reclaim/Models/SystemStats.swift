import Foundation

public struct SystemStats: Sendable {
    public static func memoryUsage() -> (used: Int64, total: Int64, percentage: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        guard kerr == KERN_SUCCESS else {
            return (total / 2, total, 0.5) // Safe default fallback
        }
        
        var pageSize: vm_size_t = 4096
        var hostPageSize: vm_size_t = 0
        if host_page_size(mach_host_self(), &hostPageSize) == KERN_SUCCESS {
            pageSize = hostPageSize
        }
        let freeMemory = Int64(stats.free_count) * Int64(pageSize)
        let inactiveMemory = Int64(stats.inactive_count) * Int64(pageSize)
        
        // Free and inactive memory can be purged or used, so they are "available".
        let available = freeMemory + inactiveMemory
        let used = total - available
        let percentage = Double(used) / Double(total)
        
        return (used, total, percentage)
    }
    
    public static func diskUsage() -> (used: Int64, total: Int64, percentage: Double) {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let used = total - free
            let percentage = Double(used) / Double(total)
            return (used, total, percentage)
        } catch {
            return (50, 100, 0.50)
        }
    }
}
