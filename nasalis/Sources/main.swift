import AppKit
import Foundation

autoreleasepool {
    let app = NSApplication.shared

    app.setActivationPolicy(.accessory)

    app.isAutomaticCustomizeTouchBarMenuItemEnabled = false

    app.appearance = NSAppearance(named: .aqua)

    UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

    let delegate = AppDelegate()
    app.delegate = delegate

    app.run()
}
