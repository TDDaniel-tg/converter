import AppKit
import UniformTypeIdentifiers

// MARK: - Wheel Mode
enum WheelMode {
    case formats   // Shift + Drag
    case tools     // Option + Shift + Drag
}

// MARK: - Global Event Monitor
/// Watches for modifier key + drag gestures globally and triggers the radial wheel.
/// False positive protection:
///   - Requires sustained modifier key hold before showing wheel (configurable in Preferences)
///   - Checks pasteboard for actual file drag
///   - Only activates when real drag session is detected
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
        // Monitor global flag changes (modifier keys)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Monitor global mouse drag
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
    }

    func stop() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m) }
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        debouncer.cancel()
    }

    // MARK: - Handlers

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags
        let shiftOnly = flags.contains(.shift) && !flags.contains(.option) && !flags.contains(.command)
        let shiftOption = flags.contains(.shift) && flags.contains(.option) && !flags.contains(.command)

        if shiftOption {
            debouncer.schedule { [weak self] in
                guard self?.hasDraggedFiles() == true else { return }
                self?.showWheel(mode: .tools, at: NSEvent.mouseLocation)
            }
        } else if shiftOnly {
            debouncer.schedule { [weak self] in
                guard self?.hasDraggedFiles() == true else { return }
                self?.showWheel(mode: .formats, at: NSEvent.mouseLocation)
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
        radialWheelController.updateHover(at: lastMousePosition)
    }

    // MARK: - Wheel Lifecycle

    private func showWheel(mode: WheelMode, at position: NSPoint) {
        guard !isWheelVisible else { return }
        isWheelVisible = true
        currentMode = mode

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.radialWheelController.show(mode: mode, at: position) {
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

    // MARK: - Drag Detection (False Positive Protection)
    /// Checks the dragging pasteboard to verify an actual file drag is happening.
    private func hasDraggedFiles() -> Bool {
        let pb = NSPasteboard(name: .drag)
        guard let types = pb.types else { return false }
        return types.contains(.fileURL) ||
               types.contains(NSPasteboard.PasteboardType("public.file-url")) ||
               types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) ||
               types.contains(NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"))
    }
}
