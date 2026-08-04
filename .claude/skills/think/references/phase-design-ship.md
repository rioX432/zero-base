# Phase D / Phase I — 詳細設計とIssue化

> `SKILL.md` から分離（Anthropic公式: SKILL.md は500行未満に保ち、詳細は別ファイルへ）。
> **Design / Ship モードのときにのみ読む。** Understand / Decide では読み込まない。

## Phase D: 詳細設計（Codex必須連携）

**リサーチ結果をもとに技術設計を行う場合に実行。**
コードの設計・詳細設計（シーケンス、アーキテクチャ、テックスタック選定等）は**必ずCodexと共同で実施**する。

テンプレートは `references/design-templates.md` を参照。

### D.1 Claude起案

リサーチ結果から設計案を策定:
- アーキテクチャ案をMermaid図で可視化（システム構成図 / シーケンス図 / コンポーネント図）
- 技術選定の根拠をリサーチ結果にリンク
- 設計判断ログ（何を・なぜ・どの選択肢から選んだか）

### D.2 Codex検証（必須）

`mcp__codex__codex` で設計案をCodexに送付し、独立検証を受ける:

```
mcp__codex__codex(
  prompt="以下の設計案を検証してください。ベストプラクティス・設計パターンの観点から問題点、代替案、リスクを指摘してください。\n\n{設計案}",
  developer-instructions="You are a senior architect reviewing a technical design. Focus on: (1) design pattern correctness, (2) scalability concerns, (3) tech stack fitness, (4) implementation feasibility. If a target repository is provided, read the actual codebase to validate assumptions.",
  cwd="{対象リポジトリのパス（あれば）}",
  sandbox="read-only"
)
```

Codexの指摘に対して `mcp__codex__codex-reply` で対話しながら設計を詰める。

### D.3 クロスバリデーション

| 判断ポイント | Claude案 | Codex案 | 最終決定 | 根拠 |
|-------------|---------|---------|---------|------|

差分がある箇所は根拠を突き合わせて解決。

### D.4 保存と報告

- `workspace/{テーマ名}/design.md` に保存（Mermaid図・設計判断ログ含む）
- **チャットで設計の全体像、主要な判断とその理由を説明** — Mermaid図・D.3クロスバリデーション表・判断ログを**チャット本文に載せる**。「design.md 参照」への丸投げ禁止

Issue作成が必要な場合 → Phase I へ。

---

## Phase I: Dev Ready Issue作成

**Phase D（詳細設計）が完了していることが前提。**

テンプレートは `references/design-templates.md` の「Dev Ready Issue」を参照。

### I.1 Issue分割

設計を実装可能な単位に分割。各Issueが独立して着手可能なサイズにする。

### I.2 Issue本文の作成

各Issueに以下を含める:
- **背景・目的**: リサーチ結果への参照
- **設計概要**: Mermaid図（アーキテクチャ・シーケンス）
- **技術スタック・依存関係**
- **実装方針**: ファイル単位の変更内容
- **受け入れ基準（Acceptance Criteria）**: チェックリスト形式
- **テスト方針**
- **参考リンク**: リサーチソース・設計ドキュメント
- **見積もり**: 工数・複雑度

### I.3 Issue作成

`mcp__github__create_issue` でIssueを作成。

### I.4 報告

**チャットでIssue一覧と各Issueの概要を説明。**

---
