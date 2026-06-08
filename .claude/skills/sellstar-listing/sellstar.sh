#!/usr/bin/env bash
# =============================================================================
#  セルスタ出品ツール ランチャー（sellstar.sh）
# -----------------------------------------------------------------------------
#  人がターミナルから叩く唯一の入口。シートの読み書き（gspread）と、
#  セルスタ転記スキルの起動（Claude Code）をまとめる。
#
#  使い方:
#    ./sellstar.sh doctor          # 環境チェック（サブPC初回はまずこれ）
#    ./sellstar.sh pending         # 未処理行（出品ステータス空＆ItemURL有り）を一覧
#    ./sellstar.sh read 9          # 9行目の中身を表示
#    ./sellstar.sh status 9 下書き保存   # 出品ステータス列へ書込
#    ./sellstar.sh error  9 "E302 ..."  # 出品エラー列へ書込
#    ./sellstar.sh run             # セルスタ転記スキルを起動（手動モード・対話）
#    ./sellstar.sh run 9           # 9行目だけ処理（単発モード・対話）
#    ./sellstar.sh patrol          # 自動巡回（無人・caffeinateでスリープ防止）
#
#  サブPCで使うとき: 下の VENV / CREDS のパスが違う場合だけ、
#  環境変数で上書きする（例: export SELLSTAR_VENV=/Users/xxx/.../venv）。
#  これ以外は変更不要。
# =============================================================================
set -euo pipefail

# --- 設定（環境変数で上書き可。サブPCはここだけ気にすればよい） ----------------
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"          # .claude/skills/sellstar-listing → プロジェクト直下
VENV="${SELLSTAR_VENV:-/Users/nfnfa/Desktop/credentials.json/venv}"
PY="$VENV/bin/python"
CREDS="${SELLSTAR_CREDENTIALS:-/Users/nfnfa/Desktop/credentials.json/credentials.json}"
SHEET_IO="$SKILL_DIR/sheet_io.py"
CLAUDE_BIN="${SELLSTAR_CLAUDE:-claude}"
LOG="${SELLSTAR_LOG:-$HOME/Library/Logs/sellstar-patrol.log}"

export SELLSTAR_CREDENTIALS="$CREDS"

c_red()  { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- 環境チェック -------------------------------------------------------------
doctor() {
  local ok=1
  echo "── セルスタ出品ツール 環境チェック ───────────────────"
  echo "SKILL_DIR    : $SKILL_DIR"
  echo "PROJECT_ROOT : $PROJECT_ROOT"
  echo "VENV         : $VENV"
  echo "CREDS        : $CREDS"
  echo "LOG          : $LOG"
  echo "──────────────────────────────────────────────────"

  if [ -x "$PY" ]; then c_grn "✓ Python venv あり"; else c_red "✗ venv が無い: $PY"; ok=0; fi
  if [ -f "$CREDS" ]; then c_grn "✓ 認証JSON あり"; else c_red "✗ 認証JSONが無い: $CREDS"; ok=0; fi
  if [ -f "$SHEET_IO" ]; then c_grn "✓ sheet_io.py あり"; else c_red "✗ sheet_io.py が無い"; ok=0; fi

  if [ -x "$PY" ]; then
    if "$PY" -c "import gspread, google.oauth2.service_account" 2>/dev/null; then
      c_grn "✓ gspread / google-auth 導入済み"
    else
      c_red  "✗ gspread 未導入 → $PY -m pip install -r '$SKILL_DIR/requirements.txt'"; ok=0
    fi
  fi

  if command -v "$CLAUDE_BIN" >/dev/null 2>&1; then c_grn "✓ claude CLI: $(command -v "$CLAUDE_BIN")"
  else c_ylw "△ claude CLI が見つからない（run/patrolに必要。pendingやread/statusは不要）"; fi

  # サービスアカウント名＋シート読取の疎通テスト
  if [ -x "$PY" ] && [ -f "$CREDS" ]; then
    echo "── シート疎通テスト ──"
    if "$PY" "$SHEET_IO" pending >/tmp/sellstar_doctor.json 2>/tmp/sellstar_doctor.err; then
      local n; n=$(grep -c '"row_num"' /tmp/sellstar_doctor.json 2>/dev/null || echo 0)
      c_grn "✓ シート読取OK（未処理 $n 行）"
    else
      c_red "✗ シート読取に失敗:"; sed 's/^/    /' /tmp/sellstar_doctor.err | head -5
      c_ylw "  → 多くは『編集者』共有もれ。再出品ツールを SA に編集者で共有してください。"
      ok=0
    fi
  fi

  echo "──────────────────────────────────────────────────"
  if [ "$ok" = 1 ]; then c_grn "判定: 使用可能 ✅"; else c_red "判定: 未解決の項目あり ⚠（上の✗を直す）"; return 1; fi
}

# --- スキル起動（対話・Claude Code） ------------------------------------------
run() {
  command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { c_red "claude CLI が無いので run できません。"; exit 1; }
  local target="${1:-}"
  local prompt
  if [ -n "$target" ]; then
    prompt="/sellstar-listing ${target}行目だけを処理して（単発モード）。下書き保存まで。"
  else
    prompt="/sellstar-listing 手動モードで、未処理行（出品ステータス空）を上から順に下書き保存まで処理して。"
  fi
  c_ylw "▶ Claude Code を起動します（対話）。ブラウザ（Claude in Chrome）＝セルスタにログイン済みで開いておいてください。"
  cd "$PROJECT_ROOT"
  exec "$CLAUDE_BIN" "$prompt"
}

# --- 自動巡回（無人・スリープ防止つき） ---------------------------------------
patrol() {
  command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { c_red "claude CLI が無いので patrol できません。"; exit 1; }
  mkdir -p "$(dirname "$LOG")"
  local stamp; stamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$stamp] patrol start ($(hostname))" >> "$LOG"
  doctor >> "$LOG" 2>&1 || { echo "[$stamp] preflight NG → 巡回中止" >> "$LOG"; exit 1; }

  local prompt="/sellstar-listing 自動巡回モード。未処理行（出品ステータス空）を順に下書き保存まで処理し、各行の結果を出品ステータス列へ書き戻して終了して。最終の出品ボタンは絶対に押さない。"
  cd "$PROJECT_ROOT"
  # caffeinate でスリープ防止。headless(-p)で1巡回ぶん実行。
  caffeinate -i "$CLAUDE_BIN" -p "$prompt" >> "$LOG" 2>&1 || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] patrol end" >> "$LOG"
  c_grn "巡回終了。ログ: $LOG"
}

# --- ディスパッチ -------------------------------------------------------------
cmd="${1:-help}"; shift || true
case "$cmd" in
  doctor)  doctor ;;
  pending) "$PY" "$SHEET_IO" pending ;;
  read)    "$PY" "$SHEET_IO" read "${1:?行番号を指定: ./sellstar.sh read 9}" ;;
  status)  "$PY" "$SHEET_IO" status "${1:?行番号}" "${2:?値（例 下書き保存）}" ;;
  error)   "$PY" "$SHEET_IO" error "${1:?行番号}" "${2:?ログ文字列}" ;;
  run)     run "${1:-}" ;;
  patrol)  patrol ;;
  help|-h|--help|*) usage ;;
esac
