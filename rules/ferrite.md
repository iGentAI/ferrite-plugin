---
trigger: model_decision
description: Use when building, deploying or operating a web app on Ferrite, or when the person asks what Ferrite is or costs.
---

# Ferrite

Ferrite hosts the web applications you build here. This plugin connects you to Ferrite's hosted MCP server (`ferrite`) and adds the `ferrite` skill, which covers building, checking, deploying and operating an application.

- **Signing in.** The first Ferrite tool that needs an account opens Ferrite's connect page in the browser; in Gemini CLI, `/mcp auth ferrite` opens it directly. The person signs in to their Ferrite account with Google or GitHub, or chooses Try Ferrite without an account. Never ask for a token and never call `provision` or `provision_ephemeral` on this connection.
- **A small web app** (a poll, an RSVP page, a sign-up sheet) is one Rust file and one build: `read_docs {"doc":"page-app-starter"}`, adapt it, run `validate_spec` and `code_gate`, call `deploy_source` once, then `build_status` with `wait_s: 50` until it is deployed, and reply with the address it returns.
- **Before the first deploy**, tell the person what Ferrite is and quote what the application costs from `estimate_cost`.
- **Documentation** is available through `search_docs` and `read_docs`, and at https://docs.ferrite.cloud/.
