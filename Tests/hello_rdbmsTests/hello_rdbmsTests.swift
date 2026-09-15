import Testing
@testable import hello_rdbms

@Test func parseInsert() {
    let result = prepareStatement("insert 1 alice alice@example.com")
    #expect(result == .success(.insert(Row(id: 1, username: "alice", email: "alice@example.com"))))
}

@Test func parseSelect() {
    #expect(prepareStatement("select") == .success(.select))
    #expect(prepareStatement("SELECT") == .success(.select))
}

@Test func parseInsertRejectsBadArgs() {
    #expect(prepareStatement("insert 1 alice") ==
        .failure(.syntaxError("usage: insert <id> <username> <email>")))
    #expect(prepareStatement("insert -1 alice a@b.c") ==
        .failure(.syntaxError("id must be a non-negative integer")))
}

@Test func parseUnknown() {
    #expect(prepareStatement("delete 1") == .failure(.unrecognizedStatement("delete")))
}

// MARK: - HeapTuple

@Test func tupleRoundTrip() {
    let row = Row(id: 42, username: "alice", email: "a@b.c")
    let row2 = HeapTuple(tupleBytes: HeapTuple(row: row).bytes).toRow()
    #expect(row2 == row)
}

@Test func tupleRoundTripMaxLength() {
    let row = Row(id: UInt32.max,
                  username: String(repeating: "u", count: 32),
                  email: String(repeating: "e", count: 255))
    #expect(HeapTuple(tupleBytes: HeapTuple(row: row).bytes).toRow() == row)
}

// MARK: - Page

@Test func pageAddAndGetTuple() {
    var page = Page()
    #expect(page.numItems == 0)
    let idx = page.addTuple(HeapTuple(row: Row(id: 7, username: "bob", email: "b@x.y")).bytes)
    #expect(idx == 0)
    let got = HeapTuple(tupleBytes: page.tuple(at: 0)!).toRow()
    #expect(got == Row(id: 7, username: "bob", email: "b@x.y"))
    #expect(page.tuple(at: 1) == nil)
}

@Test func pageFillsUp() {
    var page = Page()
    var n = 0
    while page.addTuple(HeapTuple(row: Row(id: 1, username: "a", email: "b")).bytes) != nil {
        n += 1
    }
    // 8192B ページに 293B タプルと 4B LinePointer: 理論上は ~27件
    #expect(n >= 27 && n <= 28)
    #expect(page.numItems == n)
}

// MARK: - Table

@Test func tableInsertAndSeqScan() {
    var table = Table()
    var expected: [Row] = []
    for i in 0..<40 {
        let row = Row(id: UInt32(i), username: "u\(i)", email: "e\(i)")
        expected.append(row)
        if case .failure = table.insert(row) {
            Issue.record("insert \(i) failed")
        }
    }
    let scanned = table.seqScan()
    #expect(scanned.count == 40)
    #expect(scanned.map(\.row) == expected)
    // 40行は複数ページにまたがる (1ページ約27行)
    #expect(table.pages.count >= 2)
}

@Test func tableFull() {
    var table = Table()
    while case .success = table.insert(Row(id: 1, username: "a", email: "b")) {}
    if case .success = table.insert(Row(id: 1, username: "a", email: "b")) {
        Issue.record("insert beyond capacity should fail")
    }
}
