# MCP operations

Ferrite's MCP surface is served at `/mcp`, runs sessionlessly, and answers `tools/list` and `tools/call` without a handshake. Classify the target strictly from `tools/list`, never from a version string: Ferrite Core lists `deploy_source` and `build_status`. Do not build against an endpoint exposing `create_source`, `update_source`, `source_operation`, or `mint_token`.

This plugin connects the client straight to the hosted endpoint, and the
client signs in with OAuth when a tool needs an account. The plugin embeds no
credential and reads none from the machine.

Pass credentials via `Authorization: Bearer <token>` whenever the client supports managed headers, and keep tokens out of shell arguments and shared logs.

### Ephemeral account authentication

`provision_ephemeral {}` returns `EphemeralProvisioned.token` for operating calls and `EphemeralProvisioned.claim_token` for migrating the apps later. Store both privately alongside the account ID, endpoint, and expiry before building. Provisioning does not alter the MCP client's active bearer automatically, so authenticate every subsequent account-scoped call against that account explicitly.

Prefer storing the bearer in the client's private credential vault. A hosted MCP client that sends no `Authorization` header can instead pass the supported `token` argument on each account-scoped call. That argument succeeds when it matches the active bearer, while a mismatched bearer fails with `CredentialConflict` and cannot be overridden inline; clear or replace the bearer in client configuration or open a separate connection for the new account. On a headerless connection:

```json
{"name":"deploy_source","arguments":{"token":"<ephemeral token>","spec":"<manifest JSON string>","files":{"Cargo.toml":"<manifest>","src/main.rs":"<source>"}}}
```

```json
{"name":"build_status","arguments":{"token":"<same ephemeral token>","build_id":"<returned build_id>","wait_s":50}}
```

Reuse that same token for `rcs_log`, `test_ref`, `status`, and every other account-scoped tool. After an unauthenticated refusal, fix the credential instead of retrying without it or provisioning a second account. Because tool arguments can be logged in client transcripts, treat those transcripts as private and strip tokens before sharing. Never place a token in application source, URLs, or your reply to the user.

### Dashboard sign-in and durable transfer

When the person mentions an existing Ferrite account, wants to keep the work, wants Dashboard access, or wants Ferrite on another device, call `owner_status` as the current account; an account with no owner gets a fresh private `claim_url`, which works on every trial, including one a connector started. After Google or GitHub sign-in the link offers **Keep this as my account** (the trial becomes a new durable account of the person's own with the same apps, URLs and data and no deadline; its ID changes from `eph-…` to a readable one) or **Move it into** an account that identity already owns (the apps move with their data). Either way every connection and CLI login of the trial follows: the next call may be refused once while the client refreshes its sign-in, and then acts as the new account. Confirm with `owner_status` and `account`, and use the new account ID. These choices appear for trials started by the CLI or by **Try Ferrite without an account**; a trial opened with `provision_ephemeral` keeps its deadline after an owner links, so move its apps with `claim`. An account with an owner needs no link: another agent joins it through **Sign in to your Ferrite account** on Ferrite's connect page, or `ferrite login --sign-in` with the CLI.

A connection that signs in through the browser (a connector, or the remote server added to Claude Code, Codex, Cursor, Gemini or OpenCode) opens Ferrite's connect page on its first account call: **Try Ferrite without an account** starts a trial with $5 of credit, enough to run an app or a few for 48 hours, with no account and no card, and **Sign in to your Ferrite account** reaches an existing one. Such a connection never calls `provision` or `provision_ephemeral`. It is listed under **Connected agents** in the Dashboard, where the person moves it to another account they own or revokes it; to start a fresh trial or use another account, they disconnect Ferrite in the client and connect again.

To move trial applications with the transfer secret instead (a script holding `claim_token`), open a separate MCP connection to the same endpoint authenticated as the target durable account, with that durable credential **already securely stored**, verify its account ID, tier, and balance, and call `claim` with only the trial's private `claim_token` and no `owner_id`. Expect `ClaimedInto`. If the reply drops, preserve both profiles and inspect the destination inventory, original app ID, host, and data before writing again. [Complete procedure](https://docs.ferrite.cloud/developers/mcp-only-operations/#keep-a-trial-app-past-its-48-hours).

## Ferrite Core

The MCP server supports two protocol modes selected per request. Handshake revisions using `initialize` are `2025-11-25`, `2025-06-18`, `2025-03-26`, and `2024-11-05` (unrecognized `initialize` revisions negotiate to `2025-11-25`, and omitted revisions default to `2025-03-26`). Stateless revision `2026-07-28` activates when `params._meta` declares protocol version and client capabilities and the `MCP-Protocol-Version`, `Mcp-Method`, and `Mcp-Name` headers mirror the body; `server/discover` runs under this revision. Unknown protocol revisions return HTTP 400 with `-32022` listing supported versions, and header/body mismatches return HTTP 400 with `-32020`. JSON-RPC batches fail with `-32600`, `GET /mcp` and `OPTIONS` return 405, and `tools/list` returns every tool on a single page and ignores `cursor`. Your MCP client
negotiates the revision with `initialize`.

### Reading a reply

Refusals return `isError: true`; every normal answer, including negative verdicts, returns `isError: false`. Evaluate replies in this order:

1. HTTP 401. Body `{"error":"unauthorized"}` means no bearer was sent. Body `{"error":"invalid_token", ...}` means the `Authorization` bearer does not match an active account (it expired, was revoked, rotated away, or belongs to an account absent from this environment): obtain a fresh credential without retrying (`troubleshooting.md`, "The account, its apps or its data are gone").
2. JSON-RPC `error`: `-32602 unknown tool or invalid arguments` signals a missing tool or bad parameters; `-32601` signals an unsupported method.
3. Tool refusal (`isError: true`), named by the payload's top-level field in `structuredContent` (mirrored as JSON text in `content[0].text`): `Error` (diagnostic message), `Unauthenticated` (an unrecognized `token` argument sent with no `Authorization` header), `NotOwner {app}` (nonexistent app or owned by another account), `Rejected {reasons}`, `QuotaExceeded {resource, requested, cap}`, or `InsufficientCredit`.
4. Lowercase `{"error": "missing 'app'"}`: malformed tool invocation.
5. Negative answer (`isError: false`): a `false` verdict inside a success object (`passed`, `admitted`, `Estimate.spec_valid`, `DomainVerified.verified`), or `build_status` reporting `state` as `failed`, `rejected`, or `stuck`.

`AlreadyProvisioned`, `AlreadyReleased`, and `AlreadyFunded` indicate the state already holds. `AlreadyProvisioned` never includes a token.

### Create and deploy an application

1. Call `account` to verify active identity. On a connection that signs in through the browser, that call opens Ferrite's connect page and you never provision. Provision only on a headerless or scripted connection, for a fresh task with no existing account: `provision {id}` for a durable account (do not pass `credit_micros`, which fails with `TEST_CREDIT_MINT_DISABLED` wherever the test mint is off) or `provision_ephemeral {}` for a trial account. Persist the returned token immediately; it is shown once and cannot be reissued.
2. Author the crate and InfraSpec. Call `read_docs {doc: "page-app-starter"}` (when served) for a verified single-page app with form POST handling and persistent state, or `read_docs {doc: "quickstart"}` for the minimal deployable crate and exact argument shapes. Always serialize `spec` as a JSON string. Omit fields upstream rejects (`auth`, `required_secrets`, `stream_mode`, `forward_headers` on `stream`/`ws` routes, `depends[].native`) and declare `workload` on every service (`{"read_qps": 5, "write_qps": 5, "record_size_kb": 4, "keying": "PerKey", "hot_set_gib": 0}` fits a small app). For random IDs, tokens, or passwords, remember that `ferrite_app::crypto` has no `random_*` API on Ferrite Cloud (and `rand`/`getrandom` are refused by `code_gate`): pass `"packages": ["sha256-hmac"]` to `deploy_source` and use `crate::crypto::random_bytes` / `random_token`, or derive 32 OS-CSPRNG bytes inline with `ferrite_app::crypto::hmac_sha256(&ferrite_app::crypto::Ed25519SigningKey::generate_pkcs8(), b"my-app/token/v1")`. Leave `rate_limit_per_min` unchanged: some Core builds reject it and elsewhere gateway enforcement is not yet verified, so the CLI (`ferrite deploy`, `ferrite check --target upstream`) holds specs declaring it while raw `deploy_source` does not. Never submit a spec containing `rate_limit_per_min` via raw `deploy_source`, and never strip the limit to push a deploy through; report the hold to the user.
3. Call `estimate_cost {spec}` before deployment, verify `spec_valid` is true, and report the monthly estimate and deploy fee to the user ahead of step 5 (`SKILL.md`, "Before you build"). Run `validate_spec {spec}` or `code_gate {files}` when you need admission diagnostics and resolve every violation. Because `deploy_source` runs admission itself, a separate pre-call is optional; avoid sending unchanged source merely to repeat admission. Admission does not compile the crate or execute tests, so keep required exact-revision tests and live HTTP checks intact.
4. Set every secret the app reads via `set_secret {app, name, value}` ahead of the first deploy, since secrets reach workers only through a build. When a secret depends on the generated hostname (such as the `auth` package's `auth_public_origin`), call `app_host {app}` to get `origin` and `callback_urls` before deploying. If `tools/list` omits `app_host`, compute `<shortcode>.<domain>`, where `<domain>` is this MCP host without its `mcp.` prefix and `<shortcode>` is the first 80 bits of `SHA-256(<account>/<name>)` (using the account ID from `account`), read big-endian and encoded as 16 lowercase base-36 digits (`0-9a-z`). If you cannot compute it, deploy once, read `host`, set secrets, and deploy again.
5. Save the request payload locally, then call `deploy_source {spec, files}` ONCE. Persist `BuildStarted.build_id` immediately.
6. Poll `build_status {build_id, wait_s: 50}` until `deployed`, `rejected`, `failed`, or `stuck`; each call waits up to 50 seconds for a state transition, so no sleep loop is needed. If `tools/list` omits `wait_s` on `build_status`, poll every five seconds instead. A `failed` build is undone and refunded; inspect `reasons`. Placement refusals (`"no conductor peer ... standby"`, `"FULL on the rate axis"`) surface only after compilation, and recovering from them requires a new build.
7. Poll `status {app}` until `running >= 1` and the target generation serves traffic, then send a real HTTP request to `host`. Build completion alone is not acceptance.

### Repair an existing application

Preserve the existing account, application name, service names, and security controls. Fetch the current source with `rcs_checkout {app}`; if the client writes a large payload to disk, read only the needed files from that saved file once instead of reprinting or repackaging the full tree.

1. Modify only the authored files required for the fix. Leave unchanged vendored package files untouched in the repository and adapt behavior at the application boundary where possible.
2. Run applicable spec and source checks. Remember that `code_gate` checks source policy, not Rust compilation or runtime behavior.
3. Commit only the modified files via `rcs_commit {app, files, message}`, with each changed file's complete contents. `rcs_commit` overlays the repository head: omitted files remain intact and are not deleted. Keep the manifest intact unless a manifest edit is needed, and confirm its application name matches the target app.
4. Save `RcsCommitted.commit`. Run required tests against that exact commit using `test_ref {app, reference: commit}` and wait for `tested`. Neither `code_gate` nor an alternate deploy path substitutes for a required test verdict.
5. Call `deploy_ref {app, reference: commit}` once. It reads the committed manifest (`spec_path` defaults to `ferrite.json`) and builds the complete tree. Save `BuildStarted.build_id`, poll `build_status`, then verify both the fix and intact existing data at the live host.

This flow trims source upload size without relaxing build, test, authentication, rate, storage, or lifecycle rules. If any reply drops, reconcile its outcome before retrying instead of triggering a duplicate build. Never withdraw a serving app to patch its code.

### When the `deploy_source` reply is lost

Treat the outcome as unknown and never blindly resubmit: upstream carries no idempotency token on `deploy_source`, so a repeat triggers a second charged build.

1. Call `rcs_log {app, limit: 20}`. Because `deploy_source` commits `deploy <build_id>: n file(s)` the moment the operation is minted, an in-flight build appears there immediately while `status`, `list_apps`, and `account_statement` still show nothing.
2. Adopt a candidate build ID only when its mint timestamp (`bj-<epoch ms>-<hex>`, allowing a 10-second margin on either side) falls inside your request window, it is unbound to any earlier attempt, and `build_status {build_id}` names `<account>/<app>`.
3. Follow that build to a terminal state. If two candidates qualify, adopt neither and ask the user to decide. For a changed-source deploy only (never an identical-source redeploy; check step 4 first), if no candidate appears in `rcs_log` within a minute, the request failed to arrive and one fresh `deploy_source` is safe.
4. Redeploying source identical to the previous commit (such as delivering an updated secret) creates no commit, so `rcs_log` stays silent. Check `account_statement` next for `deploy fee build=<id> sha=...`, which lands once the build is charged (a failed build shows a debit paired with a `deploy fee refund` credit).

On current Ferrite Core installations, `preview_ref`, `deploy_release`, `promote`, and `rollback_release` return `BuildStarted {build_id, app}` immediately just like `deploy_source`: persist `build_id`, follow `build_status`, and never resubmit mid-build. On older installations, `preview_ref` and `deploy_release` hold the HTTP request open for the entire build; after a timeout there, inspect `list_apps` and `environments {app}` before calling either again.

### Operating

- `scale {app, instances: 0}` halts traffic while retaining the app (requests answer 504 at the gateway deadline). Scaling back up restarts workers with the context of the last deploy.
- `rollback {app}` restores the previous artifact and returns `Error: ... has no previous artifact` when none exists.
- `withdraw {app}` unpublishes routes and removes the app from `list_apps` while keeping the name reserved to your account.
- `deploy_history`, `releases`, and `environments` track the release pipeline (`cut_release`, `deploy_release`) only; apps shipped via `deploy_source` leave them empty and record history in `rcs_log` and `account_statement`.
- Custom domains: call `claim_domain {domain}` and save `verify_token` (returned once; duplicate claims are refused), run `verify_domain {domain, presented_token}` until `verified: true`, then call `bind_domain {domain, app}`. Publish these DNS records (with `<base>` equal to `ferrite.cloud` on Ferrite Cloud) or hand them to the user: `<domain>` CNAME `<base>` (use ALIAS, ANAME, or a flattened CNAME at the apex), `_acme-challenge.<domain>` CNAME `_acme-challenge.<domain>.acme.<base>`, and `_ferrite-challenge.<domain>` TXT `<verify_token>`. TLS certificates issue within roughly ten minutes once both CNAMEs resolve (retrying hourly on misses); confirm by fetching `https://<domain>/`, since `bind_domain` and `list_domains` reflect stored bindings only. `verify_domain` does not query DNS, claims are first come, first served, and no tool releases a claim. With the CLI, `ferrite domains add <domain>` and `ferrite domains check <domain>` handle the sequence.
- Organisation roles configured via `set_member` do not grant a member's personal token MCP access to the organisation's apps; only `members` responds.

## Additions to Ferrite Core: documentation, packages, hosts, parked apps and links

Ferrite Cloud serves these extra MCP tools beyond upstream Ferrite Core. Check `tools/list` before calling any of them.

- `search_docs {query, limit?}` searches developer docs and support guides without authentication; fetch matches with `read_docs {doc: "<id>"}`. Disambiguate colliding developer page IDs with the `developers/<id>` prefix (for example `developers/quickstart`).
- `list_packages {query?}` and `read_package {name, file?}` inspect published source packages and their guides. Passing `"packages": ["alloy"]` to `code_gate`, `deploy_source`, or `rcs_commit` injects those package files server-side so you do not upload them yourself.
- `app_host {app}` returns an application's hostname, origin, and auth callback URLs ahead of its first deploy.
- `describe_services {app}` lists the services attached to the active deployment.
- `build_status {build_id, wait_s}` accepts `wait_s` from 0 to 50 to long-poll until build state changes.
- `resume {app}` (upstream: `retry_park {app}`) immediately retries a parked application. Expect `ParkRetryStarted {app, generation}` (follow via `status`), `ParkRetryBlocked {...}` (admission still refuses; add credit through `billing_portal` or trim compute), `ParkedMutationRefused {...}` (retry already pending), or `Error` (app is not parked). Apps stopped by a zero balance are not parked (`troubleshooting.md`, "The app stopped serving").
- Replies referencing an app, build, or account include dashboard `links` inside the top-level object. Hand those exact links to the user instead of assembling URLs manually.

## Credentials

`credentials` lists an account's live credentials by digest prefix (never raw tokens) and marks the caller's active credential. `revoke_other_tokens` invalidates every other credential and ends all OAuth sessions. `rotate_token` stages a replacement token that activates only when `confirm_token` is called with the new token as bearer within 15 minutes. OAuth session tokens cannot invoke `revoke_other_tokens`, `rotate_token`, or `confirm_token`. Treat those three operations as destructive: state their impact and ask first.

## Working rules

Treat the full developer manual as a reference index, not required reading up front. Query `search_docs` and read only the specific API, gate, or runtime limit needed for the current step.

Read before mutating. Before asking approval for a destructive tool, state the exact target, effect, idempotency behavior, and recovery path.
