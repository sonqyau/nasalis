import Foundation

extension String {
    @inline(__always)
    func firstMatchInt(pattern: String) -> Int? {
        firstMatchString(pattern: pattern).flatMap(Int.init)
    }

    func firstMatchString(pattern: String) -> String? {
        if pattern == "\\d+" {
            return extractFirstInteger()
        }

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsRange = NSRange(location: 0, length: utf16.count)
        guard let match = regex.firstMatch(in: self, range: nsRange) else { return nil }

        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        let matchRange = match.range(at: captureIndex)
        guard matchRange.location != NSNotFound,
              let range = Range(matchRange, in: self) else { return nil }

        return String(self[range])
    }

    @inline(__always)
    private func extractFirstInteger() -> String? {
        utf8.withContiguousStorageIfAvailable { bytes in
            var start = -1
            var end = -1

            for i in 0 ..< bytes.count {
                let byte = bytes[i]
                let isDigit = byte >= 48 && byte <= 57

                if isDigit, start == -1 {
                    start = i
                } else if !isDigit, start != -1 {
                    end = i
                    break
                }
            }

            if start != -1 {
                if end == -1 { end = bytes.count }
                let startIndex = utf8.index(utf8.startIndex, offsetBy: start)
                let endIndex = utf8.index(utf8.startIndex, offsetBy: end)
                return String(utf8[startIndex ..< endIndex]) ?? ""
            }

            return ""
        }
    }
}
