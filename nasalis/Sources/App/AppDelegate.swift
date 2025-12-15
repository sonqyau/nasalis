import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appComposition: AppComposition?

    func applicationDidFinishLaunching(_: Notification) {
        SMCReader.invalidateCache()
        appComposition = NasalisApp.AppComposition()
    }
}
