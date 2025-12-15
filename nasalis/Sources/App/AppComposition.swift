import AppKit
import SwiftUI

@MainActor
final class AppComposition {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var statusHostingView: NSHostingView<StatusView>?

    private let store: Store<AppState, AppAction>
    private let mainViewModel: MainViewModel

    init() {
        store = Store(initialState: AppState(), reducer: appReducer)

        mainViewModel = NasalisApp.MainViewModel(store: store)

        setupStatusBar()
        setupPopover()
    }

    private func setupStatusBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        guard let button = statusItem.button else { return }

        let statusView = StatusView(viewModel: mainViewModel)
        let hostingView = NSHostingView(rootView: statusView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        button.image = nil
        button.title = ""
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 1),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -1),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor, constant: 1),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -1),
        ])

        statusHostingView = hostingView

        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(handleStatusBarClick)
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let detailView = MainView(viewModel: mainViewModel)
        let hostingController = NSHostingController(rootView: detailView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 360, height: 520)

        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 360, height: 520)

        self.popover = popover
    }

    @objc private func handleStatusBarClick() {
        guard let button = statusItem?.button else { return }
        guard let popover else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu(from: button)
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        guard let popover else { return }
        guard !popover.isShown else { return }

        if let hostingController = popover.contentViewController as? NSHostingController<MainView> {
            hostingController.view.layoutSubtreeIfNeeded()
            let fittingHeight = hostingController.view.fittingSize.height

            if let screen = button.window?.screen {
                let visible = screen.visibleFrame
                let maxHeight = max(260, visible.height - 40)
                let desiredHeight = max(260, fittingHeight)
                let clampedHeight = min(desiredHeight, maxHeight)
                popover.contentSize = NSSize(width: 360, height: clampedHeight)
            } else {
                popover.contentSize = NSSize(width: 360, height: max(260, fittingHeight))
            }
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Nasalis", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
