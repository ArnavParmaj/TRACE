import SwiftUI

/// S08 for a draft: pick a category, type the amount (and fuel extras), SAVE.
/// SAVE moves to the next waiting draft, so a queue is one sheet, not N round trips.
struct DraftSheet: View {
    let capture: Capture
    @State private var draft: CaptureDraft
    @State private var saves = 0
    @Environment(\.dismiss) private var dismiss

    init(start: CaptureDraft, capture: Capture) {
        self.capture = capture
        _draft = State(initialValue: start)
    }

    var body: some View {
        DraftForm(draft: draft, capture: capture, onDone: advance)
            .id(draft.id)   // fresh fields per draft
            .background(Color.ground.ignoresSafeArea())
            .presentationBackground(Color.ground)
            .sensoryFeedback(.success, trigger: saves)
    }

    private func advance(saved: Bool) {
        if saved { saves += 1 }
        if let next = try? capture.pending().first { draft = next } else { dismiss() }
    }
}

private struct DraftForm: View {
    enum Field { case amount, litres, odometer }

    let draft: CaptureDraft
    let capture: Capture
    let onDone: (_ saved: Bool) -> Void

    @State private var category: ExpenseCategory?
    @State private var field = Field.amount
    @State private var amount = ""
    @State private var litres = ""
    @State private var odometer = ""
    @State private var fullTank = true   // the rider always fills to full
    @State private var note = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var amountMinor: Int? { Money.paise(fromRupees: amount).flatMap { $0 > 0 ? $0 : nil } }
    private var litresValue: Double? { Double(litres).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let category { form(category) } else { grid }
                    if let error {
                        Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            if category != nil { keypad }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button { dismiss() } label: {
                Text("CLOSE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                    .frame(minWidth: minTouch, minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            Text(draft.capturedAt.formatted(date: .omitted, time: .shortened) + "  DRAFT")
                .font(.oswald(15, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
            Spacer()
            Button { run { try capture.discard(draft); onDone(false) } } label: {
                Text("DISCARD DRAFT").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                    .frame(minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }

    // MARK: Category grid: FUEL full width, the rest 2×2.

    private var grid: some View {
        let others: [ExpenseCategory] = [.food, .parts, .parking, .other]
        return VStack(spacing: 12) {
            tile(.fuel, height: 72)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(others, id: \.self) { tile($0, height: minTouch) }
            }
        }
    }

    private func tile(_ c: ExpenseCategory, height: CGFloat) -> some View {
        Button { category = c; field = .amount } label: {
            Text(c.rawValue.uppercased()).font(.oswald(20, .semibold)).tracking(1.6).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: height)
                .overlay { Rectangle().stroke(c == .fuel ? Color.accent : Color.surfaceRule, lineWidth: c == .fuel ? 2 : 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: Form

    @ViewBuilder private func form(_ c: ExpenseCategory) -> some View {
        HStack {
            Text(c.rawValue.uppercased()).font(.oswald(20, .semibold)).tracking(1.6).foregroundStyle(Color.ink)
            Spacer()
            Button { category = nil } label: {
                Text("CHANGE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                    .frame(minWidth: minTouch, minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
        valueRow("AMOUNT", "₹" + (amount.isEmpty ? "0" : amount), .amount, big: true)
        if c == .fuel {
            valueRow("LITRES", litres.isEmpty ? "—" : litres + " L", .litres)
            if let ppl = Capture.pricePerLitreMinor(amountMinor: amountMinor ?? 0, litres: litresValue), ppl > 0 {
                Text("\(Money.format(ppl)) / L").font(.oswald(15, .medium)).foregroundStyle(Color.inkDim).monospacedDigit()
            }
            Button { fullTank.toggle() } label: {
                HStack {
                    Text("FULL TANK").font(.oswald(17, .semibold)).tracking(1.5).foregroundStyle(Color.ink)
                    Spacer()
                    Text(fullTank ? "ON" : "OFF").font(.oswald(17, .semibold))
                        .foregroundStyle(fullTank ? Color.accent : Color.inkMuted)
                }
                .padding(.horizontal, 16).frame(minHeight: minTouch)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityValue(fullTank ? "On" : "Off")
            if !fullTank {
                Text("Partial fills are logged but not used for km/L.")
                    .font(.condensed(15)).foregroundStyle(Color.inkDim)
            }
            valueRow("ODOMETER (OPTIONAL)", odometer.isEmpty ? "—" : odometer + " KM", .odometer)
        }
        if draft.rideID != nil {
            Text("Attached to the ride you were on.").font(.condensed(15)).foregroundStyle(Color.inkDim)
        }
        TextField("", text: $note, prompt: Text("Note (optional)").foregroundStyle(Color.inkFaint))
            .font(.condensed(17)).foregroundStyle(Color.ink)
            .padding(.horizontal, 16).frame(minHeight: minTouch)
            .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
            .submitLabel(.done)
    }

    private func valueRow(_ label: String, _ value: String, _ f: Field, big: Bool = false) -> some View {
        let on = field == f
        return Button { field = f } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                Text(value).font(.oswald(big ? 44 : 26, .semibold, relativeTo: big ? .largeTitle : .title))
                    .foregroundStyle(Color.ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
            .overlay { Rectangle().stroke(on ? Color.accent : Color.surfaceRule, lineWidth: on ? 2 : 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: Keypad + SAVE, pinned at the bottom.

    private var keypad: some View {
        VStack(spacing: 8) {
            KeypadGrid(onKey: press)
            Button(action: save) {
                Text("SAVE").font(.oswald(24, .bold)).tracking(1.6)
                    .foregroundStyle(amountMinor == nil ? Color.inkFaint : Color.ground)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(amountMinor == nil ? Color.surfaceLine : Color.accent)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(haptic: false))
            .disabled(amountMinor == nil)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }

    private func press(_ key: String) {
        switch field {
        case .amount: amount = Keypad.apply(key, to: amount, decimals: 2, maxWhole: 7)   // ₹99,99,999 cap
        case .litres: litres = Keypad.apply(key, to: litres, decimals: 2, maxWhole: 3)
        case .odometer: odometer = Keypad.apply(key, to: odometer, decimals: 0, maxWhole: 7)
        }
    }

    private func save() {
        guard let category, let amountMinor else { return }
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        run {
            try capture.complete(draft, category: category, amountMinor: amountMinor,
                                 litres: litresValue, isFullTank: fullTank, odometerKm: Int(odometer),
                                 note: trimmed.isEmpty ? nil : trimmed)
            onDone(true)
        }
    }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }
}

/// 60pt keys for gloves; the system number pad's keys are smaller (invariant 10).
struct KeypadGrid: View {
    let onKey: (String) -> Void

    var body: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button { onKey(key) } label: {
                    Text(key).font(.oswald(26, .medium)).foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: minTouch)
                        .background(Color.surfaceLine)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(key == "⌫" ? "Delete" : key == "." ? "Point" : key)
            }
        }
    }
}

/// Keypad text editing with the field's limits. Refused keys leave the text unchanged.
enum Keypad {
    static func apply(_ key: String, to text: String, decimals: Int, maxWhole: Int) -> String {
        if key == "⌫" { return String(text.dropLast()) }
        if key == "." {
            guard decimals > 0, !text.contains(".") else { return text }
            return text.isEmpty ? "0." : text + "."
        }
        let next = text == "0" ? key : text + key
        let parts = next.split(separator: ".", omittingEmptySubsequences: false)
        guard parts[0].count <= maxWhole, parts.count < 2 || parts[1].count <= decimals else { return text }
        return next
    }
}
