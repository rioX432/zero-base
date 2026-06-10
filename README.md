# Zero-Base Thinking

Claude Code project for zero-base research, analysis, and proposals. Supports the full pipeline from research to technical design (with Codex) to Dev Ready Issue creation.

`/think [topic]` triggers a multi-phase pipeline: scoping, thinking framework selection, deep search, cross-validation, case analysis, synthesis, and counter-argument verification. All claims require URL-sourced evidence.

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- Node.js (for MCP servers)

### MCP Servers

This project requires **3 Deep Search MCPs** (user-level) and **supplementary MCPs** (project-level).

#### Deep Search MCPs (user-level)

These power the core research pipeline. Install via `claude mcp add` or your preferred method:

| MCP | Tool | Cost |
|-----|------|------|
| `gemini-deepsearch` | `mcp__gemini-deepsearch__deep_search` | Free (250/day) |
| `chatgpt` | `mcp__chatgpt__chatgpt_send_and_get_response` | ChatGPT Plus subscription (250/month deep research) |
| `perplexity-web` | `mcp__perplexity-web__perplexity_ask` | Sonar $1/$1/MTok, Pro $3/$15/MTok |

Pipeline: **Gemini + ChatGPT** run in parallel on all axes → **Perplexity** for cross-validation on critical axes only (~3/topic).

#### Optional user-level MCPs

| MCP | Tool | Cost |
|-----|------|------|
| `grok` | `mcp__grok__search_posts` | $5/1,000 calls. X/Twitter deep search with date/handle filters |
| `codex` | `mcp__codex__codex` | Codex subscription. Required for Phase D (technical design) |

#### Supplementary MCPs (project `.mcp.json`)

Create `.mcp.json` in the project root (see `.mcp.json.example`):

```json
{
  "mcpServers": {
    "social-superpowers": {
      "type": "http",
      "url": "https://superpowers.social/mcp"
    },
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    },
    "github": {
      "type": "stdio",
      "command": "/bin/sh",
      "args": ["-c", "GITHUB_PERSONAL_ACCESS_TOKEN=$(gh auth token) npx -y @modelcontextprotocol/server-github"]
    },
    "notion": {
      "type": "http",
      "url": "https://mcp.notion.com/mcp"
    }
  }
}
```

### Verify Setup

```bash
claude mcp list
# Deep Search MCPs + supplementary MCPs should show "Connected"
```

## Usage

```
/think [topic]
```

Runs a multi-phase pipeline:

1. **Scoping** - MECE decomposition + thinking framework selection + Deep Search (Gemini/ChatGPT/Perplexity, auto-executed)
2. **Research** - Cross-validation + gap identification + supplementary research
3. **Deep Dive** - Case analysis + social sentiment
4. **Synthesis** - Apply thinking framework lens + pattern extraction + quality loop-back
5. **Proposal** - 2+ options with pros/cons + counter-argument verification (Inversion + Pre-mortem)

### Optional follow-on phases

- **Phase D** - Technical design with mandatory Codex cross-validation (Mermaid diagrams)
- **Phase I** - Dev Ready GitHub Issue creation (requires Phase D completion)

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
| `research.md` | Collected data with sources + gap list |
| `analysis.md` | Deep-dive analysis |
| `proposal.md` | Final proposals with counter-arguments |
| `design.md` | Technical design with Mermaid diagrams (Phase D) |

## Sub-Agents

| Agent | Role |
|-------|------|
| `deep-researcher` | Web/SNS supplementary research |
| `case-analyzer` | Individual case deep-dive |
| `social-scanner` | X/Reddit/Hatena sentiment analysis |
| `source-verifier` | URL existence + claim alignment check |
| `counter-argument` | Devil's advocate with Inversion + Pre-mortem |
| `repo-analyzer` | GitHub repo feature/issue/PR extraction |

## Customization

Edit `CONTEXT.md` to add your organization's context (team size, constraints, priorities) so proposals are tailored to your situation.
