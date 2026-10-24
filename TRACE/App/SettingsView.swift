import SwiftUI

/// S16: bikes and the primary one (decision 28), reminder settings, storage, about.
/// Units and currency are not shown: v1 has one of each, so there is nothing to pick.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var bikes: [Vehicle] = []
    @State private var primaryID: UUID?
    @State private var editing: Vehicle?
    @State private var adding = false
    @State private var soonPercent = Preferences.soonPercent
    @State private var leads = Set(Preferences.documentLeads)
    @State private var storage = ""
    @State private var error: String?

    private var garage: Garage { Garage(context: context, user: LocalStubUser.load()) }

    var body: some View {
        VStack(spacing: 0) {
            SheetBar(title: "SETTINGS")
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    bikeSection
                    reminderSection
                    dataSection
                    aboutSection
                    if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                }
                .padding(20)
            }
        }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .task { reload(); storage = Self.storageUsed() }
        .sheet(item: $editing, onDismiss: reload) { BikeEditSheet(bike: $0, garage: garage) }
        .fullScreenCover(isPresented: $adding, onDismiss: reload) { OnboardingView() }
    }

    // MARK: 01 BIKES

    private var bikeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHead(number: "01", title: "BIKES")
            Text("Rides, service and the Bike tab use the primary bike.")
                .font(.condensed(14)).foregroundStyle(Color.inkMuted).padding(.vertical, 8)
            ForEach(bikes) { bike in
                HStack(spacing: 8) {
                    Button { editing = bike } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bike.name.uppercased()).font(.oswald(18, .semibold)).tracking(0.8).foregroundStyle(Color.ink)
                            Text([bike.registrationNumber, "\(bike.odometerKm.formatted()) KM"].compactMap { $0 }.joined(separator: " · "))
                                .font(.oswald(13, .medium)).tracking(1).foregroundStyle(Color.inkMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: minTouch, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityHint("Edit bike")
                    if bike.id == primaryID {
                        Text("PRIMARY").font(.oswald(12, .semibold)).tracking(1.7).foregroundStyle(Color.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay { Rectangle().stroke(Color.accent, lineWidth: 1) }
                    } else {
                        Button { run { try garage.makePrimary(bike) }; reload() } label: {
                            Text("MAKE PRIMARY").font(.oswald(13, .semibold)).tracking(1.4).foregroundStyle(Color.inkDim)
                                .padding(.horizontal, 12).frame(minHeight: minTouch)
                                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.surfaceLine).frame(height: 1) }
            }
            TextAction("+ ADD BIKE") { adding = true }
        }
    }

    // MARK: 02 REMINDERS

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "02", title: "REMINDERS")
            label("SERVICE TURNS AMBER WITHIN")
            HStack(spacing: 8) {
                stepButton("−", "Less") { setSoon(soonPercent - 5) }
                Text("\(soonPercent)% OR 14 DAYS").font(.oswald(22, .semibold)).monospacedDigit()
                    .foregroundStyle(Color.ink).frame(maxWidth: .infinity)
                stepButton("+", "More") { setSoon(soonPercent + 5) }
            }
            Text("Of each task's interval, whichever comes first.").font(.condensed(14)).foregroundStyle(Color.inkMuted)
            label("NEW DOCUMENTS REMIND ME BEFORE").padding(.top, 8)
            HStack(spacing: 8) {
                ForEach([30, 7, 1], id: \.self) { d in
                    let on = leads.contains(d)
                    Button {
                        if on { leads.remove(d) } else { leads.insert(d) }
                        Preferences.documentLeads = Array(leads)
                    } label: {
                        Text(d == 1 ? "1 DAY" : "\(d) DAYS").font(.oswald(16, .semibold))
                            .foregroundStyle(on ? Color.ink : Color.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: minTouch)
                            .overlay { Rectangle().stroke(on ? Color.accent : Color.surfaceRule, lineWidth: on ? 2 : 1) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text("Each document can still change its own.").font(.condensed(14)).foregroundStyle(Color.inkMuted)
        }
    }

    // MARK: 03 DATA, 04 ABOUT

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHead(number: "03", title: "DATA")
            HStack {
                Text("Storage used").font(.condensed(16)).foregroundStyle(Color.ink)
                Spacer()
                Text(storage).font(.oswald(17, .semibold)).monospacedDigit().foregroundStyle(Color.ink)
            }
            .frame(minHeight: minTouch)
            Text("There is no backup. Deleting the app deletes everything.")
                .font(.condensed(14)).foregroundStyle(Color.inkMuted)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHead(number: "04", title: "ABOUT")
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTHING LEAVES THIS PHONE").font(.oswald(15, .semibold)).tracking(2).foregroundStyle(Color.ink)
                Text("No account, no cloud, no analytics. Money is never shared, even in later versions.")
                    .font(.condensed(15)).foregroundStyle(Color.inkDim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
            HStack {
                Text("Version").font(.condensed(16)).foregroundStyle(Color.ink)
                Spacer()
                Text(Self.version).font(.oswald(16, .medium)).foregroundStyle(Color.inkMuted)
            }
            .frame(minHeight: minTouch)
        }
    }

    // MARK: Helpers

    private func label(_ text: String) -> some View {
        Text(text).font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
    }

    private func stepButton(_ symbol: String, _ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol).font(.oswald(26, .medium)).foregroundStyle(Color.ink)
                .frame(width: minTouch, height: minTouch)
                .overlay { Rectangle().stroke(Color.surfaceRule, lineWidth: 1) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(name)
    }

    private func setSoon(_ value: Int) {
        Preferences.soonPercent = value
        soonPercent = Preferences.soonPercent   // clamped there
        Reminders.refresh(garage)               // day-based service reminders move with it
    }

    private func reload() {
        run {
            bikes = try garage.bikes()
            primaryID = try garage.bike()?.id
        }
    }

    private func run(_ work: () throws -> Void) {
        do { try work(); error = nil } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "—") (\(info?["CFBundleVersion"] as? String ?? "—"))"
    }

    /// Everything the app keeps on disk: both stores and document photos.
    static func storageUsed() -> String {
        let fm = FileManager.default
        let roots = [URL.applicationSupportDirectory, URL.documentsDirectory]
        var bytes = 0
        for root in roots {
            let files = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])
            while let url = files?.nextObject() as? URL {
                bytes += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            }
        }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
