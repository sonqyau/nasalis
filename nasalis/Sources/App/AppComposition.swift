import AppKit
import SwiftUI

@MainActor
final class AppComposition: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let statusHostingView: NSHostingView<StatusView>
    private let store: Store<AppState, AppAction>
    private let mainViewModel: MainViewModel
    private let popoverController: NSHostingController<MainView>

    private static let popoverSize = NSSize(width: 360, height: 520)
    private static let minPopoverHeight: CGFloat = 260
    private static let screenMargin: CGFloat = 40

    override init() {
        store = Store(initialState: AppState(), reducer: appReducer)
        mainViewModel = NasalisApp.MainViewModel(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        let statusView = StatusView(viewModel: mainViewModel)
        statusHostingView = NSHostingView(rootView: statusView)

        let detailView = MainView(viewModel: mainViewModel)
        popoverController = NSHostingController(rootView: detailView)

        super.init()

        setupStatusBar()
        setupPopover()
    }

    private func setupStatusBar() {
        guard let button = statusItem.button else {
            fatalError("Status item button unavailable")
        }

        statusHostingView.wantsLayer = true
        statusHostingView.layer?.drawsAsynchronously = true

        button.image = nil
        button.title = ""
        button.addSubview(statusHostingView)

        statusHostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusHostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
            statusHostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
            statusHostingView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            statusHostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
        ])

        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(handleStatusBarClick)

        if let cell = button.cell as? NSButtonCell {
            cell.highlightsBy = []
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = popoverController
        popover.contentSize = Self.popoverSize

        popoverController.view.frame = NSRect(origin: .zero, size: Self.popoverSize)
        popoverController.view.wantsLayer = true
        popoverController.view.layer?.drawsAsynchronously = true

        if let layer = popoverController.view.layer {
            layer.shouldRasterize = true
            layer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2.0
        }
    }

    @objc private func handleStatusBarClick() {
        guard let button = statusItem.button else { return }

        if let event = NSApp.currentEvent, event.type.rawValue == NSEvent.EventType.rightMouseUp.rawValue {
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
        guard !popover.isShown else { return }

        let view = popoverController.view
        view.layoutSubtreeIfNeeded()
        let fittingHeight = view.fittingSize.height

        let finalHeight: CGFloat
        if let screen = button.window?.screen {
            let maxHeight = max(Self.minPopoverHeight, screen.visibleFrame.height - Self.screenMargin)
            finalHeight = min(max(Self.minPopoverHeight, fittingHeight), maxHeight)
        } else {
            finalHeight = max(Self.minPopoverHeight, fittingHeight)
        }

        let newSize = NSSize(width: Self.popoverSize.width, height: finalHeight)
        if popover.contentSize != newSize {
            popover.contentSize = newSize
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = Self.contextMenu
        menu.delegate = self

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private static let contextMenu: NSMenu = {
        let menu = NSMenu()

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(AppComposition.toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(AppComposition.quit), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quit)

        return menu
    }()

    @objc private func toggleLaunchAtLogin() {
        mainViewModel.input.launchAtLoginToggled(!mainViewModel.output.launchAtLogin)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension AppComposition: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        menu.items.forEach { $0.target = self }

        if let launchAtLoginItem = menu.items.first(where: { $0.action == #selector(toggleLaunchAtLogin) }) {
            launchAtLoginItem.state = mainViewModel.output.launchAtLogin ? .on : .off
        }
    }
}
