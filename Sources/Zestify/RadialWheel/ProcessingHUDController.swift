import AppKit

// MARK: - Processing HUD Controller
/// Displays a sleek frosted-glass HUD while files are being converted.
final class ProcessingHUDController {

    static let shared = ProcessingHUDController()

    private var window: NSWindow?
    private var spinner: NSProgressIndicator?
    private var statusIcon: NSTextField?
    private var titleLabel: NSTextField?
    private var subtitleLabel: NSTextField?
    private var dismissTimer: Timer?

    private init() {}

    // MARK: - Show Processing HUD
    func show(targetFormat: String, files: [URL], at screenPoint: NSPoint) {
        dismissTimer?.invalidate()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.createOrUpdateWindow(targetFormat: targetFormat, files: files, at: screenPoint)
        }
    }

    private func createOrUpdateWindow(targetFormat: String, files: [URL], at screenPoint: NSPoint) {
        let width: CGFloat = 280
        let height: CGFloat = 80

        let origin = NSPoint(
            x: screenPoint.x - width / 2,
            y: screenPoint.y - height / 2
        )

        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .floating
            win.hasShadow = true
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
            visualEffect.material = .hudWindow
            visualEffect.blendingMode = .withinWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 18
            visualEffect.layer?.masksToBounds = true
            visualEffect.layer?.borderWidth = 1
            visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor

            // Spinner
            let spin = NSProgressIndicator(frame: NSRect(x: 20, y: 26, width: 28, height: 28))
            spin.style = .spinning
            spin.controlSize = .regular
            spin.isDisplayedWhenStopped = false
            visualEffect.addSubview(spin)
            self.spinner = spin

            // Status Icon (Checkmark or Error)
            let icon = NSTextField(labelWithString: "✅")
            icon.font = NSFont.systemFont(ofSize: 24)
            icon.frame = NSRect(x: 18, y: 24, width: 32, height: 32)
            icon.isHidden = true
            visualEffect.addSubview(icon)
            self.statusIcon = icon

            // Title
            let title = NSTextField(labelWithString: "")
            title.font = NSFont.systemFont(ofSize: 13, weight: .bold)
            title.textColor = .white
            title.frame = NSRect(x: 60, y: 42, width: 204, height: 18)
            visualEffect.addSubview(title)
            self.titleLabel = title

            // Subtitle
            let sub = NSTextField(labelWithString: "")
            let subFont = NSFont.systemFont(ofSize: 11, weight: .medium)
            sub.font = subFont
            sub.textColor = NSColor.white.withAlphaComponent(0.75)
            sub.lineBreakMode = .byTruncatingMiddle
            sub.frame = NSRect(x: 60, y: 20, width: 204, height: 16)
            visualEffect.addSubview(sub)
            self.subtitleLabel = sub

            win.contentView = visualEffect
            self.window = win
        } else {
            window?.setFrameOrigin(origin)
        }

        spinner?.isHidden = false
        spinner?.startAnimation(nil)
        statusIcon?.isHidden = true

        let fileName = files.count == 1 ? files[0].lastPathComponent : "\(files.count) файлов"
        titleLabel?.stringValue = "Конвертирую в \(targetFormat.uppercased())..."
        subtitleLabel?.stringValue = fileName

        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window?.animator().alphaValue = 1.0
        }
    }

    // MARK: - Success
    func complete(outputFiles: [URL]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.spinner?.stopAnimation(nil)
            self.spinner?.isHidden = true
            self.statusIcon?.stringValue = "✅"
            self.statusIcon?.isHidden = false

            self.titleLabel?.stringValue = "Готово!"
            let sub = outputFiles.count == 1 ? outputFiles[0].lastPathComponent : "\(outputFiles.count) файлов сохранено"
            self.subtitleLabel?.stringValue = sub

            // Play sound if enabled
            if Preferences.shared.playSound {
                NSSound(named: "Glass")?.play()
            }

            // Reveal in Finder
            if Preferences.shared.revealInFinder && !outputFiles.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting(outputFiles)
            }

            // Auto dismiss after 1.8 seconds
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    // MARK: - Failure
    func fail(message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.spinner?.stopAnimation(nil)
            self.spinner?.isHidden = true
            self.statusIcon?.stringValue = "❌"
            self.statusIcon?.isHidden = false

            self.titleLabel?.stringValue = "Ошибка конвертации"
            self.subtitleLabel?.stringValue = message

            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    // MARK: - Dismiss
    func dismiss() {
        guard let win = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        })
    }
}
