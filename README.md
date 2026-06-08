# sellstar-listing（セルスタ出品ツール）

eBay 再出品用スプレッドシートの完成済み行を読み取り、在庫管理ツール **セルスタ（sellsta.jp）** の
新規出品画面へ転記して **「下書き保存」まで** を自動化するツール一式です。
（最終の「出品」ボタンは押しません。人が目視チェックして押します。）

## このフォルダの中身
```
sellstar-listing/
├── README.md                       ← いま読んでいるこれ
├── sellstar.sh                     ← 人が叩く入口（ランチャー）
├── 運用ガイド.md                    ← 使い方の詳しいマニュアル（まずこれ）
├── 出品ツール仕様書.md               ← 正本仕様（設計の根拠・全エラーコード）
├── description-template-sample.html ← 商品説明HTMLの構造サンプル（参考）
└── .claude/skills/sellstar-listing/ ← スキル本体（Claude Code の /sellstar-listing）
    ├── SKILL.md                     … 転記の操作手順
    ├── sellstar.sh                  … ランチャー実体
    ├── sheet_io.py                  … スプレッドシート読み書き（gspread）
    ├── requirements.txt             … サブPC用 依存パッケージ
    ├── reference/                   … エラーコード表・コンディション対応表
    └── patrol/                      … 自動巡回スケジューラ（launchd）雛形
```

## 使い始め（3ステップ）
```bash
cd "/Users/nfnfa/company/eBay/ebay-listing/sellstar-listing"
./sellstar.sh doctor     # 環境チェック（初回・サブPCはまずこれ）
./sellstar.sh run        # 未処理行をまとめて下書き保存（手動モード）
```
詳しくは **運用ガイド.md** を参照。

## 前提
- Chrome でセルスタ（sellsta.jp）にログイン済み＋ Claude in Chrome 拡張が接続済み。
- スプレッドシート「再出品ツール」がサービスアカウントに「編集者」共有済み。
- Python venv（gspread 入り）と サービスアカウント認証JSON。`./sellstar.sh doctor` で確認できます。
