import AppKit

// MARK: - Radial Wheel Controller
/// Manages the transparent overlay window that displays the radial pie-menu.
final class RadialWheelController {

    private var window: NSWindow?
    private var wheelView: RadialWheelView?
    private var dismissCallback: (() -> Void)?

    // MARK: - Show Wheel

    func show(mode: WheelMode, at screenPoint: NSPoint, onDismiss: @escaping () -> Void) {
        self.dismissCallback = onDismiss
        let vm = RadialWheelViewModel(mode: mode)

        let size: CGFloat = 320
        let frame = NSRect(
            x: screenPoint.x - size / 2,
            y: screenPoint.y - size / 2,
            width: size,
            height: size
        )

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .popUpMenu
        win.ignoresMouseEvents = false
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = RadialWheelView(frame: NSRect(origin: .zero, size: frame.size), viewModel: vm)
        view.onSelect = { [weak self] segment in
            self?.handleSelection(segment)
        }
        view.onDismiss = { [weak self] in
            self?.dismiss()
        }

        win.contentView = view
        self.wheelView = view
        self.window = win

        win.makeKeyAndOrderFront(nil)

        // Fade in
        win.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            win.animator().alphaValue = 1.0
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            self?.wheelView = nil
            self?.dismissCallback?()
        })
    }

    // MARK: - Hover Update (from mouse drag position)

    func updateHover(at screenPoint: NSPoint) {
        guard let win = window else { return }
        let local = win.convertPoint(fromScreen: screenPoint)
        let center = NSPoint(x: win.frame.width / 2, y: win.frame.height / 2)
        let dx = Double(local.x - center.x)
        let dy = Double(local.y - center.y)
        let angle = atan2(dy, dx)
        wheelView?.viewModel.updateHoverAngle(angle)
        wheelView?.needsDisplay = true
    }

    // MARK: - Selection

    private func handleSelection(_ segment: WheelSegment) {
        dismiss()

        let pb = NSPasteboard(name: .drag)
        var urls: [URL] = []
        if let objects = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !objects.isEmpty {
            urls = objects
        } else if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = filenames.map { URL(fileURLWithPath: $0) }
        }

        guard !urls.isEmpty else { return }

        ConversionEngine.shared.convert(urls: urls, to: segment) { result in
            DispatchQueue.main.async {
                if Preferences.shared.playSound {
                    NSSound(named: "Glass")?.play()
                }
                if Preferences.shared.showNotifications {
                    NotificationManager.shared.notify(result: result, fileCount: urls.count)
                }
            }
        }
    }
}
