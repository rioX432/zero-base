# Zero-Base Thinking Project

ゼロベース思考で網羅的調査→本質抽出→論理的提案を行う。

## 基本原則

1. **推測禁止**: 全主張にURL付きソース必須。ソースなき主張は書かない。不明は「不明」と明記
2. **ゼロベース**: 既存の前提を排除し、事実からボトムアップで結論を導く
3. **MECE**: 調査軸は漏れなくダブりなく設計
4. **ピラミッド原則**: 結論→根拠→データの順で構造化
5. **Generator-Critic**: 提案後に必ず反論検証（counter-argument agent）

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
  Phase 1: Scoping + 並列情報収集
  │  ├─ 調査設計
  │  ├─ Deep Search（Gemini + ChatGPT + Perplexity）
  │  ├─ SNSリアルタイム（social-superpowers + google-news-trends）
  │  └─ Grok X Search（APIキー設定時）
  │
  Phase 2: Research（結果統合 + 補完調査）
  │  ├─ Deep Search + SNS結果のクロスバリデーション
  │  ├─ deep-researcher で補完（Phase 1で不足した情報）
  │  └─ source-verifier で全URL検証
  │
  Phase 3: Deep Dive（深掘り分析）
  │  ├─ case-analyzer × N（並列）
  │  ├─ social-scanner（反響調査）
  │  └─ 必要時: 追加Deep SearchをMCP経由で自動実行
  │
  Phase 4: Synthesis（本質の特定）← メインAgentが実行
  │
  Phase 5: Proposal（提案 + 反論検証）
       └─ counter-argument で検証
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
  Phase 1: Scoping + 並列情報収集（競合・先行事例調査）
  │  ├─ 自リポジトリの領域に合わせた調査設計
  │  └─ Deep Search + SNSリアルタイム + Grok で並列実行
  │
  Phase 2-3: Research + Deep Dive（競合分析）
  │
  Phase 4: Gap Analysis（差分特定）
  │  ├─ 機能比較マトリクス
  │  ├─ ポジショニング分析（強み/弱み/機会/脅威）
  │  └─ 本質: 選ばれる理由 / 選ばれない理由
  │
  Phase 5: Roadmap Proposal（ロードマップ提案）
       ├─ 短期/中期/長期の優先度付き施策
       ├─ 2パターンのロードマップ
       └─ counter-argument で検証
```

★ = ユーザーとの対話ポイント

## 情報収集ソース

MCP経由で**自動実行**する。Phase 1 で全て同時並列実行。

### Deep Search（背景調査）
| MCP | コスト | 用途 |
|-----|--------|------|
| `mcp__gemini-deepsearch__deep_search` | 無料（250回/日） | メイン調査 |
| `mcp__chatgpt__chatgpt_send_and_get_response` | サブスク内（250回/月） | 並列調査・補完 |
| `mcp__perplexity-web__perplexity_ask` | ~$0.4-1.3/回 | 重要軸の補完（1テーマ最大3回） |

### SNSリアルタイム（最新情報）
| MCP | コスト | 用途 |
|-----|--------|------|
| `mcp__social-superpowers__twitter-search` | 無料 | X/Twitter + Reddit リアルタイム検索 |
| `mcp__google-news-trends__*` | 無料 | 最新ニュース + トレンド |
| `mcp__grok__search_posts` | $5/1,000回 | X特化の深い検索（日付・ハンドルフィルタ可） |

コスト管理: Gemini + ChatGPT + social-superpowers + google-news-trends で全軸並列実行（無料枠/サブスク内） → Perplexityは最重要軸のみ、Grokは必要時のみ

## Sub-Agents

| Agent | 役割 | Model |
|-------|------|-------|
| `repo-analyzer` | GitHubリポジトリの機能・Issue/PR・外部評価を収集 | sonnet |
| `deep-researcher` | Web検索・SNS検索でDeep Search結果を補完。収集者に徹する | sonnet |
| `case-analyzer` | 個別事例の詳細分析（成果・成功要因・反響） | sonnet |
| `social-scanner` | X/Reddit/はてブ/connpassでの反響・評判調査 | sonnet |
| `source-verifier` | 全URLの実在確認 + 主張との整合性チェック | sonnet |
| `counter-argument` | 提案に対する反論・論理飛躍・リスクの検証 | sonnet |

## 出力先

`workspace/{テーマ名}/` に保存:
- `repo-analysis.md` — リポジトリ分析結果・機能マップ（リポジトリ分析モード）
- `research.md` — 収集情報一覧（ソース付き）
- `analysis.md` — 深掘り分析
- `proposal.md` — 最終提案・ロードマップ（依頼者に見せるもの）

## 自社コンテキスト

提案に自社状況を反映する場合 → `CONTEXT.md` に記載。

## MCP（補完調査ツール）

| MCP | 用途 | 認証 |
|-----|------|------|
| WebSearch / WebFetch | 個別検索・URL取得 | 組み込み |
| social-superpowers | X/Twitter + Reddit 検索 | 不要 |
| google-news-trends | Google News + Trends | 不要 |
| grok | Grok X Search（X/Twitterリアルタイム検索） | xAI APIキー |
| playwright | ブラウザ自動操作 | 不要 |
| Notion | 社内情報検索 | 設定済み |
| github | GitHubリポジトリ分析（コード・Issue・PR） | gh CLI連携 |

## 品質基準

- 全事実主張にURL付きソース
- 提案は2案以上（比較可能）
- 各提案にメリット・デメリット・リスク
- source-verifier でURL実在確認済み
- counter-argument で反論検証済み
- 論理チェーン（事実→推論→結論）が第三者に説明可能
