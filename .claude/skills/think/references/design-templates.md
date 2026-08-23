# Phase D / Phase I テンプレート

## Contents
- 設計ドキュメント（Phase D）
- Dev Ready Issue（Phase I）

## 設計ドキュメント（Phase D）

```markdown
## 設計: {テーマ}

### サマリー
{設計の全体像を3行以内で。技術選定の結論 + 最大の判断ポイント}

### システムアーキテクチャ

\`\`\`mermaid
graph TB
    subgraph "Client"
        A[Component A]
    end
    subgraph "Server"
        B[Component B]
        C[Component C]
    end
    A --> B
    B --> C
\`\`\`

### シーケンス図

\`\`\`mermaid
sequenceDiagram
    participant U as User
    participant A as Service A
    participant B as Service B
    U->>A: Request
    A->>B: Process
    B-->>A: Response
    A-->>U: Result
\`\`\`

### コンポーネント図

\`\`\`mermaid
classDiagram
    class ComponentA {
        +method1()
        +method2()
    }
    class ComponentB {
        +method3()
    }
    ComponentA --> ComponentB
\`\`\`

### 技術選定

| 領域 | 選定 | 理由 | 代替案 | 代替を選ばなかった理由 |
|------|------|------|--------|---------------------|

### 設計判断ログ

| # | 判断 | 選択肢 | 決定 | 根拠（リサーチ参照） |
|---|------|--------|------|-------------------|

### Claude vs Codex クロスバリデーション

| 判断ポイント | Claude案 | Codex案 | 最終決定 | 根拠 |
|-------------|---------|---------|---------|------|

### リスクと軽減策

| リスク | 影響度 | 軽減策 |
|--------|--------|--------|
```

---

## Dev Ready Issue（Phase I）

```markdown
## {Issue Title}

### 背景・目的
{なぜこの実装が必要か。リサーチ結果への参照リンク}

### 設計概要

{アーキテクチャ図（Mermaid）}

{シーケンス図（Mermaid）}

### 技術スタック
- **言語/FW**: {選定結果}
- **依存ライブラリ**: {必要なもの}
- **対象リポジトリ**: {URL}

### 実装方針

#### Step 1: {ステップ名}
- 対象ファイル: `path/to/file`
- やること: {具体的な変更内容}

#### Step 2: {ステップ名}
- ...

### 受け入れ基準（Acceptance Criteria）
- [ ] {基準1}
- [ ] {基準2}
- [ ] {基準3}

### テスト方針
- {どのレベルのテストが必要か}
- {エッジケース}

### 参考リンク
- [リサーチ結果]({URL})
- [設計ドキュメント]({URL})
- [関連Issue/PR]({URL})

### 見積もり
- **工数**: {時間}
- **複雑度**: {高/中/低}
```
