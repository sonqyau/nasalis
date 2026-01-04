import Foundation
import SMCBridge

struct SMCReader: Sendable {
  private static let temperatureMin: Float = -20.0
  private static let temperatureMax: Float = 120.0
  private static let temperatureEpsilon: Float = 0.001

  @inline(__always)
  func readTelemetry() -> SMCSnapshot {
    var data = SMCBridgeData()
    guard SMCBridgeReadAll(&data) else {
      return SMCSnapshot()
    }

    return withUnsafePointer(to: data) { ptr in
      SMCSnapshot(
        systemLoadW: Self.doubleOrNil(ptr.pointee.systemPowerW),
        adapterPowerW: Self.doubleOrNil(ptr.pointee.adapterPowerW),
        adapterVoltageV: Self.doubleOrNil(ptr.pointee.adapterVoltageV),
        adapterAmperageA: Self.doubleOrNil(ptr.pointee.adapterAmperageA),
        batteryVoltageV: Self.doubleOrNil(ptr.pointee.batteryVoltageV),
        batteryAmperageA: Self.doubleOrNil(ptr.pointee.batteryAmperageA),
        batteryPowerW: Self.doubleOrNil(ptr.pointee.batteryPowerW),
        batteryTemperatureC: Self.temperatureOrNil(ptr.pointee.batteryTemperatureC),
        batteryCycleCount: Self.intOrNil(ptr.pointee.batteryCycleCount),
      )
    }
  }

  @inline(__always)
  static func invalidateCache() {
    SMCBridgeInvalidateCache()
  }

  @inline(__always)
  private static func doubleOrNil(_ value: Float) -> Double? {
    value.isNaN ? nil : Double(value)
  }

  @inline(__always)
  private static func temperatureOrNil(_ value: Float) -> Double? {
    guard !value.isNaN else { return nil }
    guard abs(value) >= temperatureEpsilon else { return nil }
    let v = value
    guard v >= temperatureMin, v <= temperatureMax else { return nil }
    return Double(v)
  }

  @inline(__always)
  private static func intOrNil(_ value: Int32) -> Int? {
    value < 0 ? nil : Int(value)
  }
}

struct SMCSnapshot: Sendable {
  var systemLoadW: Double?
  var adapterPowerW: Double?
  var adapterVoltageV: Double?
  var adapterAmperageA: Double?
  var batteryVoltageV: Double?
  var batteryAmperageA: Double?
  var batteryPowerW: Double?
  var batteryTemperatureC: Double?
  var batteryCycleCount: Int?
}
