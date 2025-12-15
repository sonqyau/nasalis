import Foundation
import IOKit.ps

enum IOKitReader {
    struct BatterySummary: Sendable {
        var batteryPercent: Int?
        var isCharging: Bool?
    }

    static func readBatterySummary() async -> BatterySummary {
        await withCheckedContinuation { continuation in
            let result = readBatterySummarySync()
            continuation.resume(returning: result)
        }
    }

    private static func readBatterySummarySync() -> BatterySummary {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatterySummary(batteryPercent: nil, isCharging: nil)
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatterySummary(batteryPercent: nil, isCharging: nil)
        }

        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let type = description[kIOPSTypeKey as String] as? String,
               type != kIOPSInternalBatteryType as String
            {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let max = description[kIOPSMaxCapacityKey as String] as? Int

            let percent: Int? = if let current, let max, max > 0 {
                Int((Double(current) / Double(max)) * 100.0)
            } else {
                description[kIOPSCurrentCapacityKey as String] as? Int
            }

            let isCharging = description[kIOPSIsChargingKey as String] as? Bool

            return BatterySummary(batteryPercent: percent, isCharging: isCharging)
        }

        return BatterySummary(batteryPercent: nil, isCharging: nil)
    }
}
