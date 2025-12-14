import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: StatusViewController?
    private var statusMenu: NSMenu?

    private var statusHostingView: NSHostingView<StatusView>?

    func applicationDidFinishLaunching(_: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        let panelController = StatusViewController()
        self.panelController = panelController

        if let button = statusItem.button {
            let hosting = NSHostingView(rootView: StatusView(feature: panelController.feature))
            hosting.translatesAutoresizingMaskIntoConstraints = false
            button.image = nil
            button.title = ""
            button.addSubview(hosting)

            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 1),
                hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -1),
                hosting.topAnchor.constraint(equalTo: button.topAnchor, constant: 1),
                hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
            ])

            statusHostingView = hosting
        }

        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        statusMenu = makeStatusMenu()
    }

    @objc
    private func togglePanel() {
        guard let button = statusItem?.button else { return }
        guard let panelController else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu(from: button)
            return
        }

        if panelController.isVisible {
            panelController.hide()
        } else {
            panelController.show(relativeTo: button)
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Nasalis", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func showMenu(from _: NSStatusBarButton) {
        guard let statusMenu else { return }
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
