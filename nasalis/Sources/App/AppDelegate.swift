import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appComposition: AppComposition?

    func applicationDidFinishLaunching(_: Notification) {
        DispatchQueue.global(qos: .userInitiated).async {
            SMCReader.invalidateCache()
        }

        appComposition = nasalisApp.AppComposition()

        NSApp.setActivationPolicy(.accessory)

        NSApp.appearance = NSAppearance(named: .aqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        appComposition = nil
    }
}
