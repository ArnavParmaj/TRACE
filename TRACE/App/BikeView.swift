import SwiftData
import SwiftUI

/// S11 Bike: odometer, trip meters, service tasks and documents, most urgent first.
struct BikeView: View {
    @Environment(\.modelContext) private var context
    @State private var bike: Vehicle?
    @State private var tasks: [ServiceTask] = []
    @State private var docs: [VehicleDocument] = []
    @State private var trips = (a: 0.0, b: 0.0)
    @State private var editingOdo = false
    @State private var editingBike = false
    @State private var task: ServiceTask?
    @State private var doc: VehicleDocument?
    @State private var resets = 0
    @State private var error: String?

    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let bike { content(bike) } else { AddBikeForm(garage: garage, onAdded: reload) }
                if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
            }
            .padding(20)
        }
        .task { reload() }
        .sheet(isPresented: $editingOdo, onDismiss: reload) { if let bike { OdometerSheet(bike: bike, garage: garage) } }
        .sheet(isPresented: $editingBike, onDismiss: reload) { if let bike { BikeEditSheet(bike: bike, garage: garage) } }
        .animation(.easeOut(duration: 0.2), value: tasks.map(\.id) + docs.map(\.id))
        .sheet(item: $task, onDismiss: reload) { TaskSheet(task: $0, bike: bike!, garage: garage) }
        .sheet(item: $doc, onDismiss: reload) { DocumentSheet(doc: $0, garage: garage) }
        .sensoryFeedback(.success, trigger: resets)
    }

    @ViewBuilder private func content(_ bike: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { editingBike = true } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text([bike.name, bike.registrationNumber].compactMap { $0 }.joined(separator: " · ").uppercased())
                        .font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6).foregroundStyle(Color.ink)
                    Spacer()
                    Text("EDIT ›").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                }
                .frame(minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            Button { editingOdo = true } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("ODO").font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    Text("\(bike.odometerKm.formatted()) KM").font(.oswald(26, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
                    Spacer()
                    Text("UPDATE ›").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                }
                .frame(minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            HStack(spacing: 12) {
                tripMeter("TRIP A", trips.a, .a, bike)
                tripMeter("TRIP B", trips.b, .b, bike)
            }
        }

        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "01", title: "SERVICE").padding(.bottom, 4)
            ForEach(tasks) { t in
                Button { task = t } label: { DueRow(label: t.label, status: garage.due(t, bike)) }
                    .buttonStyle(PressStyle())
            }
            addButton("+ ADD TASK") { task = ServiceTask(vehicleID: bike.id, kind: .chainLube, label: ServiceKind.chainLube.label) }
        }

        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "02", title: "DOCUMENTS").padding(.bottom, 4)
            ForEach(docs) { d in
                Button { doc = d } label: {
                    DueRow(label: d.kind.label, status: Due.document(expiresOn: d.expiresOn, now: .now))
                }
                .buttonStyle(PressStyle())
            }
            addButton("+ ADD DOCUMENT") {
                let new = VehicleDocument(kind: .insurance, expiresOn: Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now)
                new.vehicleID = bike.id
                doc = new
            }
        }
    }

    /// Hold to reset, so a gloved brush can't wipe it (S11).
    private func tripMeter(_ title: String, _ km: Double, _ trip: Trip, _ bike: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
            Text(String(format: "%.1f KM", km)).font(.oswald(22, .medium)).monospacedDigit().foregroundStyle(Color.ink)
            Text("HOLD TO RESET").font(.oswald(11, .medium)).tracking(1.5).foregroundStyle(Color.inkFaint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
        .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1) {
            run { try garage.resetTrip(bike, trip) }
            resets += 1
            reload()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Reset") { run { try garage.resetTrip(bike, trip) }; reload() }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.accent)
                .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func reload() {
        run {
            bike = try garage.bike()
            guard let bike else { return }
            tasks = try garage.tasks(bike)
            docs = try garage.documents(bike).sorted {
                Due.document(expiresOn: $0.expiresOn, now: .now).urgency < Due.document(expiresOn: $1.expiresOn, now: .now).urgency
            }
            trips = (try garage.tripKm(bike, .a), try garage.tripKm(bike, .b))
            Reminders.refresh(garage)
        }
    }

    private func run(_ work: () throws -> Void) {
        do { try work(); error = nil } catch { self.error = "Couldn't load the bike: \(error.localizedDescription)" }
    }
}

/// One due line. Overdue gets the alarm rail and alarm ink (invariant 9); soon gets amber.
struct DueRow: View {
    let label: String
    let status: DueStatus

    var body: some View {
        let alarm = status.urgency == .overdue
        let soon = status.urgency == .soon
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased()).font(.oswald(17, .semibold)).tracking(1.2).foregroundStyle(Color.ink)
                Spacer()
                Text(status.text).font(.oswald(15, .medium)).tracking(1).monospacedDigit()
                    .foregroundStyle(alarm ? Color.alarmInk : soon ? Color.warn : Color.inkDim)
            }
            if soon, let progress = status.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.surfaceRule)
                        Rectangle().fill(Color.warn).frame(width: geo.size.width * min(1, progress))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.leading, alarm ? 14 : 0).padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
        .overlay(alignment: .leading) { if alarm { Rectangle().fill(Color.alarm).frame(width: 4) } }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// First run: the bike everything hangs off. Full onboarding is M8 (S01).
private struct AddBikeForm: View {
    let garage: Garage
    let onAdded: () -> Void
    @State private var name = ""
    @State private var registration = ""
    @State private var odo = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ADD YOUR BIKE").font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6).foregroundStyle(Color.ink)
            FieldBox("NAME", text: $name, prompt: "CB350")
            FieldBox("REGISTRATION (OPTIONAL)", text: $registration, prompt: "MH 02 AB 1234")
            FieldBox("ODOMETER KM", text: $odo, prompt: "12480", numeric: true)
            if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
            PrimaryButton("SAVE BIKE", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(odo) != nil) {
                do {
                    let reg = registration.trimmingCharacters(in: .whitespaces)
                    try garage.addBike(name: name.trimmingCharacters(in: .whitespaces),
                                       registration: reg.isEmpty ? nil : reg.uppercased(), odometerKm: Int(odo) ?? 0)
                    onAdded()
                } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
            }
        }
    }
}

/// Rename the bike, change its registration, or remove it.
private struct BikeEditSheet: View {
    let bike: Vehicle
    let garage: Garage
    @State private var name: String
    @State private var registration: String
    @State private var confirmRemove = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(bike: Vehicle, garage: Garage) {
        self.bike = bike
        self.garage = garage
        _name = State(initialValue: bike.name)
        _registration = State(initialValue: bike.registrationNumber ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetBar(title: "EDIT BIKE")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FieldBox("NAME", text: $name, prompt: "CB350")
                    FieldBox("REGISTRATION (OPTIONAL)", text: $registration, prompt: "MH 02 AB 1234")
                    if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                    PrimaryButton("SAVE CHANGES", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        run {
                            let reg = registration.trimmingCharacters(in: .whitespaces)
                            try garage.updateBike(bike, name: name.trimmingCharacters(in: .whitespaces),
                                                  registration: reg.isEmpty ? nil : reg.uppercased())
                            dismiss()
                        }
                    }
                    TextAction("REMOVE BIKE") { confirmRemove = true }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .alert("Remove \(bike.name)?", isPresented: $confirmRemove) {
            Button("Remove") { run { try garage.removeBike(bike); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its rides stay. Its service tasks and documents stop showing.") }
    }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }
}

/// S14: big number + keypad. A lower reading asks "odometer replaced?" first.
struct OdometerSheet: View {
    let bike: Vehicle
    let garage: Garage
    @State private var text = ""
    @State private var confirmLower = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let suggestion = (try? garage.odometerSuggestion(bike)) ?? bike.odometerKm
        VStack(spacing: 0) {
        SheetBar(title: "ODOMETER")
        VStack(alignment: .leading, spacing: 14) {
            Text(text.isEmpty ? "—" : "\(text) KM").font(.oswald(52, .semibold, relativeTo: .largeTitle))
                .monospacedDigit().foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text("Last reading \(bike.odometerKm.formatted()) km")
                .font(.condensed(15)).foregroundStyle(Color.inkDim)
            if suggestion != bike.odometerKm {
                Button { text = String(suggestion) } label: {
                    Text("USE GPS ESTIMATE \(suggestion.formatted()) KM").font(.oswald(15, .semibold)).tracking(1.2)
                        .foregroundStyle(Color.accent).frame(minHeight: minTouch).contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
            }
            if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
            Spacer(minLength: 0)
            KeypadGrid { text = Keypad.apply($0, to: text, decimals: 0, maxWhole: 7); confirmLower = false }
            if confirmLower {
                Text("Lower than the last reading. Was the odometer replaced?")
                    .font(.condensed(15)).foregroundStyle(Color.warn)
                PrimaryButton("YES, IT WAS REPLACED") { save(allowLower: true) }
            } else {
                PrimaryButton("SAVE", enabled: Int(text) != nil) { save(allowLower: false) }
            }
        }
        .padding(20)
        }
        .animation(.easeOut(duration: 0.18), value: confirmLower)
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
    }

    private func save(allowLower: Bool) {
        guard let km = Int(text) else { return }
        do {
            try garage.setOdometer(bike, km: km, allowLower: allowLower)
            dismiss()
        } catch Garage.Failure.odometerWentDown {
            confirmLower = true
        } catch {
            self.error = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

/// Labelled one-line text field, 60pt tall. For setup forms filled in at home.
struct FieldBox: View {
    let label: String
    @Binding var text: String
    let prompt: String
    var numeric = false
    @FocusState private var focused: Bool

    init(_ label: String, text: Binding<String>, prompt: String, numeric: Bool = false) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.numeric = numeric
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Color.inkFaint))
                .font(.oswald(22, .medium)).foregroundStyle(Color.ink)
                .keyboardType(numeric ? .numberPad : .default)
                .focused($focused)
                .submitLabel(.done)
                .padding(.horizontal, 14).frame(minHeight: minTouch)
                .overlay { Rectangle().stroke(focused ? Color.accent : Color.surfaceRule, lineWidth: focused ? 2 : 1) }
                .toolbar {
                    // The number pad has no return key; without this the keyboard can't be closed.
                    if focused {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { focused = false }.font(.oswald(17, .semibold)).tint(Color.accent)
                        }
                    }
                }
        }
    }
}

/// Top of every sheet: what it is, and a 60pt CLOSE so nobody is trapped in a form.
struct SheetBar: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Text(title).font(.oswald(15, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
            Spacer()
            Button { dismiss() } label: {
                Text("CLOSE").font(.oswald(15, .semibold)).tracking(1.5).foregroundStyle(Color.inkDim)
                    .frame(minWidth: minTouch, minHeight: minTouch).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceRule).frame(height: 1) }
    }
}

/// Primary action: amber outline, 72pt.
struct PrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            // Outlined, not filled: no large lit slabs (DESIGN.md rule 2).
            Text(title).font(.oswald(24, .bold)).tracking(1.6)
                .foregroundStyle(enabled ? Color.ink : Color.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 72)
                .overlay { Rectangle().stroke(enabled ? Color.accent : Color.surfaceRule, lineWidth: 2) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(haptic: false))
        .disabled(!enabled)
    }
}
