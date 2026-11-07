import AppKit

// MARK: - Radial Wheel Controller
/// Manages the transparent overlay window that displays the radial pie-menu.
final class RadialWheelController {

    private var window: NSWindow?
    private var wheelView: RadialWheelView?
    private var dismissCallback: (() -> Void)?
    private var currentScreenPoint: NSPoint = .zero

    // MARK: - Show Wheel

    func show(mode: WheelMode,
              category: FileCategory = .video,
              sourceFormat: String = "Zestify",
              at screenPoint: NSPoint,
              onDismiss: @escaping () -> Void) {

        self.dismissCallback = onDismiss
        self.currentScreenPoint = screenPoint

        let vm = RadialWheelViewModel(mode: mode, category: category, sourceFormat: sourceFormat)

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
        view.onPerformDrop = { [weak self] segment, urls in
            self?.handleDrop(segment: segment, urls: urls)
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
            ctx.duration = 0.15
            win.animator().alphaValue = 1.0
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
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
        let dist = sqrt(dx*dx + dy*dy)
        let angle = atan2(dy, dx)
        wheelView?.viewModel.updateHoverAngle(angle, distance: dist)
        wheelView?.needsDisplay = true
    }

    // MARK: - Drop Handling

    private func handleDrop(segment: WheelSegment, urls: [URL]) {
        let center = currentScreenPoint
        dismiss()

        // 1. Show Processing HUD
        ProcessingHUDController.shared.show(targetFormat: segment.label, files: urls, at: center)

        // 2. Perform Conversion
        ConversionEngine.shared.convert(urls: urls, to: segment) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let outputUrls):
                    ProcessingHUDController.shared.complete(outputFiles: outputUrls)
                    if Preferences.shared.showNotifications {
                        NotificationManager.shared.notify(result: .success(outputUrls: outputUrls), fileCount: urls.count)
                    }

                case .partial(let converted, let failed, let message):
                    if converted > 0 {
                        ProcessingHUDController.shared.complete(outputFiles: [])
                    } else {
                        ProcessingHUDController.shared.fail(message: message ?? "Не удалось конвертировать")
                    }

                case .failure(let error):
                    ProcessingHUDController.shared.fail(message: error)
                }
            }
        }
    }
}
