# Zero-Base Thinking

Claude Code project for zero-base research, analysis, and proposals.

`/think [topic]` triggers a multi-phase pipeline: scoping, deep search, cross-validation, case analysis, synthesis, and counter-argument verification. All claims require URL-sourced evidence.

## Setup

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- Node.js (for MCP servers)
- Python / [uv](https://docs.astral.sh/uv/) (for google-news-trends MCP)

### MCP Servers

This project requires **3 Deep Search MCPs** (user-level) and **4 supplementary MCPs** (project-level).

#### Deep Search MCPs (user-level)

These power the core research pipeline. Install via `claude mcp add` or your preferred method:

| MCP | Tool | Cost |
|-----|------|------|
| `gemini-deepsearch` | `mcp__gemini-deepsearch__deep_search` | Free (250/day) |
| `chatgpt` | `mcp__chatgpt__chatgpt_send_and_get_response` | ChatGPT Plus subscription (250/month deep research) |
| `perplexity-web` | `mcp__perplexity-web__perplexity_ask` | ~$0.4-1.3/query |

Pipeline: **Gemini + ChatGPT** run in parallel on all axes → **Perplexity** for cross-validation on critical axes only (~3/topic).

#### Supplementary MCPs (project `.mcp.json`)

Create `.mcp.json` in the project root:

```json
{
  "mcpServers": {
    "social-superpowers": {
      "type": "http",
      "url": "https://superpowers.social/mcp"
    },
    "google-news-trends": {
      "type": "stdio",
      "command": "uvx",
      "args": ["google-news-trends-mcp@latest"]
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
    }
  }
}
```

### Verify Setup

```bash
claude mcp list
# All 7 MCPs should show "Connected"
```

## Usage

```
/think [topic]
```

Runs a 5-phase pipeline:

1. **Scoping** - MECE decomposition + Deep Search (Gemini/ChatGPT/Perplexity, auto-executed)
2. **Research** - Cross-validation + supplementary research (SNS, local sources)
3. **Deep Dive** - Case analysis + social sentiment
4. **Synthesis** - Pattern extraction + insight distillation
5. **Proposal** - 2+ options with pros/cons + counter-argument verification

### Repository Analysis Mode

```
/think [topic] github.com/owner/repo
```

Adds Phase 0 (repo analysis) and replaces Phase 4 with gap analysis + roadmap proposals.

## Output

Results are saved to `workspace/{topic}/`:

| File | Content |
|------|---------|
| `research.md` | Collected data with sources |
| `analysis.md` | Deep-dive analysis |
| `proposal.md` | Final proposals with counter-arguments |

## Sub-Agents

| Agent | Role |
|-------|------|
| `deep-researcher` | Web/SNS supplementary research |
| `case-analyzer` | Individual case deep-dive |
| `social-scanner` | X/Reddit/Hatena sentiment analysis |
| `source-verifier` | URL existence + claim alignment check |
| `counter-argument` | Devil's advocate for proposals |
| `repo-analyzer` | GitHub repo feature/issue/PR extraction |

## Customization

Edit `CONTEXT.md` to add your organization's context (team size, constraints, priorities) so proposals are tailored to your situation.
