import Foundation
import IOKit.ps

enum IOKitReader {
    struct BatterySummary: Sendable {
        let batteryPercent: Int?
        let isCharging: Bool

        @inline(__always)
        init(batteryPercent: Int?, isCharging: Bool) {
            self.batteryPercent = batteryPercent
            self.isCharging = isCharging
        }
    }

    private static let emptyResult = BatterySummary(batteryPercent: nil, isCharging: false)
    private static let typeKey = kIOPSTypeKey as String
    private static let internalBatteryType = kIOPSInternalBatteryType as String
    private static let currentCapacityKey = kIOPSCurrentCapacityKey as String
    private static let maxCapacityKey = kIOPSMaxCapacityKey as String
    private static let isChargingKey = kIOPSIsChargingKey as String

    @inline(__always)
    static func readBatterySummary() async -> BatterySummary {
        readBatterySummarySync()
    }

    private static func readBatterySummarySync() -> BatterySummary {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return emptyResult
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return emptyResult
        }

        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let type = description[typeKey] as? String,
               type != internalBatteryType
            {
                continue
            }

            let current = description[currentCapacityKey] as? Int
            let max = description[maxCapacityKey] as? Int

            let percent: Int? = if let current, let max, max > 0 {
                (current * 100) / max
            } else {
                current
            }

            let isCharging = description[isChargingKey] as? Bool ?? false

            return BatterySummary(batteryPercent: percent, isCharging: isCharging)
        }

        return emptyResult
    }
}
