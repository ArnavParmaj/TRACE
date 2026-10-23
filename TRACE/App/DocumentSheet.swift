import QuickLook
import SwiftUI
import UniformTypeIdentifiers

/// S13: kind, number, expiry, reminder lead times and an attachment kept in the app only.
/// Renewing = changing the expiry date here (decision 61).
struct DocumentSheet: View {
    let doc: VehicleDocument
    let garage: Garage

    @State private var kind: DocumentKind
    @State private var identifier: String
    @State private var expires: Date
    @State private var leads: Set<Int>
    @State private var attachment: String?
    @State private var picking = false
    @State private var preview: URL?
    @State private var error: String?
    @State private var confirmRemove = false
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { doc.ownerID == .unowned }

    init(doc: VehicleDocument, garage: Garage) {
        self.doc = doc
        self.garage = garage
        _kind = State(initialValue: doc.kind)
        _identifier = State(initialValue: doc.identifier ?? "")
        _expires = State(initialValue: doc.expiresOn)
        _leads = State(initialValue: Set(doc.reminderDaysBefore))
        _attachment = State(initialValue: doc.attachmentPath)
    }

    var body: some View {
        VStack(spacing: 0) {
        SheetBar(title: isNew ? "NEW DOCUMENT" : "DOCUMENT")
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isNew ? "ADD DOCUMENT" : kind.label.uppercased())
                    .font(.oswald(28, .bold, relativeTo: .largeTitle)).tracking(1.6).foregroundStyle(Color.ink)
                if !isNew { DueRow(label: "STATUS", status: Due.document(expiresOn: expires, now: .now)) }
                ChipGrid(options: DocumentKind.allCases, selected: kind, title: \.label) { kind = $0 }
                FieldBox("NUMBER (OPTIONAL)", text: $identifier, prompt: "Policy or certificate no.")
                DatePicker("EXPIRES ON", selection: $expires, displayedComponents: .date)
                    .font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                    .frame(minHeight: minTouch)
                Text("REMIND ME").font(.oswald(13, .medium)).tracking(2).foregroundStyle(Color.inkMuted)
                HStack(spacing: 8) {
                    ForEach([30, 7, 1], id: \.self) { lead in
                        let on = leads.contains(lead)
                        Button { if on { leads.remove(lead) } else { leads.insert(lead) } } label: {
                            Text(lead == 1 ? "1 DAY" : "\(lead) DAYS").font(.oswald(14, .semibold)).tracking(1)
                                .foregroundStyle(on ? Color.ink : Color.inkDim)
                                .frame(maxWidth: .infinity, minHeight: minTouch)
                                .overlay { Rectangle().stroke(on ? Color.accent : Color.surfaceRule, lineWidth: on ? 2 : 1) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                attachmentRow
                if let error { Text(error).font(.condensed(13)).foregroundStyle(Color.alarmInk) }
                PrimaryButton(isNew ? "SAVE DOCUMENT" : "SAVE CHANGES", action: save)
                if !isNew { TextAction("REMOVE DOCUMENT") { confirmRemove = true } }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        }
        .alert("Remove \(kind.label)?", isPresented: $confirmRemove) {
            Button("Remove") { run { try garage.remove(doc); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its reminders stop.") }
        .background(Color.ground.ignoresSafeArea())
        .presentationBackground(Color.ground)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.image, .pdf]) { result in
            run { attachment = try Attachments.store(try result.get(), for: doc.id) }
        }
        .quickLookPreview($preview)
    }

    @ViewBuilder private var attachmentRow: some View {
        if let attachment {
            HStack(spacing: 8) {
                TextAction("VIEW ATTACHMENT") { preview = Attachments.url(attachment) }
                TextAction("REMOVE") { self.attachment = nil }
            }
        } else {
            TextAction("ATTACH PHOTO OR PDF") { picking = true }
        }
    }

    private func save() {
        run {
            if let old = doc.attachmentPath, old != attachment { Attachments.delete(old) }
            doc.kind = kind
            let number = identifier.trimmingCharacters(in: .whitespaces)
            doc.identifier = number.isEmpty ? nil : number
            doc.expiresOn = expires
            doc.reminderDaysBefore = leads.sorted(by: >)
            doc.attachmentPath = attachment
            try garage.save(doc)
            dismiss()
        }
    }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { self.error = "Couldn't save: \(error.localizedDescription)" }
    }
}

/// Document files live in Application Support, never Photos, never synced.
/// The stored path is the file name only: the container path changes between installs.
enum Attachments {
    static var folder: URL { URL.applicationSupportDirectory.appending(path: "attachments", directoryHint: .isDirectory) }

    static func url(_ name: String) -> URL { folder.appending(path: name) }

    static func store(_ source: URL, for id: UUID) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(id).\(source.pathExtension.lowercased())"
        try? FileManager.default.removeItem(at: url(name))
        try FileManager.default.copyItem(at: source, to: url(name))
        return name
    }

    static func delete(_ name: String) { try? FileManager.default.removeItem(at: url(name)) }
}
