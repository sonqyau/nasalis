import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var AppComposition: AppComposition?

    func applicationDidFinishLaunching(_: Notification) {
        SMCReader.invalidateCache()
        AppComposition = NasalisApp.AppComposition()
    }
}
