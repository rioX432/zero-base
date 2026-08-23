# /think スキル Evaluation ハーネス

## 目的

「改善したつもりが実は劣化した」を防ぐ。Anthropic公式ガイド（[Agent Skills best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)）の Evaluation-Driven Development に準拠:

> Create evaluations BEFORE writing extensive documentation... 1. Identify gaps 2. Create evaluations 3. Establish baseline 4. Write minimal instructions 5. Iterate

感覚でなく、**過去に実際に起きた失敗/成功を再現テストとして固定化**し、スキルを修正するたびにこれらを再実行して比較する。

## 運用ルール

1. **新しい失敗が見つかったら、直す前に必ずeval化する**（`EVAL-XXX-*.md` を1件追加）。直してから「多分直った」で終わらせない。
2. 各evalは「入力（何が起きたか）」「期待される挙動」「実際に起きた挙動」「検出すべきライン（どのPhase/agentが捕まえるべきか）」「現状ステータス」を持つ。
3. **成功例（正しく検出できたケース）もevalとして残す**（回帰防止）。失敗例だけ集めると「直したら別の壊れ方をした」を見逃す。
4. スキルを変更したら、関連するeval群を目視で再確認する（自動実行の仕組みはまだ無い＝手動でのwalk-throughが前提）。
5. `status` は3段階: `未対応` / `部分対応(理由)` / `対応済み(方法・日付)`。

## Eval一覧

| ID | 名前 | 検出すべき問題 | ステータス |
|---|---|---|---|
| [EVAL-001](EVAL-001-websearch-summary-transcription.md) | WebSearch要約の未確認転記 | 一次ページを開かずに要約文の数値を転記する | 対応済み(2026-08-23・要継続観察) |
| [EVAL-002](EVAL-002-generator-critic-confirmation-device.md) | Generator-Criticが確認装置化 | 反論が全て改良に吸収され棄却が0件になる | 部分対応(2026-08-23・健全性チェック追加、未実運用検証) |
| [EVAL-003](EVAL-003-fabricated-citation-detection.md) | 捏造引用の検出（成功例） | judgeが捏造引用をveto:trueで正しく検出 | 対応済み(既存judge設計で機能・回帰防止用) |
| [EVAL-004](EVAL-004-cross-model-shared-origin.md) | cross-model一致が同一originを隠す | 異モデルが同じ二次情報プールに収束し「独立した一致」に見える | 対応済み(2026-08-23・要継続観察) |

## 現状の限界（★2026-08-23 Codex再レビューで指摘）

このharnessは現状「eval catalog（再現手順を書いた文書集）」であり、Anthropic公式が言う意味での実行可能なeval harness（固定fixture・runner・grader・baseline結果ログ）にはなっていない:
- 実行コマンド・runnerが無い（人間/agentが手順を読んで手動で再現する前提）
- 固定入力fixtureが無い（EVAL-001のようにライブWebページ参照だと内容が変わりうる）
- 機械的なpass/fail判定（grader）が無い
- 「対応済み」は「文書を修正した」ことを意味し、「実際に再実行して直ったことを確認した」ことを意味しない（要注意）

**フルオートメーション化は別タスクとして意識的に見送る**（このスキルはプロンプト駆動でありCIのような自動実行環境を持たないため、構築には別途設計が要る）。当面は、次に該当シナリオに遭遇したセッションで手動walk-throughして確認する運用とする。

## 次に追加すべきeval候補

- rioが指摘した「調査意図の履き違え」（新規技術調査で顕著）— 具体例が1件（Piik/Gorest）のみで再現条件が未確定、材料が増え次第追加
- recallタイミングの不適切さ — 1回の指摘のみ、具体例待ち
