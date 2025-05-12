import SwiftUI

@main
struct DeepLCloneMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appDelegate.viewModel)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}
