---
name: auto-research
description: 指示なしで1本、profile/interests/INDEXを元に「次に深掘るべきテーマ」を選び、/think で検証付きリサーチし、結果をTelegramへ配信してINDEXに記録する。cron Routineから起動する自律リサーチのv1エントリ。
when_to_use: |
  Scheduled/autonomous research runs. Invoked by a cron Routine (daily) to
  produce one verified deep-research digest and push it to chat without a
  human prompt. Not for interactive research — use /think for that.
argument-hint: "（引数不要。テーマは自動選定。'--dry-run' で送信せず表示）"
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Grep, Glob, Skill, WebSearch, WebFetch, mcp__gemini-deepsearch__deep_search, mcp__perplexity-web__perplexity_ask, mcp__codex__codex
effort: medium
---

# /auto-research — 自律リサーチ v1（zero-base as brain）

指示なしで **1日1本、検証付きの深掘りリサーチをチャットに届ける** 最小ループ。
設計: `docs/autonomous-research-design.md` §9。**cron Routine から起動**される前提。

## 前提（環境変数）

- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` — 配信先（未設定なら **必ず `--dry-run` 相当で止め**、送信せずレポートをチャット/ログに残すだけにする）
- `INTERESTS_YAML`（任意）— interests.yaml のパス。既定探索: `knowledge/interests.yaml` → secretary クローン → `data/interests.yaml`

## フロー（この順で実行する）

### 1. テーマ選定（機械的・LLMに選ばせない）
```bash
scripts/auto-research/pick-topic.sh
```
出力の `TOPIC` を今日のテーマにする。**「重要そう」でLLMに選ばせず、interests.yaml(weight) × INDEX差分(novelty) で機械的に決める**（design原則）。選定理由(`WHY`)も控える。

### 2. Recall（レイヤーA/B）
- `workspace/INDEX.md`（＋`INDEX-archive.md`）を選定テーマ語で grep（結論はrecallしない・ソース/失敗クエリのみ）
- `knowledge/profile.md` を読む（提示の好み・判断スタイル。真偽の再導出には使わない）

### 3. リサーチ（/think を Understand 既定で）
選定テーマで `/think` を呼ぶ。**コスト管理: 既定は Understand（本質＋推論トレースまで）**。フル Decide/Design はコスト15x級なので**自動実行では上げない**（rio が後で指示したときだけ）。
検証は省かない: source-verifier 相当の裏取り（最低2ソース）・残存不確実性の併記は自動実行でも必須。

### 4. 整形（結論先出し・チャット向け）
Telegram 向けに簡潔整形（Markdown・~3000字以内）:
```
🔎 今日の深掘り: {テーマ}  （選定理由: {WHY}）

結論: {1–3文で本質}

根拠（検証済・2ソース以上）:
- {要点} — {URL}
- {要点} — {URL}

残存不確実性: {検証済でも残るリスク}
次の一歩（任意）: {あれば}
```
過信を生む書き方をしない（「検証済み」には必ず残存不確実性を併記）。

### 5. 配信
```bash
printf '%s' "$整形本文" | scripts/auto-research/send-telegram.sh
# token未設定 or 引数に --dry-run が来た場合は DRY_RUN=1 で送信せず表示のみ
```

### 6. 記録（次回のnovelty基準）
`workspace/INDEX.md` に1行追記（テーマ / 当時の暫定結論(要再検証) / 検証済ソースURL / 失敗クエリ）。**結論はrecall対象にしない規律を守る**。
INDEX が肥大したら `scripts/compact-workspace.sh`（別途・定期）でローテーション。

## 安全（v1）
- **Notify型のみ**（報告だけ・不可逆操作なし・承認ゲート不要）。
- 1回1テーマ・Understand既定＝コスト上限（財務サーキットブレーカー）。
- 配信失敗（send-telegram 非ゼロ終了）はログに残し、握り潰さない。

## v2以降（このskillの拡張余地）
- チャットの reaction/返信 → `knowledge/profile.md` 更新候補（feedback loop・人間ゲート）
- novelty厳密化（INDEX/mem0 差分＋serendipity3条件）
- 実装×計画 drift check（repo-analyzer 連携）
- proactivityレベル（Observer→Partner）／1日3回化
