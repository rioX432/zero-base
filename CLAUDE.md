# Zero-Base Thinking Project

ゼロベース思考で網羅的調査→本質抽出→論理的提案を行う。リサーチ→設計→Issue作成まで一気通貫で対応。

## 基本原則

1. **推測禁止**: 全主張に**検証可能なprovenance**必須（Web主張はURL付きソース、自リポ主張はfile:line＋再現コマンド＝self-audit profile）。ソースなき主張は書かない。不明は「不明」と明記（★2026-08-23修正: 以前「全主張にURL」と書いており、self-audit profile（`references/profiles/self-audit.md`）の「local-repo file:lineが一次証拠」という原則と矛盾していた）
2. **ゼロベース**: 既存の前提を排除し、事実からボトムアップで結論を導く
3. **MECE**: 調査軸は漏れなくダブりなく設計
4. **ピラミッド原則**: 結論→根拠→データの順で構造化
5. **Generator-Critic**: 提案後に必ず反論検証（counter-argument agent）
6. **チャット報告**: 各Phase完了時にファイル保存+チャットで要点を説明。ファイル作成のみで終わらない
7. **非決定性の抑制**（`references/verification.md`）: ①検証対象は「重要だから」でLLMに選ばせず**ルールベース機械抽出** ②**独立性はモデル系統でなくorigin系統で判定**（同一モデルN回多数決はもちろん、異モデルでも同じ検索結果に収束すれば独立でない。origin_id＝発行主体+原データ+版日付が異なるかで判定し、cross-modelは一次ソース発見・解釈比較の補助に留める。★2026-08-23改訂・[EVAL-004](.claude/skills/think/evals/EVAL-004-cross-model-shared-origin.md)） ③検証の入れ子は**人間（rio）を最終検証者に固定**（無限ループ禁止） ④過去結論はrecallしない（anchoring毒）ソースと失敗クエリのみ**（＝レイヤーA。ただし「rioの嗜好・文脈」＝レイヤーBはrecall可。原則9参照）** ⑤**「検証済み」には残存不確実性を常に併記**（過信防止）
8. **コスト観のAI再基準化**: 実装難度を理由に**アイディア出し・リサーチ・提案の段階で選択肢を削らない**（LLMのpragmatism/status-quo/anchoringバイアス対策・[ICSE2026](https://arxiv.org/pdf/2601.08045)）。基準線は「rio + AIエージェント（Fable/Codex/Claude Code）で日〜週単位」（build-vs-buyは反転済み・AI製は従来の10–20%コスト・[blink.new](https://blink.new/blog/build-vs-buy-software-2026)）。既存解が無ければ「妥協」でなく**「作る」を既定**とする。**ownership/保守/どう作るかは Phase D（設計）で人間（rio）が舵取りする領域**であり、リサーチ〜提案には**持ち込まない**（[Cheap Prototype, Expensive Maintenance](https://www.vccafe.com/cheap-prototype-expensive-maintenance/) の論点は設計段階で扱う。工数はリサーチ段階の選択の門にしない）
9. **知識レイヤーの分離と衛生**（`references/knowledge.md`）: 蓄積するローカル資産を2レイヤーに分ける。**レイヤーA=テーマ事実/結論**（`workspace/INDEX.md`・各テーマ）は原則7④の通り結論recall禁止。**レイヤーB=rioプロファイル**（`knowledge/profile.md`＝関心領域・判断の好み・制約/文脈・地雷）は「人物の安定属性」でありrecall可。ただしBは**「提案の当てはめ・提示形式」専用でテーマの真偽を歪めない**。Bの更新は**マージ&重複排除**（append-only禁止・推測禁止・2回以上観測した傾向のみ）。**workspaceは昇華（INDEX追記）後に`scripts/compact-workspace.sh`でコンパクション**し、無限肥大を防ぐ（アーカイブ・最終成果物は消さない）

## Skill

| コマンド | 用途 |
|---------|------|
| `/think [テーマ]` | テーマ起点でゼロベース調査→分析→提案を一気通貫実行 |
| `/think [テーマ] github.com/...` | リポジトリ分析モード: 自リポジトリの競争力分析→ロードマップ提案 |

## ワークフロー

### 通常モード

★冒頭で**成果物モードを宣言**（Understand/Decide/Design/Ship）＝終点を固定し、越えて進まない。

```
0.5 Recall → 1 Scoping（1.0 Ambition pass ／ ★1.2 調査計画の承認）→ 1.3 並列収集
 → 2 Research+claim検証 → 3 Deep Dive → ★3.5 調査結果確認 → 4 Synthesis（cross-model検証・競合仮説）
 → 4.5 発散レーン（★要rio判断・judge非適用）→ ★5.0 調査レポート+承認ゲート → 5.1 提案+反論検証+judge
 → ［Understand］終了 ／［Decide］終了 ／→ D 詳細設計［Design］→ I Issue作成［Ship］
```

**各Phaseの手順は `.claude/skills/think/SKILL.md` が唯一の正**。CLAUDE.md は原則の要約のみを置く方針だが、**現状は情報収集ソース一覧・Phase D/I詳細・品質基準がCLAUDE.md側にも実体として残っており、方針と実態が一部乖離している**（★2026-08-23 Codexレビューで指摘・未解消。SKILL.mdと内容が食い違った場合はSKILL.md側を正とすること。将来的な整理課題として残す）。原則の要点:

- **0.5 Recall**: A=結論はrecallしない（検証済ソースURL+失敗クエリのみ）／B=`knowledge/profile.md` はrecall可（当てはめ・提示用。真偽は歪めない）。**INDEXは索引であり、過去テーマは `grep -ril <kw> workspace/*/*.md` でも直接引く**
- **1.0 Ambition pass**: 工数で選択肢を削らない。無ければ作るを既定。ownership/保守は Phase D へ
- **1.1 profile 判定**: 問いの種類（`tech-selection` / `ideation` / **`self-audit`** / `advocacy` / `casual`）を選ぶ。**一次ソースが自リポである問いは、GitHub URLが無くても `self-audit`**（放置すると外部Web収集に流れる）。迷ったらrioに問う
- **★1.2**: 軸/ソース/FW/**profile**/モード/effort を提示し、rio承認後に収集を走らせる（承認と同時にprofileとrubricを**凍結**）
- **2**: ブラウザ取得は階層化（WebFetch/検索API既定 → ログイン壁のみClaude in Chrome＝メインagent限定 → Playwright不使用）。source-verifierはルールベース抽出→CoVe→cross-model
- **4**: cross-model検証（一致=解釈頑健性が高い、として競合仮説の証拠適合度で本質を選ぶ。多数決でない。相違=不確実と明記。同一モデルN回はしない）
- **4.5**: 廃棄プール＋STORM型視点で根拠ベースに生成。**Build-the-gap を必ず1件**。provenance付き
- **★5.0**: 調査レポート（背景→調査結果→考察=推論トレース→まとめ）を提示し、**承認を得るまで提案本体を書かない**
- **5.1**: counter-argument → 改訂 → judge → INDEX追記／profile.mdマージ更新

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

### 最重要claimのDeep Research escalation（★2026-08-23改訂）
Perplexity MCPは恒常的な信頼性問題（頻繁なタイムアウト・空応答、Perplexity社自身が2026年3月に自社内でMCPから離脱表明）のため最重要軸専用の役割から外した。代わりに、Phase2で「裏取り不足」と判定された最重要claim（1テーマ最大2-3件）に限り、**Claude in Chrome（メインagent限定）でGemini/ChatGPTの実Deep Research UIを操作**する（詳細: `references/verification.md`、SKILL.md Phase1.3 Layer1.5）。

### SNSリアルタイム（最新情報）
| MCP | コスト | 用途 |
|-----|--------|------|
| `mcp__social-superpowers__twitter-search` | 無料 | X/Twitter + Reddit リアルタイム検索 |
| `mcp__grok__search_posts` | $5/1,000回 | X特化の深い検索（日付・ハンドルフィルタ可） |

コスト管理: Gemini + Codex + social-superpowers で全軸並列実行（無料枠/サブスク内・ブラウザレス） → Layer1.5(Claude in Chrome Deep Research)は最重要claimのみ、Grokは必要時のみ

## Sub-Agents

| Agent | 役割 | Model |
|-------|------|-------|
| `repo-analyzer` | GitHubリポジトリの機能・Issue/PR・外部評価を収集 | sonnet |
| `deep-researcher` | Web検索・SNS検索でDeep Search結果を補完。収集者に徹する | sonnet |
| `case-analyzer` | 個別事例の詳細分析（成果・成功要因・反響） | sonnet |
| `social-scanner` | X/Reddit/はてブ/connpassでの反響・評判調査 | sonnet |
| `source-verifier` | claim検証（ルールベース抽出→CoVe方式→一次ソース直接確認・origin_id独立性判定）。grounded hallucination検出 | sonnet |
| `counter-argument` | 提案に対する反論・論理飛躍・リスクの検証（自己採点で的外れを除外） | sonnet |
| `judge` | 成果物をルーブリックで0-1採点する品質ゲート。順序入替2回・棄権許容・人間トリガー | sonnet |

## 出力先

**レイヤーA（テーマ事実・`workspace/{テーマ名}/` に保存）:**
- `repo-analysis.md` — リポジトリ分析結果・機能マップ（リポジトリ分析モード）
- `research.md` — 収集情報一覧（ソース付き）
- `analysis.md` — 深掘り分析
- `proposal.md` — 最終提案・ロードマップ
- `design.md` — 詳細設計・Mermaid図（Phase D実施時）
- `workspace/INDEX.md` — Recall索引（検証済ソースURL+失敗クエリ。結論はrecallしない）

**レイヤーB（テーマ横断の個人知識・`workspace/` の外）:**
- `knowledge/profile.md` — rioプロファイル（関心領域・判断の好み・制約/文脈・地雷）。gitignore・会話ローカル限定。初期テンプレは `.claude/skills/think/references/profile-template.md`
- `knowledge/{ドメイン}.md` — ドメインナレッジ（例: `avvy.md`）。プロダクトの定義・一次資料に接地した目標・**明示された価値観や不可侵の制約**・実装の地図・繰り返し踏んだ罠。同一ドメインを継続調査する場合に毎回組み直さないための前提。**過去の /think の結論・診断・推奨は書かない**（レイヤーAでありanchoring毒）。数値には測定日を必ず添える

**肥大の抑制:** `scripts/compact-workspace.sh`（既定dry-run・`--apply`で実行）。規律の詳細は `.claude/skills/think/references/knowledge.md`。

## Phase D: 詳細設計（Codex必須連携）

技術設計（シーケンス、アーキテクチャ、テックスタック選定等）は**必ずCodexと共同で実施**する。
**ここが ownership/保守/運用コスト/どう作るかを扱う唯一の場所**。リサーチ〜提案で追い出した「作る難度・保守負担」の舵取りは、設計段階で人間（rio）が判断する（build≠own の現実は設計で織り込む）。

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

## 知識レイヤー / workspace 衛生（原則9）

蓄積するローカル資産（gitignore・会話ローカル限定）を整理された状態に保つ。詳細規律は `.claude/skills/think/references/knowledge.md`。

- **レイヤーA=テーマ事実**（`workspace/INDEX.md`・各テーマ）: 結論はrecall禁止（anchoring毒）。ソースURL+失敗クエリのみ再利用。
- **レイヤーB=rioプロファイル**（`knowledge/profile.md`）: 関心領域・判断の好み・制約/文脈・地雷。recall可だが**提案の当てはめ・提示形式専用**（テーマの真偽を歪めない）。更新はマージ&重複排除（append-only/推測/1発言決めつけ禁止）。初期化は `references/profile-template.md` を `knowledge/profile.md` にコピー。
- **サイズバジェット（Anthropic準拠・G1）**: `profile.md` は 200行/25KB 目安（超過はマージで簡潔化）。`INDEX.md` はエントリ上限（既定150）。根拠は「MEMORY.md先頭200行/25KBのみロード・CLAUDE.md 200行超でadherence低下」（[Claude Code memory](https://code.claude.com/docs/en/memory)）。
- **workspaceライフサイクル**: 1テーマ＝最終成果物＋INDEX1行を live に残し、raw中間物は昇華後に `scripts/compact-workspace.sh`（既定dry-run・N日でアーカイブ）で剪定。**INDEX上限超過分は `INDEX-archive.md` へローテーション（削除でなく退避・grep可能）**（G2）。`_archive/` と成果物は消さない。

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
- **Phase 5.0 調査レポート**（背景/調査結果/考察=推論トレース/まとめ）をチャット提示し、**rio承認後にのみ提案を生成** ＝「いきなり提案」の禁止（レポートと提案を同一ターンで出さない）
- **（Decide以上）Phase 4.5 発散レーン**をprovenance付きで提示（judge非適用・要rio判断）。**Build-the-gap（既存に無い→作る案）を一級の選択肢として提示**
- **コスト観をAI速度に再基準化**（実装難度でリサーチ〜提案の選択肢を削らない・既存に無ければ作るを既定・ownership/保守はPhase Dで人間が舵取り）
- **ブラウザ取得は階層化**（WebFetch既定→Claude in Chromeはメインagent限定→Playwright不使用）
- 全事実主張に検証可能なprovenance（Web主張はURL付きソース、self-audit時はfile:line＋再現コマンド）
- 提案は2案以上（比較可能）
- 各提案にメリット・デメリット・リスク
- **source-verifier で claim検証済み**（ルールベース抽出→CoVe方式→一次ソース直接確認・origin_id独立性判定）
- **grounded hallucination（NOT_ALIGNED）・origin間の矛盾を洗い出し済み**
- **提案の根拠主張は2本以上の独立origin裏取り**（単一originは「裏取り不足」と明示。実測: 単一ソース率93%が最大の弱点。同じoriginへの収束は1本と数える）
- **主張の細部はソース範囲内**（数値/固有名詞/最上級を個別照合。実測: PARTIAL過剰主張33%）
- **「検証済み」に残存不確実性を併記**（過信防止）
- **Synthesisをcross-modelの競合仮説＋証拠適合度で検証**（多数決・1サンプル確定でない）
- counter-argument で反論検証済み（自己採点で的外れ除外）
- **judge 品質ゲート通過**（<0.7×2回なら人間確認・最終検証者は人間）
- **INDEX.md に追記**（レイヤーA・結論はrecall対象にしない規律を遵守）
- **新属性があれば `knowledge/profile.md` をマージ更新**（レイヤーB・推測禁止・重複排除。テーマの結論を歪めない）
- **workspaceは昇華後にコンパクション**（`scripts/compact-workspace.sh`・肥大の抑制・アーカイブと成果物は保持）
- 論理チェーン（事実→推論→結論）が第三者に説明可能
- **各Phaseでチャットによる説明を実施**
- **（Phase D実施時）Codexによる設計検証済み**
- **（Phase I実施時）IssueがDev Ready状態**
