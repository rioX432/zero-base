# EVAL-001: WebSearch要約の未確認転記

## 出典
テーマ: `workspace/viral-loc-indie-benchmark/`（Pestleの数値）、`workspace/2d-to-3d-character-ai-gen/`（Gorest等）
発生日: 2026-08-23（複数回、`feedback_verify_websearch_summaries` メモリで4回目の再発と記録済み）

## シナリオ
Pestleというアプリのダウンロード数・評価を確認する際、`WebSearch`を実行し、その**AI生成要約文**（"Pestle: Recipe Manager by Will Bishop is a Food & Drink app rated 4.7/5 with 211K+ downloads"）をそのままresearch.mdに「211K+DL・4.7評価」として転記した。

## 実際に起きた挙動（失敗）
出典として付けたURL(`mwm.ai/apps/pestle-recipe-manager/1574776971`)を**実際には一度も開いていなかった**。judgeの1回目改訂チェックで、実際にそのページをWebFetchしたところ「100k+」downloadsと表記されており、「211K+」はWebSearchの要約文にしか存在しない数字だった（要約自体がハルシネーションしていた可能性が高い）。

## 期待される挙動
WebSearchの返り値には常に「AI生成の要約文」と「個別のリンク一覧」が両方含まれる。**引用として書く数値は、要約文でなく、対応するURLを`WebFetch`で直接開いて確認した値でなければならない**。これは`CLAUDE.md`の「推測禁止」原則、`feedback_verify_websearch_summaries`メモリで既に明文化されているが、実行時に守られなかった。

## 検出すべきライン
- 理想: 書く**前**に自分でチェックする（一次確認してから転記、が正しい順序）
- 現状: judge agent（層1 citation accuracy）が事後的に検出。**2回検出されて初めて修正された**（1回目の改訂でも別の数値を同じ手口で誤って転記し、2回目のjudgeでまた検出された）

## 現状ステータス: 対応済み(2026-08-23)
`references/verification.md` P2 Step3を改訂し、「重要claimはまず一次成果物を直接WebFetchする」「検索要約やリダイレクト先の抜粋だけでは未検証扱い」を明記した（cross-model原則の見直し(EVAL-004)と同じ改訂の一部）。予防の仕組みとしては効くはずだが、**プロンプト上の注意喚起である点は変わらない**（今回も既存の`feedback_verify_websearch_summaries`原則は既に明文化されていたのに実行時に守られなかった）。次に同じ失敗が起きた場合、「明文化しても実行時に破られる」という追加の教訓として記録すること。

## 改善案（実施済み・要継続観察）
- research.mdに数値を書き込む工程そのものに「この数値の出典URLをWebFetchで直接確認したか」を`references/verification.md`（P2 Step3・origin_idセクション）に追加 → 実施済み
- 効果測定は次回このevalケースに該当する状況が発生した時点で行う（このプロンプト強化だけで再発が防げるかは未検証）

## 再現手順
1. 何らかの実績数値（ダウンロード数・評価スコア等）についてWebSearchを実行する
2. 返ってきた要約文に具体的な数値が含まれる
3. その数値を、URLを開かずにそのまま成果物に書く
4. → 高確率で誤り（要約文自体がWebSearchツール内のAI要約プロセスでハルシネートしている場合がある）
