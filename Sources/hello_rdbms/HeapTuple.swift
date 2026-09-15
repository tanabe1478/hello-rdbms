import Foundation

/// ヒープタプル = ページに収まる行のバイナリ形式。
/// PostgreSQL の HeapTupleHeaderData は xmin/xmax/ctid/infomask 等を持つ
/// 23B だが、ここでは最小限の t_len (タプル全長) だけをヘッダにする。
///
/// レイアウト:
///   [t_len: UInt16 (2B)][payload]
///
/// payload は users テーブル固定カラム:
///   [id: UInt32 (4B)][username: UTF-8 32B固定][email: UTF-8 255B固定]
struct HeapTuple {
    static let headerSize = 2
    static let payloadSize = 4 + Row.usernameMaxLength + Row.emailMaxLength  // 291B
    static let size = headerSize + payloadSize                                // 293B

    var payload: [UInt8]

    /// Row をタプルのバイト列にシリアライズする。
    init(row: Row) {
        var p = [UInt8](repeating: 0, count: HeapTuple.payloadSize)
        // id (little-endian)
        p[0] = UInt8(row.id & 0xff)
        p[1] = UInt8((row.id >> 8) & 0xff)
        p[2] = UInt8((row.id >> 16) & 0xff)
        p[3] = UInt8((row.id >> 24) & 0xff)
        // username / email: UTF-8で書き残りは0パディング
        let u = Array(row.username.utf8.prefix(Row.usernameMaxLength))
        p.replaceSubrange(4..<(4 + u.count), with: u)
        let e = Array(row.email.utf8.prefix(Row.emailMaxLength))
        let emailStart = 4 + Row.usernameMaxLength
        p.replaceSubrange(emailStart..<(emailStart + e.count), with: e)
        payload = p
    }

    /// タプルのバイト列から Row をデシリアライズする。
    func toRow() -> Row {
        let id = UInt32(payload[0])
            | (UInt32(payload[1]) << 8)
            | (UInt32(payload[2]) << 16)
            | (UInt32(payload[3]) << 24)
        let uEnd = 4 + Row.usernameMaxLength
        let username = String(decoding: payload[4..<uEnd].prefix { $0 != 0 }, as: UTF8.self)
        let email = String(decoding: payload[uEnd..<payload.count].prefix { $0 != 0 }, as: UTF8.self)
        return Row(id: id, username: username, email: email)
    }

    /// t_len ヘッダつきのタプル全体のバイト列。
    var bytes: [UInt8] {
        var b = [UInt8](repeating: 0, count: HeapTuple.size)
        let len = UInt16(HeapTuple.size)
        b[0] = UInt8(len & 0xff)
        b[1] = UInt8(len >> 8)
        b.replaceSubrange(HeapTuple.headerSize..<HeapTuple.size, with: payload)
        return b
    }

    /// ページ上のタプルバイト列を受け取る (t_len を読み飛ばす)。
    init(tupleBytes: [UInt8]) {
        payload = Array(tupleBytes[HeapTuple.headerSize..<tupleBytes.count])
    }
}
