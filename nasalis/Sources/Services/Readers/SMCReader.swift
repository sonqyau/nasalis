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

        return SMCSnapshot(
            systemLoadW: Self.doubleOrNil(data.systemPowerW),
            adapterPowerW: Self.doubleOrNil(data.adapterPowerW),
            adapterVoltageV: Self.doubleOrNil(data.adapterVoltageV),
            adapterAmperageA: Self.doubleOrNil(data.adapterAmperageA),
            batteryVoltageV: Self.doubleOrNil(data.batteryVoltageV),
            batteryAmperageA: Self.doubleOrNil(data.batteryAmperageA),
            batteryPowerW: Self.doubleOrNil(data.batteryPowerW),
            batteryTemperatureC: Self.temperatureOrNil(data.batteryTemperatureC),
            batteryCycleCount: Self.intOrNil(data.batteryCycleCount)
        )
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
        guard value >= temperatureMin, value <= temperatureMax else { return nil }
        return Double(value)
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

    init(
        systemLoadW: Double? = nil,
        adapterPowerW: Double? = nil,
        adapterVoltageV: Double? = nil,
        adapterAmperageA: Double? = nil,
        batteryVoltageV: Double? = nil,
        batteryAmperageA: Double? = nil,
        batteryPowerW: Double? = nil,
        batteryTemperatureC: Double? = nil,
        batteryCycleCount: Int? = nil,
    ) {
        self.systemLoadW = systemLoadW
        self.adapterPowerW = adapterPowerW
        self.adapterVoltageV = adapterVoltageV
        self.adapterAmperageA = adapterAmperageA
        self.batteryVoltageV = batteryVoltageV
        self.batteryAmperageA = batteryAmperageA
        self.batteryPowerW = batteryPowerW
        self.batteryTemperatureC = batteryTemperatureC
        self.batteryCycleCount = batteryCycleCount
    }
}
