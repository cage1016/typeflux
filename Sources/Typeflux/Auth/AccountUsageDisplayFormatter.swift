import Foundation

enum AccountUsageDisplayFormatter {
    static func count(_ value: Int64) -> String {
        let sign = value < 0 ? "-" : ""
        let absValue = value == Int64.min ? Int64.max : abs(value)

        guard absValue >= 10_000 else {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = true
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        let units: [(threshold: Double, suffix: String)] = [
            (1_000_000_000_000, "T"),
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K"),
        ]

        for index in units.indices {
            let unit = units[index]
            guard Double(absValue) >= unit.threshold else { continue }

            let scaled = Double(absValue) / unit.threshold
            let rounded = roundedCompactValue(scaled)
            if rounded >= 1_000, index > 0 {
                let biggerUnit = units[index - 1]
                let biggerScaled = roundedCompactValue(Double(absValue) / biggerUnit.threshold)
                return sign + compactDecimalString(biggerScaled) + biggerUnit.suffix
            }
            return sign + compactDecimalString(rounded) + unit.suffix
        }

        return "\(value)"
    }

    static func audioDuration(_ milliseconds: Int64) -> String {
        let seconds = max(0, Double(milliseconds) / 1_000.0)
        if seconds < 60 {
            return String(format: L("auth.account.usageSeconds"), seconds)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return String(format: L("auth.account.usageMinutes"), minutes)
        }

        let hours = minutes / 60
        if hours < 24 {
            return String(format: L("auth.account.usageHours"), hours)
        }

        return String(format: L("auth.account.usageDays"), hours / 24)
    }

    private static func roundedCompactValue(_ value: Double) -> Double {
        if value >= 100 {
            return value.rounded()
        }
        if value >= 10 {
            return (value * 10).rounded() / 10
        }
        return (value * 100).rounded() / 100
    }

    private static func compactDecimalString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value >= 100 ? 0 : (value >= 10 ? 1 : 2)
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
