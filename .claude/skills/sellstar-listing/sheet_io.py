#!/usr/bin/env python3
"""セルスタ出品ツール — スプレッドシート読み書きヘルパー（Google Sheets API / gspread）。

なぜAPIか:
- Drive APIエクスポートは複数タブ連結＋列ズレ＋切り詰めで精密抽出に不向き。
- ブラウザのtypeは日本語セル入力が不安定。
→ サービスアカウント＋gspreadなら、行スコープの確実な読取と日本語の確実な書込ができる。

前提:
- サービスアカウント認証 JSON（既存 fetch系ツールと共用）:
  既定 /Users/nfnfa/Desktop/credentials.json/credentials.json
- 対象シートを上記サービスアカウントに「編集者」で共有しておくこと
  （読取のみなら閲覧者でも可。書込には編集者が必要）。
- 列は **1行目ヘッダーのラベル名で解決**（列移動に耐える）。

使い方（例）:
  python3 sheet_io.py pending                 # 出品ステータスが空＆ItemURL有りの行を一覧
  python3 sheet_io.py read 6                   # 6行目の全項目を表示
  python3 sheet_io.py status 6 下書き保存       # B列(出品ステータス)に書込（要編集者権限）
  python3 sheet_io.py error 6 "E301 ..."       # 出品エラー列に書込（要編集者権限）
"""

import os
import sys
import json

import gspread
from google.oauth2.service_account import Credentials

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

# --- 設定（必要に応じて変更） ---
CREDENTIALS_PATH = os.environ.get(
    "SELLSTAR_CREDENTIALS",
    "/Users/nfnfa/Desktop/credentials.json/credentials.json",
)
SPREADSHEET_ID = os.environ.get(
    "SELLSTAR_SHEET_ID",
    "1XNwsNA8x6v06-rfGy1T02DAsSrmXJc1zUVZ_wmXZRTM",  # 再出品ツール
)
WORKSHEET_NAME = os.environ.get("SELLSTAR_WS", "出品")
HEADER_ROW = 1  # 1行目がヘッダー（2〜4行目はサブヘッダー、データは実質5行目以降）

# 書込先・判定に使うヘッダー名
H_STATUS = "出品ステータス"   # B列。区分を書く
H_ERROR = "出品エラー"        # コード＋ログを書く（工程管理列内）
H_ITEMURL = "ItemURL"         # 対象判定に使用


def _client():
    if not os.path.exists(CREDENTIALS_PATH):
        raise FileNotFoundError(f"認証JSONが見つかりません: {CREDENTIALS_PATH}")
    creds = Credentials.from_service_account_file(CREDENTIALS_PATH, scopes=SCOPES)
    return gspread.authorize(creds)


def _ws():
    ss = _client().open_by_key(SPREADSHEET_ID)
    return ss.worksheet(WORKSHEET_NAME)


def _col_letter(idx0: int) -> str:
    """0-based 列インデックス → A1表記の列レター。"""
    n = idx0 + 1
    s = ""
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def _header_map(values: list) -> dict:
    """ヘッダー名 → 0-based 列インデックス。表記ゆれの軽い吸収のみ。"""
    if len(values) < HEADER_ROW:
        return {}
    header = values[HEADER_ROW - 1]
    m = {}
    for i, name in enumerate(header):
        key = (name or "").strip()
        if key and key not in m:
            m[key] = i
    return m


def _cell(row: list, idx0: int) -> str:
    return row[idx0].strip() if (0 <= idx0 < len(row)) else ""


def list_pending() -> list:
    """出品ステータス(B)が空 かつ ItemURL有り のデータ行を返す。"""
    ws = _ws()
    values = ws.get_all_values()
    hm = _header_map(values)
    for need in (H_STATUS, H_ITEMURL):
        if need not in hm:
            raise RuntimeError(f"ヘッダー『{need}』が見つかりません（E004相当）。実ヘッダー: {list(hm)[:20]}")
    si, ui = hm[H_STATUS], hm[H_ITEMURL]
    out = []
    for r in range(HEADER_ROW, len(values)):  # HEADER_ROW以降（0-based）＝2行目以降
        row = values[r]
        status = _cell(row, si)
        itemurl = _cell(row, ui)
        if status == "" and itemurl != "" and itemurl != H_ITEMURL:
            out.append({"row_num": r + 1, "ItemURL": itemurl[:60]})
    return out


def read_row(row_num: int) -> dict:
    """指定行の全項目を {ヘッダー名: 値} で返す。"""
    ws = _ws()
    values = ws.get_all_values()
    hm = _header_map(values)
    if row_num - 1 >= len(values):
        raise RuntimeError(f"{row_num}行目が存在しません。")
    row = values[row_num - 1]
    return {name: (row[i] if i < len(row) else "") for name, i in hm.items()}


def _resolve_col(header_name: str) -> str:
    ws = _ws()
    values = ws.get_all_values()
    hm = _header_map(values)
    if header_name not in hm:
        raise RuntimeError(f"ヘッダー『{header_name}』が見つかりません。")
    return _col_letter(hm[header_name])


def write_status(row_num: int, status: str) -> None:
    """B列(出品ステータス)に区分を書く。要編集者権限。"""
    ws = _ws()
    col = _col_letter(_header_map(ws.get_all_values())[H_STATUS])
    ws.update(values=[[status]], range_name=f"{col}{row_num}")


def write_error(row_num: int, code_log: str) -> None:
    """出品エラー列にコード＋ログを書く。要編集者権限。"""
    ws = _ws()
    col = _col_letter(_header_map(ws.get_all_values())[H_ERROR])
    ws.update(values=[[code_log]], range_name=f"{col}{row_num}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "pending"
    if cmd == "pending":
        print(json.dumps(list_pending(), ensure_ascii=False, indent=2))
    elif cmd == "read":
        d = read_row(int(sys.argv[2]))
        for k, v in d.items():
            if str(v).strip():
                print(f"{k} = {str(v)[:80]}")
    elif cmd == "status":
        write_status(int(sys.argv[2]), sys.argv[3])
        print("OK: status written")
    elif cmd == "error":
        write_error(int(sys.argv[2]), sys.argv[3])
        print("OK: error written")
    else:
        print(__doc__)
