#!/usr/bin/env bash
#
# pick-topic.sh — 次に深掘りする1テーマを機械的に選ぶ（zero-base as brain / v1）
#
# 方針（design §4/§9）:
#   - 話題taxonomy = interests.yaml（personal-ai-secretary の正本）を参照。zero-base に複製しない。
#   - novelty = INDEX.md との「機械的差分」（LLMの主観surprisalに依存しない）。
#     直近research済みの話題は避け、未researchの高weight話題を優先。
#   - 変化を出すため、候補が複数なら day-of-year で日替りローテーション（乱数不使用＝再現可能）。
#
# 入力:
#   INTERESTS_YAML  interests.yaml のパス（既定: knowledge/interests.yaml → 無ければ探索）
#   INDEX_MD        INDEX.md のパス（既定: workspace/INDEX.md）
#   RECENT_N        「直近」とみなすINDEXエントリ数（既定: 14）
#
# 出力（stdout, 1行）:
#   TOPIC\t<話題名>\tWEIGHT\t<重み>\tHINT\t<keyword例>\tWHY\t<選定理由>
#
set -euo pipefail

INTERESTS_YAML="${INTERESTS_YAML:-}"
INDEX_MD="${INDEX_MD:-workspace/INDEX.md}"
RECENT_N="${RECENT_N:-14}"

# interests.yaml の探索（明示指定 → knowledge/ → secretary クローン → リポ内）
if [[ -z "$INTERESTS_YAML" ]]; then
  for c in knowledge/interests.yaml \
           "$HOME/workspace/personal-ai-secretary/data/interests.yaml" \
           ../personal-ai-secretary/data/interests.yaml \
           /workspace/personal-ai-secretary/data/interests.yaml \
           data/interests.yaml; do
    [[ -f "$c" ]] && { INTERESTS_YAML="$c"; break; }
  done
fi
if [[ -z "$INTERESTS_YAML" || ! -f "$INTERESTS_YAML" ]]; then
  echo "error: interests.yaml が見つからない。INTERESTS_YAML= で指定するか knowledge/interests.yaml を置いてください" >&2
  exit 1
fi

# --- interests.yaml の topics: セクションから (weight, name, first-keyword) を抽出 ---
# name と weight は別行。topics: 内のみ対象（feeds: 等の同名キーを誤検出しない）。
parse_topics() {
  awk '
    /^[a-zA-Z_]+:/ { in_topics = ($0 ~ /^topics:/) ? 1 : 0 }
    in_topics && /^[[:space:]]*-[[:space:]]*name:/ {
      # 前トピックを確定
      if (name != "") print weight "\t" name "\t" hint
      name = $0; sub(/^[[:space:]]*-[[:space:]]*name:[[:space:]]*/, "", name)
      weight = "1.0"; hint = ""; want_kw = 0
    }
    in_topics && /^[[:space:]]*weight:/ {
      w = $0; sub(/^[[:space:]]*weight:[[:space:]]*/, "", w); weight = w
    }
    in_topics && /^[[:space:]]*keywords:/ { want_kw = 1; next }
    in_topics && want_kw && /^[[:space:]]*-[[:space:]]/ && hint == "" {
      h = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", h); hint = h; want_kw = 0
    }
    END { if (name != "") print weight "\t" name "\t" hint }
  ' "$INTERESTS_YAML"
}

# --- INDEX.md の直近エントリ（テーマ名の集合・小文字）---
recent_index_lc() {
  [[ -f "$INDEX_MD" ]] || return 0
  grep '^[[:space:]]*-' "$INDEX_MD" 2>/dev/null | tail -n "$RECENT_N" \
    | tr 'A-Z' 'a-z'
}

# mapfile は bash 4+ のみ（macOS 標準 bash 3.2 に無い）ので while-read で読む
TOPICS=()
while IFS= read -r row; do TOPICS+=("$row"); done < <(parse_topics)
if [[ ${#TOPICS[@]} -eq 0 ]]; then
  # ${} 必須: bash 3.2 × UTF-8 では `$VAR）` の全角括弧が変数名に食われる
  echo "error: interests.yaml の topics: を解析できませんでした（${INTERESTS_YAML}）" >&2
  exit 1
fi

RECENT_LC="$(recent_index_lc || true)"

# weight 降順にソート
IFS=$'\n' TOPICS_SORTED=($(printf '%s\n' "${TOPICS[@]}" | sort -t$'\t' -k1,1 -rn)); unset IFS

# 直近INDEXに話題名が現れないもの＝未research候補（機械的novelty）
ELIGIBLE=()
for row in "${TOPICS_SORTED[@]}"; do
  name="$(cut -f2 <<<"$row")"
  name_lc="$(tr 'A-Z' 'a-z' <<<"$name")"
  if [[ -z "$RECENT_LC" ]] || ! grep -qiF "$name_lc" <<<"$RECENT_LC"; then
    ELIGIBLE+=("$row")
  fi
done

WHY="未researchの高weight話題（INDEX差分でnovelty）"
if [[ ${#ELIGIBLE[@]} -eq 0 ]]; then
  ELIGIBLE=("${TOPICS_SORTED[@]}")
  WHY="全話題が直近research済み。最高weightを再訪（新しい角度で）"
fi

# 上位候補内で day-of-year ローテーション（変化を出す・再現可能）
TOP_W="$(cut -f1 <<<"${ELIGIBLE[0]}")"
TOP_TIER=()
for row in "${ELIGIBLE[@]}"; do
  [[ "$(cut -f1 <<<"$row")" == "$TOP_W" ]] && TOP_TIER+=("$row") || break
done
DOY="$(date +%j | sed 's/^0*//')"
IDX=$(( DOY % ${#TOP_TIER[@]} ))
CHOSEN="${TOP_TIER[$IDX]}"

W="$(cut -f1 <<<"$CHOSEN")"; N="$(cut -f2 <<<"$CHOSEN")"; H="$(cut -f3 <<<"$CHOSEN")"
printf 'TOPIC\t%s\tWEIGHT\t%s\tHINT\t%s\tWHY\t%s\n' "$N" "$W" "$H" "$WHY"
