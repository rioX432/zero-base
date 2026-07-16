#!/usr/bin/env bash
#
# compact-workspace.sh — workspace/ の肥大を抑えるコンパクション
#
# 何をするか:
#   (1) テーマ剪定: mtime が N日以上前の workspace/{テーマ}/ を対象に、
#       - 丸ごと workspace/_archive/{テーマ}.tar.gz へ圧縮退避（何も失わない・完全復元可能）
#       - live 側には最終成果物（proposal.md / design.md）と .compacted マーカーだけ残し、
#         raw中間物（research.md / analysis.md / repo-analysis.md）を削除
#         （成果物が無いテーマは最新の1 .md を stub として残す）
#   (2) INDEX ローテーション [G2]: workspace/INDEX.md が上限エントリ数を超えたら、
#       古いエントリを workspace/INDEX-archive.md へ退避（grep可能・recall一次ソースとして保持）。
#       Anthropic の「MEMORY.md は先頭200行/25KBのみロード」に倣い、索引を簡潔に保つ。
#   (3) profile サイズ警告 [G1]: knowledge/profile.md が目安(200行/25KB)を超えたら警告のみ
#       （自動編集はしない＝情報損失防止。手動マージ&重複排除を促す）。
#
# 安全策:
#   - 既定は DRY-RUN（何も変更しない）。実行するには --apply を付ける。
#   - workspace/INDEX.md に当該テーマの行が無ければ「昇華未完」と見なしスキップ + 警告。
#   - アーカイブ（tarball / INDEX-archive.md）は削除しない（recall の一次ソース）。
#   - INDEX ローテーションは「削除」ではなく「退避」（Zep の invalidate-not-delete に倣う）。
#
# サイズバジェットの根拠（Anthropic 準拠）:
#   - Claude Code auto memory: MEMORY.md は先頭200行/25KBのみ毎回ロード
#   - CLAUDE.md: 200行超で adherence 低下
#   （https://code.claude.com/docs/en/memory）
#
# 使い方:
#   ./scripts/compact-workspace.sh                 # dry-run・30日既定・INDEX上限150
#   ./scripts/compact-workspace.sh --days 60       # 60日より古いものだけ
#   ./scripts/compact-workspace.sh --index-max 100 # INDEX を100エントリで切る
#   ./scripts/compact-workspace.sh --apply         # 実際に圧縮・剪定・ローテーション
#
# 実行場所: 実 workspace/ があるローカル環境（リポジトリルート）で走らせる。
#
set -euo pipefail

DAYS=30
APPLY=0
INDEX_MAX=150   # INDEX.md に live で残す最大エントリ数（先頭200行バジェットの内側）

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="${2:?--days needs a value}"; shift 2 ;;
    --days=*) DAYS="${1#*=}"; shift ;;
    --index-max) INDEX_MAX="${2:?--index-max needs a value}"; shift 2 ;;
    --index-max=*) INDEX_MAX="${1#*=}"; shift ;;
    --apply) APPLY=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# リポジトリルート確認（CLAUDE.md と workspace/ の存在で判定）
if [[ ! -f CLAUDE.md ]]; then
  echo "error: run from repo root (CLAUDE.md not found in \$PWD)" >&2
  exit 1
fi
if [[ ! -d workspace ]]; then
  echo "workspace/ が無い。対象なし（fresh clone か未使用）。" >&2
  exit 0
fi

INDEX="workspace/INDEX.md"
ARCHIVE_DIR="workspace/_archive"
RAW_FILES=(research.md analysis.md repo-analysis.md)
DELIVERABLES=(proposal.md design.md)

now_epoch=$(date +%s)
cutoff=$(( DAYS * 86400 ))

if [[ $APPLY -eq 1 ]]; then
  mkdir -p "$ARCHIVE_DIR"
  MODE="APPLY"
else
  MODE="DRY-RUN"
fi

echo "== compact-workspace [$MODE] : ${DAYS}日より古いテーマを対象 =="
echo

total_before=$(du -sk workspace 2>/dev/null | cut -f1 || echo 0)
compacted=0
skipped=0

for dir in workspace/*/; do
  theme="$(basename "$dir")"
  # _archive とその他予約ディレクトリは対象外
  [[ "$theme" == "_archive" ]] && continue
  [[ -d "$dir" ]] || continue

  # 既にコンパクト済みはスキップ
  if [[ -f "${dir}.compacted" ]]; then
    continue
  fi

  # 年齢判定（ディレクトリ内で最も新しい mtime を使う）
  newest=$(find "$dir" -type f -printf '%T@\n' 2>/dev/null | sort -nr | head -1 | cut -d. -f1)
  [[ -z "$newest" ]] && continue
  age=$(( now_epoch - newest ))
  if [[ $age -lt $cutoff ]]; then
    continue
  fi

  # ガード: INDEX.md にテーマ行が無ければ昇華未完 → スキップ
  if [[ ! -f "$INDEX" ]] || ! grep -qF "$theme" "$INDEX" 2>/dev/null; then
    echo "  [SKIP] $theme : INDEX.md に行が無い（昇華未完）。先に INDEX 追記が必要。"
    skipped=$(( skipped + 1 ))
    continue
  fi

  size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  echo "  [COMPACT] $theme (${size}, $(( age / 86400 ))日前)"

  if [[ $APPLY -eq 1 ]]; then
    # 1. 丸ごとアーカイブ（完全復元可能）
    tar -czf "${ARCHIVE_DIR}/${theme}.tar.gz" -C workspace "$theme"

    # 2. 成果物の有無を確認
    has_deliverable=0
    for d in "${DELIVERABLES[@]}"; do
      [[ -f "${dir}${d}" ]] && has_deliverable=1
    done

    if [[ $has_deliverable -eq 1 ]]; then
      # raw中間物だけ削除、成果物は残す
      for r in "${RAW_FILES[@]}"; do
        rm -f "${dir}${r}"
      done
    else
      # 成果物なし（Understand止まり等）: 最新1 .md を残し他を削除
      keep=$(find "$dir" -maxdepth 1 -name '*.md' -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
      find "$dir" -maxdepth 1 -name '*.md' -type f ! -path "$keep" -delete 2>/dev/null || true
    fi

    # 3. マーカー
    printf 'archived: %s\ncompacted_at: %s\n' \
      "${ARCHIVE_DIR}/${theme}.tar.gz" "$(date -Iseconds)" > "${dir}.compacted"
  fi

  compacted=$(( compacted + 1 ))
done

# ---- (2) INDEX.md ローテーション [G2] ----
if [[ -f "$INDEX" ]]; then
  entries=$(grep -c '^[[:space:]]*-' "$INDEX" || true)
  entries=${entries:-0}
  if [[ "$entries" -gt "$INDEX_MAX" ]]; then
    overflow=$(( entries - INDEX_MAX ))
    echo
    echo "  [INDEX] エントリ ${entries} > 上限 ${INDEX_MAX} → 古い ${overflow} 件を INDEX-archive.md へ退避"
    if [[ $APPLY -eq 1 ]]; then
      ARCH_INDEX="workspace/INDEX-archive.md"
      [[ -f "$ARCH_INDEX" ]] || printf '# INDEX archive（ローテーション退避・grep可能・recall一次ソース。削除ではなく退避）\n\n' > "$ARCH_INDEX"
      tmp_keep=$(mktemp); tmp_arch=$(mktemp)
      # bullet(テーマ行)を上から数え、古い overflow 件を archive、残りと非bullet行は keep。順序保持。
      awk -v ovf="$overflow" -v keep="$tmp_keep" -v arch="$tmp_arch" '
        /^[[:space:]]*-/ { b++; if (b<=ovf) print >> arch; else print >> keep; next }
        { print >> keep }
      ' "$INDEX"
      cat "$tmp_arch" >> "$ARCH_INDEX"
      mv "$tmp_keep" "$INDEX"
      rm -f "$tmp_arch"
      echo "    -> ${overflow} 件を ${ARCH_INDEX} へ移動（INDEX.md は最新 ${INDEX_MAX} 件に）"
    fi
  fi
fi

# ---- (3) profile.md サイズバジェット警告 [G1] ----
PROFILE="knowledge/profile.md"
if [[ -f "$PROFILE" ]]; then
  p_lines=$(wc -l < "$PROFILE")
  p_kb=$(du -k "$PROFILE" | cut -f1)
  if [[ "$p_lines" -gt 200 || "$p_kb" -gt 25 ]]; then
    echo
    echo "  [PROFILE] knowledge/profile.md = ${p_lines}行/${p_kb}KB（目安 200行/25KB 超）"
    echo "            手動でマージ&重複排除して簡潔化を（自動編集はしない＝情報損失防止）"
  fi
fi

echo
if [[ $APPLY -eq 1 ]]; then
  total_after=$(du -sk workspace 2>/dev/null | cut -f1 || echo 0)
  echo "compacted: ${compacted}  skipped(昇華未完): ${skipped}"
  echo "workspace: ${total_before}KB -> ${total_after}KB"
else
  echo "compacted候補: ${compacted}  skipped(昇華未完): ${skipped}"
  echo "（dry-run。実行するには --apply を付ける）"
fi
