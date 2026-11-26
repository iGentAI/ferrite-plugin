# Auth workflows

User sign-in for an application is handled by the `auth` source package, vendored directly into your crate and invoked from your own request handler. Which routes require a signed-in user is a product decision: a storefront catalogue stays public while account and checkout views do not, and an app with no user accounts needs no sign-in. Ferrite Core does not provide platform-managed auth (no `auth` manifest field, no `/_ferrite/auth` routes, and no gateway-injected identity header), and `ferrite auth` is a retired verb that directs you here. Keep authentication separate from application roles, ownership, and business authorization. Run all commands from the directory holding `ferrite.json`.

## Install and wire

```sh
ferrite add auth
ferrite check
ferrite test
```

`ferrite add auth` vendors OAuth authorization-code login with PKCE, store-backed opaque sessions, a single session cookie (`__Host-ferrite_auth`), CSRF verification, and an access list under `src/auth/`, then prints the crate-root declaration to wire in. Because the command does not edit `ferrite.json` or write secrets, complete the remaining items listed in `src/auth/SETUP.md`:

1. Update `ferrite.json`: every `api` route reaching the auth package or reading a session must forward `cookie`, `origin`, `sec-fetch-site`, `sec-fetch-user`, `sec-fetch-mode`, `sec-fetch-dest`, `x-csrf-token`, `accept`, and `content-type`. Bind a `store` handle and an `egress` handle named `auth-providers` declaring the configured providers' endpoints: GitHub (`https://github.com/login/oauth/access_token`, `https://api.github.com/user`, `https://api.github.com/user/emails`) and Google (`https://oauth2.googleapis.com/token`, `https://www.googleapis.com/oauth2/v3/certs`).
2. Set runtime secrets with `ferrite secrets set <NAME>` (value on stdin) or MCP `set_secret`, then deliver them via `ferrite deploy`: `auth_public_origin` (the exact lowercase origin printed by `ferrite host`, with no path or trailing slash), `auth_session_key` (at least 32 random bytes), `auth_allow` (the access list), and each enabled provider's client ID and secret (`auth_github_client_id`, `auth_github_client_secret`, `auth_google_client_id`, `auth_google_client_secret`). Presence of a client ID activates that provider, and at least one provider is required. Reserve `auth_dev_mode` strictly for plain-HTTP local fleets; never enable it on a public Ferrite host.
3. Register each OAuth client with its provider. On GitHub, create an OAuth app whose callback URL is `<auth_public_origin>/auth/callback/github`; the package requests the `user:email` scope. On Google, create a web OAuth client (`<number>-<hash>.apps.googleusercontent.com`) whose authorised redirect URI is `<auth_public_origin>/auth/callback/google`; the package requests `openid email profile` and accepts an address only when Google marks `email_verified` true. Existing callbacks at custom paths can be preserved through `AuthOptions::callback_paths`.

Wiring auth takes one deploy. The platform derives the hostname deterministically from `<account>/<name>`, so the public origin and OAuth callback URLs are known before the first build. After `ferrite add auth` (which prints the origin, callback URLs, and one `ferrite secrets set` command per missing secret), run `ferrite host` (`--json` returns one object with `origin` and `callbacks`), register the callback URL with the provider, set every secret (`openssl rand -base64 48 | ferrite secrets set auth_session_key` generates a fresh session secret; include `auth_dev_mode` only on a plain-HTTP local fleet), and run `ferrite deploy` once. Deployment refuses with `DEPLOY_AUTH_SECRETS_MISSING` while any secret read by the package is unset. Passing `--allow-missing-secrets` bypasses the refusal and causes gated routes to answer 503 naming the missing secret until secrets are set and redeployed. Over MCP without a CLI, call `app_host {app}` for the origin and callback URLs; `set_secret` works ahead of the first deploy. If `tools/list` omits `app_host`, derive the hostname as described in `mcp-operations.md`, or deploy once, read `host` from `build_status` or `list_apps`, set the secrets, and deploy again. Complete these steps as part of building the app instead of handing setup instructions to the user, and never hard-code fallback values in source.

## Access list

Authentication proves identity; the access list decides who is allowed into the app, and the package requires one. `auth_allow` accepts comma- or whitespace-separated entries: `*` admits any user vouched for by a configured provider (the normal choice for customer-facing products), `@example.com` matches a verified email domain, `alice@example.com` matches a verified address, and `github:<id>` or `google:<sub>` pins a specific account by immutable provider ID for internal tools. `auth_admins` names administrators who can edit a store-backed extension of the list at `/auth/access` without redeploying; that stored extension can add specific entries but never `*`. Administrators are always admitted regardless of list contents, and the list is evaluated on every request.

## Public pages and gated pages

Because Ferrite Core's gateway does not run an authentication layer, the package evaluates every request inside your handler. Invoke `auth.handle` first for the package's own routes, then serve explicitly listed public pages (calling `auth.session` if a public page displays signed-in state), and place `auth.gate` ahead of everything else, including unknown paths, so unlisted routes ask for sign-in instead of leaking. Return any refusal produced by `gate` unchanged:

- No session on browser navigation (`GET` with `accept` containing `text/html`): 303 redirect to `/auth/sign-in?return_to=<path>`.
- No session on any other request: 401 `{"error":"sign_in_required"}`.
- Signed in but absent from the access list: 403 (HTML page for browser navigation, `{"error":"not_on_access_list"}` otherwise).
- State-changing request lacking the session CSRF token in `x-csrf-token` (returned by `GET /auth/session`) or the form-encoded `_csrf` field (`session.csrf_field()`), or originating from another origin: 403 whose body starts with `csrf:`.

Index application data by `session.subject().key()` (`github:<id>` or `google:<sub>`), never by a mutable login handle or email address.

## Verify

Fetch one public route and one gated route without cookies: the public route returns 200 and the gated route returns a 303 to sign-in. Sign in through the real provider on the deployed origin, inspect `GET /auth/session`, execute one state-changing action with the CSRF token, and sign out. Where feasible, confirm that an identity outside `auth_allow` receives 403. Local tests check wiring and code paths, not OAuth provider registration or cookie handling on the live origin.

## Password discovery

`ferrite add agent-ready` mounts `/.well-known/change-password`. It advertises only a route served by the app (`PageSource::change_password_url()`); since the `auth` package uses OAuth without passwords, keep the default (`None`) so discovery returns 404. Never expose credentials or password changes through an MCP tool.

## When the person asks for SSO

The `auth` package supports GitHub and Google sign-in. To restrict an internal tool to a Google Workspace domain, configure Google as the provider and set `auth_allow` to `@yourcompany.com`: Google accounts pass a domain rule only when Google's `hd` claim matches that domain, whereas GitHub accounts match on their verified primary email address.

The `ferrite-sso` package and `ferrite-login` broker are internal to Ferrite's own applications; their shared signing secret makes them unsuitable across mutually untrusted apps. Use the `auth` package directly.
