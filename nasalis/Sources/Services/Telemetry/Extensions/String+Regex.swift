import Foundation

extension String {
    func firstMatchInt(pattern: String) -> Int? {
        guard let s = firstMatchString(pattern: pattern) else { return nil }
        return Int(s)
    }

    func firstMatchString(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(startIndex ..< endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range) else {
            return nil
        }

        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let r = Range(match.range(at: captureIndex), in: self) else {
            return nil
        }

        return String(self[r])
    }
}
