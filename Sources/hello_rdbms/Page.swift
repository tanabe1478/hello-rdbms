import Foundation

/// ページサイズ。PostgreSQL の BLCKSZ と同じ 8KiB。
let pageSize = 8192

/// PostgreSQL の PageHeaderData (24B) と同じレイアウトのページヘッダ。
/// 今使うのは pd_lower / pd_upper だけで、残りは将来のために予約。
///
///   offset 0 : pd_lsn      (8B)  WAL関連。未使用
///   offset 8 : pd_checksum (2B)  未使用
///   offset 10: pd_flags    (2B)  未使用
///   offset 12: pd_lower    (2B)  空き領域の先頭 = LinePointer配列の末尾
///   offset 14: pd_upper    (2B)  空き領域の末尾 = タプル領域の先頭
///   offset 16: pd_special  (2B)  未使用(インデックスページで使用)
///   offset 18: pd_pagesize_version (2B)
///   offset 20: pd_prune_xid (4B) 未使用
struct PageHeader {
    static let size = 24

    var pdLower: UInt16   // 空き領域の開始オフセット
    var pdUpper: UInt16   // 空き領域の終了オフセット

    static let pagesizeVersion: UInt16 = 4  // PostgreSQL の現在値
}

/// PostgreSQL の ItemIdData (LinePointer) 相当。
/// 本物は4Bに packed されるが、ここでは読みやすさ優先で offset/length を分離。
/// length == 0 は「このスロットは空き(削除済み等)」を意味する。
struct LinePointer {
    static let size = 4  // 2B + 2B

    var lpOff: UInt16   // タプル本体のページ内オフセット
    var lpLen: UInt16   // タプルのバイト長 (0 = 未使用)
}

/// 8KiB のヒープページ1枚。PostgreSQL の heap page と同じ構造:
///
///   [PageHeader][LinePointer配列 →][ ← 空き ][← タプル列]
///
/// LinePointer 配列は先頭から後ろへ、タプルは末尾から前へ伸びる。
/// 真ん中の空き領域が尽きたらページは満杯。
struct Page {
    var bytes: [UInt8]

    init() {
        bytes = [UInt8](repeating: 0, count: pageSize)
        writeUInt16(PageHeader.pagesizeVersion, at: 18)
        pdLower = UInt16(PageHeader.size)
        pdUpper = UInt16(pageSize)
    }

    init(bytes: [UInt8]) {
        precondition(bytes.count == pageSize)
        self.bytes = bytes
    }

    // MARK: - pd_lower / pd_upper

    var pdLower: UInt16 {
        get { readUInt16(at: 12) }
        set { writeUInt16(newValue, at: 12) }
    }
    var pdUpper: UInt16 {
        get { readUInt16(at: 14) }
        set { writeUInt16(newValue, at: 14) }
    }

    /// ページ中間の空きバイト数。
    var freeSpace: Int { Int(pdUpper) - Int(pdLower) }

    /// LinePointer の個数 (= ページ内のスロット数)。
    var numItems: Int {
        (Int(pdLower) - PageHeader.size) / LinePointer.size
    }

    /// `size` バイトのタプルを1件入れられるか。
    /// タプル本体 + LinePointer 1個ぶんの空きが必要。
    func canFit(tupleSize: Int) -> Bool {
        freeSpace >= tupleSize + LinePointer.size
    }

    // MARK: - LinePointer

    private func linePointerOffset(at index: Int) -> Int {
        PageHeader.size + index * LinePointer.size
    }

    func linePointer(at index: Int) -> LinePointer {
        let o = linePointerOffset(at: index)
        return LinePointer(lpOff: readUInt16(at: o), lpLen: readUInt16(at: o + 2))
    }

    private mutating func writeLinePointer(_ lp: LinePointer, at index: Int) {
        let o = linePointerOffset(at: index)
        writeUInt16(lp.lpOff, at: o)
        writeUInt16(lp.lpLen, at: o + 2)
    }

    // MARK: - タプルの追加・取得

    /// タプルを末尾側の空き領域に追記し、LinePointer を先頭側に追加する。
    /// 戻り値は割り当てられたスロット番号 (0始まり)。入らなければ nil。
    mutating func addTuple(_ tuple: [UInt8]) -> Int? {
        guard canFit(tupleSize: tuple.count) else { return nil }
        let newUpper = Int(pdUpper) - tuple.count
        bytes.replaceSubrange(newUpper..<(newUpper + tuple.count), with: tuple)
        pdUpper = UInt16(newUpper)

        let index = numItems
        writeLinePointer(LinePointer(lpOff: UInt16(newUpper), lpLen: UInt16(tuple.count)), at: index)
        pdLower = UInt16(Int(pdLower) + LinePointer.size)
        return index
    }

    /// スロット `index` の指すタプルのバイト列。空スロットや範囲外は nil。
    func tuple(at index: Int) -> [UInt8]? {
        guard index >= 0 && index < numItems else { return nil }
        let lp = linePointer(at: index)
        guard lp.lpLen > 0 else { return nil }
        return Array(bytes[Int(lp.lpOff)..<Int(lp.lpOff) + Int(lp.lpLen)])
    }

    // MARK: - リトルエンディアンの読み書きヘルパ

    func readUInt16(at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    mutating func writeUInt16(_ value: UInt16, at offset: Int) {
        bytes[offset] = UInt8(value & 0xff)
        bytes[offset + 1] = UInt8(value >> 8)
    }
}
