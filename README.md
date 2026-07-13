# Zero-Base Thinking

ゼロベース思考でリサーチ・分析・提案を行う Claude Code プロジェクト。リサーチ → 技術設計（Codex連携） → Dev Ready Issue作成までを一気通貫で扱う。

`/think [テーマ]` が多段パイプライン（スコーピング、思考フレームワーク選択、並列 Deep Search、**claim単位の検証**、本質抽出、反論検証）を実行する。**LLM推論の非決定性とハルシネーションを抑える**ことを目的に設計されており、全ての事実主張に URL 付きソースを要求する。

## 成果物モード（終点を冒頭で固定）

「調査したら必ず提案・設計まで進む」を禁止する。テーマ受領時に**終点を宣言**し、`Phase 1.2` の計画承認で確定させる。宣言した終点より先へ勝手に進まない。

| モード | 終点 | 収集の広さ |
|--------|------|-----------|
| **Understand（理解）** | Phase 4 + 推論トレース | 絞る（Gemini + ChatGPT 中心） |
| **Decide（意思決定）** | Phase 5（提案 + judge） | 全ソース並列 |
| **Design（設計）** | Phase D（Codex設計） | 全ソース並列 |
| **Ship（実装準備）** | Phase I（Dev Ready Issue） | 全ソース並列 |

迷ったら Understand を既定にし、「Decide以上に上げますか?」と1問確認する（過剰調査の回避。マルチエージェントは約15xトークン）。

## ハルシネーション抑制の設計

LLM推論は非決定的で、一定確率で静かに誤る。ゼロにできるモデルは存在しない。本ハーネスはその上に検証層を重ねる。5原則（`.claude/skills/think/references/verification.md`）:

1. **ルールベースの claim 抽出** — 検証対象（数値・固有名詞・断定）は機械的に選ぶ。LLMの「重要そう」判断で選ばせない。
2. **cross-model 検証** — 重要claimと最終的な本質抽出は*異なるモデル*（Gemini / ChatGPT / Codex）で再確認する。*同一*モデルをN回多数決するのは偽の独立性として扱い、使わない。
3. **人間を最終検証者に固定** — 検証ループには上限がある。品質 `judge` が < 0.7 を2回付けたら、ループさせず人間（rio）に上げる。
4. **結論をrecallしない** — 過去の結論を事実として再利用しない（anchoring毒）。`workspace/INDEX.md` からは検証済みソースURLと行き止まりクエリのみを再利用する。
5. **残存不確実性を常に併記** — 「検証済み」ラベルは、残るリスクを隣に書かずには出さない（過信防止）。

> これらの選択は一次調査（Anthropic のコンテキストエンジニアリング & multi-agent system、Cognition "Don't Build Multi-Agents"、CoVe / Self-Consistency 論文、LLM-as-judge の位置バイアス研究）に基づき、ハーネス自身の counter-argument agent でストレステスト済み。2026-07 の第2次改善では GPT Researcher / STORM・Co-STORM / Anthropic multi-agent / Gemini・Perplexity Deep Research を実調査し、設計を裏取りした。詳細は `workspace/think-harness-modernization/` と `workspace/think-harness-redesign/`。

## セットアップ

### 前提

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/)（`gh auth login`）
- Node.js（MCPサーバー用）
- （任意）[Claude in Chrome 拡張](https://docs.anthropic.com/en/docs/claude-code) — ログイン必須ページの取得に使う

### MCPサーバー

**Deep Search MCP**（ユーザーレベル）と**補完MCP**（プロジェクトレベル）を使う。

#### Deep Search MCP

コアのリサーチパイプラインを駆動し、独立した **cross-model 検証者**も兼ねる:

| MCP | ツール | コスト |
|-----|------|------|
| `gemini-deepsearch` | `mcp__gemini-deepsearch__deep_search` | 無料（250回/日）・APIキー・ブラウザ不要 |
| `chatgpt` | `mcp__chatgpt__chatgpt_send_and_get_response` | ChatGPTサブスク（ブラウザ自動操作） |
| `perplexity-web` | `mcp__perplexity-web__perplexity_ask` | サブスク（Web版・APIキー不要） |
| `codex` | `mcp__codex__codex` | Codexサブスク — cross-model検証者 + Phase D設計 |

> 補足: API版 Perplexity Sonar MCP（`@perplexity-ai/mcp-server`）は**意図的に不使用**。クレジットが Pro サブスクと別会計で、バンドルクレジット枯渇後は 401 を返すため。ブラウザ/サブスクの `perplexity-web` を使う。Gemini（無料・API・ブラウザ不要）を主力の Deep Search ソースにする。

パイプライン: **Gemini + ChatGPT** を全軸で並列実行 → 重要claimと本質抽出は**異なるモデルで独立再検証**。

#### 任意・補完MCP

| MCP | ツール | 用途 |
|-----|------|-----|
| `grok` | `mcp__grok__search_posts` | X/Twitter 深掘り検索（日付・ハンドルフィルタ可） |
| `social-superpowers` | `twitter-search` / `reddit-search` | X + Reddit リアルタイム（HTTP・無料） |
| `claude-in-chrome` | `mcp__claude-in-chrome__*` | ログイン壁/JS重ページの取得（実ブラウザセッション・**メインagent限定**・ヘッドレス起動なし） |
| `github` | `mcp__github__*` | リポジトリ分析、Issue作成（Phase I） |
| `notion` | `mcp__notion__*` | 社内コンテキスト |

プロジェクトルートで `.mcp.json.example` から `.mcp.json` を作成する。

### ブラウザ取得の方針

ヘッドレスブラウザの自動起動は行わない。取得は次の順:

1. **既定 = WebFetch / 検索API**（大半はここで足りる）
2. **ログイン壁・JS重・403 のページのみ = Claude in Chrome**（実ログイン済みセッション。メインagentのみ実行。サブエージェントは `NEEDS_BROWSER` として返し、メインagentが取得する）
3. **Playwright は使わない**

### セットアップ確認

```bash
claude mcp list   # MCP が "Connected" と表示されること
```

## 使い方

```
/think [テーマ]
```

多段パイプラインを実行する:

0. **Recall** — `workspace/INDEX.md` を grep して関連する過去作業を探す。再利用するのは*ソースと行き止まりのみ*、結論は使わない
1. **Scoping** — MECE分解 + 思考フレームワーク選択 + 成果物モード仮決め
   - **1.2 ★調査計画の承認ゲート** — 収集を走らせる前に、軸/ソース/FW/モードを提示して承認を取る（手戻りを着手前に潰す）
2. **Research + claim検証** — クロスバリデーション、ルールベース claim 抽出 → CoVe方式のソース突合 → cross-model 再検証、Gap識別
3. **Deep Dive** — 事例分析 + 反響調査
4. **Synthesis** — 思考フレームワークのレンズ + **cross-model 合意**（一致=本質、相違=不確実と明記）
5. **提案**
   - **4.5 発散レーン** — 方針外OKの面白い脇道を根拠ベースで生成（judge非適用・provenance付き・要rio判断。Goしたものだけ深掘り）
   - **5.0 ★推論トレース** — 提案の前に「事実 → 解釈 → 論点 → 選択肢 ＋ 却下理由」の決定ログを必ず提示（いきなり提案を禁止）
   - 2案以上をメリデメ付きで → counter-argument（自己採点）→ **`judge` 品質ゲート**（ルーブリック0-1・順序入替2回・人間トリガー）→ `INDEX.md` に追記

全ての「検証済み」出力は残存不確実性を併記する。

### 任意の後続Phase

- **Phase D** — Codex との必須クロスバリデーションを伴う技術設計（Mermaid図）
- **Phase I** — Dev Ready GitHub Issue 作成（Phase D 完了が前提）

### 定期ベースライン計測

大きな変更の前に、過去の `workspace/*/research.md` から claim を約15件サンプリングして再検証し、*実際の*誤りの内訳（NOT_ALIGNED / PARTIAL過剰主張 / 単一ソース率）を計測する。汎用のハルシネーション統計でなく、自分のデータで設計を駆動する。`references/verification.md` P6 参照。

### 思考フレームワーク

Phase 1 でテーマに応じて1-2個を選ぶ:

| フレームワーク | 適する場面 |
|-----------|------|
| First Principles | テックスタック、アーキテクチャ設計 |
| Inversion | リスク分析、戦略判断 |
| Second-Order Effects | プラットフォーム選定、事業判断 |
| Hypothesis-Driven | 市場調査、ユーザー行動分析 |
| Systems Thinking | 組織・エコシステム分析 |
| Pre-mortem | プロジェクト計画、大きな意思決定 |

### リポジトリ分析モード

```
/think [テーマ] github.com/owner/repo
```

Phase 0（リポジトリ分析）を追加し、Phase 4 を Gap Analysis + ロードマップ提案に置き換える。

## 出力

結果は `workspace/{テーマ名}/` に保存される:

| ファイル | 内容 |
|------|------|
| `research.md` | 収集データ（ソース付き）+ Gapリスト（検証済み・残存不確実性併記） |
| `analysis.md` | 深掘り分析 + 発散レーン |
| `proposal.md` | 推論トレース + 最終提案（反論検証・judgeスコア付き） |
| `design.md` | 技術設計（Mermaid図・Phase D） |
| `workspace/INDEX.md` | Recall索引 — 検証済みソースURL + 失敗クエリ（結論は事実として recall しない） |

## Sub-Agents

| Agent | 役割 |
|-------|------|
| `deep-researcher` | Web/SNS の補完調査 |
| `case-analyzer` | 個別事例の深掘り |
| `social-scanner` | X/Reddit/はてブ の反響調査 |
| `source-verifier` | claim検証: ルールベース抽出 → CoVe方式のソース突合 → cross-model独立検証（grounded hallucination検出） |
| `counter-argument` | Devil's advocate（Inversion + Pre-mortem）。自己採点で弱い反論を除外 |
| `judge` | ルーブリック品質ゲート（0-1）。位置バイアス対策で順序入替2回・棄権許容・閾値未満で人間トリガー |
| `repo-analyzer` | GitHubリポジトリの機能/Issue/PR抽出 |

## カスタマイズ

`CONTEXT.md` に自社のコンテキスト（チーム規模・制約・優先度）を追記すると、提案が自社状況に合わせて調整される。
