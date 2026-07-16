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
# source ではなく KEY=VALUE だけを読む（.env は token 置き場であってスクリプトではない。
# source すると .env に紛れたシェルコードが cron 権限で走る）。
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r env_line || [[ -n "$env_line" ]]; do
    [[ "$env_line" =~ ^[[:space:]]*# ]] && continue
    [[ "$env_line" =~ ^[[:space:]]*$ ]] && continue
    if [[ "$env_line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      env_key="${BASH_REMATCH[2]}"; env_val="${BASH_REMATCH[3]}"
      # 引用符があれば中身をそのまま採用（インラインコメントは値の一部にしない）。
      # 引用符なしは ` #` 以降をコメントとして落とす（token に空白は含まれない）。
      if [[ "$env_val" =~ ^\"([^\"]*)\" ]]; then
        env_val="${BASH_REMATCH[1]}"
      elif [[ "$env_val" =~ ^\'([^\']*)\' ]]; then
        env_val="${BASH_REMATCH[1]}"
      else
        env_val="${env_val%%[[:space:]]#*}"
        env_val="${env_val#"${env_val%%[![:space:]]*}"}"
        env_val="${env_val%"${env_val##*[![:space:]]}"}"
      fi
      export "$env_key=$env_val"
    fi
  done < "$ENV_FILE"
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
# 変数は必ず ${} で囲む: bash 3.2 × UTF-8ロケールでは `$WHY）` の全角括弧が
# 変数名の一部として解釈され `unbound variable` で落ちる（cron/手動実行の両方で踏む）。
log "今日のテーマ: ${TOPIC} （${WHY}）"

# INDEX行は既存INDEX.mdの形式 `- [slug] (YYYY-MM-DD, workspace/slug/) | …` に揃える。
# compact-workspace.sh の昇華済み判定がこの構造に依存するため、ズレると剪定されない。
TODAY="$(date +%F)"
TOPIC_SLUG="$(printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')"
[[ -z "$TOPIC_SLUG" ]] && TOPIC_SLUG="auto-research-${TODAY}"

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
INDEX_LINE: - [${TOPIC_SLUG}] (${TODAY}, workspace/${TOPIC_SLUG}/) | 当時の暫定結論(要再検証): <1文> | 検証済ソース: <url1, url2> | 失敗クエリ/行き止まり: <あれば> | 既知の罠: <あれば>
EOF

log "Claude で調査中..."
MODEL_ARG=(); [[ -n "$CLAUDE_MODEL" ]] && MODEL_ARG=(--model "$CLAUDE_MODEL")
# stderr は捨てずに残す。無人cronでは認証切れ・レート制限・ツール拒否の原因がここにしか出ない。
CLAUDE_ERR="$(mktemp)"
trap 'rm -f "$CLAUDE_ERR"' EXIT
# ${arr[@]+"${arr[@]}"}: bash 3.2 は set -u 下で空配列の "${arr[@]}" を unbound 扱いにする（4.4で修正）
# shellcheck disable=SC2086
if ! OUT="$("$CLAUDE_BIN" -p "$PROMPT" $CLAUDE_ARGS ${MODEL_ARG[@]+"${MODEL_ARG[@]}"} 2>"$CLAUDE_ERR")"; then
  log "claude 実行に失敗（CLI認証/フラグを確認）:"
  sed 's/^/[auto-research][claude] /' "$CLAUDE_ERR" >&2
  exit 1
fi
if [[ -z "${OUT// }" ]]; then
  log "Claude 出力が空:"
  sed 's/^/[auto-research][claude] /' "$CLAUDE_ERR" >&2
  exit 1
fi
[[ -s "$CLAUDE_ERR" ]] && sed 's/^/[auto-research][claude:warn] /' "$CLAUDE_ERR" >&2

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
  if [[ "$DRY_RUN" == "1" ]]; then
    # dry-run は副作用ゼロにする（ディレクトリ/ヘッダも作らない）
    log "INDEX追記(dry-run): ${IDX_LINE}"
  else
    mkdir -p workspace
    [[ -f workspace/INDEX.md ]] || printf '# INDEX（Recall索引・結論はrecallしない）\n\n## 索引\n\n' > workspace/INDEX.md
    printf -- '%s\n' "$IDX_LINE" >> workspace/INDEX.md
    log "INDEX追記: $IDX_LINE"
  fi
fi
log "done"
