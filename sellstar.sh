#!/usr/bin/env bash
# セルスタ出品ツール トップレベル・ランチャー（便利ラッパー）
# 実体は .claude/skills/sellstar-listing/sellstar.sh。ここから叩けば cwd がこのフォルダになり
# /sellstar-listing スキルも自動で見つかる。
#   ./sellstar.sh doctor | pending | read N | status N 値 | error N ログ | run [N] | patrol
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/.claude/skills/sellstar-listing/sellstar.sh" "$@"
