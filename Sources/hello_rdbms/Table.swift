import Foundation

/// PostgreSQL の ctid (ItemPointer) 相当: タプルの物理位置 (ページ番号, スロット番号)。
/// PGのスロット番号は1始まりなのでそれに倣う。
struct Ctid: Equatable, CustomStringConvertible {
    var blockNumber: Int
    var offsetNumber: Int

    var description: String { "(\(blockNumber),\(offsetNumber))" }
}

enum InsertError: Error {
    case tableFull
}

/// ヒープファイル (テーブル)。今はメモリ上にページを保持するだけで、
/// ディスクへの書き出しは次のステップ。
struct Table {
    /// デモ用の上限。1400行 ≒ 52ページぶん (1ページに約27タプル)。
    static let maxPages = 100

    private(set) var pages: [Page] = []

    /// タプルをヒープに挿入する。PostgreSQL の heap_insert 相当。
    /// 末尾ページに空きがあればそこへ、なければ新規ページを追加する。
    /// (本物は FSM = Free Space Map で空きのあるページを探す)
    mutating func insert(_ row: Row) -> Result<Ctid, InsertError> {
        let tuple = HeapTuple(row: row).bytes

        if !pages.isEmpty {
            var last = pages[pages.count - 1]
            if let slot = last.addTuple(tuple) {
                pages[pages.count - 1] = last
                return .success(Ctid(blockNumber: pages.count - 1, offsetNumber: slot + 1))
            }
        }

        guard pages.count < Table.maxPages else {
            return .failure(.tableFull)
        }
        var page = Page()
        let slot = page.addTuple(tuple)!
        pages.append(page)
        return .success(Ctid(blockNumber: pages.count - 1, offsetNumber: slot + 1))
    }

    /// 全タプルを挿入順に読み出すシーケンシャルスキャン (SeqScan) 相当。
    /// 全ページの全 LinePointer をなめる、テーブル走査の基本形。
    func seqScan() -> [(ctid: Ctid, row: Row)] {
        var result: [(Ctid, Row)] = []
        for (pageNum, page) in pages.enumerated() {
            for slot in 0..<page.numItems {
                if let tupleBytes = page.tuple(at: slot) {
                    let row = HeapTuple(tupleBytes: tupleBytes).toRow()
                    result.append((Ctid(blockNumber: pageNum, offsetNumber: slot + 1), row))
                }
            }
        }
        return result
    }
}
