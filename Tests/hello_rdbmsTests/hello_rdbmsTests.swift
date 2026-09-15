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
