import Foundation

/// users テーブルの1行。(まだメモリ上の表現のみ。永続化は後のステップ)
struct Row: Equatable {
    var id: UInt32
    var username: String
    var email: String

    static let usernameMaxLength = 32
    static let emailMaxLength = 255
}

/// パース済みのSQL文。今は insert / select の2種類だけ。
enum Statement: Equatable {
    case insert(Row)
    case select
}

enum PrepareError: Error, Equatable {
    case unrecognizedStatement(String)
    case syntaxError(String)
}

/// 入力行を `Statement` に変換する (SQLコンパイラの前半部分)。
func prepareStatement(_ input: String) -> Result<Statement, PrepareError> {
    let tokens = input.split(separator: " ").map(String.init)
    guard let keyword = tokens.first else {
        return .failure(.unrecognizedStatement(input))
    }
    switch keyword.lowercased() {
    case "insert":
        // insert <id> <username> <email>
        guard tokens.count == 4 else {
            return .failure(.syntaxError("usage: insert <id> <username> <email>"))
        }
        guard let id = UInt32(tokens[1]) else {
            return .failure(.syntaxError("id must be a non-negative integer"))
        }
        guard tokens[2].count <= Row.usernameMaxLength else {
            return .failure(.syntaxError("username is too long"))
        }
        guard tokens[3].count <= Row.emailMaxLength else {
            return .failure(.syntaxError("email is too long"))
        }
        return .success(.insert(Row(id: id, username: tokens[2], email: tokens[3])))
    case "select":
        return .success(.select)
    default:
        return .failure(.unrecognizedStatement(keyword))
    }
}

/// `Statement` を実行する (executor 相当)。
func executeStatement(_ statement: Statement, table: inout Table) {
    switch statement {
    case .insert(let row):
        switch table.insert(row) {
        case .success(let ctid):
            print("Inserted at ctid \(ctid).")
        case .failure(.tableFull):
            print("Error: table is full.")
        }
    case .select:
        // シーケンシャルスキャンで全行を表示
        for (ctid, row) in table.seqScan() {
            print("\(ctid)\t(\(row.id), \(row.username), \(row.email))")
        }
        print("Executed.")
    }
}
