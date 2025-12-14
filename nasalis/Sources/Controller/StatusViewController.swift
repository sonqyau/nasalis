import AppKit
import SwiftUI

@MainActor
final class StatusViewController {
    private let popover: NSPopover

    private let hostingController: NSHostingController<MainView>

    private let store: AppStoreType
    private let viewModel: MainViewModel

    let feature: MainFeature

    var isVisible: Bool {
        popover.isShown
    }

    init() {
        store = AppStoreType(initialState: AppState(), reducer: appReducer)
        viewModel = MainViewModel(store: store)

        feature = viewModel.feature

        let rootView = MainView(feature: viewModel.feature)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 360, height: 520)
        self.hostingController = hostingController

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 360, height: 520)
        self.popover = popover
    }

    func show(relativeTo statusBarButton: NSStatusBarButton) {
        guard !popover.isShown else { return }

        hostingController.view.layoutSubtreeIfNeeded()
        let fittingHeight = hostingController.view.fittingSize.height

        if let screen = statusBarButton.window?.screen {
            let visible = screen.visibleFrame
            let maxHeight = max(260, visible.height - 40)
            let desiredHeight = max(260, fittingHeight)
            let clampedHeight = min(desiredHeight, maxHeight)
            popover.contentSize = NSSize(width: 360, height: clampedHeight)
        } else {
            popover.contentSize = NSSize(width: 360, height: max(260, fittingHeight))
        }

        popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .maxY)
    }

    func hide() {
        popover.performClose(nil)
    }
}
