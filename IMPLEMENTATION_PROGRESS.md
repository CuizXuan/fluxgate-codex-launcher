# Implementation Progress

## Current Focus
- Align Launcher, desktop Bridge, and downloadable mobile web with the production dedicated-key and one-use-ticket contract.
- Use `gpt-5.4-mini` as the default Codex model.

## Latest Update - 2026-07-27 22:55
- Scope: Repair the v2.0.0 production integration and prepare a validated patch release.
- Completed: Confirmed the repository is clean at `v2.0.0`.
- Validation: Pending authenticated production and local release checks.
- Problems / Blockers: The released clients still use the retired access-token/query-token contract.
- Not Done: Source changes, build, release, and final production verification.
- Next: Run a sanitized production baseline, then update all client surfaces and integration fixtures together.

## Latest Update - 2026-07-27 23:31
- Scope: Complete the v2.0.1 dedicated-key/ticket client update and validate release artifacts.
- Completed: Updated the GUI login flow, desktop Bridge authentication, mobile one-use-ticket flow, default model, release version, documentation, production integration snapshots, and contract tests.
- Validation: `build/build-release.ps1 -Version 2.0.1` passed and produced all seven expected artifacts; the 320x640 and 640x320 browser checks passed; the local login, ticket, device discovery, prompt, output, and done flow passed; public server-integration blobs match production revision `44bea1e317d3cded2d9c7ffbe43fdfda74b57c44` exactly.
- Problems / Blockers: None in the Launcher repository.
- Not Done: Commit, push, tag, GitHub Release workflow, and final published-asset verification.
- Next: Finish the companion Switch and APK patch releases, then publish and verify all three repositories together.

## Open Issues
- [x] GUI account login consumes `data.api_key` directly.
- [x] Desktop Bridge authenticates WSS with the dedicated API key header.
- [x] Mobile web mints and consumes one-use Bridge tickets.
- [x] Local release assets build successfully.
- [ ] Publish and verify the v2.0.1 GitHub Release assets.
