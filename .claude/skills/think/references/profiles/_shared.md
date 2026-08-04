# _shared.md — 全プロファイル共通のダイヤル既定値

各プロファイルは**このファイルの差分のみ**を記述する（値の重複記述を禁止する＝プロファイル間driftの防止）。
SKILL.md / CLAUDE.md 側の固定値は、以下のパラメータ名に置き換えて参照する。

## パラメータと既定値

| パラメータ | 既定値 | 意味 | 参照元（置き換え対象） |
|---|---|---|---|
| `primary_source` | web | 一次ソースとして何を信頼するか | SKILL.md 情報収集ソース |
| `collection_shape` | parallel-deep-search | 収集の形 | SKILL.md 1.3 |
| `min_sources` | 2 | 提案の主柱に必要な独立裏取り本数 | CLAUDE.md 品質基準 |
| `verification_mode` | cross-model | 検証の作法 | verification.md P2 |
| `divergence_count` | 3 | Phase 4.5 発散レーンの案数（0で無効） | SKILL.md 4.5.2 |
| `proposal_count` | 2 | Phase 5.1 の提案数 | SKILL.md 5.1 |
| `rubric_id` | null | judge層2に注入する成果ルーブリック（nullなら層1のみ） | judge.md |
| `default_endpoint` | Decide | 既定の成果物モード | SKILL.md 成果物モード |
| `effort_basis` | complexity | エージェント数/ツールコール数の決定基準 | — |

## effort の決め方（★カテゴリで決めない）

エージェント数・ツールコール数は**問いの種類ではなく、その問い自体の複雑さ**で決める。
「技術選定だから重い / カジュアルだから軽い」と固定しない（カジュアルな問いが難しいこともあり、技術比較が自明なこともある）。

Anthropic の公開ガイダンスを基準線とする:
> Simple fact-finding requires just 1 agent with 3-10 tool calls, direct comparisons might need 2-4 subagents with 10-15 calls each, and complex research might use more than 10 subagents
> — [Anthropic: How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)

また同ソースより、multi-agent が向くのは「独立した複数方向を同時に追う breadth-first な問い」であり、
「全エージェントが同じ文脈を共有する必要がある／依存関係が多い」問いには向かない。**依存関係の有無**で並列化を判断する。

## 全プロファイル共通の不変ルール（プロファイルで上書き不可）

- **事実主張にはソースを付ける**。裏取りが `min_sources` に満たない場合は「**裏取り不足**」と明示する（黙って書かない）
- **推論と実証を区別して書く**。「実行して落ちた」は実証、「だから永久に使えない」は推論
- **「検証済み」には残存不確実性を併記する**
- **judge層1（証拠ゲート）は常に適用される**。`rubric_id` が null でも層1は省略しない
- **実装難度・工数・保守を理由に、リサーチ〜提案の段階で選択肢を削らない**（原則8）

## run contract（Phase 1.2 で凍結し記録する）

同一セッションで2回目の /think を回すと、前回のプロファイルがcontextに残って引き継がれる。
これを防ぐため、Phase 1.2 の承認時に以下を**明示的に記録**し、以降そのrunの間は固定する。

```
profile_id      : {tech-selection | ideation | self-audit | advocacy | casual}
profile_version : {ファイルの版}
rubric_id       : {judge層2に渡すid、またはnull}
output_mode     : {Understand | Decide | Design | Ship}
exceptions      : {既定値から外した項目と理由}
```

- **rubric は成果物が存在する前に凍結する**（後から自分に有利なルーブリックを選ぶ rubric shopping の防止）
- profile 判定に迷う場合、既定値に倒さず **rio に問う**（分類精度は未検証のため）
