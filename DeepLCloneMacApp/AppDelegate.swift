import Cocoa
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let viewModel = TranslationViewModel()
    private var hotKey: HotKey?    // HotKey インスタンスを保持

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーアイコンの設定
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Translate")
        statusItem.button?.action = #selector(toggleWindow)
        statusItem.button?.target = self

        // Cmd+G のホットキー登録
        hotKey = HotKey(key: .g, modifiers: [.command])
        hotKey?.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            // クリップボードの文字を左テキストエリアにセットして翻訳
            self.viewModel.translateClipboard()
            self.showWindow()
        }

        // 起動時にクリップボード内のテキストを入力欄にセット
        if let text = NSPasteboard.general.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.inputText = text
        }
    }

    @objc func toggleWindow() {
        // ウィンドウを表示／非表示切り替え
        guard let window = NSApp.mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        // 他アプリより前面に出してフォーカス
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
