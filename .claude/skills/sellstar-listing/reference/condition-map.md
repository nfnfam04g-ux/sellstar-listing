# コンディション対応表（`状態`日本語 → eBay Condition）

仕様書 付録A-3 の写し＋運用メモ。**シート内に eBay 公式 Condition 参照表が既にある**ので、
最終的にはシート側の参照表を正とする。ここは実装の足場（要確定の雛形）。

## eBay 公式 Condition ID（基本）
| Condition ID | 名称 |
|---|---|
| 1000 | New |
| 1500 | New other |
| 1750 | New with defects |
| 2000 | Manufacturer refurbished |
| 2500 | Seller refurbished |
| 3000 | Used |
| 4000 | Very Good |
| 5000 | Good |
| 6000 | Acceptable |
| 7000 | For parts or not working |

- **カテゴリで表示名が変わる**（例: 1000 New → 衣類「New with tags」、箱物「New with box」）。
  → `状態` から Condition を決めたら、画面のカテゴリに応じた表示名を選ぶ。
- 商品状態ドロップダウンの観測値: New / New other / Used / Very Good / Good / For Part / Pre-Owned。

## `状態`(W列) 日本語 → Condition（要確定）
> ⚠ シートの「状態」列の実際の値一覧を確認して確定する（動作確認ステップ①で埋める）。
> 値が対応表にない場合は **E301（要確認）** とし、その行を止める。

| シートの `状態`（日本語・例） | eBay Condition（暫定） |
|---|---|
| 新品 / 未使用 / 未開封 | New (1000) |
| 新品（その他） | New other (1500) |
| 中古 / 中古美品 | Used (3000) / Very Good (4000) |
| 並品 | Good (5000) |
| ジャンク / 部品取り | For parts or not working (7000) |

## Condition description（中古品のみ）
- New → 不要。
- 中古品（New以外）のときのみ: `状態テンプレート`(X列) の値を、別シート **「状態　テンプレ」** の
  **A列（日本語キー）** で引き、**一致行の C列（英文）** を Condition description 欄へ入力する。
  例: A2「未開封」→ C2 の英文。
