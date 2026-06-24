# Reclaim Workspace Rules & Guidelines for Agents

Welcome to the **Reclaim** repository. When working on this codebase, please follow the guidelines and technical constraints listed below.

---

## 🛠️ XcodeGen Project Generation
* **Do NOT edit `.xcodeproj` files manually.** Xcode files are programmatically generated.
* All configuration changes (adding files, schemes, settings, framework linking) must be defined in [project.yml](file:///Users/akmittal/projects/reclaim/project.yml).
* After modifying files or configurations, regenerate the project file using:
  ```bash
  xcodegen
  ```

---

## 💻 Compiling & Launching
* **Target Build Recommendation:** Compile using the target parameter to ensure binaries are outputted directly in the workspace `build` folder:
  ```bash
  xcodebuild -project Reclaim.xcodeproj -target Reclaim -configuration Debug build
  ```
* **Relaunch Process:** When launching a newly built app, kill the existing process first to prevent Launch Services from reusing cached old binaries:
  ```bash
  killall Reclaim || true
  open build/Debug/Reclaim.app
  ```

---

## 🛡️ macOS Sandbox & Permissions
* **Keep App Sandbox Disabled:** Reclaim is a direct-distribution system cleaning utility and requires `com.apple.security.app-sandbox` set to `false`. Do not enable Sandbox, as it will break directory scanning, uninstallation, and disk space analyzers.
* **AppleScript Finder Fallbacks:** Direct POSIX file system access to folders like `~/.Trash` is blocked under macOS TCC without Full Disk Access. Bypasses are handled using `NSAppleScript` to automate Finder. Ensure this fallback logic remains intact:
  * Scanning is done via Finder scripting.
  * Deletions inside the Trash are handled by emptying the trash via Finder (`empty trash without warnings`).
* **Info.plist Requirements:** Any addition of AppleEvents automations requires maintaining `NSAppleEventsUsageDescription` in `Info.plist`, or macOS will block execution with error `-1743` without warning.

---

## 🎨 Design System & Aesthetics
* **Theme Styling:** Reclaim uses a dark-mode theme by default. Maintain the signature deep blue/purple radial gradient background and glassmorphism styling overlays.
* **Loader States:** Any time clean actions or scans are triggered, display loaders (`ProgressView`) on primary action buttons to prevent duplicate execution.
