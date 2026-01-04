import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginService: ObservableObject {
  @Published public private(set) var isEnabled: Bool = false
  @Published public private(set) var status: SMAppService.Status = .notFound

  private let service: SMAppService
  private var cancellables = Set<AnyCancellable>()

  @MainActor public static let shared = LaunchAtLoginService()

  public var wasLaunchedAtLogin: Bool {
    let event = NSAppleEventManager.shared().currentAppleEvent
    return event?.eventID == kAEOpenApplication
      && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        == keyAELaunchedAsLogInItem
  }

  public init() {
    service = SMAppService.mainApp
    Task { @MainActor in
      setupStatusMonitoring()
      updateStatus()
    }
  }

  private func setupStatusMonitoring() {
    let shared = Self.shared
    Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          let currentStatus = self.service.status
          if currentStatus != shared.status {
            shared.updateStatus()
          }
        }
      }
      .store(in: &cancellables)
  }

  @discardableResult
  public func enable() async -> Bool {
    do {
      if service.status == .enabled {
        try? await service.unregister()
      }
      try service.register()
      await MainActor.run {
        updateStatus()
      }
      return true
    } catch {
      print("Failed to enable start at login: \(error.localizedDescription)")
      return false
    }
  }

  @discardableResult
  public func disable() async -> Bool {
    do {
      try await service.unregister()
      await MainActor.run {
        updateStatus()
      }
      return true
    } catch {
      print("Failed to disable start at login: \(error.localizedDescription)")
      return false
    }
  }

  @discardableResult
  public func toggle() async -> Bool {
    if isEnabled {
      await disable()
    } else {
      await enable()
    }
  }

  @MainActor
  @discardableResult
  public func enableImmediate() -> Bool {
    Task {
      await enable()
    }
    return true
  }

  @MainActor
  @discardableResult
  public func disableImmediate() -> Bool {
    Task {
      await disable()
    }
    return true
  }

  @MainActor
  private func updateStatus() {
    let newStatus = service.status
    if status != newStatus {
      status = newStatus
      isEnabled = status == .enabled
    }
  }
}
