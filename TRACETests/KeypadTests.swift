import Testing
@testable import TRACE

@Suite struct KeypadTests {
    // Amount field: 2 decimals, ≤ 7 whole digits (₹99,99,999 cap, S08).
    @Test(arguments: [
        ("", "4", "4"),
        ("41", "0", "410"),
        ("0", "5", "5"),              // no leading zero
        ("", ".", "0."),
        ("410", ".", "410."),
        ("410.", ".", "410."),        // one point only
        ("410.5", "0", "410.50"),
        ("410.50", "1", "410.50"),    // third decimal refused
        ("9999999", "9", "9999999"),  // cap refused
        ("410", "⌫", "41"),
        ("", "⌫", ""),
    ])
    func amount(text: String, key: String, expected: String) {
        #expect(Keypad.apply(key, to: text, decimals: 2, maxWhole: 7) == expected)
    }

    @Test func odometerTakesNoPoint() {
        #expect(Keypad.apply(".", to: "1248", decimals: 0, maxWhole: 7) == "1248")
    }

    // First key after picking a prefilled field replaces it (critique #5).
    @Test(arguments: [
        ("12480", "5", "5"),
        ("12480", "⌫", ""),
        ("410.50", ".", "0."),
        ("12480", ".", "12480"),      // refused on a whole-number field: value kept
    ])
    func firstKeyReplaces(text: String, key: String, expected: String) {
        let decimals = text.contains(".") ? 2 : 0
        #expect(Keypad.apply(key, to: text, decimals: decimals, maxWhole: 7, replacing: true) == expected)
    }
}
