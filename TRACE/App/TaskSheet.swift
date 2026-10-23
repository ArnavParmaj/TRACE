import SwiftUI

/// S12: add or edit a service task; status, history and MARK DONE for an existing one.
struct TaskSheet: View {
    let task: ServiceTask
    let bike: Vehicle
    let garage: Garage

    @State private var kind: ServiceKind
    @State private var label: String
    @State private var intervalKm: String
    @State private var intervalDays: String
    @State private var lastOdo: String
    @State private var lastDate: Date
    @State private var markingDone = false
    @State private var history: [(event: ServiceEvent, costMinor: Int?)] = []
    @State private var error: String?
    @State private var confirmRemove = false
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { task.ownerID == .unowned }

    init(task: ServiceTask, bike: Vehicle, garage: Garage) {
        self.task = task
        self.bike = bike
        self.garage = garage
        _kind = State(initialValue: task.kind)
        _label = State(initialValue: task.label)
        _intervalKm = State(initialValue: task.intervalKm.map(String.init) ?? "")
        _intervalDays = State(initialValue: task.intervalDays.map(String.init) ?? "")
        _lastOdo = State(initialValue: String(task.lastDoneOdoKm ?? bike.odometerKm))
        _lastDate = State(initialValue: task.lastDoneAt ?? .now)
    }

    var body: some View {
        VStack(spacing: 0) {
        SheetBar(title: isNew ? "NEW SERVICE TASK" : "SERVICE TASK")
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "ADD TASK" : label.uppercased())
                    .font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6).foregroundStyle(Color.ink)
                if !isNew {
                    DueRow(label: "STATUS", status: garage.due(task, bike))
                    PrimaryButton("MARK DONE") { markingDone = true }
                }
                ChipGrid(options: ServiceKind.allCases, selected: kind, title: \.label) { new in
                    if label.isEmpty || label == kind.label { label = new.label }
                    kind = new
                }
                FieldBox("NAME", text: $label, prompt: "Chain lube")
                HStack(spacing: 12) {
                    FieldBox("EVERY KM", text: $intervalKm, prompt: "500", numeric: true)
                    FieldBox("OR DAYS", text: $intervalDays, prompt: "180", numeric: true)
                }
                FieldBox("LAST DONE AT KM", text: $lastOdo, prompt: String(bike.odometerKm), numeric: true)
                DatePicker("LAST DONE ON", selection: $lastDate, in: ...Date.now, displayedComponents: .date)
                    .font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    .frame(minHeight: minTouch)
                if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                PrimaryButton(isNew ? "SAVE TASK" : "SAVE CHANGES", enabled: canSave, action: save)
                if !history.isEmpty { historyList }
                if !isNew {
                    TextAction("REMOVE TASK") { confirmRemove = true }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        }
        .alert("Remove \(label)?", isPresented: $confirmRemove) {
            Button("Remove") { run { try garage.remove(task); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its service history stays.") }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .task { loadHistory() }
        .sheet(isPresented: $markingDone, onDismiss: loadHistory) {
            MarkDoneSheet(task: task, bike: bike, garage: garage)
        }
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty && (Int(intervalKm) ?? 0 > 0 || Int(intervalDays) ?? 0 > 0)
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "", title: "HISTORY").padding(.bottom, 4)
            ForEach(history, id: \.event.id) { item in
                HStack {
                    Text(item.event.performedAt.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
                        .font(.oswald(15, .medium)).foregroundStyle(Color.ink)
                    Text("\(item.event.odometerKm.formatted()) KM").font(.oswald(15, .medium)).foregroundStyle(Color.inkDim)
                    Spacer()
                    if let cost = item.costMinor { Text(Money.format(cost)).font(.oswald(15, .medium)).foregroundStyle(Color.ink) }
                }
                .monospacedDigit()
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
            }
        }
    }

    private func save() {
        run {
            task.kind = kind
            task.label = label.trimmingCharacters(in: .whitespaces)
            task.intervalKm = Int(intervalKm).flatMap { $0 > 0 ? $0 : nil }
            task.intervalDays = Int(intervalDays).flatMap { $0 > 0 ? $0 : nil }
            task.lastDoneOdoKm = Int(lastOdo)
            task.lastDoneAt = lastDate
            try garage.save(task, for: bike)
            dismiss()
        }
    }

    private func loadHistory() { if !isNew { history = (try? garage.history(task)) ?? [] } }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }
}

/// S09: odometer (prefilled) and an optional cost, on the glove keypad.
private struct MarkDoneSheet: View {
    enum Field { case odo, cost }

    let task: ServiceTask
    let bike: Vehicle
    let garage: Garage
    @State private var field = Field.odo
    @State private var odo: String
    @State private var cost = ""
    @State private var saved = 0
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(task: ServiceTask, bike: Vehicle, garage: Garage) {
        self.task = task
        self.bike = bike
        self.garage = garage
        _odo = State(initialValue: String(bike.odometerKm))
    }

    var body: some View {
        VStack(spacing: 0) {
        SheetBar(title: "\(task.label.uppercased()) DONE")
        VStack(alignment: .leading, spacing: 14) {
            box("ODOMETER", odo.isEmpty ? "—" : "\(odo) KM", .odo)
            box("COST (OPTIONAL)", "₹" + (cost.isEmpty ? "0" : cost), .cost)
            if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
            Spacer(minLength: 0)
            KeypadGrid { key in
                switch field {
                case .odo: odo = Keypad.apply(key, to: odo, decimals: 0, maxWhole: 7)
                case .cost: cost = Keypad.apply(key, to: cost, decimals: 2, maxWhole: 7)
                }
            }
            PrimaryButton("SAVE", enabled: Int(odo) != nil) {
                guard let km = Int(odo) else { return }
                do {
                    try garage.markDone(task, bike: bike, odometerKm: km, costMinor: Money.paise(fromRupees: cost))
                    saved += 1
                    dismiss()
                } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
            }
        }
        .padding(20)
        }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .sensoryFeedback(.success, trigger: saved)
    }

    private func box(_ label: String, _ value: String, _ f: Field) -> some View {
        Button { field = f } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                Text(value).font(.oswald(32, .semibold, relativeTo: .title)).monospacedDigit().foregroundStyle(Color.ink)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
            .overlay { Rectangle().stroke(field == f ? Color.accent : Color.surfaceRule, lineWidth: field == f ? 2 : 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// Single-choice chips, 3 per row, 60pt.
struct ChipGrid<Option: Hashable>: View {
    let options: [Option]
    let selected: Option
    let title: (Option) -> String
    let onPick: (Option) -> Void

    init(options: [Option], selected: Option, title: @escaping (Option) -> String, onPick: @escaping (Option) -> Void) {
        self.options = options
        self.selected = selected
        self.title = title
        self.onPick = onPick
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = option == selected
                Button { onPick(option) } label: {
                    Text(title(option).uppercased()).font(.oswald(14, .semibold)).tracking(1)
                        .foregroundStyle(on ? Color.ink : Color.inkDim).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: minTouch)
                        .overlay { Rectangle().stroke(on ? Color.accent : Color.surfaceRule, lineWidth: on ? 2 : 1) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Quiet secondary action (no system red: invariant 9).
struct TextAction: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                .frame(maxWidth: .infinity, minHeight: minTouch).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
