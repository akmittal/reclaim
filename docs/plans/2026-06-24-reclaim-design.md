# Reclaim: macOS Cleaner & Optimizer - System Design

**Date**: 2026-06-24  
**Project**: Reclaim (Open-source alternative to CleanMyMac)  
**Platform**: macOS (Swift & SwiftUI, Non-Sandboxed, target macOS 14.0+)  

---

## 1. Architectural Overview

Reclaim uses a modular service-oriented architecture written in pure Swift and SwiftUI. The application relies on a central coordinator, `AppState`, to manage global states (navigation, scanning status, general configurations) while delegate services execute feature-specific operations.

### Service Decomposition
- **`JunkCleanerService`**: Scans and deletes temporary files, user/system caches, log files, Xcode DerivedData, and Trash bins.
- **`UninstallerService`**: Finds application bundles and recursively searches for related configuration, cache, and container files.
- **`MaintenanceService`**: Runs safe maintenance scripts, frees up inactive memory, flushes the DNS cache, and repairs the Spotlight index.
- **`SpaceLensService`**: Employs parallel directory traversal to build a hierarchical tree map of disk usage.
- **`LargeFilesFinderService`**: Traverses folders to detect files exceeding a configured size threshold (default >100MB), grouped by size and age.

---

## 2. User Interface & Experience

The UI follows modern macOS design guidelines (glassmorphism, vibrant colors, subtle micro-animations) built entirely in SwiftUI.

### Sidebar Navigation
- A translucent sidebar (`NavigationSplitView` with `.background(.ultraThinMaterial)`) organizes pages:
  - **Dashboard / Quick Scan**
  - **System Junk**
  - **Uninstaller**
  - **Space Lens**
  - **Large & Old Files**
  - **Maintenance**
  - **Settings**

### Key UI Features
- **Gauges & Indicators**: Custom-drawn, gradient-filled circular gauges for RAM, CPU, and Disk metrics.
- **Interactive Tree Map**: The Space Lens view uses a custom squarified tree map layout. Users can hover over nodes for file previews, double-click to drill down, or drag items out.
- **Micro-Animations**: Custom button hover effects, rotating scanning status symbols, and progress indicators that update at a throttled rate to guarantee 60fps UI performance.

---

## 3. Data Flow & Concurrency

All heavy scanning and disk modification operations run asynchronously on background queues.

### Threading & Concurrency
- Traversal operations use **Swift Concurrency** (`async/await` and `TaskGroup`) to divide and conquer large folder hierarchies.
- Services manage internal mutable scanner states inside dedicated `actor` components to ensure complete thread-safety.
- To prevent UI stuttering, state updates are throttled (max 10Hz) before publishing progress to the Main Actor.

### Permissions & Safety
- **Sandbox**: Disabled (`App Sandbox = NO` in Entitlements) to grant access to system folders.
- **Full Disk Access**: If the app fails to read protected directories, a sheet prompts the user with graphic guides to enable Full Disk Access in macOS System Settings.
- **Exclusion Filters**: Critical system directories (e.g., `/System`, `/usr/bin`, `/sbin`) are strictly blacklisted from cleaning or shredding.
