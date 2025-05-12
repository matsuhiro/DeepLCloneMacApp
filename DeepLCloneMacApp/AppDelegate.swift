import Cocoa
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let viewModel = TranslationViewModel()
    private var lastHotKeyDate = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーアイコン
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Translate")
        statusItem.button?.action = #selector(toggleWindow)
        statusItem.button?.target = self

        // グローバルショートカット
        let hotKey = HotKey(key: .c, modifiers: [.command])
        hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            let now = Date()
            if now.timeIntervalSince(self.lastHotKeyDate) < 0.5 {
                self.viewModel.translateClipboard()
                self.showWindow()
            }
            self.lastHotKeyDate = now
        }
    }

    @objc func toggleWindow() {
        guard let window = NSApp.mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
