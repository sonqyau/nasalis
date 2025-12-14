import Foundation
import SMCBridge

struct SMCReader: Sendable {
    func readTelemetry() -> EmbeddedSMCSnapshot {
        let systemW = doubleOrNil(SMCBridgeGetRawSystemPowerW())
        let adapterW = doubleOrNil(SMCBridgeGetAdapterPowerW())
        let adapterV = doubleOrNil(SMCBridgeGetAdapterVoltageV())
        let adapterA = doubleOrNil(SMCBridgeGetAdapterAmperageA())

        let batteryV = doubleOrNil(SMCBridgeGetBatteryVoltageV())
        let batteryA = doubleOrNil(SMCBridgeGetBatteryAmperageA())
        let batteryW = doubleOrNil(SMCBridgeGetBatteryPowerW())

        let batteryTempC = temperatureOrNil(SMCBridgeGetBatteryTemperatureC())
        let cycleCount = intOrNil(SMCBridgeGetBatteryCycleCount())

        return EmbeddedSMCSnapshot(
            systemLoadW: systemW,
            adapterPowerW: adapterW,
            adapterVoltageV: adapterV,
            adapterAmperageA: adapterA,
            batteryVoltageV: batteryV,
            batteryAmperageA: batteryA,
            batteryPowerW: batteryW,
            batteryTemperatureC: batteryTempC,
            batteryCycleCount: cycleCount,
            )
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

struct EmbeddedSMCSnapshot: Sendable {
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
