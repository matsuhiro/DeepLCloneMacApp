import Cocoa
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let viewModel = TranslationViewModel()
    private var lastHotKeyDate = Date()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーアイコンの設定
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Translate")
        statusItem.button?.action = #selector(toggleWindow)
        statusItem.button?.target = self

        // Cmd+C ダブルタップのグローバルショートカット登録
        let hotKey = HotKey(key: .c, modifiers: [.command])
        hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            let now = Date()
            if now.timeIntervalSince(self.lastHotKeyDate) < 0.5 {
                // ダブルタップ検出
                self.viewModel.translateClipboard()
                self.showWindow()
            }
            self.lastHotKeyDate = now
        }
    }

    @objc func toggleWindow() {
        // メインウィンドウを表示・非表示切り替え
        guard let window = NSApp.mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func showWindow() {
        // 常に前面に表示
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
