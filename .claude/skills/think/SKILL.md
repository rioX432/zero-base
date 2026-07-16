---
name: think
description: テーマを受け取り、ゼロベース思考で網羅的調査→本質抽出→論理的提案を実行する。技術設計やIssue作成まで一気通貫で対応。
when_to_use: |
  Researching a topic, analyzing competitors, evaluating tech stacks,
  creating proposals, technical design with architecture diagrams,
  creating dev-ready GitHub issues from research findings
argument-hint: "[テーマ・依頼内容（リポジトリURLを含む場合はリポジトリ分析モードで実行）]"
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Agent, WebSearch, WebFetch, AskUserQuestion, mcp__claude_ai_Notion__notion-fetch, mcp__claude_ai_Notion__notion-search, mcp__gemini-deepsearch__deep_search, mcp__perplexity-web__perplexity_search, mcp__perplexity-web__perplexity_ask, mcp__social-superpowers__*, mcp__grok__*, mcp__codex__codex, mcp__codex__codex-reply, mcp__claude-in-chrome__*, mcp__github__create_issue, mcp__github__add_issue_comment, mcp__github__list_issues
effort: max
---

# /think — ゼロベース思考オーケストレータ

`$ARGUMENTS` について調査・分析・提案を行う。

テンプレートは `${CLAUDE_SKILL_DIR}/references/` を参照:
- `references/templates.md` — リサーチ・提案テンプレート
- `references/design-templates.md` — 設計・Issue テンプレート
- `references/thinking-frameworks.md` — 思考フレームワーク定義
- `references/verification.md` — **検証/反ハルシネーションプロトコル（claim検証・cross-model・judge・recall・残存不確実性）**
- `references/knowledge.md` — **知識レイヤー（recall 2レイヤー分離・`knowledge/profile.md` 運用）と workspace ライフサイクル（肥大の抑制）**
- `references/profile-template.md` — `knowledge/profile.md` の初期テンプレート

## モード判定

### 入力モード（What）
`$ARGUMENTS` にGitHubリポジトリURL（`github.com/...`）が含まれる場合:
→ **リポジトリ分析モード**（Phase 0 + Phase 4をGap Analysisに変更）

含まれない場合:
→ **通常モード**（Phase 0をスキップ）

### 成果物モード（Where to stop）★終点を冒頭で固定する

「調査したら必ず提案・設計まで進む」を禁止する。テーマ受領時に**終点を宣言し、Phase 1.2の計画承認でrioに確定させる**。以降、宣言した終点より先へ勝手に進まない（`feedback_scope_per_request` 準拠）。

| モード | 終点 | Phase 1 収集の広さ（effort scaling） | 発散4.5 | 提案/judge |
|--------|------|-----------------------------------|---------|-----------|
| **Understand（理解）** | Phase 4 + 推論トレース | 絞る（Gemini + Codex(web検索)。SNS/Grok/Perplexityは要時のみ） | 任意（面白ければ提示） | なし（本質と論点整理まで） |
| **Decide（意思決定）** | Phase 5 | 全ソース並列 | あり | 2案 + judge |
| **Design（設計）** | Phase D | 全ソース並列 | あり | 2案 + judge + Codex設計 |
| **Ship（実装準備）** | Phase I | 全ソース並列 | あり | + Dev Ready Issue |

- 迷ったら **Understand** を既定にして「Decide以上に上げますか?」と1問確認する。過剰調査（Anthropic実測: マルチエージェントは約15xトークン）を避ける。
- モードは途中で昇格できる（Understand→Decide 等）。**降格・飛び越し（Understandなのに勝手にIssue作成）は禁止**。

## フロー概要

```
事前: Recall（workspace/INDEX.md grep。結論はrecallしない／ソース+失敗クエリのみ）
Phase 0: Repo Analysis（リポジトリ分析モードのみ）
Phase 1: Scoping（分解・FW選択・成果物モード仮決め）
  └─ Phase 1.2: ★調査計画の提示と承認（軸/ソース/FW/モード/effort）→ rio承認後に収集を走らせる
Phase 2: Research + claim検証（ルールベース抽出→CoVe方式→cross-model）
Phase 3: Deep Dive（深掘り分析）
Phase 3.5: ★ ユーザーとの調査結果確認
Phase 4: Synthesis（本質の特定 + cross-model 合意）
Phase 4.5: 発散レーン（Divergence｜方針外OKの面白い脇道。judge非適用・要rio判断）
Phase 5: Proposal
  ├─ 5.0: ★推論トレース（事実→解釈→論点→選択肢。提案の前に必ず提示）
  ├─ 提案 + 反論検証 + judge品質ゲート + INDEX追記
  │     └─ <0.7×2回 → ★人間確認（最終検証者は人間）
  ├─ ［Understand］終了（本質+トレースまで）
  ├─ ［Decide］終了（提案まで）
  └─ → Phase D: 詳細設計（Codex必須連携）
        ├─ ［Design］終了（設計まで）
        └─ → Phase I: Dev Ready Issue作成（設計完了が前提）［Ship］
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
3. **`workspace/INDEX.md`（＋あれば `workspace/INDEX-archive.md`）を recall（レイヤーA=テーマ事実）** — テーマ関連語で `grep`。**結論はrecallしない**（anchoring毒）。再利用するのは「検証済みソースURL」と「失敗クエリ/行き止まり/既知の罠」のみ。過去結論は「前回の仮説（要再検証）」としてのみ扱い、今回ゼロベースで再検証する。※INDEX.mdはサイズバジェット（既定150エントリ）超過分が INDEX-archive.md へローテーションされるので、古い件は archive 側も grep する（詳細: `references/verification.md` P6 / `references/knowledge.md`）
4. **`knowledge/profile.md` を読む（レイヤーB=rioプロファイル）** — 存在すれば読む。関心領域・判断の好み・既知の制約/文脈・地雷。**これは「テーマ結論」ではないので recall してよい**（anchoring毒の対象外）。使うのは「提案の当てはめ」と「提示形式の最適化」だけで、**テーマの真偽の再導出には使わない**。2レイヤー分離の詳細: `references/knowledge.md`。無ければ `references/profile-template.md` から実体化を検討。
5. `workspace/{近いテーマ}/` — 必要なら本文も参照（レイヤーA同様の規律）
6. **Notion等の社内情報** — 既存の施策・実績・計画の早期把握

---

## Phase 0: Repo Analysis（リポジトリ分析モードのみ）

`repo-analyzer` agent で対象リポジトリの現状を収集 → 機能マップ作成 → **ユーザーに確認してからPhase 1へ**。

詳細はCLAUDE.mdのPhase 0セクション参照。

---

## Phase 1: Scoping + 並列情報収集

### 1.0 Ambition pass（理想解を先に描く｜コスト観のAI再基準化）★収束の前に発散

**Scopingで削る前に、まず理想解を描く。** LLMには実装難度で選択肢を刈る既知バイアス（pragmatism/status-quo/anchoring・[ICSE2026](https://arxiv.org/pdf/2601.08045)）がある。これを構造で殺す。

1. **コスト基準線を宣言**: 「rio + AIエージェント（Fable/Codex/Claude Code）で日〜週単位」を前提に置く（build-vs-buy反転・AI製は従来の10–20%コスト・[blink.new](https://blink.new/blog/build-vs-buy-software-2026)）。「重そう」で案を落とさない。
2. **理想解を先に生成**: 「制約ゼロなら何が最良か」を2〜3行で言語化。既存解が無い箇所は**「妥協」でなく「作る」を既定**にする。
3. **ownership/保守は持ち込まない**: 「どう作るか・保守・運用コスト・build≠own」は **Phase D（設計）で人間（rio）が舵取りする領域**。リサーチ〜提案では理想解の探索に集中し、build工数/保守を理由に案を刈らない。工数の心配は設計段階まで棚上げする。
4. この理想解を 1.2 計画に持ち込み、**Scopingが理想解の要素を黙って落としていないか**を承認時にrioが確認できるようにする。

**批評器（counter-argument/judge）は後段（Phase 5）限定**。Phase 1〜4では実装難度で刈らない。

### 1.1 テーマの分解

`$ARGUMENTS` から What/Why/Who/Output/Constraints を特定。曖昧な場合はAskUserQuestionで確認（1回、最大3問）。テーマをMECEに調査軸へ分解。
あわせて**成果物モード（Understand/Decide/Design/Ship）を仮決め**する（「モード判定」参照）。判断材料が薄いテーマは Understand を既定にする。

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

### 1.2 ★調査計画の提示と承認（着手前ゲート）

**収集を走らせる前に、調査計画をチャットで提示し rio の承認を取る**（Gemini Deep Research の collaborative planning 型。実測で高信頼な設計）。無駄な調査と手戻りを着手前に潰すのが目的。

提示する内容（簡潔な表1枚）:
- **調査軸**（MECE分解の結果）
- 各軸に**使うソース**（Gemini/Codex/Perplexity/SNS/Grok のどれを回すか。全てブラウザレス）
- **思考フレームワーク**（1.1aの選択）
- **成果物モード**（1.1の仮決め）と**終点**
- **effort**（並列ソース数・deep-researcher並列数の見積り）

→ rio が **承認 / 軸やモードを編集** → 確定してから 1.3 へ。
※ ただし「軽い事実確認1件」で明らかに計画不要なテーマは、そう告げて 1.3 へ直行してよい（ゲートを儀式化しない）。

### 1.3 並列情報収集（MCP経由・自動）

承認された計画に従い、**モードのeffort scalingに応じた広さで**並列実行する（Layer間に依存関係なし）:

- **Understand**: Layer 1 を Gemini + Codex に絞る（SNS/Grok/Perplexity は「この軸に本当に要る」場合のみ）。単純テーマに全ソース総動員しない（Anthropic effort scaling: 単純タスクへの過剰並列はトークンの無駄）。
- **Decide / Design / Ship**: 下記 Layer 1-3 を全軸並列。

**★調査経路はブラウザレス**: ヘッドレスブラウザを立てる ChatGPT web MCP は使わない。OpenAI系モデルでの調査・cross-model は **Codex（`web_search=live`）** が担う（サブスク内・ブラウザ不要。実測で live 検索が機能することを確認済み）。

**Layer 1: Deep Search（全てブラウザレス）**
```
mcp__gemini-deepsearch__deep_search(query="{調査クエリ}", effort="high")
mcp__codex__codex(prompt="Use live web search: {調査クエリ}. Cite a source URL for every claim. If web search is unavailable, say so instead of answering from memory.", config={"web_search": "live"}, sandbox="read-only", approval-policy="never")
mcp__perplexity-web__perplexity_ask(query="{調査クエリ}")  # 最重要軸のみ（セッションHTTP・ブラウザレス）
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
- **Gemini + Codex + social-superpowers で全軸並列**（無料枠/サブスク内・ブラウザレス）
- Perplexity: Web版（perplexity-web・サブスク利用/APIキー不要、最重要軸のみ、1テーマ最大3回）。API版(@perplexity-ai/mcp-server)はサブスクと別会計のため不使用
- Grok: $5/1,000回（重要なX情報がある軸のみ）

---

## Phase 2: Research（結果統合 + 補完調査）

### ★ブラウザ取得の階層（点2・全Phase共通）

ヘッドレスブラウザ（Playwright等）の自動起動をやめ、以下の順で取得する（業界標準も検索API + URL fetch 主体。常設ブラウザ自動操作は例外）:

1. **既定 = WebFetch / 検索API**（Gemini・Codex(web_search=live)・Perplexity・social-superpowers・grok）。全てブラウザレス。取得の大半はここで足りる。
2. **ログイン壁・JS重・403 のページのみ = Claude in Chrome**（`mcp__claude-in-chrome__*`。rio の実ログイン済みセッションを使う。別プロセスのヘッドレス起動が不要）。**メインagent（自分）だけが実行**する — 対話認証MCPはサブagent（source-verifier/social-scanner）では使えないため、サブagentは当該URLを `NEEDS_BROWSER` として返し、メインagentが取得・再投入する。
3. **Playwright は使わない**（撤去済み）。

Claude in Chrome 利用時は複数ブラウザが接続され得るので、初回に接続ブラウザをrioに選ばせる（`list_connected_browsers`）。ダイアログを誘発する操作は避ける。

### 手順

1. Deep Search結果を読み込み（Geminiは JSON → Read、他は直接テキスト）
2. **クロスバリデーション**: 複数ソース一致 → 高、単一ソース → 中、矛盾 → WebSearchで追加確認
3. **補完調査**: `deep-researcher` agent で不足情報を補完
4. **claim検証**: `source-verifier` agent で検証（`references/verification.md` P1-P2）。
   - **ルールベースで claim を機械抽出**（数値/固有名詞/断定）。「重要だから」でLLMに選ばせない。
   - URL実在だけでなく**主張を伏せてソース内容を先に要約→突合**（grounded hallucination検出）。
   - 提案根拠になる重要claim・数値は **cross-model**（Gemini/Codex/Grok の異なるモデル系統）で独立再検証。不一致は「論争あり」と明記。
   - **裏取り本数の必須化**（実測で単一ソース率93%が最大の弱点）: 提案の根拠主張は**単一ソース禁止・最低2本の独立裏取り**。取れなければ「裏取り不足」と明示し主柱にしない。
   - **scope check**（実測でPARTIAL過剰主張33%）: 主張の細部（数値/固有名詞/最上級）がソースに**個別に明記されているか**を1つずつ照合。超過分は削るか別ソースで裏取り。
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
2. **異なるモデル**（Gemini/Codex/Grok のいずれか。ブラウザレス）に同じ材料で本質を出させる。
3. **一致点＝本質**として採用、**相違点＝「不確実」と明記**。
4. 同一モデルでN回回すのは独立性が偽物なので**しない**（cross-modelで独立性を作る）。

### 4.3 品質ループバック

Phase 4 の分析中に**重大な情報ギャップ**が発見された場合（フレームワーク適用で「この情報がないと結論が出せない」と判明した場合）、Phase 2-3 に戻って追加調査を行う。Phase 5 に進む前にギャップを埋める。

---

## Phase 4.5: 発散レーン（Divergence）

**収束（Phase 5の2案）に入る前に、方針からズレてもよい「面白い脇道」を意図的に生成する。** /think は構造的にコンバージェント（counter-argument で刈り、judge で採点）で、放っておくと面白い逸脱案が淘汰される。これへのカウンターウェイト。STORM/Co-STORM の多視点生成が下敷き。

**適用**: Decide/Design/Ship で標準実行。Understand では「面白い脇道があれば」任意提示。
**Build-the-gap を一級化**: 調査で「既存に無い/どれも中途半端」と判明した箇所は、**それを自作する案**を発散の中核に据える（Phase 1.0 Ambition pass の理想解と接続）。工数・保守の心配は持ち込まない（Phase Dで人間が舵取り）。

### 4.5.1 根拠ベースで出す（思いつき禁止）

思いつきの逸脱ではなく、**すでに集めた情報**から生成する:

1. **廃棄プールの活用（Co-STORM モデレーター型）**: research.md / analysis.md で**収集したが本質（Phase 4）に使わなかった情報**（未引用の断片・脇道・矛盾・異分野の事例）を拾い出す。「トピックに関連するが本流の問いから遠い」ものほど良い。
2. **視点選出（STORM 型）**: 隣接領域・逆張り・異分野アナロジーの視点を **2〜3個** 列挙し、各視点から「rioの想定とは少しズレるが面白い案」を1つずつ出す。
3. **Build-the-gap（作る案を一級化）**: 調査で判明した「既存に無い/中途半端」なGap（research.mdの不足リスト）について、**それを自作する案**を発散案として必ず1つ立てる。AI速度前提（日〜週）でスコープを描き、「既存で妥協」を既定にしない。provenance＝どのGapに対応するかを明記。**build工数/保守での却下はしない**（設計段階の判断）。

### 4.5.2 出力と扱い

- **発散案 3件程度**。各案に **provenance タグ**を付す（どの捨てた情報／どの視点から生まれたか、research.md の該当箇所リンク）。
- **judge にはかけない**（収束ゲートで殺さない）。**counter-argument も任意**。
- 「**面白い脇道（方針外・要rio判断）**」としてチャット提示。★rio が Go を出したものだけ、Phase 3 相当の深掘りに回す。Go が出なければ記録だけ残して先へ。
- `workspace/{テーマ名}/analysis.md` に「発散レーン」節として追記（捨てずに残す＝次回 recall のソースになる）。

**→ チャットで発散案とprovenanceを提示し、深掘りする案をrioに選ばせる。**

---

## Phase 5: Proposal（提案 + 反論検証）

### 5.0 ★推論トレース（調査 → 提案の橋渡し・点1の核心）

**いきなり2案を出さない。** 提案の前に、**調査結果からどう考えてその案に至ったか**を1枚の決定ログで必ず提示する（rio が明示的に求めた部分）。Co-STORM の「情報の系譜を追跡可能にする」発想。

| # | 事実（research.md該当） | 解釈（so-what） | 立ち上がる論点 | 分岐した選択肢 |
|---|---------------------|---------------|-------------|-------------|
| 1 | {検証済みの事実+リンク} | {だから何が言えるか} | {その結果どんな問いが立つか} | {A案/B案/却下案} |

- 各行の事実は **Phase 2 で検証済み**のものに限る（未検証の推測から論点を立てない）。
- **「なぜ他案でないか（却下理由）」も同じ表に書く**。収束の過程を隠さない。
- Phase 4 の本質（cross-model 合意）と、Phase 4.5 で Go が出た発散案があればそれも、この表に接続する。
- `proposal.md` の冒頭に置き、**チャットでこの表を説明してから**提案本体に入る。

### 5.1 提案生成

1. **2案生成**（通常）/ **2パターンのロードマップ**（リポジトリ分析）
2. `counter-argument` agent で反論検証（自己採点で的外れな反論を除外したもの）
3. **生き残った反論を提案に反映して改訂**（Generator-Criticループ）。提案比較表を作成
4. **judge 品質ゲート**: `judge` agent でルーブリック採点（`references/verification.md` P4）。
   - 順序入替2回採点・棄権許容。
   - **停止条件（人間トリガー）**: 総合<0.7が2回連続 → rioに確認を上げる。ループバック上限2回。**最終検証者は人間**。
5. `workspace/{テーマ名}/proposal.md` に保存。**「検証済み」「推奨」には残存不確実性を併記**。
6. **INDEX.md追記（レイヤーA）**: `workspace/INDEX.md` に1行追記（テーマ/当時の暫定結論(要再検証)/検証済ソースURL/失敗クエリ/既知の罠）。**結論はrecall対象にしない規律を守る**。
7. **profile.md 更新（レイヤーB）**: そのセッションで **新たに判明した rio の安定属性**（判断の好み・恒常的制約・地雷）があれば `knowledge/profile.md` を更新する。**マージ & 重複排除**（append-onlyにしない）・**推測で書かない**・**2回以上観測した傾向のみ記録**（1発言で人格を決めない）。追記でよいのは「更新ログ」節のみ。詳細: `references/knowledge.md`。新属性が無ければ何もしない。

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
- **過去の結論をrecallして確定事実扱いしない**: anchoring毒。ソースと失敗クエリのみ再利用（レイヤーA）
- **profile（レイヤーB）でテーマの結論を歪めない**: `knowledge/profile.md` は「提案の当てはめ・提示形式」専用。「rioが好きだから結論もそれ」にしない。テーマの真偽はゼロベースで再導出する
- **profile を append-only の澱にしない**: 更新はマージ&重複排除。推測で人格を刻まない（2回以上観測した傾向のみ）。rio が直接編集できる前提を壊さない
- **workspace を昇華前に剪定しない / 昇華済みを放置して肥大させない**: INDEX追記（昇華）を済ませてから raw をアーカイブ。`scripts/compact-workspace.sh`（既定dry-run）で定期コンパクション。アーカイブ（`_archive/`）と最終成果物は消さない
- **「検証済み」を残存不確実性なしで書かない**: 過信を生む
- **提案の根拠を単一ソースで主柱にしない**: 最低2本の独立裏取り。取れなければ「裏取り不足」と明示（実測: 単一ソース率93%）
- **主張の細部をソース範囲を超えて書かない**: 数値・固有名詞・最上級はソースに個別明記を確認（実測: PARTIAL過剰主張33%）
- **宣言した成果物モードの終点を越えて勝手に進まない**: Understandなのに提案・設計・Issueを作らない。昇格はrio承認で（`feedback_scope_per_request`）
- **調査計画の承認（Phase 1.2）を飛ばして収集を走らせない**: 軽い事実確認1件を除き、着手前に軸/ソース/モードを提示する
- **いきなり提案を出さない**: Phase 5.0 の推論トレース（事実→解釈→論点→選択肢＋却下理由）を提案の前に必ず提示する
- **発散案（Phase 4.5）を judge/counter-argument で殺さない**: 収束ゲートは提案本体にのみ適用。発散は「要rio判断」で残す
- **発散を思いつきでやらない**: 廃棄プール（収集したが未使用の情報）と根拠ベースの視点選出から出す
- **実装難度を理由にリサーチ〜提案の選択肢を削らない**: コスト基準線は「rio+AIで日〜週」（build-vs-buy反転）。既存に無ければ「作る」を既定にする（Phase 1.0 Ambition pass）
- **アイディア出し・リサーチ・提案に ownership/保守/運用コストを持ち込まない**: 「どう作るか・保守負担・build≠own」は **Phase D（設計）で人間（rio）が舵取り**する領域。リサーチ段階で工数の心配をして案を萎ませない
- **ヘッドレスブラウザを自動起動しない**: WebFetch/検索API を既定にし、ログイン壁のみ Claude in Chrome（メインagent）。Playwright も ChatGPT web MCP も使わない（OpenAI系は Codex `web_search=live` でブラウザレス）
- **壊れた/退化した収集結果から synthesis しない**: `deep_search` 等の返り値が空・退化（英数字比率が極端に低い等の破損）していないかを使う前に検査する。破損時は1回リトライ or 別ソース（WebSearch/Codex）へフォールバック。ゴミを黙って結論に流し込まない（実測: Gemini `answer` が英数字81/65,615文字で破損した事例あり）

## 品質チェック（最終確認）

- [ ] 成果物モード（Understand/Decide/Design/Ship）を冒頭で宣言し、終点を越えずに進めたか
- [ ] Phase 1.2 の調査計画承認をrioから得たか（軽い1件を除く）
- [ ] Phase 1.0 Ambition pass で理想解を先に描き、実装難度で選択肢を削っていないか（ownership/保守を持ち込んでいないか）
- [ ] （Decide以上）Phase 4.5 発散レーンを実行し、provenance付きで「面白い脇道」を提示したか
- [ ] （Decide以上）Phase 4.5 で Build-the-gap（既存に無い→作る案）を一級の選択肢として提示したか
- [ ] Phase 5.0 推論トレース（事実→解釈→論点→選択肢＋却下理由）を提案の前に提示したか
- [ ] ブラウザ取得を階層化したか（WebFetch既定→Claude in Chromeはメインagent限定→Playwright不使用）
- [ ] 全事実主張にURL付きソースがあるか
- [ ] source-verifier で claim検証済みか（ルールベース抽出→CoVe→cross-model）
- [ ] grounded hallucination（NOT_ALIGNED）/ cross-model不一致を洗い出したか
- [ ] **提案の根拠主張は2本以上の独立裏取りがあるか**（単一ソースは「裏取り不足」と明示）
- [ ] **主張の細部（数値/固有名詞/最上級）がソース範囲を超えていないか**（scope check）
- [ ] 「検証済み」に残存不確実性を併記したか
- [ ] Synthesisを cross-model で合意形成したか（1サンプル確定でないか）
- [ ] judge 品質ゲートを通過したか（<0.7×2回なら人間確認）
- [ ] INDEX.md に追記したか（結論はrecall対象にしない規律を守ったか｜レイヤーA）
- [ ] 新たに判明した rio の安定属性があれば `knowledge/profile.md` をマージ更新したか（推測で書かず・重複排除｜レイヤーB）
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
- `workspace/INDEX.md` — Recall索引（レイヤーA・検証済ソースURL+失敗クエリ。結論は事実としてrecallしない）

テーマ横断の個人知識（レイヤーB）は `workspace/` の外に置く:
- `knowledge/profile.md` — rioプロファイル（関心領域・判断の好み・制約/文脈・地雷）。gitignore・会話ローカル限定。初期テンプレは `references/profile-template.md`。

workspace の肥大抑制は `scripts/compact-workspace.sh`（既定dry-run・`--apply`で実行）。詳細規律は `references/knowledge.md`。
