# Troubleshooting

## CLI unavailable or incompatible

Run `scripts/check-cli.sh`. If it returns `missing`, ask approval and run `scripts/install-cli.sh`. If it returns `version_mismatch` or `capability_mismatch` (the binary lacks `ferrite add`), install this plugin's pinned binary beside the older one and put its directory earlier on `PATH`. Unsupported platforms can still run the full workflow over MCP.

## Authentication

Check `ferrite account` first and keep the active account it reports. Only when no account is configured, sign in using one of the forms in `cli-workflows.md` ("Authenticate and deploy"). Missing MCP credentials are a client authentication problem, never a reason to edit `mcp.json` or embed a token. Never paste tokens into plugin files.

## The account, its apps or its data are gone

HTTP 401 `invalid_token` (`Unauthenticated` when sent via the `token` argument), paired with an empty `list_apps` after signing in again, has two normal causes: either a trial account passed its 48-hour window (`expires_at_ms` saved with the credential confirms this), or the stored credential was revoked, rotated, or issued for an account no longer present on that environment. The pinned CLI and `ferrite mcp-serve` detect this directly: they report that the login is unknown to the platform and return `LOGIN_UNKNOWN_TO_PLATFORM` in `ferrite account --json` (or the tool error) with recovery commands in `next`. Tell the user which cause applies and make clear it is not a bug in their application. With their approval, sign in again (`ferrite login --sign-in` for an account they own, `ferrite login` per `cli-workflows.md`, or re-authorize the MCP connection and choose **Sign in to your Ferrite account**) and redeploy from local source; deploying a new revision of your own app never wipes its data. See `SKILL.md`, "Accounts, trials and running cost", for trial bounds, and share [Sign-in stopped working after a platform release](https://docs.ferrite.cloud/kb/guide/sign-in-stopped-working-after-a-platform-release/) when the environment was rebuilt.

## Development server

Always use the exact local URL printed by `ferrite dev`. Passing an occupied port with `--port` exits with an error; when the default port `8787` is busy without `--port`, `ferrite dev` binds the next free port and prints it. Read compiler and child-process diagnostics before restarting. Stop the attached server with Ctrl-C and verify its child processes exited.

## Deployment

Record both the attempt ID printed by `ferrite deploy` and any returned build ID whenever a deploy fails or disconnects. Recover an interrupted deploy with `ferrite deploy resume --attempt <attempt-id>` (omitting `--attempt` selects the project's latest unfinished attempt) instead of submitting again: every fresh submission charges a build, whereas `resume` only reconciles. Treat a build verdict without a bound URL and live HTTP response as incomplete. Follow progress with `status`, `logs` (CLI or MCP), and `build_status` using the saved identifiers.

## The app stopped serving

Inspect `status {app}` and `account`. A stopped application comes from one of two causes, each with a different fix.

If `status` reports `park_phase` and `park_retry_after_ms`, the platform parked the app because workers kept crashing or failed startup preparation. Fix the underlying bug, then invoke `resume {app}` (upstream: `retry_park`) to retry immediately without waiting for backoff. A `ParkRetryBlocked` reply indicates admission still rejects the app: add credit or lower compute resources, then call `resume` again.

If `account` shows a zero balance, the account paused for lack of credit instead of parking. Applications stay stopped while preserving their data for 30 days before permanent deletion. Tell the user and pass them the top-up link from `billing_portal`; never redeploy to work around an empty balance. Once credit is added, the platform restarts each app at its recorded instance count automatically, so `resume` is unnecessary and returns `Error` for unparked apps. Trial accounts cannot be topped up and suspend when their credit runs out. Check `notifications` for low-balance warnings and stop notices, and see `SKILL.md`, "Accounts, trials and running cost", for balance rules and trial limits.

## MCP revision

HTTP 400 with `-32022` ("Unsupported protocol version") means a request sent a revision the server does not accept; the error payload lists supported revisions. Confirm the plugin's MCP server URL is exactly
`https://mcp.ferrite.cloud/mcp`, and do not change the endpoint to a compatibility route. HTTP 400 with `-32020` indicates a mismatch between the `MCP-Protocol-Version` header and `_meta` in the request body.

`-32601 method not found: server/discover` is expected against an older Ferrite Core installation, and `initialize` serves instead. `-32602 unknown tool or invalid arguments` on `create_source`, `mint_token`, or `auth_capability` confirms you are talking to upstream Ferrite Core, where those fork-era tools do not exist; follow `mcp-operations.md`.

## A tool "succeeded" and nothing happened (upstream)

Refusals return `isError: true` with the payload's top-level field naming the cause: `Error`, `Unauthenticated`, `NotOwner`, `Rejected`, `QuotaExceeded`, or `InsufficientCredit`. Negative verdicts leave `isError: false`: `passed`, `admitted`, `spec_valid`, and `verified` can be `false` inside a normal reply, and `build_status` reports failures in `state`. Always inspect the returned payload.

## The deploy reply never arrived (upstream)

Do not submit a second deploy. Call `rcs_log {app}`: any started build appears as the newest commit, `deploy <build_id>: n file(s)`. Track that `build_id` through `build_status` following the reconciliation rules in `mcp-operations.md`.

## A build ended `failed` after minutes (upstream)

A `failed` build is undone and its deploy fee is refunded. `"FULL on the rate axis"` means a service omitted `workload`; declare one on every service (`ferrite deploy` adds defaults automatically, while raw MCP calls need `"workload": {"read_qps": 5, "write_qps": 5, "record_size_kb": 4, "keying": "PerKey", "hot_set_gib": 0}`). `"conductor peer is a standby"` is a transient fleet placement flap: wait briefly and submit a fresh deploy. Neither error indicates a defect in your Rust code.

## Repeated gate or build loops

Save the first failing build ID and read its terminal `reasons`. Never resubmit unchanged source. Map each refusal to a targeted edit, re-run `code_gate` and `validate_spec`, and retry only after both pass. If the same code persists after a fix, inspect the exact submitted file text and manifest instead of rereading the entire guide or scaffolding a new app.

## Missing `ferrite_app::crypto::random_bytes` or `SDK_SYMBOL_ABSENT_UPSTREAM`

Ferrite Cloud's `ferrite_app::crypto` exports `sha256`, `hmac_sha256`, `ct_eq`, `hex`, base64, and JWT/signature keys only — it has no `random_bytes`, `random_fill`, `random_token`, `random_u64`, `EntropyHandle`, `password_*`, or `AppContext::entropy` (even if the local CLI SDK twin compiles them), and `code_gate` refuses `rand`, `getrandom`, and `std::fs`.

Fix any `E0432: unresolved import ferrite_app::crypto::random_bytes` or `SDK_SYMBOL_ABSENT_UPSTREAM` error by switching to one of:

- **Recommended (`sha256-hmac` package):** run `ferrite add sha256-hmac` (or pass `"packages": ["sha256-hmac"]` to MCP `deploy_source`) and call `crate::crypto::random_bytes` / `random_token` / `password_hash` / `constant_time_eq`.
- **Zero-package inline:** derive 32 OS-CSPRNG bytes directly with `ferrite_app::crypto::hmac_sha256(&ferrite_app::crypto::Ed25519SigningKey::generate_pkcs8(), b"my-app/token/v1")` (and encode with `ferrite_app::crypto::base64url_encode` or `ferrite_app::crypto::hex`).

Run `ferrite check --target upstream` before deploying to catch any local-twin-only SDK symbols offline.

## Oversized documentation output

When a tool saves an oversized documentation payload to disk, avoid reading the whole file. Search it for the exact method, type, or gate code blocking your current step and read only the surrounding section.
