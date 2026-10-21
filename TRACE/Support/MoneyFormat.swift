import Foundation

/// Money is stored as Int paise. These two functions are the only bridge to text.
enum Money {
    /// Keypad or typed rupees → paise. "410" → 41000, "1,04,250.5" → 10425050.
    /// Nil for anything that is not a plain non-negative amount with ≤2 decimals.
    static func paise(fromRupees text: String) -> Int? {
        let t = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else { return nil }
        let parts = t.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }
        let wholeText = parts[0]
        let fracText = parts.count == 2 ? parts[1] : ""
        guard fracText.count <= 2, !(wholeText.isEmpty && fracText.isEmpty),
              let whole = Int(wholeText.isEmpty ? "0" : wholeText),
              let frac = Int((fracText + "00").prefix(2)) else { return nil }
        let (scaled, o1) = whole.multipliedReportingOverflow(by: 100)
        let (total, o2) = scaled.addingReportingOverflow(frac)
        return o1 || o2 ? nil : total
    }

    /// Paise → "₹1,04,250" or "₹410.50". View layer only. Locale decides grouping
    /// (en_IN gives lakh grouping); currency is per expense, INR by default.
    static func format(_ paise: Int, currencyCode: String = "INR", locale: Locale = .current) -> String {
        let value = Decimal(paise) / 100
        let decimals = paise % 100 == 0 ? 0 : 2
        return value.formatted(.currency(code: currencyCode).locale(locale).precision(.fractionLength(decimals)))
    }
}
