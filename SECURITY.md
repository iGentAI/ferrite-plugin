# Security

Report a security problem in this plugin, in the Ferrite command-line tool or in the hosted Ferrite platform to security@ferrite.cloud. Please do not open a public issue for it.

Include what you found, the steps that reproduce it, the plugin version from `VERSION`, and the agent and operating system you used. If the report concerns a deployed application, name its address.

This repository holds text only: the skill, the agent manifests and three shell scripts under `skills/ferrite/scripts/`. The installer downloads the Ferrite CLI from `https://downloads.ferrite.cloud` and refuses an archive whose SHA-256 differs from the checksum pinned in `skills/ferrite/scripts/SHA256SUMS`. A mismatch between a published archive and that file is worth a report.
