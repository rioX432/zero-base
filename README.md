# Zero-Base Thinking

Claude Code project for zero-base research, analysis, and proposals. Supports the full pipeline from research to technical design (with Codex) to Dev Ready Issue creation.

`/think [topic]` runs a multi-phase pipeline — scoping, thinking-framework selection, parallel deep search, **claim-level verification**, synthesis, and counter-argument — engineered to **minimize the non-determinism and hallucination of LLM reasoning**. All claims require URL-sourced evidence.

## Anti-Hallucination by Design

LLM reasoning is non-deterministic and quietly wrong some of the time; no model gets this to zero. This harness layers verification on top, following 5 principles (see `.claude/skills/think/references/verification.md`):

1. **Rule-based claim extraction** — what gets verified (numbers, proper nouns, assertions) is selected mechanically, never by the LLM's own "this seems important" judgment.
2. **Cross-model verification** — important claims and the final synthesis are re-checked by a *different* model (Gemini / ChatGPT / Codex). Majority-voting the *same* model N times is treated as false independence and is not used.
3. **Human as final verifier** — verification loops have a hard cap; when the quality `judge` scores < 0.7 twice, it escalates to you instead of looping.
4. **No conclusion recall** — past conclusions are never recalled as fact (anchoring poison). Only verified source URLs and dead-end queries are reused, via `workspace/INDEX.md`.
5. **Residual uncertainty is always shown** — a "verified" label never appears without the remaining risk beside it, to prevent overconfidence.

> These choices are grounded in primary research (Anthropic context-engineering & multi-agent system, Cognition "Don't Build Multi-Agents", CoVe / Self-Consistency papers, LLM-as-judge position-bias study) and were stress-tested by the harness's own counter-argument agent. See `workspace/think-harness-modernization/`.

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- Node.js (for MCP servers)

### MCP Servers

This project uses **Deep Search MCPs** (user-level) and **supplementary MCPs** (project-level).

#### Deep Search MCPs

These power the core research pipeline and double as independent **cross-model verifiers**:

| MCP | Tool | Cost |
|-----|------|------|
| `gemini-deepsearch` | `mcp__gemini-deepsearch__deep_search` | Free (250/day), API-key — no browser |
| `chatgpt` | `mcp__chatgpt__chatgpt_send_and_get_response` | ChatGPT subscription (browser automation) |
| `perplexity-web` | `mcp__perplexity-web__perplexity_ask` | Subscription (web version, no API key) |
| `codex` | `mcp__codex__codex` | Codex subscription — cross-model verifier + Phase D design |

> Note: the API-based Perplexity Sonar MCP (`@perplexity-ai/mcp-server`) is intentionally **not** used — its credits are billed separately from the Pro subscription and it returns 401 once the (now-removed) bundled credit is exhausted. The browser/subscription `perplexity-web` is used instead. Gemini (free, API, browser-free) is the primary deep-search source.

Pipeline: **Gemini + ChatGPT** run in parallel on all axes → important claims & the synthesis are **independently re-verified by a different model**.

#### Optional / supplementary MCPs

| MCP | Tool | Use |
|-----|------|-----|
| `grok` | `mcp__grok__search_posts` | X/Twitter deep search with date/handle filters |
| `social-superpowers` | `twitter-search` / `reddit-search` | Real-time X + Reddit (HTTP, free) |
| `github` | `mcp__github__*` | Repo analysis, Issue creation (Phase I) |
| `notion` | `mcp__notion__*` | Internal context |

Create `.mcp.json` from `.mcp.json.example` in the project root.

### Verify Setup

```bash
claude mcp list   # MCPs should show "Connected"
```

## Usage

```
/think [topic]
```

Runs a multi-phase pipeline:

0. **Recall** - grep `workspace/INDEX.md` for related past work — reuse *sources and dead-ends only*, never conclusions
1. **Scoping** - MECE decomposition + thinking-framework selection + parallel Deep Search (auto-executed)
2. **Research + claim verification** - cross-validation, rule-based claim extraction → CoVe-style source check → cross-model re-verification; gap identification
3. **Deep Dive** - case analysis + social sentiment
4. **Synthesis** - thinking-framework lens + **cross-model consensus** (agreement = essence, divergence = flagged uncertain)
5. **Proposal** - 2+ options with pros/cons → counter-argument (with self-scoring) → **`judge` quality gate** (rubric 0-1, order-swapped twice, human-trigger) → append to `INDEX.md`

Every "verified" output carries its residual uncertainty.

### Optional follow-on phases

- **Phase D** - Technical design with mandatory Codex cross-validation (Mermaid diagrams)
- **Phase I** - Dev Ready GitHub Issue creation (requires Phase D completion)

### Periodic baseline measurement

Before major changes, sample ~15 claims from past `workspace/*/research.md` and re-verify them to measure the *actual* error mix (NOT_ALIGNED / PARTIAL-overreach / single-source rate). Drive the design from your own data, not generic hallucination stats. See `references/verification.md` P6.

### Thinking Frameworks

Phase 1 selects 1-2 frameworks based on the topic:

| Framework | Best for |
|-----------|----------|
| First Principles | Tech stack, architecture design |
| Inversion | Risk analysis, strategy decisions |
| Second-Order Effects | Platform selection, business decisions |
| Hypothesis-Driven | Market research, user behavior analysis |
| Systems Thinking | Organization, ecosystem analysis |
| Pre-mortem | Project planning, major decisions |

### Repository Analysis Mode

```
/think [topic] github.com/owner/repo
```

Adds Phase 0 (repo analysis) and replaces Phase 4 with gap analysis + roadmap proposals.

## Output

Results are saved to `workspace/{topic}/`:

| File | Content |
|------|---------|
| `research.md` | Collected data with sources + gap list (verified, with residual uncertainty) |
| `analysis.md` | Deep-dive analysis |
| `proposal.md` | Final proposals with counter-arguments + judge scores |
| `design.md` | Technical design with Mermaid diagrams (Phase D) |
| `workspace/INDEX.md` | Recall index — verified source URLs + failed queries (conclusions are *not* recalled as fact) |

## Sub-Agents

| Agent | Role |
|-------|------|
| `deep-researcher` | Web/SNS supplementary research |
| `case-analyzer` | Individual case deep-dive |
| `social-scanner` | X/Reddit/Hatena sentiment analysis |
| `source-verifier` | Claim verification: rule-based extraction → CoVe-style source check → cross-model independent verification (catches grounded hallucination) |
| `counter-argument` | Devil's advocate (Inversion + Pre-mortem) with self-scoring to drop weak critiques |
| `judge` | Rubric quality gate (0-1), order-swapped twice for position-bias, abstention allowed, human-trigger below threshold |
| `repo-analyzer` | GitHub repo feature/issue/PR extraction |

## Customization

Edit `CONTEXT.md` to add your organization's context (team size, constraints, priorities) so proposals are tailored to your situation.
