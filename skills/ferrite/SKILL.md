---
name: ferrite
description: Build, verify, deploy, and operate applications on Ferrite and Ferrite Cloud. Use when someone asks what Ferrite is, what an application costs, or whether to ship on it; when building or hosting a web app, page, API, poll, form, sign-up sheet, or site on Ferrite; or when working with Ferrite source trees, packages such as auth, user sign-in or SSO, the ferrite CLI, deployments, or control-plane MCP operations.
---

# Ferrite

<!-- ferrite-brief:start (written by the documentation corpus generator; edit developers/agent-brief.mdx) -->
FERRITE BRIEF. With a shell, use the CLI path below.

1. Before building, tell the user what Ferrite is (each app reaches only what `ferrite.json` declares) and what the app costs (`ferrite cost`, MCP `estimate_cost`).
2. `ferrite new alloy <name>` for HTML pages (`hello` for an API), edit `src/lib.rs`, then `ferrite check`, `ferrite test`, `ferrite dev`, `ferrite deploy`. CLI and MCP share one account; never provision another. Without a shell: `validate_spec`, `code_gate`, one `deploy_source`, poll `build_status`.
3. Safe Rust, one dependency: `ferrite-app`. Shared source: `ferrite add <package>`, or MCP† `list_packages`, `read_package`, then `deploy_source` with `packages`. Randomness: no `ferrite_app::crypto::random_*`; use `sha256-hmac` or `hmac_sha256(&Ed25519SigningKey::generate_pkcs8(), label)`.
4. Test shipped logic with `#[test]` against known answers; `ferrite test` must show them passed.
5. Secrets: `printf %s "$VALUE" | ferrite secrets set <NAME>` (MCP: `set_secret`) before deploying; the app reads them at runtime. Never put credentials in source.
6. App users: `ferrite add auth`, then read `src/auth/SETUP.md`. `ferrite host` (MCP `app_host`†) prints the address first; set every secret `SETUP.md` lists, then deploy once. Get OAuth credentials from the user; never invent them.
7. Deploy once with a long timeout; builds take minutes and draw credit. `ferrite deploy resume` reattaches.
8. Docs: `search_docs "<words>"`† finds sections for `read_docs` († if present in `tools/list`).
9. Limits: 256 KiB body, one `set-cookie` per reply, 8 s API deadline, ~1 MiB egress reply.
10. Trials: keep `token` and `claim_token` private. Dashboard sign-in: `owner_status` and `claim_url`. To keep apps past expiry, read `mcp-only-operations`.
<!-- ferrite-brief:end -->

When repairing an existing application over MCP, commit only the changed files with `rcs_commit`, then deploy the returned commit with `deploy_ref` while keeping required tests intact. Follow [Repair an existing application](references/mcp-operations.md#repair-an-existing-application); unchanged vendored packages stay in the hosted repository.

## Before you build: tell your person what Ferrite is

Before the first remote mutation in a conversation (opening an account or running the first deploy), send a short, plain summary of what Ferrite is and what the application will cost. Send it once per conversation.

If the user asked you to build on a trial account, share the summary and continue unless they object. On a durable account, wait for approval on the monthly projection before the first deploy of a new application. If they only asked a question, answer it and wait.

### What Ferrite is

Ferrite is production hosting designed for software built by coding agents. Every application ships as safe Rust (no `unsafe` code, one dependency: `ferrite-app`) alongside a short `ferrite.json` declaration. The platform checks and compiles the source, then passes capability handles strictly for the stores, queues, routes, secrets, and outbound destinations declared in that manifest. The running process gets no ambient filesystem, environment, shell, or open sockets, and the platform gateway mediates every outbound request. Applications declared once can expose web pages, Markdown twins, OpenAPI, MCP, and A2A through the same handlers, so human visitors and their AI assistants follow the same rules. The owner never needs to audit Rust: `ferrite.json` is the complete list of what the app can touch, and you can read it back to them directly.

### What it costs

Run `ferrite cost --instances 1` in the app directory (MCP: `estimate_cost`) and quote the deploy fee and monthly projection it returns; the live tariff from the platform is authoritative. Before an account or project directory exists, give the orientation below, then quote the platform's exact figure before the first deploy.

Ferrite bills a prepaid balance at metered rates with no plan fees and no seat fees, and quotes every deploy upfront. A small always-on application runs about $8 a month. Refusals and failed builds are not charged. When a balance hits zero, running applications stop and remain recoverable for 30 days before permanent deletion. On Ferrite Cloud, a trial account runs for 48 hours with $50 of credit, one instance per application, 256 MiB of memory, and 0.5 vCPU. Durable accounts receive $50 of welcome credit once.

## Fast path: a small web app in one build

For a small single-page web application (a poll, voting page, RSVP, sign-up sheet, guestbook, scoreboard, countdown, or compact dashboard), start from the verified starter in `starters/page-app/` next to this file: `src/main.rs` (one file holding the serve loop, store-backed form POST, theme tokens, and unit tests), `Cargo.toml`, and `spec.json`. It deploys directly. Skip the `alloy` package and Alloy scaffolding here; Alloy targets multi-page server-rendered applications with routing, cached loaders, and actions, and requires reading its package contract. For a single-page app, this fast path takes precedence over the brief's `ferrite new alloy`.

1. Read all three starter files and adapt `src/main.rs` to the request: constants, `handle` routes, and `render` markup. Keep the CSS theme tokens clean and escape every visitor-supplied string with `escape`.
2. Set the app name in `Cargo.toml` and `spec.json` (`name` and `artifact_key`). Pick sensible defaults for minor unspecified details (such as four clean options on a poll) instead of stalling on clarifying questions.
3. Call `validate_spec` or `code_gate` when you need admission diagnostics before submission and fix any refusal. Because `deploy_source` enforces both admission checks itself, a separate pre-call is optional and does not compile or test the crate. Submit ONE `deploy_source` (`spec` + `files`), then poll `build_status {build_id, wait_s: 50}` until `deployed`, `rejected`, `failed`, or `stuck`; each call blocks up to 50 seconds for a state change, so no sleep is needed. If `tools/list` omits `wait_s` on `build_status`, poll every five seconds instead. Keep required tests intact and verify the served response before reporting completion.
4. Ship what was asked cleanly and stop there: leave admin panels, extra views, QR codes, custom fonts, and entrance animations out of the first build, and offer additions once the live URL is delivered.
5. Skip local dev servers and screenshots on this fast path. Fetch the live URL once to confirm it responds, then share it. Iterate through follow-up deploys.

## Routing and operating rules

Use the shortest authoritative surface for the task.

Canonical services:

- Developer documentation: `https://docs.ferrite.cloud`
- Dashboard: `https://dashboard.ferrite.cloud`
- Stateless Ferrite MCP: `https://mcp.ferrite.cloud/mcp`

1. If a writable application workspace and shell are available, prefer the `ferrite` CLI for scaffolding, source changes, validation, tests, local development, deployment, log streaming, and repeatable automation.
2. Prefer Ferrite MCP for remote discovery and control-plane records, or when
   no shell is available. The MCP surface is sessionless: requests are
   independent and carry no session ID. In this plugin, Ferrite MCP signs in
   with its own OAuth session, so call `account` on MCP and `ferrite account`
   in the CLI and keep one application on one account; never provision a
   second identity because you switched surfaces.
3. Never treat build acceptance as deployment completion. Verify the final URL and confirm a real HTTP read-back from the live app.
4. Ask before production, destructive, scaling, promotion, rollback, domain, or withdrawal operations, and before modifying secrets on an app that already serves users. Setting the secrets required by a new app you are building is normal build work: set them without asking via `ferrite secrets set <NAME>` (value on stdin) or MCP `set_secret`. Never pass a secret in argv, and never write credentials into source, tests, or fallback defaults.
5. Application user sign-in is part of the app. When an app has its own users (customers in a shop, members of a team tool), run `ferrite add auth`, follow `src/auth/SETUP.md`, and configure `auth_allow`: `*` admits any verified GitHub or Google user for a customer-facing product, while a domain or explicit allowlist fits an internal tool. Public pages stay public; authenticated views go behind `Auth::gate`. An app without user accounts needs no sign-in. See the Authentication page in the developer docs for the full recipe. Never hand-roll password hashing, sessions, cookies, reset links, TOTP, passkeys, OAuth/OIDC, SAML, or SCIM, and never attach an external auth database, cache, broker, or KMS. Ferrite Core does not provide platform-managed auth, and `ferrite auth` is a retired verb that redirects to the package. On Ferrite Cloud, every app is reachable at its host from its first deploy with no platform login wall in front, so every restricted route must go through `Auth::gate`. Edge sign-in on a private instance is that instance's perimeter control, never a substitute for app sign-in.
6. Look up documentation with `search_docs {query}` and fetch specific entries with `read_docs {doc: "<id>"}` instead of loading full manuals or reading package internals. Both calls are read-only. If an installation does not list `search_docs`, call `read_docs` with no arguments for its index. Platform docs such as `quickstart` and the writing-apps `guide` assume a shell-less MCP client; when you have a shell and the CLI, follow this skill and scaffold, check, test, and deploy with `ferrite`.
7. Treat the hosted platform as an opaque service during application work. Do not inspect, clone, patch, or version-match a Core checkout, and do not invoke fleet scripts unless explicitly tasked with platform engineering or operations.

In a writable shell, your first tool action after reading this skill MUST check the configured CLI version: run `$FERRITE_CLI_BIN --version` when `FERRITE_CLI_BIN` is set, otherwise `ferrite --version`. Wait for the version output, then scaffold, edit, and pass `ferrite check` and `ferrite test` before any remote mutation (`provision_ephemeral`, `deploy_source`, `ferrite deploy`). Documentation reads (`search_docs`, `read_docs`) are not mutations and can run anytime. Start local projects with the CLI even when deployment or control-plane checks will use MCP.

## Which platform is this?

Inspect `tools/list` once and branch on its tool inventory, never on a version string, hostname, or `server/discover` output (which varies with protocol revision). Ferrite Core exposes `deploy_source` and `build_status`. If an endpoint lists `create_source`, `update_source`, `source_operation`, `mint_token`, or `auth_capability`, stop and inform the user before building against it.

## Ferrite Core rules

The MCP-only path is self-contained: an agent with an endpoint and bearer token can build, deploy, and operate an application without a shell or CLI. These behavioral contracts cover details omitted from raw tool schemas; if a live server response differs, trust the server response. Read `references/mcp-core-rules.md` before the first MCP deploy. In short:

1. Read the verdict inside the payload: refusals set `isError: true`, while negative answers (`passed`, `admitted`, `spec_valid` or `verified` false, and `build_status` states `failed`, `rejected` or `stuck`) arrive with `isError: false`.
2. Pass `spec` to `validate_spec`, `estimate_cost` and `deploy_source` as a JSON string, not an object.
3. Omit the manifest fields upstream rejects (`auth`, `required_secrets`, `stream_mode`, `forward_headers` on `stream` or `ws` routes, `native` on `depends`), never send a spec with `rate_limit_per_min` through raw `deploy_source`, and declare a `workload` on every service.
4. Submit each deploy once, save its `build_id`, and poll `build_status {build_id, wait_s: 50}` to a terminal state; builds take 3 to 8 minutes.
5. Reconcile a lost reply through `rcs_log` and `account_statement` before submitting again.
6. `deployed` means registered: confirm with `status` and a live request.
7. Secrets reach an app only through its next deploy: set them all, then deploy once.
8. Guard every token. A connector never calls `provision` or `provision_ephemeral`; to keep a trial or join an existing account, give the person `claim_url`.
9. Public URLs assume public routing; local fleets route by `Host` header over plain HTTP.
10. Design within the runtime bounds the reference lists (256 KiB request body, 8 s API deadline, 4 MiB response).

## Local project with the CLI

An empty writable workspace with a shell and a compatible Ferrite CLI is a local project: scaffold through the CLI and run local checks and tests before the first MCP call or remote mutation. Start on MCP only when no writable shell or compatible CLI exists. Do not probe unrelated configs, install or mock a replacement CLI without permission, or deploy a dummy connectivity probe ahead of the requested app.

When `FERRITE_CLI_BIN` is set, use that exact binary throughout the session; otherwise invoke `ferrite`. Run both `--version` and `add --help` before any package workflow. A `0.1.x` binary is compatible only if the required subcommand exists. If the CLI is missing, incompatible, or lacks `add`, explain the step and ask approval before running `scripts/install-cli.sh` (pass `--force` only to replace an owned incompatible install). The installer is non-root, checksum-verified, and idempotent. If the platform artifact is unavailable, continue with MCP and tell the user that local CLI workflows are unavailable.

```text
ferrite new --with-tests --target upstream alloy <name>
cd <name>
ferrite check --json
ferrite test
ferrite dev
ferrite check --remote --json
ferrite deploy
ferrite status <name>
```

`ferrite new` accepts `alloy` (routing, documents, and actions; default choice for HTML apps), `hello` (request/reply API), or `webapp` (content, API, and SSE live page). Shared subsystems ship as source packages, not crates: `ferrite add <name>` vendors one under `src/<mount>/` and tracks it in `ferrite-packages.json`, so the crate keeps its single `ferrite-app` dependency. Run `search_docs "packages"` to inspect the published catalog before writing a subsystem from scratch. `ferrite add` is CLI-only; over MCP, `deploy_source` injects package files only when `tools/list` advertises the `packages` argument, otherwise include the files directly.

`ferrite deploy` writes an upstream projection of `ferrite.json` and `Cargo.toml` under `.ferrite/upstream-projection/`, logs every transform, and leaves your project files untouched. It blocks fields upstream rejects unless explicitly cleared with `--drop-auth` or `--drop-stream-mode`; ask before passing either flag.

Rules for the local loop, in full under "Local project rules" in `references/cli-workflows.md`:

- Give `ferrite deploy` a shell timeout of at least 20 minutes, and finish an interrupted attempt with `ferrite deploy resume`, never a second deploy.
- Share the live URL once a deployment serves verified traffic, then iterate in follow-up deploys.
- Fork an app that serves users before changing it (`ferrite fork <copy>`), and edit the fork from a clean copy whose `ferrite.json` names it.
- Set every secret first (`ferrite secrets set <NAME>` on stdin), then deploy once; never withdraw a serving app to change configuration.
- An app with the `auth` package deploys in one pass: `ferrite host` for the callbacks, register them, set the secrets, deploy.
- Turn the request into an acceptance checklist, then pass `ferrite check` and `ferrite test` before any remote build; compiling cleanly does not prove the app works.
- Learn APIs from `search_docs`, `read_docs` and the compiler, not from `vendor/` or generated files.
- Never strip sign-in or expose a signed-in user's data to produce a link.
- `ferrite preview` is free and expires in two hours; `ferrite deploy` is billable and needs the person's intent.
- Record the account, app id, build id and host; on a gate rejection, fix the same project and retry the same app.

Load only the reference document needed for the task at hand:

- Surface choice and safety: `references/surface-routing.md`
- MCP-only build and deploy contracts: `references/mcp-core-rules.md`
- CLI workflows and output: `references/cli-workflows.md`
- App user authentication and SSO: `references/auth-workflows.md`
- MCP remote operations: `references/mcp-operations.md`
- Recovery and diagnostics: `references/troubleshooting.md`

### Password discovery with agent-ready

`ferrite add agent-ready` (MCP: `local_add`) mounts `/.well-known/change-password` discovery. It advertises only a route the app actually serves: set one via `PageSource::change_password_url()`, or leave the default (`None`) so the endpoint returns 404. Because the `auth` package uses OAuth without passwords, apps using it normally leave the default. Dispatch through `agent_ready::well_known::handle_h` ahead of the catch-all route and emit every returned header. Never request a user's password or pass one through MCP or agent context.

## Accounts, trials and running cost

On Ferrite Cloud, a trial account runs for 48 hours with $50 of credit, one instance per application, 256 MiB of memory, 0.5 vCPU, and a 32 MiB source upload cap. Because trial accounts cannot be topped up, $50 is the hard spend ceiling, and any running apps are withdrawn when the 48 hours end. Size trial workloads to fit. The trial's `claim_url` link keeps it for good: after sign-in, **Keep this as my account** turns it into a permanent account of the person's own with the same apps, URLs and data and no deadline or trial caps; its ID changes from `eph-…` to a readable one, and the CLI login and every connected agent follow. A person who already owns an account picks **Move it into** that account instead, and later agents join it with `ferrite login --sign-in` or the connect page's **Sign in to your Ferrite account** (see `references/cli-workflows.md`). Every new durable account also receives $50 of welcome credit once. Read the live account payload for actual balance and expiry instead of assuming the initial grant remains.

When a durable account's balance hits zero, running apps pause and stay recoverable for 30 days before their data is permanently removed. Trial accounts cannot be funded and suspend as soon as credit runs out. Call `notifications` to inspect platform notices such as low-balance warnings, zero-balance stops, or insufficient-credit refusals.

Durable accounts have no 48-hour expiry. If a stored credential returns HTTP 401 `invalid_token`, follow `references/troubleshooting.md` to re-authenticate cleanly.

Start new applications with a single store whenever data shares permissions, durability, and throughput needs, and separate namespaces with distinct storage prefixes. Before consolidating existing stores, account for existing data, prefix scans, rate ceilings, and sign-in replay state; an idle store can still be required on the next authentication flow.

For small stores, leave `hot_set_gib: 0` (the platform cache default) and set a realistic positive `record_size_kb`. Inflating `volume_mib` merely to clear hot-set validation raises index reservations on every replica, while shrinking `volume_mib` without measured headroom risks write failures when space fills. Remember that omitting `workload` in local source still receives CLI defaults on deploy; preserve required throughput settings explicitly.

Declare worker CPU and memory explicitly. Quote the exact manifest and target replica count with `ferrite cost --instances N` or MCP `estimate_cost`, which reflect live target pricing. Keep unreleased tariff forecasts separate and confirm billed usage through `account_statement` after rollout.

Run `ferrite cost --dir <app-directory> --instances N` before deployment for the live monthly estimate and deploy fee, and `ferrite statement` for metered charges and remaining credit (both accept `--json`). Hosted MCP exposes `estimate_cost` and `account_statement`; `ferrite mcp-serve` exposes `remote_estimate_cost` and `remote_account_statement`. Through `ferrite mcp-serve`, inspect apps with `remote_list_apps` and `remote_describe`, and invoke `remote_rollback`, `remote_scale`, and `remote_withdraw` only with `confirm: true` after explicit user consent. Always report the returned rates and assumptions, since actual traffic and declared resources govern final spend.
