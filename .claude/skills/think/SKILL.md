---
name: think
description: テーマを受け取り、ゼロベース思考で網羅的調査→本質抽出→論理的提案を実行する。技術設計やIssue作成まで一気通貫で対応。
when_to_use: |
  Researching a topic, analyzing competitors, evaluating tech stacks,
  creating proposals, technical design with architecture diagrams,
  creating dev-ready GitHub issues from research findings
argument-hint: "[テーマ・依頼内容（リポジトリURLを含む場合はリポジトリ分析モードで実行）]"
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Agent, WebSearch, WebFetch, AskUserQuestion, mcp__notion__notion-fetch, mcp__notion__notion-search, mcp__gemini-deepsearch__deep_search, mcp__perplexity-web__perplexity_search, mcp__perplexity-web__perplexity_ask, mcp__social-superpowers__*, mcp__grok__*, mcp__codex__codex, mcp__codex__codex-reply, mcp__claude-in-chrome__*, mcp__github__create_issue, mcp__github__add_issue_comment, mcp__github__list_issues
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

### 入力モード（What）— 「対象」と「問いの種類」を別々に決める

**(a) 対象**: `$ARGUMENTS` にGitHubリポジトリURL（`github.com/...`）が含まれる → **リポジトリ分析モード**（Phase 0 + Phase 4をGap Analysisに変更）。含まれなければ Phase 0 をスキップ。

**(b) 問いの種類（profile）**: 対象とは**独立に**、問いの性質で profile を選ぶ。収集ソース・検証の作法・発散量・評価軸が変わる。

| profile | 該当する問い | 実測比率(164テーマ) | 状態 |
|---|---|---|---|
| `tech-selection` | 技術・アーキテクチャの選定/検証 | 47% | 未実装（既定で動く） |
| `ideation` | 事業・プロダクト戦略、成長アイディア | 22% | 未実装（既定で動く） |
| **`self-audit`** | **自分のリポジトリ・設定・ハーネスを実査して直す** | **21%** | **実装済** |
| `advocacy` | 登壇・発信（CFP/スライド/記事） | 6% | 未実装（既定で動く） |
| `casual` | 軽い事実確認・実務判断 | 4% | 未実装（既定で動く） |

**★ `self-audit` の取りこぼしに注意**: このカテゴリは **GitHub URL を伴わないことが多く**、放置すると (a) の判定で通常モードに入り、**一次ソースが自分のコードなのに外部Web収集パイプラインに流れる**。**一次ソースが自リポである問いは、URLの有無にかかわらず `self-audit` を選ぶ。**

**手順:**
1. **Phase 1.1 で profile を判定する。迷ったら既定値に倒さず rio に問う**（分類精度は未検証のため）。
2. **Phase 1.2 の承認表に profile を明記し、rio の承認と同時に凍結する**（成果物ができてから自分に有利なルーブリックを選ぶ *rubric shopping* の防止）。
3. 承認後、`${CLAUDE_SKILL_DIR}/references/profiles/_shared.md` と `${CLAUDE_SKILL_DIR}/references/profiles/{profile}.md` を **明示的に Read する**（参照先は列挙しただけでは読み込まれない）。
4. **run contract を記録**: `profile_id / rubric_id / output_mode / 既定値から外した項目と理由`。
   **同一セッションで2回目の /think を回すときは再判定・再記録する**（前回の profile が context に残って引き継がれるため）。

未実装の profile は `_shared.md` の既定値で従来どおり動く（挙動は変わらない）。

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
  ├─ 5.0: ★調査レポート（背景→調査結果→考察=推論トレース→まとめ）をチャット提示
  │     └─ ★rio承認ゲート: 提案に進むか判断を仰ぐ（承認まで提案本体を生成しない）
  ├─ 5.1: 提案 + 反論検証 + judge品質ゲート + INDEX追記
  │     └─ <0.7×2回 → ★人間確認（最終検証者は人間）
  ├─ ［Understand］終了（本質+トレースまで）
  ├─ ［Decide］終了（提案まで）
  └─ → Phase D: 詳細設計（Codex必須連携）
        ├─ ［Design］終了（設計まで）
        └─ → Phase I: Dev Ready Issue作成（設計完了が前提）［Ship］
```

全Phase共通: 「検証済み」には必ず**残存不確実性**を併記する（過信防止）。

> **allowed-tools の効き方（公式仕様・誤解しやすい）**: frontmatter の `allowed-tools` は「このスキルを起動した**ターンの間だけ**、許可を求めずに使えるツール」であり、**次のメッセージを送ると失効する**。/think は承認ゲートが4つあり必ず複数ターンにまたがるため、**2ターン目以降はこの事前承認が効かない**。恒久的に許可プロンプトを避けたいツールは `.claude/settings.local.json` 側に置くこと。`Bash` はここに含めていない（無条件許可のリスクを避けるため。実行自体は都度承認で可能）。

## 報告ルール（★全Phase共通）

**各Phase完了時、ファイル保存に加えて必ずチャットで以下を説明する:**
- 何がわかったか（調査結果の要点）
- なぜその判断をしたか（根拠）
- 次に何をするか

ファイル作成のみで報告を省略しない。ユーザーは全ファイルを読む前提で作業していない。

**チャットが正・ファイルは控え（全Phaseの報告に適用）**: Phase 0 機能マップ / 2 収集結果 / 3.5 調査結果 / 4 本質 / 4.5 発散案 / 5.0 調査レポート / 5.1 提案 / D 設計 / I Issue概要 — いずれの報告・確認も**内容そのものをチャット本文に書く**。「詳細は research.md / proposal.md / design.md 参照」とファイルへ丸投げしない（rio にファイルを見に行かせない）。特に★確認ポイントでは **rio が判断に必要な材料を全てチャットに揃える**。ファイルは記録・recall 用の控え。

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

### 5.0 ★調査レポート + 提案着手の承認ゲート

**いきなり2案を出さない。提案本体は rio の承認が出るまで生成しない**（このターンで提案まで書き切るのは禁止）。Phase 5 に入ったら、まず以下の構成の**レポートをチャットに出力**し、rio に「提案に進んでよいか」の判断を仰ぐ。

レポート構成（チャット出力・4節）:

1. **背景** — このテーマを調査した目的・問い・成果物モード（何を判断するための調査だったか）
2. **調査結果** — Phase 2-3 で検証済みの主要ファクトを表形式で（ソースリンク付き。NOT_ALIGNED/論争あり/裏取り不足も明記）
3. **考察（推論トレース）** — 調査結果からどう考えたかの決定ログ。Co-STORM の「情報の系譜を追跡可能にする」発想:

   | # | 事実（research.md該当） | 解釈（so-what） | 立ち上がる論点 | 分岐した選択肢 |
   |---|---------------------|---------------|-------------|-------------|
   | 1 | {検証済みの事実+リンク} | {だから何が言えるか} | {その結果どんな問いが立つか} | {A案/B案/却下案} |

   - 各行の事実は **Phase 2 で検証済み**のものに限る（未検証の推測から論点を立てない）。
   - **「なぜ他案でないか（却下理由）」も同じ表に書く**。収束の過程を隠さない。
   - Phase 4 の本質（cross-model 合意）と、Phase 4.5 で Go が出た発散案があればそれも、この表に接続する。
4. **まとめ** — 本質（Phase 4）の再掲 + 提案に進む場合に何を2案として出す想定か（方向性だけ。提案本体は書かない）

**チャットが正・ファイルは控え**: レポート全文（4節）をチャット本文に書く。「詳細は proposal.md 参照」とファイルへ丸投げしない（rio にファイルを見に行かせない）。

レポート提示後、**AskUserQuestion で rio に確認**する: 「このまま提案に進む / 考察・論点を修正してから進む / 追加調査に戻る / ここで終了（Understand相当に降格）」。承認が出てから 5.1 へ進む。

このレポート（1〜3節）は `proposal.md` の冒頭にもそのまま置く。

### 5.1 提案生成（★5.0 の rio 承認後のみ）

1. **2案生成**（通常）/ **2パターンのロードマップ**（リポジトリ分析）
2. `counter-argument` agent で反論検証（自己採点で的外れな反論を除外したもの）
3. **生き残った反論を提案に反映して改訂**（Generator-Criticループ）。提案比較表を作成
4. **judge 品質ゲート**: `judge` agent で採点（`references/verification.md` P4）。**judge は評価器であって判定者ではない。**
   - **層1（証拠ゲート）は常に走る**。層2は Phase 1.2 で凍結した `rubric_id` を**呼び出し時に渡した場合のみ**走る（渡さなければ層1のみ）。
   - **judge に閾値を渡さない**（プロンプトにも参照文書にも数値を書かない）。judge はスコアと観察のみを返す。
   - **合否判定はこちら（メインagent）が行う**: 総合<0.7が2回連続 → rioに確認を上げる。ループバック上限2回。**最終検証者は人間**。
   - **`veto: true` が返ったら、スコアの高低にかかわらず即修正**（捏造引用・NOT_ALIGNED・単一ソース主柱の未明示）。平均で相殺しない。
   - **初回スコアと改訂後スコアを分けて記録する**（張り付きが anchoring 由来か revise-until-pass 由来かを後から切り分けるため）。
5. `workspace/{テーマ名}/proposal.md` に保存。**「検証済み」「推奨」には残存不確実性を併記**。
6. **INDEX.md追記（レイヤーA）**: `workspace/INDEX.md` に1行追記（テーマ/当時の暫定結論(要再検証)/検証済ソースURL/失敗クエリ/既知の罠）。**結論はrecall対象にしない規律を守る**。
7. **profile.md 更新（レイヤーB）**: そのセッションで **新たに判明した rio の安定属性**（判断の好み・恒常的制約・地雷）があれば `knowledge/profile.md` を更新する。**マージ & 重複排除**（append-onlyにしない）・**推測で書かない**・**2回以上観測した傾向のみ記録**（1発言で人格を決めない）。追記でよいのは「更新ログ」節のみ。詳細: `references/knowledge.md`。新属性が無ければ何もしない。

**→ チャットで提案の要点・推奨理由・残存不確実性・judgeスコアを説明。**

テーマが技術設計を必要とする場合 → Phase D へ。そうでなければここで完了。

---

## Phase D / Phase I（設計・Issue化）

**Design / Ship モードのときのみ**、`${CLAUDE_SKILL_DIR}/references/phase-design-ship.md` を読んで実行する。
要点だけ再掲: **Phase D は Codex との共同必須**（`mcp__codex__codex` で独立検証 → クロスバリデーション表 → design.md）。**Phase I は Phase D 完了が前提**。

## Anti-Patterns と品質チェック

禁止事項の一覧と最終チェックリストは `${CLAUDE_SKILL_DIR}/references/quality-gates.md` にある。
**成果物を出す直前に必ず読む。** 特に頻出の3つだけここに置く:
- **いきなり提案を出さない**（5.0 の承認ゲートを飛ばさない）
- **実装難度・工数を理由にリサーチ〜提案の選択肢を削らない**（原則8）
- **「検証済み」を残存不確実性なしで書かない**

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
