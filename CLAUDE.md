# Zero-Base Thinking Project

ゼロベース思考で網羅的調査→本質抽出→論理的提案を行う。リサーチ→設計→Issue作成まで一気通貫で対応。

## 基本原則

1. **推測禁止**: 全主張にURL付きソース必須。ソースなき主張は書かない。不明は「不明」と明記
2. **ゼロベース**: 既存の前提を排除し、事実からボトムアップで結論を導く
3. **MECE**: 調査軸は漏れなくダブりなく設計
4. **ピラミッド原則**: 結論→根拠→データの順で構造化
5. **Generator-Critic**: 提案後に必ず反論検証（counter-argument agent）
6. **チャット報告**: 各Phase完了時にファイル保存+チャットで要点を説明。ファイル作成のみで終わらない
7. **非決定性の抑制**（`references/verification.md`）: ①検証対象は「重要だから」でLLMに選ばせず**ルールベース機械抽出** ②検証は**cross-model**で独立性を作る（同一モデルN回多数決は無効） ③検証の入れ子は**人間（rio）を最終検証者に固定**（無限ループ禁止） ④過去結論はrecallしない（anchoring毒）ソースと失敗クエリのみ ⑤**「検証済み」には残存不確実性を常に併記**（過信防止）

## Skill

| コマンド | 用途 |
|---------|------|
| `/think [テーマ]` | テーマ起点でゼロベース調査→分析→提案を一気通貫実行 |
| `/think [テーマ] github.com/...` | リポジトリ分析モード: 自リポジトリの競争力分析→ロードマップ提案 |

## ワークフロー

### 通常モード

```
/think テーマ
  │
  ★成果物モードを冒頭で宣言（Understand/Decide/Design/Ship）＝終点を固定。越えて進まない
  │
  Phase 0.5: Recall（workspace/INDEX.md を grep）
  │  └─ ★結論はrecallしない。ソースURL+失敗クエリのみ再利用
  │
  Phase 1: Scoping（分解・FW選択・モード仮決め）
  │  └─ Phase 1.2: ★調査計画の提示と承認（軸/ソース/FW/モード/effort）
  │       └─ rio承認後に収集を走らせる（Gemini collaborative planning 型）
  │  ├─ Deep Search（Gemini + Codex(web_search=live) + perplexity-web、全てブラウザレス）※Understandは絞る（effort scaling）
  │  ├─ SNSリアルタイム（social-superpowers）
  │  └─ Grok X Search（APIキー設定時）
  │
  Phase 2: Research + claim検証
  │  ├─ ブラウザ取得は階層化: WebFetch/検索API 既定 → ログイン壁のみ Claude in Chrome（メインagent）→ Playwright不使用
  │  ├─ クロスバリデーション + deep-researcher で補完
  │  └─ source-verifier: ルールベース抽出→CoVe方式→cross-model独立検証
  │       （grounded hallucination/論争を検出、残存不確実性を併記）
  │
  Phase 3: Deep Dive（case-analyzer × N 並列 / social-scanner）
  │
  Phase 3.5: ★ ユーザーとの調査結果確認
  │
  Phase 4: Synthesis（本質の特定）← メインAgent
  │  └─ cross-model 合意（一致=本質 / 相違=不確実と明記。同一モデルN回はしない）
  │
  Phase 4.5: 発散レーン（Divergence｜方針外OKの面白い脇道）
  │  ├─ 廃棄プール（未使用情報）+ STORM型 視点選出で根拠ベースに生成
  │  └─ judge非適用・provenance付き・★要rio判断（Goしたものだけ深掘り）
  │
  Phase 5: Proposal
  │  ├─ 5.0: ★推論トレース（事実→解釈→論点→選択肢＋却下理由）を提案の前に必ず提示
  │  ├─ counter-argument（自己採点で的外れ除外）→ 反論を反映し改訂
  │  ├─ judge: ルーブリック採点（順序入替2回・棄権許容）
  │  │    └─ <0.7×2回 → ★rio確認（人間が最終検証者・ループ上限2回）
  │  └─ INDEX.md に追記（結論はrecall対象外の規律）
  │
  ├─ ［Understand］終了（本質+推論トレースまで。提案なし）
  ├─ ［Decide］終了（提案まで）
  └─ → Phase D: 詳細設計（Codex必須連携）［Design］
        └─ → Phase I: Dev Ready Issue作成［Ship］
```

### リポジトリ分析モード

```
/think テーマ github.com/owner/repo
  │
  Phase 0: Repo Analysis（自リポジトリ理解）
  │  ├─ repo-analyzer でコード・機能・Issue/PR分析
  │  ├─ 機能マップ作成
  │  └─ ★ ユーザーに機能マップを確認
  │
  Phase 1-3: 競合・先行事例調査
  │
  Phase 4: Gap Analysis（差分特定）
  │
  Phase 5: Roadmap Proposal（ロードマップ提案）
  │
  ├─ 終了（リサーチのみ）
  └─ → Phase D → Phase I（設計・Issue作成が必要な場合）
```

★ = ユーザーとの対話ポイント

## 情報収集ソース

MCP経由で**自動実行**する。Phase 1 で全て同時並列実行。

### Deep Search（背景調査）
| MCP | コスト | 用途 |
|-----|--------|------|
| `mcp__gemini-deepsearch__deep_search` | 無料（250回/日） | メイン調査 |
| `mcp__codex__codex`（`config={"web_search":"live"}`） | サブスク内 | 並列調査・補完 + cross-model（OpenAI系・ブラウザレス。ChatGPT web MCPの代替） |
| `mcp__perplexity-web__perplexity_ask` | サブスク内（Web版・APIキー不要） | 重要軸の補完（1テーマ最大3回） |

### SNSリアルタイム（最新情報）
| MCP | コスト | 用途 |
|-----|--------|------|
| `mcp__social-superpowers__twitter-search` | 無料 | X/Twitter + Reddit リアルタイム検索 |
| `mcp__grok__search_posts` | $5/1,000回 | X特化の深い検索（日付・ハンドルフィルタ可） |

コスト管理: Gemini + Codex + social-superpowers で全軸並列実行（無料枠/サブスク内・ブラウザレス） → Perplexityは最重要軸のみ、Grokは必要時のみ

## Sub-Agents

| Agent | 役割 | Model |
|-------|------|-------|
| `repo-analyzer` | GitHubリポジトリの機能・Issue/PR・外部評価を収集 | sonnet |
| `deep-researcher` | Web検索・SNS検索でDeep Search結果を補完。収集者に徹する | sonnet |
| `case-analyzer` | 個別事例の詳細分析（成果・成功要因・反響） | sonnet |
| `social-scanner` | X/Reddit/はてブ/connpassでの反響・評判調査 | sonnet |
| `source-verifier` | claim検証（ルールベース抽出→CoVe方式→cross-model独立検証）。grounded hallucination検出 | sonnet |
| `counter-argument` | 提案に対する反論・論理飛躍・リスクの検証（自己採点で的外れを除外） | sonnet |
| `judge` | 成果物をルーブリックで0-1採点する品質ゲート。順序入替2回・棄権許容・人間トリガー | sonnet |

## 出力先

`workspace/{テーマ名}/` に保存:
- `repo-analysis.md` — リポジトリ分析結果・機能マップ（リポジトリ分析モード）
- `research.md` — 収集情報一覧（ソース付き）
- `analysis.md` — 深掘り分析
- `proposal.md` — 最終提案・ロードマップ
- `design.md` — 詳細設計・Mermaid図（Phase D実施時）

## Phase D: 詳細設計（Codex必須連携）

技術設計（シーケンス、アーキテクチャ、テックスタック選定等）は**必ずCodexと共同で実施**する。

1. **Claude起案**: リサーチ結果からアーキテクチャ案 + Mermaid図
2. **Codex検証（必須）**: `mcp__codex__codex` で設計案を送付し独立検証
3. **クロスバリデーション**: Claude vs Codex の判断差分を解決
4. **保存**: `design.md` に Mermaid図・設計判断ログ含め保存

## Phase I: Dev Ready Issue作成

**Phase D完了が前提。** 設計内容を丁寧にIssue本文に記載し、開発者がすぐ着手可能な状態にする。

Issue本文に含める情報:
- 背景・目的（リサーチ参照）
- 設計概要（Mermaid図）
- 技術スタック・実装方針
- 受け入れ基準（Acceptance Criteria）
- テスト方針・見積もり

## 自社コンテキスト

提案に自社状況を反映する場合 → `CONTEXT.md` に記載。

## MCP（補完調査ツール）

| MCP | 用途 | 認証 |
|-----|------|------|
| WebSearch / WebFetch | 個別検索・URL取得 | 組み込み |
| social-superpowers | X/Twitter + Reddit 検索 | 不要 |
| grok | Grok X Search（X/Twitterリアルタイム検索） | xAI APIキー |
| claude-in-chrome | ログイン壁/JS重ページの取得（rio実セッション。**メインagentのみ**・ヘッドレス起動なし） | Chrome拡張 |
| Notion | 社内情報検索 | 設定済み |
| github | GitHubリポジトリ分析（コード・Issue・PR） | gh CLI連携 |
| codex | OpenAI Codex（設計検証・ベストプラクティスチェック） | Codex CLI |

## 品質基準

- **成果物モードを冒頭で宣言**（Understand/Decide/Design/Ship）し終点を越えない
- **Phase 1.2 で調査計画をrio承認**してから収集（軽い1件を除く）
- **Phase 5.0 推論トレース**（事実→解釈→論点→選択肢＋却下理由）を提案の前に提示 ＝「いきなり提案」の禁止
- **（Decide以上）Phase 4.5 発散レーン**をprovenance付きで提示（judge非適用・要rio判断）
- **ブラウザ取得は階層化**（WebFetch既定→Claude in Chromeはメインagent限定→Playwright不使用）
- 全事実主張にURL付きソース
- 提案は2案以上（比較可能）
- 各提案にメリット・デメリット・リスク
- **source-verifier で claim検証済み**（ルールベース抽出→CoVe方式→cross-model独立検証）
- **grounded hallucination（NOT_ALIGNED）・cross-model不一致を洗い出し済み**
- **提案の根拠主張は2本以上の独立裏取り**（単一ソースは「裏取り不足」と明示。実測: 単一ソース率93%が最大の弱点）
- **主張の細部はソース範囲内**（数値/固有名詞/最上級を個別照合。実測: PARTIAL過剰主張33%）
- **「検証済み」に残存不確実性を併記**（過信防止）
- **Synthesisを cross-model で合意形成**（1サンプル確定でない）
- counter-argument で反論検証済み（自己採点で的外れ除外）
- **judge 品質ゲート通過**（<0.7×2回なら人間確認・最終検証者は人間）
- **INDEX.md に追記**（結論はrecall対象にしない規律を遵守）
- 論理チェーン（事実→推論→結論）が第三者に説明可能
- **各Phaseでチャットによる説明を実施**
- **（Phase D実施時）Codexによる設計検証済み**
- **（Phase I実施時）IssueがDev Ready状態**
