# 自律リサーチ v1 — セットアップ手順（Telegram）

`docs/autonomous-research-design.md` §9 の v1（zero-base as brain）を動かす手順。
**指示なしで1日1本、検証付きの深掘りリサーチが Telegram に届く**状態にする。

構成: **cron Routine → Claude セッションが `/auto-research` を実行 → Telegram へ push**。

---

## 1. Telegram bot を作る（rio・約5分）

1. Telegram で **@BotFather** に話しかけ、`/newbot` → 名前とユーザー名を決める。
2. 発行された **bot token** を控える（`123456:ABC-...`）。
3. 作った bot を開き、**一度なんでもいいので話しかける**（Telegram制約: ユーザーが先に話しかけないと bot は送信不可）。
4. 自分の **chat_id** を取得: bot に話しかけた後、ブラウザで
   `https://api.telegram.org/bot<TOKEN>/getUpdates` を開くと `"chat":{"id":...}` に出る（または @userinfobot に聞く）。

## 2. 環境変数を設定

`/auto-research` を実行する環境に以下を渡す:

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-..."
export TELEGRAM_CHAT_ID="<自分のchat_id>"
# 任意: interests.yaml の場所（既定探索でも可）
export INTERESTS_YAML="/path/to/personal-ai-secretary/data/interests.yaml"
```

> `knowledge/interests.yaml` に置く/シンボリックリンクを張れば `INTERESTS_YAML` 省略可。
> **話題taxonomy の正本は interests.yaml**（design §3。zero-base に複製しない）。

## 3. まず手元でドライラン（送信せず中身確認）

```bash
# テーマ選定だけ確認
scripts/auto-research/pick-topic.sh

# 送信整形のドライラン（token不要）
DRY_RUN=1 scripts/auto-research/send-telegram.sh "テスト本文"
```

Claude セッションで実際のフローを試すなら:
```
/auto-research --dry-run
```
（送信せず、整形済みレポートを画面に出す）

## 4. 実配信テスト

token/chat_id を設定した状態で:
```
/auto-research
```
Telegram に「🔎 今日の深掘り: …」が届けば成功。

## 5. 毎日自動化（cron Routine）

この基盤の Routine（スケジュールトリガー）で `/auto-research` を毎日起動する。
- **cron**: 例 `0 22 * * *`（UTC 22:00 = JST 07:00）など好みの時刻。
- **起動先**: 毎回フレッシュセッション（リポジトリ＋上記環境変数が入っていること）。
- **プロンプト**: `/auto-research`

> Routine の作成はエージェントに「毎朝7時に /auto-research を回す Routine を作って」と頼めば設定できる。
> **前提**: 環境に `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` が入っていること（入っていないと自動で送信せず dry-run 相当で止まる）。

## コスト/安全（v1）

- 1日1本・**Understand 既定**（フル /think の15xトークンは rio が明示指示した時だけ）。
- **Notify型のみ**（報告だけ・不可逆操作・承認ゲートなし）。
- INDEX が育ったら `scripts/compact-workspace.sh`（既定dry-run）で定期コンパクション。

## トラブルシュート

| 症状 | 対処 |
|---|---|
| `bot can't initiate conversation` | 手順1-3。先に bot へ一度話しかける |
| 何も届かない | `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` 未設定 → dry-run で止まっている。env確認 |
| interests.yaml が見つからない | `INTERESTS_YAML` を指定 or `knowledge/interests.yaml` を置く |
| 毎回同じテーマ | INDEX に追記されているか確認（手順6の記録が効くと日々ずれる） |

## 次段（v2）
チャットの返信で「気になり」を投げる→profile更新、novelty厳密化、実装ドリフト警告、1日3回化。設計は `docs/autonomous-research-design.md` §9「v2以降」。
