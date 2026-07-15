#!/usr/bin/env bash
#
# compact-workspace.sh — workspace/ の肥大を抑えるコンパクション
#
# 何をするか:
#   mtime が N日以上前の workspace/{テーマ}/ を対象に、
#   1. 丸ごと workspace/_archive/{テーマ}.tar.gz へ圧縮退避（何も失わない・完全復元可能）
#   2. live 側には最終成果物（proposal.md / design.md）と .compacted マーカーだけ残し、
#      raw中間物（research.md / analysis.md / repo-analysis.md）を削除
#      （成果物が無いテーマは最新の1 .md を stub として残す）
#
# 安全策:
#   - 既定は DRY-RUN（何も変更しない）。実行するには --apply を付ける。
#   - workspace/INDEX.md に当該テーマの行が無ければ「昇華未完」と見なしスキップ + 警告。
#   - アーカイブ tarball は削除しない（recall の一次ソース）。
#   - _archive/ と INDEX.md 自体は対象外。
#
# 使い方:
#   ./scripts/compact-workspace.sh              # dry-run・30日既定
#   ./scripts/compact-workspace.sh --days 60    # 60日より古いものだけ
#   ./scripts/compact-workspace.sh --apply      # 実際に圧縮・剪定
#
# 実行場所: 実 workspace/ があるローカル環境（リポジトリルート）で走らせる。
#
set -euo pipefail

DAYS=30
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="${2:?--days needs a value}"; shift 2 ;;
    --days=*) DAYS="${1#*=}"; shift ;;
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

echo
if [[ $APPLY -eq 1 ]]; then
  total_after=$(du -sk workspace 2>/dev/null | cut -f1 || echo 0)
  echo "compacted: ${compacted}  skipped(昇華未完): ${skipped}"
  echo "workspace: ${total_before}KB -> ${total_after}KB"
else
  echo "compacted候補: ${compacted}  skipped(昇華未完): ${skipped}"
  echo "（dry-run。実行するには --apply を付ける）"
fi
