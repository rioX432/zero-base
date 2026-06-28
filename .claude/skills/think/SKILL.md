---
name: think
description: テーマを受け取り、ゼロベース思考で網羅的調査→本質抽出→論理的提案を実行する。技術設計やIssue作成まで一気通貫で対応。
when_to_use: |
  Researching a topic, analyzing competitors, evaluating tech stacks,
  creating proposals, technical design with architecture diagrams,
  creating dev-ready GitHub issues from research findings
argument-hint: "[テーマ・依頼内容（リポジトリURLを含む場合はリポジトリ分析モードで実行）]"
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Agent, WebSearch, WebFetch, AskUserQuestion, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-search, mcp__gemini-deepsearch__deep_search, mcp__perplexity-web__perplexity_search, mcp__perplexity-web__perplexity_ask, mcp__chatgpt__chatgpt_send_and_get_response, mcp__social-superpowers__*, mcp__grok__*, mcp__codex__codex, mcp__codex__codex-reply, mcp__github__create_issue, mcp__github__add_issue_comment, mcp__github__list_issues
effort: max
---

# /think — ゼロベース思考オーケストレータ

`$ARGUMENTS` について調査・分析・提案を行う。

テンプレートは `${CLAUDE_SKILL_DIR}/references/` を参照:
- `references/templates.md` — リサーチ・提案テンプレート
- `references/design-templates.md` — 設計・Issue テンプレート
- `references/thinking-frameworks.md` — 思考フレームワーク定義
- `references/verification.md` — **検証/反ハルシネーションプロトコル（claim検証・cross-model・judge・recall・残存不確実性）**

## モード判定

`$ARGUMENTS` にGitHubリポジトリURL（`github.com/...`）が含まれる場合:
→ **リポジトリ分析モード**（Phase 0 + Phase 4をGap Analysisに変更）

含まれない場合:
→ **通常モード**（Phase 0をスキップ）

## フロー概要

```
事前: Recall（workspace/INDEX.md grep。結論はrecallしない／ソース+失敗クエリのみ）
Phase 0: Repo Analysis（リポジトリ分析モードのみ）
Phase 1: Scoping + 並列情報収集
Phase 2: Research + claim検証（ルールベース抽出→CoVe方式→cross-model）
Phase 3: Deep Dive（深掘り分析）
Phase 3.5: ★ ユーザーとの調査結果確認
Phase 4: Synthesis（本質の特定 + cross-model 合意）
Phase 5: Proposal（提案 + 反論検証 + judge品質ゲート + INDEX追記）
  │     └─ <0.7×2回 → ★人間確認（最終検証者は人間）
  ├─ 終了（リサーチのみ）
  └─ → Phase D: 詳細設計（Codex必須連携）
        ├─ 終了（設計のみ）
        └─ → Phase I: Dev Ready Issue作成（設計完了が前提）
```

全Phase共通: 「検証済み」には必ず**残存不確実性**を併記する（過信防止）。

## 報告ルール（★全Phase共通）

**各Phase完了時、ファイル保存に加えて必ずチャットで以下を説明する:**
- 何がわかったか（調査結果の要点）
- なぜその判断をしたか（根拠）
- 次に何をするか

ファイル作成のみで報告を省略しない。ユーザーは全ファイルを読む前提で作業していない。

## 事前読み込み

1. `CLAUDE.md` — 原則確認
2. `CONTEXT.md` — 自社コンテキスト（存在すれば）
3. **`workspace/INDEX.md` を recall** — テーマ関連語で `grep`。**結論はrecallしない**（anchoring毒）。再利用するのは「検証済みソースURL」と「失敗クエリ/行き止まり/既知の罠」のみ。過去結論は「前回の仮説（要再検証）」としてのみ扱い、今回ゼロベースで再検証する（詳細: `references/verification.md` P6 / `workspace/INDEX.md` の recall規律）
4. `workspace/{近いテーマ}/` — 必要なら本文も参照（同上の規律）
5. **Notion等の社内情報** — 既存の施策・実績・計画の早期把握

---

## Phase 0: Repo Analysis（リポジトリ分析モードのみ）

`repo-analyzer` agent で対象リポジトリの現状を収集 → 機能マップ作成 → **ユーザーに確認してからPhase 1へ**。

詳細はCLAUDE.mdのPhase 0セクション参照。

---

## Phase 1: Scoping + 並列情報収集

### 1.1 テーマの分解

`$ARGUMENTS` から What/Why/Who/Output/Constraints を特定。曖昧な場合はAskUserQuestionで確認（1回、最大3問）。テーマをMECEに調査軸へ分解。

### 1.1a 思考フレームワーク選択

テーマの性質に応じて `references/thinking-frameworks.md` から**1-2個**を選択する。Phase 4（Synthesis）でこのフレームワークのレンズを通して分析する。

| テーマの性質 | 推奨フレームワーク |
|------------|-----------------|
| 技術選定・アーキテクチャ設計 | First Principles |
| リスク分析・戦略判断 | Inversion |
| プラットフォーム選定・事業判断 | Second-Order Effects |
| 市場調査・ユーザー行動分析 | Hypothesis-Driven |
| 組織・エコシステム分析 | Systems Thinking |
| プロジェクト計画・大きな意思決定 | Pre-mortem |

選択したフレームワークをチャットでユーザーに共有する（「今回はFirst PrinciplesとInversionの視点で分析します」等）。

### 1.2 並列情報収集（MCP経由・自動）

**全てを同時に並列実行する**（Layer間に依存関係なし）:

**Layer 1: Deep Search**
```
mcp__gemini-deepsearch__deep_search(query="{調査クエリ}", effort="high")
mcp__chatgpt__chatgpt_send_and_get_response(message="Search the web: {調査クエリ}. Include source URLs.")
mcp__perplexity-web__perplexity_ask(query="{調査クエリ}")  # 最重要軸のみ
```

**Layer 2: SNSリアルタイム**
```
mcp__social-superpowers__twitter-search(query="{キーワード}")
mcp__social-superpowers__reddit-search(query="{キーワード}")
```

**Layer 3: Grok X Search** ※XAI_API_KEY設定時のみ
```
mcp__grok__search_posts(query="{キーワード}")
```

#### コスト管理
- **Gemini + ChatGPT + social-superpowers で全軸並列**（無料枠/サブスク内）
- Perplexity: Web版（perplexity-web・サブスク利用/APIキー不要、最重要軸のみ、1テーマ最大3回）。API版(@perplexity-ai/mcp-server)はサブスクと別会計のため不使用
- Grok: $5/1,000回（重要なX情報がある軸のみ）

---

## Phase 2: Research（結果統合 + 補完調査）

1. Deep Search結果を読み込み（Geminiは JSON → Read、他は直接テキスト）
2. **クロスバリデーション**: 複数ソース一致 → 高、単一ソース → 中、矛盾 → WebSearchで追加確認
3. **補完調査**: `deep-researcher` agent で不足情報を補完
4. **claim検証**: `source-verifier` agent で検証（`references/verification.md` P1-P2）。
   - **ルールベースで claim を機械抽出**（数値/固有名詞/断定）。「重要だから」でLLMに選ばせない。
   - URL実在だけでなく**主張を伏せてソース内容を先に要約→突合**（grounded hallucination検出）。
   - 提案根拠になる重要claim・数値は **cross-model**（Gemini/ChatGPT/Codex）で独立再検証。不一致は「論争あり」と明記。
5. **Gap識別**: 調査軸ごとに「不足している情報」を明示的にリストアップ → Phase 3の入力にする
6. 統合して `workspace/{テーマ名}/research.md` に保存（Gap リスト含む）。**「検証済み」には必ず「残存不確実性」を併記**（過信防止）。

**→ チャットで収集結果 + 不足情報 + NOT_ALIGNED/論争ありを共有。**

---

## Phase 3: Deep Dive（深掘り分析）

1. Phase 2から重要事例を3〜7件選定
2. `case-analyzer` agent を**並列起動**
3. 反響調査が必要な場合: `social-scanner` agent（複数手法を組み合わせ）
4. 情報不足時: 追加Deep Search/SNS検索をMCP経由で自動実行
5. `workspace/{テーマ名}/analysis.md` に保存

---

## Phase 3.5: ★ ユーザーとの調査結果確認

**Phase 4に進む前に必須。**

1. 調査結果を**表形式でチャットに共有**
2. 「0件」「反響なし」等の否定的結論はユーザーに検証を依頼
3. フィードバックを受けて修正・追加調査

---

## Phase 4: Synthesis（本質の特定）

**メインAgent（自分）が実行。Sub-Agentに委譲しない。**

### 4.1 フレームワーク適用

Phase 1.1a で選択した思考フレームワークのレンズを通して分析する。`references/thinking-frameworks.md` の該当フレームワークの出力形式に従う。

### 4.2 本質の抽出（cross-model 合意で1回勝負を避ける）

通常モード: 共通パターン・差別化要因・失敗パターン・前提条件を抽出 → 本質を1〜3文で定義。
リポジトリ分析モード: 機能比較マトリクス + ポジショニング分析 + 本質特定。

**非決定性対策（`references/verification.md` P3）**: 本質抽出を1サンプルで確定しない。
1. メインAgent(Claude)が本質案を出す。
2. **異なるモデル**（Gemini/ChatGPT/Codex のいずれか）に同じ材料で本質を出させる。
3. **一致点＝本質**として採用、**相違点＝「不確実」と明記**。
4. 同一モデルでN回回すのは独立性が偽物なので**しない**（cross-modelで独立性を作る）。

### 4.3 品質ループバック

Phase 4 の分析中に**重大な情報ギャップ**が発見された場合（フレームワーク適用で「この情報がないと結論が出せない」と判明した場合）、Phase 2-3 に戻って追加調査を行う。Phase 5 に進む前にギャップを埋める。

---

## Phase 5: Proposal（提案 + 反論検証）

1. **2案生成**（通常）/ **2パターンのロードマップ**（リポジトリ分析）
2. `counter-argument` agent で反論検証（自己採点で的外れな反論を除外したもの）
3. **生き残った反論を提案に反映して改訂**（Generator-Criticループ）。提案比較表を作成
4. **judge 品質ゲート**: `judge` agent でルーブリック採点（`references/verification.md` P4）。
   - 順序入替2回採点・棄権許容。
   - **停止条件（人間トリガー）**: 総合<0.7が2回連続 → rioに確認を上げる。ループバック上限2回。**最終検証者は人間**。
5. `workspace/{テーマ名}/proposal.md` に保存。**「検証済み」「推奨」には残存不確実性を併記**。
6. **INDEX.md追記**: `workspace/INDEX.md` に1行追記（テーマ/当時の暫定結論(要再検証)/検証済ソースURL/失敗クエリ/既知の罠）。**結論はrecall対象にしない規律を守る**。

**→ チャットで提案の要点・推奨理由・残存不確実性・judgeスコアを説明。**

テーマが技術設計を必要とする場合 → Phase D へ。そうでなければここで完了。

---

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
- **チャットで設計の全体像、主要な判断とその理由を説明**

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

## Anti-Patterns（明示的に禁止する行為）

- **URLを発明しない**: 存在を確認できないURLを引用に使わない。source-verifierで検証する
- **counter-argumentをスキップしない**: 時間がなくても必ず実行する
- **ユーザー提供データで自己主張を循環検証しない**: 外部ソースで裏取りする
- **「0件」を安易に結論しない**: 複数手法でクロスチェックしてから結論する
- **前提を検証せず受け入れない**: Phase 1.1aで選択したフレームワークで前提を問い直す
- **情報ギャップを無視してPhase 5に進まない**: Phase 4.3のループバックを実行する
- **検証対象を「重要だから」でLLMに選ばせない**: ルールベースで機械抽出する（`references/verification.md` P1）
- **同一モデルのN回多数決を「検証」と呼ばない**: 系統的バイアスが消えない。cross-modelで独立性を作る
- **過去の結論をrecallして確定事実扱いしない**: anchoring毒。ソースと失敗クエリのみ再利用
- **「検証済み」を残存不確実性なしで書かない**: 過信を生む

## 品質チェック（最終確認）

- [ ] 全事実主張にURL付きソースがあるか
- [ ] source-verifier で claim検証済みか（ルールベース抽出→CoVe→cross-model）
- [ ] grounded hallucination（NOT_ALIGNED）/ cross-model不一致を洗い出したか
- [ ] 「検証済み」に残存不確実性を併記したか
- [ ] Synthesisを cross-model で合意形成したか（1サンプル確定でないか）
- [ ] judge 品質ゲートを通過したか（<0.7×2回なら人間確認）
- [ ] INDEX.md に追記したか（結論はrecall対象にしない規律を守ったか）
- [ ] 推測と事実が区別されているか
- [ ] counter-argument の反論検証を通過しているか
- [ ] 未取得データに理由が明記されているか
- [ ] Phase 1.1aで選択した思考フレームワークをPhase 4で適用したか
- [ ] Phase 2のGap識別で挙げた不足情報がPhase 3で解消されたか
- [ ] ユーザーとの調査結果確認（Phase 3.5）を実施したか
- [ ] **各Phaseでチャットによる説明を行ったか**
- [ ] （Phase D実施時）Codexによる設計検証を実施したか
- [ ] （Phase I実施時）IssueがDev Ready状態か（着手に必要な情報が全て記載されているか）

## 出力の原則

### レポートの構造

1. **サマリー（5行以内）** — 結論 + 根拠の要点 + リファレンスリンク
2. **結論と根拠（表形式）** — 各結論に「なぜそう言えるか」のデータとリンクを併記
3. **詳細データ** — 各事例の詳細、生データ

### ルール
- 全ての結論・主張にリファレンスリンクを併記（表の中にリンクを入れる）
- 表形式を優先。横幅が大きい場合はファイル出力
- 未取得データには理由を明記（「—」を使わない）
- 図はMermaid記法を使用（GitHub Markdown対応、トークン効率が散文の3-6倍）

## 出力先

`workspace/{テーマ名}/` に保存:
- `repo-analysis.md` — リポジトリ分析結果（リポジトリ分析モード）
- `research.md` — 収集情報一覧（ソース付き）
- `analysis.md` — 深掘り分析
- `proposal.md` — 最終提案
- `design.md` — 詳細設計（Phase D実施時）
