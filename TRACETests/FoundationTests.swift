import Foundation
import SwiftData
import Testing
@testable import TRACE

private struct TestUser: CurrentUser { let ownerID = UUID() }

@MainActor
@Suite struct RepositoryTests {
    let container = try! Store.container(inMemory: true)

    @Test func insertStampsOwnerAndTimestamps() throws {
        let user = TestUser()
        let repo = Repository<Vehicle>(context: container.mainContext, user: user)
        let bike = Vehicle(name: "CB350")
        repo.insert(bike)
        #expect(bike.ownerID == user.ownerID)
        #expect(bike.createdAt == bike.updatedAt)
        #expect(try repo.all().map(\.name) == ["CB350"])
    }

    @Test func softDeletedRowsAreExcluded() throws {
        let repo = Repository<Ride>(context: container.mainContext, user: TestUser())
        let kept = Ride(vehicleID: UUID())
        let gone = Ride(vehicleID: UUID())
        repo.insert(kept)
        repo.insert(gone)
        repo.softDelete(gone)
        try repo.save()
        #expect(try repo.all().map(\.id) == [kept.id])
        #expect(try repo.find(gone.id) == nil)
        #expect(gone.deletedAt != nil)   // tombstone kept, not hard-deleted
    }

    @Test func queriesAreScopedToOwner() throws {
        let ctx = container.mainContext
        let mine = Repository<Expense>(context: ctx, user: TestUser())
        let theirs = Repository<Expense>(context: ctx, user: TestUser())
        let fuel = Expense(amountMinor: 41_000, category: .fuel)
        mine.insert(fuel)
        theirs.insert(Expense(amountMinor: 7_000, category: .food))
        try mine.save()
        #expect(try mine.all().map(\.amountMinor) == [41_000])
        #expect(try theirs.find(fuel.id) == nil)
    }

    @Test func updateBumpsUpdatedAt() throws {
        let repo = Repository<Vehicle>(context: container.mainContext, user: TestUser())
        let bike = Vehicle(name: "CB350")
        repo.insert(bike)
        let before = bike.updatedAt
        repo.update(bike) { $0.odometerKm = 12_480 }
        #expect(bike.odometerKm == 12_480)
        #expect(bike.updatedAt >= before)
    }
}

@Suite struct LocalOnlyTests {
    @Test func moneyIsLocalOnlyAtModelLevel() {
        #expect(Expense(amountMinor: 1, category: .other).syncScope == .localOnly)
        #expect(CaptureDraft().syncScope == .localOnly)
        #expect(Ride(vehicleID: UUID()).syncScope == .syncable)
    }

    @Test func moneyLivesOnlyInTheLocalStore() {
        let local = Store.localOnlyModels.map { "\($0)" }
        let synced = Store.syncableModels.map { "\($0)" }
        #expect(local.contains("Expense"))
        #expect(!synced.contains("Expense"))
        #expect(!synced.contains("CaptureDraft"))
    }
}

@Suite struct CurrentUserTests {
    @Test func stubOwnerIsStableAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: "test-\(UUID())"))
        #expect(LocalStubUser.load(from: defaults).ownerID == LocalStubUser.load(from: defaults).ownerID)
    }
}

@Suite struct MoneyTests {
    @Test(arguments: [
        ("410", 41_000), ("410.5", 41_050), ("410.05", 41_005), (".5", 50),
        ("1,04,250", 10_425_000), (" 0 ", 0), ("99,99,999", 999_999_900),
    ])
    func parsesRupeesToPaise(text: String, paise: Int) {
        #expect(Money.paise(fromRupees: text) == paise)
    }

    @Test(arguments: ["", ".", "4.105", "-5", "+5", "1e3", "4.1.0", "abc", "९९"])
    func rejectsJunk(text: String) {
        #expect(Money.paise(fromRupees: text) == nil)
    }

    @Test func noFloatDrift() {
        let a = Money.paise(fromRupees: "0.1")!, b = Money.paise(fromRupees: "0.2")!
        #expect(a + b == 30)
    }

    @Test func formatsWithIndianGrouping() {
        let inLocale = Locale(identifier: "en_IN")
        #expect(Money.format(10_425_000, locale: inLocale) == "₹1,04,250")
        #expect(Money.format(41_050, locale: inLocale) == "₹410.50")
        #expect(Money.format(0, locale: inLocale) == "₹0")
    }
}

@Suite struct TokenTests {
    /// DESIGN.md is the source of truth; Tokens.swift is hand-written (decision 41).
    @Test func tokensMatchDesignDoc() throws {
        let doc = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("design/DESIGN.md")
        let text = try String(contentsOf: doc, encoding: .utf8)
        var found: [String: UInt32] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, parts[0].hasPrefix("--"), parts[1].hasPrefix("#"),
                  let hex = UInt32(parts[1].dropFirst(), radix: 16) else { continue }
            found[String(parts[0])] = hex
        }
        #expect(found.count == Token.allCases.count)
        for token in Token.allCases {
            #expect(found[token.rawValue] == token.hex, "\(token.rawValue)")
        }
    }
}
