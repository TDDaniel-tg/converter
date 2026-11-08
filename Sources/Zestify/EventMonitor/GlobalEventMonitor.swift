import AppKit
import UniformTypeIdentifiers

// MARK: - Wheel Mode
enum WheelMode {
    case formats   // Shift + Drag
    case tools     // Option + Shift + Drag
}

// MARK: - Global Event Monitor
final class GlobalEventMonitor {

    private var flagsMonitor: Any?
    private var mouseMonitor: Any?
    private var localMonitor: Any?

    private let debouncer = ModifierKeyDebouncer()
    private let radialWheelController: RadialWheelController

    private var currentMode: WheelMode?
    private var isWheelVisible = false
    private var lastMousePosition: NSPoint = .zero

    init(radialWheelController: RadialWheelController) {
        self.radialWheelController = radialWheelController
    }

    func start() {
        // Global monitor for modifier keys
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Global monitor for mouse drag
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.handleMouseDragged(event)
        }

        // Local monitor to also catch events when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .leftMouseDragged, .keyDown]) { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                self?.dismissWheel()
            }
            if event.type == .flagsChanged { self?.handleFlagsChanged(event) }
            if event.type == .leftMouseDragged { self?.handleMouseDragged(event) }
            return event
        }

        // Watch for active app changes so we dismiss immediately if switching away from Finder
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func stop() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        debouncer.cancel()
    }

    // MARK: - Active App Filter (Finder-Only Protection)

    private func isFinderActive() -> Bool {
        guard Preferences.shared.onlyInFinder else { return true }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let bundleId = frontApp.bundleIdentifier ?? ""
        return bundleId == "com.apple.finder" || bundleId == "com.zestify.app"
    }

    @objc private func appDidActivate(_ notification: Notification) {
        if !isFinderActive() {
            debouncer.cancel()
            if isWheelVisible {
                dismissWheel()
            }
        }
    }

    // MARK: - Handlers

    private func handleFlagsChanged(_ event: NSEvent) {
        // Ignore modifier events completely if Finder is not active (e.g. Fusion 360, Blender, etc.)
        guard isFinderActive() else {
            debouncer.cancel()
            if isWheelVisible {
                dismissWheel()
            }
            return
        }

        let flags = event.modifierFlags
        let shiftOnly = flags.contains(.shift) && !flags.contains(.option) && !flags.contains(.command)
        let shiftOption = flags.contains(.shift) && flags.contains(.option) && !flags.contains(.command)

        if shiftOption {
            debouncer.schedule { [weak self] in
                self?.triggerWheel(mode: .tools)
            }
        } else if shiftOnly {
            debouncer.schedule { [weak self] in
                self?.triggerWheel(mode: .formats)
            }
        } else {
            debouncer.cancel()
            if isWheelVisible {
                dismissWheel()
            }
        }
    }

    private func handleMouseDragged(_ event: NSEvent) {
        lastMousePosition = NSEvent.mouseLocation

        guard isWheelVisible else { return }
        guard isFinderActive() else {
            dismissWheel()
            return
        }
        radialWheelController.updateHover(at: lastMousePosition)
    }

    // MARK: - Wheel Trigger

    private func triggerWheel(mode: WheelMode) {
        guard !isWheelVisible else { return }
        guard isFinderActive() else { return }

        let files = getDraggedFiles()
        guard !files.isEmpty else { return }

        let category = FileCategory.detect(from: files)
        let sourceFormat = files.first?.pathExtension.uppercased() ?? "Zestify"

        showWheel(mode: mode, category: category, sourceFormat: sourceFormat, at: NSEvent.mouseLocation)
    }

    private func showWheel(mode: WheelMode, category: FileCategory, sourceFormat: String, at position: NSPoint) {
        guard !isWheelVisible else { return }
        isWheelVisible = true
        currentMode = mode

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.radialWheelController.show(mode: mode, category: category, sourceFormat: sourceFormat, at: position) {
                self.isWheelVisible = false
            }
        }
    }

    private func dismissWheel() {
        guard isWheelVisible else { return }
        isWheelVisible = false
        DispatchQueue.main.async { [weak self] in
            self?.radialWheelController.dismiss()
        }
    }

    // MARK: - Drag Detection
    private func getDraggedFiles() -> [URL] {
        let pb = NSPasteboard(name: .drag)
        if let objects = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !objects.isEmpty {
            return objects
        }
        if let files = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !files.isEmpty {
            return files.map { URL(fileURLWithPath: $0) }
        }
        return []
    }
}
