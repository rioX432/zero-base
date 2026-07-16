#!/usr/bin/env bash
#
# run-local.sh — 自律リサーチ v1 をローカルマシンで実行する（cron から呼ぶ）
#
# 構成: pick-topic(機械選定) → Claude Code CLI 単発セッションで Understand 相当の
#       検証付きリサーチ（2ソース裏取り・残存不確実性併記。フル /think パイプライン
#       =subagent/judge は無人実行では走らせない） → 整形 → send-telegram → INDEX追記。
#       token等は scripts/auto-research/.env のみ。
#
# 前提:
#   - Claude Code CLI (`claude`) がインストール＆認証済み（`claude login` or ANTHROPIC_API_KEY）
#   - scripts/auto-research/.env を用意（.env.example をコピー）
#
# 使い方:
#   ./scripts/auto-research/run-local.sh            # 実行（配信あり）
#   DRY_RUN=1 ./scripts/auto-research/run-local.sh  # 送信せず内容表示
#
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

ENV_FILE="scripts/auto-research/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; # shellcheck disable=SC1090
  source "$ENV_FILE"; set +a
fi

DRY_RUN="${DRY_RUN:-0}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
# 無人cron用フラグ（cited: code.claude.com/docs/en/headless）。
# リサーチ手順はWeb取得＋読取専用で足りる。recall（INDEX grep / profile読み）が
# dontAsk下で拒否されないよう Read/Grep/Glob も明示allowする。
# 書込・送信・INDEX追記はこのシェルが担うので、Claudeにはツールを最小限しか渡さない。
# 環境変数 CLAUDE_ARGS で上書き可。
CLAUDE_ARGS="${CLAUDE_ARGS:---permission-mode dontAsk --allowedTools WebSearch,WebFetch,Read,Grep,Glob}"
CLAUDE_MODEL="${CLAUDE_MODEL:-}"   # 未指定ならCLI既定モデル（IDをハードコードしない）

log() { printf '[auto-research] %s\n' "$*" >&2; }

# --- 1. テーマ選定（機械的） ---
PICK="$(bash scripts/auto-research/pick-topic.sh)"
TOPIC="$(awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="TOPIC") print $(i+1)}' <<<"$PICK")"
WHY="$(awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="WHY") print $(i+1)}' <<<"$PICK")"
HINT="$(awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="HINT") print $(i+1)}' <<<"$PICK")"
[[ -z "$TOPIC" ]] && { log "テーマ選定に失敗: $PICK"; exit 1; }
log "今日のテーマ: $TOPIC （$WHY）"

# --- 2-4. Claude で recall→/think(Understand,検証付き)→整形 ---
read -r -d '' PROMPT <<EOF || true
あなたは .claude/skills/auto-research/SKILL.md のフローを実行するエージェントです。
今日のテーマ: 「${TOPIC}」（keyword例: ${HINT} / 選定理由: ${WHY}）。

手順:
1. workspace/INDEX.md（あれば INDEX-archive.md も）をテーマ語で grep して recall（結論はrecallしない・ソース/失敗クエリのみ）。knowledge/profile.md があれば読む（提示の好み用。真偽の再導出には使わない）。
2. テーマを具体的な問いに絞り、Understand モードでリサーチ。**必ず独立2ソース以上で裏取り**し、残存不確実性を併記。ソースにはURLを付ける。推測を事実として書かない。
3. Telegram向けに簡潔整形（日本語・Markdown・3000字以内・結論先出し）。

出力は次の形式ちょうどにする（他は何も出力しない）:
<digest本文>
---INDEX---
INDEX_LINE: - <テーマ短縮名> | 暫定: <1文結論(要再検証)> | <検証済ソースURL> | 失敗クエリ:<あれば>
EOF

log "Claude で調査中..."
MODEL_ARG=(); [[ -n "$CLAUDE_MODEL" ]] && MODEL_ARG=(--model "$CLAUDE_MODEL")
# shellcheck disable=SC2086
OUT="$("$CLAUDE_BIN" -p "$PROMPT" $CLAUDE_ARGS "${MODEL_ARG[@]}" 2>/dev/null)" || { log "claude 実行に失敗（CLI認証/フラグを確認）"; exit 1; }
[[ -z "${OUT// }" ]] && { log "Claude 出力が空"; exit 1; }

# --- digest と INDEX_LINE を分離 ---
BODY="${OUT%%---INDEX---*}"
IDX_LINE="$(sed -n 's/^INDEX_LINE:[[:space:]]*//p' <<<"$OUT" | head -1)"

# --- 5. 配信 ---
if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s' "$BODY" | DRY_RUN=1 bash scripts/auto-research/send-telegram.sh
else
  printf '%s' "$BODY" | bash scripts/auto-research/send-telegram.sh || { log "Telegram配信に失敗"; exit 1; }
  log "配信完了"
fi

# --- 6. INDEX追記（次回novelty基準） ---
if [[ -n "$IDX_LINE" ]]; then
  mkdir -p workspace
  [[ -f workspace/INDEX.md ]] || printf '# INDEX（Recall索引・結論はrecallしない）\n\n' > workspace/INDEX.md
  if [[ "$DRY_RUN" == "1" ]]; then
    log "INDEX追記(dry-run): $IDX_LINE"
  else
    printf -- '%s\n' "$IDX_LINE" >> workspace/INDEX.md
    log "INDEX追記: $IDX_LINE"
  fi
fi
log "done"
