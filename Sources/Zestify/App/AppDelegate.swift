import AppKit
import ApplicationServices

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private var radialWheelController: RadialWheelController?
    private var eventMonitor: GlobalEventMonitor?
    private var statusMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupEventMonitor()
        checkAccessibilityOnLaunch()
    }

    // MARK: - Menu Bar
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            button.image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Zestify")?.withSymbolConfiguration(config)
            button.contentTintColor = NSColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "🍋 Zestify 1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        statusMenuItem = NSMenuItem(title: "● Активен (Ожидание перетаскивания)", action: nil, keyEquivalent: "")
        statusMenuItem?.isEnabled = false
        menu.addItem(statusMenuItem!)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ Настройки…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let accessItem = NSMenuItem(title: "🔑 Разрешения системы…", action: #selector(checkAccessibility), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)

        launchAtLoginMenuItem = NSMenuItem(title: "🚀 Запуск при старте системы", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginMenuItem?.target = self
        launchAtLoginMenuItem?.state = Preferences.shared.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginMenuItem!)

        let helpItem = NSMenuItem(title: "📖 Как пользоваться…", action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Завершить Zestify", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            statusMenuItem?.title = "🟢 Активен (Готов к работе)"
        } else {
            statusMenuItem?.title = "⚠️ Требуется доступ к Спец. возможностям"
        }
        launchAtLoginMenuItem?.state = Preferences.shared.launchAtLogin ? .on : .off
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func checkAccessibility() {
        let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(promptOption)
        if trusted {
            let alert = NSAlert()
            alert.messageText = "Доступ предоставлен! 🟢"
            alert.informativeText = "Zestify имеет необходимые системные разрешения для отслеживания жестов перетаскивания файлов."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Отлично")
            alert.runModal()
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let current = Preferences.shared.launchAtLogin
        Preferences.shared.launchAtLogin = !current
        launchAtLoginMenuItem?.state = (!current) ? .on : .off
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "🍋 Zestify — Как пользоваться"
        alert.informativeText = """
        Zestify работает в фоне без лишних окон:

        1. Выделите один или несколько файлов в Finder.
        2. Начните перетаскивать их и зажмите:
           • ⇧ Shift — откроется круговое колесо форматов (JPEG, PNG, WebP, MP4, PDF...)
           • ⌥⇧ Option + Shift — откроется колесо инструментов (Сжатие, Удаление метаданных, QR-сканер...)
        3. Наведите курсор на нужный сектор и отпустите файл.

        Защита от ложных срабатываний:
        Колесо появляется только если удерживать клавишу во время реального перетаскивания файлов. Настроить задержку можно в Настройках (Cmd+,).
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Понятно!")
        alert.runModal()
    }

    private func checkAccessibilityOnLaunch() {
        if !AXIsProcessTrusted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "Требуется разрешение macOS 🔐"
                alert.informativeText = """
                Для обнаружения жестов перетаскивания с клавишей Shift приложению Zestify требуется доступ к «Универсальному доступу» (Accessibility) в Системных настройках.

                Пожалуйста, включите Zestify в списке.
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Открыть Системные настройки")
                alert.addButton(withTitle: "Позже")
                if alert.runModal() == .alertFirstButtonReturn {
                    let promptOption = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(promptOption)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    // MARK: - Event Monitor
    private func setupEventMonitor() {
        radialWheelController = RadialWheelController()
        eventMonitor = GlobalEventMonitor(radialWheelController: radialWheelController!)
        eventMonitor?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor?.stop()
    }
}
