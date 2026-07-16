#!/usr/bin/env bash
#
# send-telegram.sh — Telegram へメッセージを push（zero-base as brain / v1）
#
# 個人用bot前提。rio が BotFather で bot を作り token を取得、自分の chat_id を控える。
# ※ Telegram制約: bot は「ユーザーが先に bot へ話しかける」まで送信できない。初回に一度話しかける。
#
# 環境変数:
#   TELEGRAM_BOT_TOKEN  BotFather 発行のトークン（必須）
#   TELEGRAM_CHAT_ID    送信先 chat_id（必須。自分のuser id。@userinfobot 等で取得）
#
# 使い方:
#   echo "本文" | ./send-telegram.sh                 # stdin から本文
#   ./send-telegram.sh "本文"                        # 引数で本文
#   DRY_RUN=1 ./send-telegram.sh "本文"              # 送信せず curl 内容を表示（token不要でテスト可）
#
# 仕様:
#   - Telegram sendMessage の 4096 文字上限に合わせて分割送信。
#   - parse_mode=Markdown。失敗時は非ゼロ終了（Routine 側で検知可能）。
#
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

# 本文取得（引数優先、無ければ stdin）
if [[ $# -ge 1 && -n "${1:-}" ]]; then
  MSG="$1"
else
  MSG="$(cat)"
fi

if [[ -z "${MSG// }" ]]; then
  echo "error: 送信本文が空です" >&2
  exit 2
fi

if [[ "$DRY_RUN" != "1" ]]; then
  : "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN が未設定}"
  : "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID が未設定}"
fi
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN:-DRYRUN}/sendMessage"

# 4096文字ごとに分割（マルチバイトを避けて安全側に 3500 文字で切る）
LIMIT=3500

# 1回の sendMessage POST。$2 が空なら parse_mode を付けない（plain text）
tg_post() {
  local text="$1" mode="${2:-}" http
  local args=(
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}"
    --data-urlencode "text=${text}"
    --data-urlencode "disable_web_page_preview=true"
  )
  [[ -n "$mode" ]] && args+=(--data-urlencode "parse_mode=${mode}")
  http=$(curl -sS -o "/tmp/tg_resp.$$" -w '%{http_code}' "${args[@]}" "$API") \
    || { echo "error: curl 失敗" >&2; return 1; }
  if [[ "$http" != "200" ]]; then
    echo "error: Telegram API HTTP $http: $(cat "/tmp/tg_resp.$$" 2>/dev/null)" >&2
    rm -f "/tmp/tg_resp.$$"
    return 1
  fi
  rm -f "/tmp/tg_resp.$$"
}

send_chunk() {
  local text="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "----- [DRY_RUN] Telegram sendMessage (chat_id=${TELEGRAM_CHAT_ID:-<unset>}) -----"
    printf '%s\n' "$text"
    echo "----- (${#text} chars) -----"
    return 0
  fi
  # LLM出力のMarkdownは未閉じ */_ 等でlegacy parserが400を返しやすい
  # → Markdownで失敗したらplain textで再送（配信自体は落とさない）
  if ! tg_post "$text" "Markdown"; then
    echo "warn: Markdown送信に失敗 → plain text で再送" >&2
    tg_post "$text" ""
  fi
}

# 行境界を尊重しつつ LIMIT で分割
buf=""
while IFS= read -r line || [[ -n "$line" ]]; do
  # 1行が LIMIT を超える場合は行内でハード分割（行単位の分割では 4096 制限を超える）
  while (( ${#line} > LIMIT )); do
    [[ -n "$buf" ]] && { send_chunk "$buf"; buf=""; }
    send_chunk "${line:0:LIMIT}"
    line="${line:LIMIT}"
  done
  if (( ${#buf} + ${#line} + 1 > LIMIT )); then
    [[ -n "$buf" ]] && send_chunk "$buf"
    buf="$line"
  else
    buf="${buf:+$buf$'\n'}$line"
  fi
done <<< "$MSG"
[[ -n "$buf" ]] && send_chunk "$buf"

[[ "$DRY_RUN" == "1" ]] && echo "(DRY_RUN: 実送信していません)" >&2
exit 0
