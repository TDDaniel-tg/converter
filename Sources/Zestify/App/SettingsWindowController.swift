import AppKit
import ApplicationServices

final class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private var delaySlider: NSSlider!
    private var delayLabel: NSTextField!
    private var saveNextRadio: NSButton!
    private var saveCustomRadio: NSButton!
    private var customPathLabel: NSTextField!
    private var chooseFolderButton: NSButton!
    private var launchAtLoginCheck: NSButton!
    private var soundCheck: NSButton!
    private var notifyCheck: NSButton!
    private var revealCheck: NSButton!
    private var accessibilityStatusLabel: NSTextField!
    private var accessibilityButton: NSButton!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Настройки Zestify"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = self.window else { return }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        let pad: CGFloat = 24
        var y: CGFloat = window.contentView!.bounds.height - pad

        // MARK: - Header
        y -= 36
        let headerIcon = NSTextField(labelWithString: "🍋")
        headerIcon.font = NSFont.systemFont(ofSize: 32)
        headerIcon.frame = NSRect(x: pad, y: y, width: 40, height: 38)
        contentView.addSubview(headerIcon)

        let titleLabel = NSTextField(labelWithString: "Zestify — Настройки")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.frame = NSRect(x: pad + 44, y: y + 8, width: 300, height: 24)
        contentView.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Конвертер файлов с радиальным интерфейсом")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: pad + 44, y: y - 10, width: 350, height: 16)
        contentView.addSubview(subtitleLabel)

        y -= 24
        addSeparator(at: y, in: contentView)

        // MARK: - Section 1: False positive protection
        y -= 30
        let sec1Title = createSectionTitle("Защита от ложных срабатываний", y: y)
        contentView.addSubview(sec1Title)

        y -= 22
        let sliderDesc = NSTextField(labelWithString: "Задержка удержания клавиши (Shift / Option+Shift):")
        sliderDesc.font = NSFont.systemFont(ofSize: 12)
        sliderDesc.frame = NSRect(x: pad, y: y, width: 320, height: 18)
        contentView.addSubview(sliderDesc)

        delayLabel = NSTextField(labelWithString: "\(Int(Preferences.shared.debounceDelay * 1000)) мс")
        delayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        delayLabel.alignment = .right
        delayLabel.frame = NSRect(x: 380, y: y, width: 70, height: 18)
        contentView.addSubview(delayLabel)

        y -= 26
        delaySlider = NSSlider(value: Preferences.shared.debounceDelay, minValue: 0.15, maxValue: 0.80, target: self, action: #selector(sliderChanged(_:)))
        delaySlider.frame = NSRect(x: pad, y: y, width: 432, height: 20)
        contentView.addSubview(delaySlider)

        y -= 18
        let noteLabel = NSTextField(labelWithString: "Колесо появится только если удерживать клавишу во время перетаскивания.")
        noteLabel.font = NSFont.systemFont(ofSize: 10)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.frame = NSRect(x: pad, y: y, width: 432, height: 16)
        contentView.addSubview(noteLabel)

        y -= 16
        addSeparator(at: y, in: contentView)

        // MARK: - Section 2: Save Destination
        y -= 30
        let sec2Title = createSectionTitle("Сохранение файлов", y: y)
        contentView.addSubview(sec2Title)

        y -= 24
        saveNextRadio = NSButton(radioButtonWithTitle: "Сохранять в ту же папку рядом с оригиналом", target: self, action: #selector(saveLocationModeChanged))
        saveNextRadio.frame = NSRect(x: pad, y: y, width: 400, height: 18)
        saveNextRadio.state = Preferences.shared.saveNextToOriginal ? .on : .off
        contentView.addSubview(saveNextRadio)

        y -= 24
        saveCustomRadio = NSButton(radioButtonWithTitle: "Сохранять в отдельную папку:", target: self, action: #selector(saveLocationModeChanged))
        saveCustomRadio.frame = NSRect(x: pad, y: y, width: 400, height: 18)
        saveCustomRadio.state = Preferences.shared.saveNextToOriginal ? .off : .on
        contentView.addSubview(saveCustomRadio)

        y -= 26
        customPathLabel = NSTextField(labelWithString: Preferences.shared.customSaveDirectory.path)
        customPathLabel.font = NSFont.systemFont(ofSize: 11)
        customPathLabel.textColor = .secondaryLabelColor
        customPathLabel.lineBreakMode = .byTruncatingMiddle
        customPathLabel.frame = NSRect(x: pad + 20, y: y, width: 280, height: 20)
        contentView.addSubview(customPathLabel)

        chooseFolderButton = NSButton(title: "Выбрать папку…", target: self, action: #selector(chooseFolderClicked))
        chooseFolderButton.bezelStyle = .rounded
        chooseFolderButton.font = NSFont.systemFont(ofSize: 11)
        chooseFolderButton.frame = NSRect(x: 320, y: y - 2, width: 130, height: 24)
        chooseFolderButton.isEnabled = !Preferences.shared.saveNextToOriginal
        contentView.addSubview(chooseFolderButton)

        y -= 16
        addSeparator(at: y, in: contentView)

        // MARK: - Section 3: Behavior
        y -= 30
        let sec3Title = createSectionTitle("Поведение и уведомления", y: y)
        contentView.addSubview(sec3Title)

        y -= 24
        launchAtLoginCheck = NSButton(checkboxWithTitle: "Запускать при входе в систему (всегда висеть в трее)", target: self, action: #selector(launchAtLoginToggled(_:)))
        launchAtLoginCheck.frame = NSRect(x: pad, y: y, width: 430, height: 18)
        launchAtLoginCheck.state = Preferences.shared.launchAtLogin ? .on : .off
        contentView.addSubview(launchAtLoginCheck)

        y -= 24
        soundCheck = NSButton(checkboxWithTitle: "Звуковой сигнал по завершении", target: self, action: #selector(soundToggled(_:)))
        soundCheck.frame = NSRect(x: pad, y: y, width: 430, height: 18)
        soundCheck.state = Preferences.shared.playSound ? .on : .off
        contentView.addSubview(soundCheck)

        y -= 24
        notifyCheck = NSButton(checkboxWithTitle: "Системные уведомления", target: self, action: #selector(notifyToggled(_:)))
        notifyCheck.frame = NSRect(x: pad, y: y, width: 430, height: 18)
        notifyCheck.state = Preferences.shared.showNotifications ? .on : .off
        contentView.addSubview(notifyCheck)

        y -= 24
        revealCheck = NSButton(checkboxWithTitle: "Показывать созданный файл в Finder", target: self, action: #selector(revealToggled(_:)))
        revealCheck.frame = NSRect(x: pad, y: y, width: 430, height: 18)
        revealCheck.state = Preferences.shared.revealInFinder ? .on : .off
        contentView.addSubview(revealCheck)

        y -= 16
        addSeparator(at: y, in: contentView)

        // MARK: - Section 4: Accessibility
        y -= 28
        let sec4Title = createSectionTitle("Системные разрешения", y: y)
        contentView.addSubview(sec4Title)

        y -= 24
        accessibilityStatusLabel = NSTextField(labelWithString: "")
        accessibilityStatusLabel.font = NSFont.systemFont(ofSize: 12)
        accessibilityStatusLabel.frame = NSRect(x: pad, y: y, width: 260, height: 20)
        contentView.addSubview(accessibilityStatusLabel)

        accessibilityButton = NSButton(title: "Открыть настройки", target: self, action: #selector(openAccessibilitySettings))
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.font = NSFont.systemFont(ofSize: 11)
        accessibilityButton.frame = NSRect(x: 290, y: y - 2, width: 160, height: 24)
        contentView.addSubview(accessibilityButton)

        refreshAccessibilityStatus()
    }

    private func createSectionTitle(_ title: String, y: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        label.frame = NSRect(x: 24, y: y, width: 400, height: 18)
        return label
    }

    private func addSeparator(at y: CGFloat, in view: NSView) {
        let line = NSBox(frame: NSRect(x: 24, y: y, width: 432, height: 1))
        line.boxType = .separator
        view.addSubview(line)
    }

    // MARK: - Actions

    @objc private func sliderChanged(_ sender: NSSlider) {
        let val = (sender.doubleValue * 100).rounded() / 100
        Preferences.shared.debounceDelay = val
        delayLabel.stringValue = "\(Int(val * 1000)) мс"
    }

    @objc private func saveLocationModeChanged() {
        let nextToOriginal = (saveNextRadio.state == .on)
        Preferences.shared.saveNextToOriginal = nextToOriginal
        saveCustomRadio.state = nextToOriginal ? .off : .on
        chooseFolderButton.isEnabled = !nextToOriginal
    }

    @objc private func chooseFolderClicked() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать"
        if panel.runModal() == .OK, let url = panel.url {
            Preferences.shared.customSaveDirectory = url
            customPathLabel.stringValue = url.path
        }
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        Preferences.shared.launchAtLogin = (sender.state == .on)
    }

    @objc private func soundToggled(_ sender: NSButton) {
        Preferences.shared.playSound = (sender.state == .on)
    }

    @objc private func notifyToggled(_ sender: NSButton) {
        Preferences.shared.showNotifications = (sender.state == .on)
    }

    @objc private func revealToggled(_ sender: NSButton) {
        Preferences.shared.revealInFinder = (sender.state == .on)
    }

    @objc private func openAccessibilitySettings() {
        let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(promptOption)

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refreshAccessibilityStatus() {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            accessibilityStatusLabel.stringValue = "🟢 Доступ предоставлен"
            accessibilityStatusLabel.textColor = .systemGreen
            accessibilityButton.title = "Проверено"
        } else {
            accessibilityStatusLabel.stringValue = "⚠️ Требуется доступ (Спец. возможности)"
            accessibilityStatusLabel.textColor = .systemOrange
            accessibilityButton.title = "Разрешить доступ…"
        }
    }

    func showSettings() {
        refreshAccessibilityStatus()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
