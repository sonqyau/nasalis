import AppKit
import SwiftUI

@MainActor
final class MainViewController: NSViewController {
    private let store: AppStoreType = .init(initialState: AppState(), reducer: appReducer)
    private var viewModel: MainViewModel!

    override func loadView() {
        viewModel = MainViewModel(store: store)

        let root = MainView(feature: viewModel.feature)

        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }
}
