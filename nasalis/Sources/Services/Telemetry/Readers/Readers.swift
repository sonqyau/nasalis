import Foundation

enum Readers {
    static func readBatteryPercentAndCharging() async -> (Int?, Bool?) {
        let output = await runProcess("/usr/bin/pmset", ["-g", "batt"], timeoutSeconds: 1.0) ?? ""

        let percent = parsePercent(output)

        let charging: Bool? = if output.localizedCaseInsensitiveContains("charging") {
            true
        } else if output.localizedCaseInsensitiveContains("discharging") {
            false
        } else {
            nil
        }

        return (percent, charging)
    }

    struct BatteryDetails: Sendable {
        var designCapacity_mAh: Int?
        var maxCapacity_mAh: Int?
        var cycleCount: Int?
        var temperatureC: Double?
        var serialNumber: String?
        var batteryVoltageV: Double?
        var batteryAmperageA: Double?
        var batteryPowerW: Double?
    }

    static func readBatteryDetails() async -> BatteryDetails {
        let output = await runProcess(
            "/usr/sbin/ioreg",
            [
                "-r",
                "-c",
                "AppleSmartBattery",
            ],
            timeoutSeconds: 1.0,
            ) ?? ""

        let designCapacity = parseKeyInt(output, key: "\"DesignCapacity\"")
        let maxCapacity = parseKeyInt(output, key: "\"AppleRawMaxCapacity\"")
        let cycleCount = parseKeyInt(output, key: "\"CycleCount\"")
        let temperatureRaw = parseKeyInt(output, key: "\"VirtualTemperature\"")

        let voltage_mV =
            parseKeyInt(output, key: "\"Voltage\"", allowSign: true)
            ?? parseKeyInt(output, key: "\"InstantVoltage\"", allowSign: true)

        let amperage_mA =
            parseKeyInt(output, key: "\"InstantAmperage\"", allowSign: true)
            ?? parseKeyInt(output, key: "\"Amperage\"", allowSign: true)
            ?? parseKeyInt(output, key: "\"InstantCurrent\"", allowSign: true)

        let serialNumber = parseKeyQuotedString(output, key: "\"Serial\"")

        let temperatureC: Double? = if let temperatureRaw {
            Double(temperatureRaw) / 100.0
        } else {
            nil
        }

        let batteryVoltageV: Double? = if let voltage_mV {
            Double(voltage_mV) / 1000.0
        } else {
            nil
        }

        let batteryAmperageA: Double? = if let amperage_mA {
            Double(amperage_mA) / 1000.0
        } else {
            nil
        }

        let batteryPowerW: Double? = if let v = batteryVoltageV, let a = batteryAmperageA {
            v * a
        } else {
            nil
        }

        return BatteryDetails(
            designCapacity_mAh: designCapacity,
            maxCapacity_mAh: maxCapacity,
            cycleCount: cycleCount,
            temperatureC: temperatureC,
            serialNumber: serialNumber,
            batteryVoltageV: batteryVoltageV,
            batteryAmperageA: batteryAmperageA,
            batteryPowerW: batteryPowerW,
            )
    }

    private static func runProcess(_ executablePath: String, _ arguments: [String], timeoutSeconds: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            actor State {
                var finished = false
                let continuation: CheckedContinuation<String?, Never>
                let process: Process
                let pipe: Pipe
                var timeoutTask: Task<Void, Never>?

                init(continuation: CheckedContinuation<String?, Never>, process: Process, pipe: Pipe) {
                    self.continuation = continuation
                    self.process = process
                    self.pipe = pipe
                }

                func armTimeout(seconds: TimeInterval) {
                    timeoutTask = Task.detached {
                        let ns = UInt64(seconds * 1_000_000_000)
                        if ns > 0 {
                            try? await Task.sleep(nanoseconds: ns)
                        }
                        await self.onTimeout()
                    }
                }

                func onTimeout() {
                    guard !finished else { return }
                    if process.isRunning {
                        process.terminate()
                    }
                }

                func onTerminate() {
                    guard !finished else { return }
                    finished = true
                    timeoutTask?.cancel()
                    timeoutTask = nil
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(bytes: data, encoding: .utf8))
                }

                func onStartFailed() {
                    guard !finished else { return }
                    finished = true
                    timeoutTask?.cancel()
                    timeoutTask = nil
                    continuation.resume(returning: nil)
                }
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let state = State(continuation: continuation, process: process, pipe: pipe)
            Task { await state.armTimeout(seconds: timeoutSeconds) }

            process.terminationHandler = { _ in
                Task { await state.onTerminate() }
            }

            do {
                try process.run()
            } catch {
                Task { await state.onStartFailed() }
            }
        }
    }

    private static func parsePercent(_ s: String) -> Int? {
        s.utf8.withContiguousStorageIfAvailable { bytes -> Int? in
            let n = bytes.count
            var i = 0
            while i < n {
                if bytes[i] == 37 {
                    var j = i
                    var v = 0
                    var mul = 1
                    var any = false
                    while j > 0 {
                        j &-= 1
                        let d = Int(bytes[j]) - 48
                        if d < 0 || d > 9 { break }
                        any = true
                        v &+= d * mul
                        mul &*= 10
                        if mul > 1000 { break }
                    }
                    if any { return v }
                }
                i &+= 1
            }
            return nil
        } ?? fallbackParsePercent(s)
    }

    private static func fallbackParsePercent(_ s: String) -> Int? {
        var last = 0
        var any = false
        for u in s.utf8 {
            if u == 37 { return any ? last : nil }
            let d = Int(u) - 48
            if d >= 0, d <= 9 {
                any = true
                last = min(999, last * 10 + d)
            } else {
                any = false
                last = 0
            }
        }
        return nil
    }

    private static func parseKeyInt(_ s: String, key: String, allowSign: Bool = false) -> Int? {
        guard let keyRange = s.range(of: key) else { return nil }
        let tail = s[keyRange.upperBound...]
        return tail.utf8.withContiguousStorageIfAvailable { bytes -> Int? in
            var i = 0
            let n = bytes.count
            while i < n {
                let c = bytes[i]
                if c == 61 { i &+= 1; break }
                i &+= 1
            }
            while i < n {
                let c = bytes[i]
                if c != 9, c != 10, c != 13, c != 32 { break }
                i &+= 1
            }
            var sign = 1
            if allowSign, i < n, bytes[i] == 45 { sign = -1; i &+= 1 }
            var v = 0
            var any = false
            while i < n {
                let d = Int(bytes[i]) - 48
                if d < 0 || d > 9 { break }
                any = true
                v = v &* 10 &+ d
                i &+= 1
            }
            return any ? v * sign : nil
        } ?? nil
    }

    private static func parseKeyQuotedString(_ s: String, key: String) -> String? {
        guard let keyRange = s.range(of: key) else { return nil }
        let tail = s[keyRange.upperBound...]
        guard let firstQuote = tail.firstIndex(of: "\"") else { return nil }
        let after = tail.index(after: firstQuote)
        guard let secondQuote = tail[after...].firstIndex(of: "\"") else { return nil }
        return String(tail[after ..< secondQuote])
    }
}
