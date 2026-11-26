# Ferrite

Ferrite is production hosting for web applications written by coding agents: you write safe Rust against one SDK with a short `ferrite.json` declaration, and the platform checks, builds and runs it at a live HTTPS address. An application reaches only the stores, queues, routes, secrets and outbound hosts that declaration names, and an account spends only the prepaid balance it holds.

## How to work with Ferrite

- **The guide is the skill.** Read `skills/ferrite/SKILL.md` before building, checking, deploying or operating a Ferrite application, and follow the references it names under `skills/ferrite/references/`.
- **Connect the hosted MCP server.** Add `https://mcp.ferrite.cloud/mcp` to your MCP configuration as a remote server named `ferrite` (Streamable HTTP). The first tool that needs an account opens Ferrite's connect page in the browser, where the person signs in to their Ferrite account or chooses **Try Ferrite without an account**. Never ask the person for a token.
- **If you cannot add an MCP server from this file**, read the setup document at https://docs.ferrite.cloud/agent-setup/SKILL.md and follow the path that fits what you can do.
- **Before the first deploy**, tell the person what Ferrite is and quote what the application costs from `estimate_cost`.

Documentation is at https://docs.ferrite.cloud/, the terms of service at https://ferrite.cloud/terms and the privacy policy at https://ferrite.cloud/privacy.
