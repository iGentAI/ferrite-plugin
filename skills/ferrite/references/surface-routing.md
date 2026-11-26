# Surface routing

## Before you build

Before the first deploy of any new application, follow `SKILL.md` ("Before you build"): explain briefly what Ferrite is and quote the monthly projection and deploy fee from `ferrite cost` or `estimate_cost`.

## Prefer the CLI

Reach for `ferrite` whenever a shell and local project tree are present:

- scaffolding, vendoring packages, editing source, validating, explaining gate codes, building, and running tests;
- `ferrite dev`, hot reload, local diagnostics, and browser verification;
- deployments, previews, and safe recovery via journaled attempt IDs;
- streaming logs and deterministic `--json` automation;
- local RCS commands and source-heavy or iterative workflows.

## Prefer MCP

Reach for Ferrite MCP for:

- structured remote discovery across accounts, apps, builds, releases, routes, domains, usage, and notifications;
- full remote lifecycle operations in environments without a shell;
- compact control-plane reads where structured tool output beats parsing terminal text.

Avoid reconstructing a local source tree through repeated MCP calls when the CLI can inspect or submit it directly, and avoid shelling out merely to reformat structured JSON already returned by MCP.

Against upstream Ferrite Core, MCP alone is a complete workflow for building, deploying, operating, and recovering apps (`mcp-operations.md`). When using the CLI, run only the version pinned by this plugin (`scripts/check-cli.sh` reports `ready`); an older binary can submit a duplicate charged build where the pinned CLI reattaches safely.

## Safety

- `ferrite deploy` and `deploy_source` publish live at the app's public host; they are production deploys, not previews. `ferrite preview` commits the current workspace and deploys to an isolated temporary host: it passes the same build and admission gates, skips the test-verdict hold, incurs no charge, creates no release, and expires after two hours. Over MCP, `preview_ref` creates the same preview from a committed revision.
- Ship a new application once the user has seen the cost quote (`SKILL.md`, "Before you build"). Ask first before redeploying an app that already serves users, and before any destructive or externally visible change (`scale`, `rollback`, `withdraw`, custom domains, promotion, or updating secrets on a serving app). `ferrite withdraw <app>` prompts for the app name interactively and requires `--yes` non-interactively; pass `--yes` only after explicit user consent. `ferrite usage [app]` reads requests, errors, and latency without mutating anything.
- Write secrets through `ferrite secrets set <NAME>` (value on stdin) or MCP `set_secret`; never place secret values in command arguments, source files, prompts, transcripts, or logs. Workers receive the injected values at runtime, and application code must never log, return, or persist them. If `ferrite secrets` is absent, the installed binary does not match this plugin's pin; check with `scripts/check-cli.sh`.
- Track build, release, deployment, route binding, and served HTTP response as distinct milestones.
- Preserve correlation, build, release, deployment, and revision identifiers across turns.
