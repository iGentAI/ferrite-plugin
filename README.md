# Ferrite

Where what your coding agent builds goes to live.

Ferrite is production hosting designed for software built by coding agents. Every application ships as safe Rust against a single SDK (`ferrite-app`) alongside a short `ferrite.json` declaration. The platform checks and compiles the source, then grants capability handles strictly for the stores, queues, routes, secrets, and outbound destinations that manifest names, with no ambient filesystem, environment, shell, or open sockets. Operations declared once serve web pages, Markdown twins, OpenAPI, MCP, and A2A through the same handlers, so human users and their AI assistants share one set of rules.

This plugin teaches your coding agent to build, verify, deploy, and operate Ferrite applications and connects it to Ferrite's hosted MCP server. Before the first remote deployment, the agent explains how Ferrite works and quotes the monthly cost from the live tariff.

## Install

One repository serves every agent. Each step below installs the Ferrite skill and the hosted MCP server where the agent has a plugin format, and the hosted MCP server alone where it does not. The first Ferrite tool that needs an account opens Ferrite's connect page in your browser.

### Claude Code

```text
/plugin marketplace add iGentAI/ferrite-plugin
/plugin install ferrite@ferrite
```

### claude.ai and the Claude desktop app

Open **Customize > Plugins**, choose **Add > Add marketplace**, enter `iGentAI/ferrite-plugin` and add Ferrite. Then open the plugin's **Connectors** tab and connect Ferrite. To use Ferrite without the skill, add `https://mcp.ferrite.cloud/mcp` as a custom connector under **Customize > Connectors**.

### Codex

```sh
codex plugin marketplace add iGentAI/ferrite-plugin
codex plugin add ferrite@ferrite
```

### GitHub Copilot CLI and VS Code

```sh
copilot plugin marketplace add iGentAI/ferrite-plugin
copilot plugin install ferrite@ferrite
```

In VS Code, run **Chat: Install Plugin from Source** from the Command Palette and enter `https://github.com/iGentAI/ferrite-plugin`, or open this link:

```text
vscode://chat-plugin/install?source=iGentAI%2Fferrite-plugin&plugin=ferrite
```

### Cursor

Open this link, and Cursor asks to add the hosted Ferrite MCP server:

```text
cursor://anysphere.cursor-deeplink/mcp/install?name=ferrite&config=eyJ1cmwiOiJodHRwczovL21jcC5mZXJyaXRlLmNsb3VkL21jcCJ9
```

The link writes the same entry you can add by hand to `~/.cursor/mcp.json`:

```json
{"mcpServers": {"ferrite": {"url": "https://mcp.ferrite.cloud/mcp"}}}
```

### Antigravity

```sh
agy plugin install https://github.com/iGentAI/ferrite-plugin
```

### Gemini CLI

```sh
gemini extensions install https://github.com/iGentAI/ferrite-plugin
```

### Devin

```sh
devin plugins install iGentAI/ferrite-plugin
```

### OpenCode

```sh
opencode mcp add ferrite --url https://mcp.ferrite.cloud/mcp
opencode mcp auth ferrite
```

### Cline

```sh
cline mcp add ferrite https://mcp.ferrite.cloud/mcp --transport http --yes
```

### Any other agent

Add `https://mcp.ferrite.cloud/mcp` as a remote MCP server (Streamable HTTP, with OAuth sign-in in the browser). Agents that read `AGENTS.md` find the same instructions there. You can also paste this prompt and let the agent set itself up:

```text
Read the Ferrite setup document at https://docs.ferrite.cloud/agent-setup/SKILL.md and follow it to set yourself up.
```

## Accounts and cost

Ferrite bills a prepaid balance at metered rates with no plan fees and no seat fees, and quotes the deploy fee and monthly projection before you ship. A small always-on application costs about $8 a month.

Trial accounts run for 48 hours with $50 of credit, one instance per application, 256 MiB of memory, and 0.5 vCPU. Durable accounts also receive $50 of welcome credit once. When a prepaid balance reaches zero, running applications stop and remain recoverable for 30 days before permanent deletion.

## What this plugin runs, sends and fetches

- Ferrite MCP (`https://mcp.ferrite.cloud/mcp`), operated by iGent AI, receives the source files, application specifications, and control-plane requests needed for the operations you request, such as code checks, deployments, and log reads. On the first tool call that needs an account, your browser opens Ferrite's connect page at `mcp.ferrite.cloud`. Choose **Sign in to your Ferrite account** to connect the account you already have with Google or GitHub, or **Try Ferrite without an account** for a 48-hour trial with $50 of credit that you can keep later from a claim link. The connection reaches that one Ferrite account and nothing else, and you can end it from the dashboard.
- The Ferrite command-line tool, only with your approval. Where the agent has a shell, the skill prefers the `ferrite` CLI. If it is missing, the agent asks before running `skills/ferrite/scripts/install-cli.sh`, which downloads the CLI archive for your platform from `https://downloads.ferrite.cloud/releases/<version>/`, refuses it unless its SHA-256 matches the checksum pinned in `skills/ferrite/scripts/SHA256SUMS`, and installs it in `~/.local/bin` without root. `skills/ferrite/scripts/check-cli.sh` only reads the installed version. `skills/ferrite/scripts/uninstall-cli.sh` removes what the installer placed. This repository carries no executable and no archive.
- The plugin defines no hooks and runs nothing on its own. It reads no credentials from your environment and communicates only with Ferrite hosts.

Ferrite's terms of service are at `https://ferrite.cloud/terms`, and its privacy policy at `https://ferrite.cloud/privacy` details what is recorded for visits and accounts. Developer documentation lives at `https://docs.ferrite.cloud`, and the dashboard at `https://dashboard.ferrite.cloud`.

## Licence

The plugin's files are MIT-licensed; see `LICENSE`. The hosted Ferrite platform is proprietary and not open source.

## Support

Write to info@igent.ai. Report a security problem to security@ferrite.cloud; `SECURITY.md` says what to include.
