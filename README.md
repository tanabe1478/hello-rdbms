# hello-rdbms

ゼロから作る自作RDBMS (SQLiteのような小さな組み込みDB)。学習目的で、理解できる粒度ごとにPull Requestを積み上げて進める。

## 言語

Swift (SwiftPM)。ビルド:

```sh
swift build
swift run hello-rdbms
```

## ロードマップ

各ステップが1つのPRに対応する。

1. **REPL** — 対話ループの骨組み(プロンプト表示、`.exit`で終了)
2. **SQLパーサ** — `insert` / `select` 文を内部表現(`Statement`)に変換
3. **インメモリテーブル** — 行を配列に保持し、insert/selectを実行
4. **ディスク永続化** — 4KBページ単位の読み書き(Pager)
5. **B-treeインデックス** — リーフノード → 分割 → 内部ノード → 再帰検索
6. 以降: カーソル、主キー検索、より多くのSQL機能…
