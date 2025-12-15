import Foundation
import SMCBridge

struct SMCReader: Sendable {
    func readTelemetry() -> SMCSnapshot {
        var data = SMCBridgeData()
        guard SMCBridgeReadAll(&data) else {
            return SMCSnapshot()
        }

        return SMCSnapshot(
            systemLoadW: doubleOrNil(data.systemPowerW),
            adapterPowerW: doubleOrNil(data.adapterPowerW),
            adapterVoltageV: doubleOrNil(data.adapterVoltageV),
            adapterAmperageA: doubleOrNil(data.adapterAmperageA),
            batteryVoltageV: doubleOrNil(data.batteryVoltageV),
            batteryAmperageA: doubleOrNil(data.batteryAmperageA),
            batteryPowerW: doubleOrNil(data.batteryPowerW),
            batteryTemperatureC: temperatureOrNil(data.batteryTemperatureC),
            batteryCycleCount: intOrNil(data.batteryCycleCount),
            )
    }

    static func invalidateCache() {
        SMCBridgeInvalidateCache()
    }

    private func doubleOrNil(_ value: Float) -> Double? {
        if value.isNaN { return nil }
        return Double(value)
    }

    private func temperatureOrNil(_ value: Float) -> Double? {
        if value.isNaN { return nil }
        let v = Double(value)

        if abs(v) < 0.001 { return nil }
        if v < -20 || v > 120 { return nil }
        return v
    }

    private func intOrNil(_ value: Int32) -> Int? {
        if value < 0 { return nil }
        return Int(value)
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
