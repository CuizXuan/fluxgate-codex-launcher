# Implementation Progress

## Current Focus
- Integrate the desktop Bridge into the Windows Launcher as a background companion with no Node.js or terminal workflow.
- Reuse the isolated Launcher credentials and `CODEX_HOME`, add project selection and startup registration, and keep the legacy ZIPs only for advanced use.

## Latest Update - 2026-07-28 12:00
- Scope: Replace the multi-terminal Launcher + Node Bridge flow with a beginner-ready integrated Windows experience.
- Completed: Confirmed the current Launcher and Bridge repositories are clean and identified the shared-binary/isolated-config boundary and the stuck Windows sandbox bootstrap observed during real use.
- Validation: Current production Bridge endpoint remains reachable; implementation validation is pending.
- Problems / Blockers: The v2.0.1 Bridge requires Node.js, a separate terminal, a second login, and one `codex exec` process per prompt.
- Not Done: Native companion implementation, installer integration, build, runtime tests, release, and production verification.
- Next: Build the native background companion and wire it into the GUI installer.

## Latest Update - 2026-07-28 12:55
- Scope: Complete the integrated v2.1.0 Windows beginner flow.
- Completed: Added the embedded native tray companion, single-login credential reuse, project selection, startup registration, dedicated standalone Codex CLI installation, explicit unelevated `workspace-write` sandboxing, dedicated-Key validation, and APK-native ticket support in the mobile page. Legacy Node/mobile ZIPs remain advanced assets.
- Validation: PowerShell/XAML parsing passed; the release build produced seven assets; the companion self-test and local WebSocket/process integration passed; `codex doctor --strict-config` accepted the sandbox setting; a real Codex `SANDBOX_OK` run completed without elevated sandbox setup; and the native companion completed the production ticket/device/prompt/output/done WSS loop.
- Problems / Blockers: None in the Launcher repository.
- Not Done: Commit, push, v2.1.0 tag, GitHub Release workflow, and published-asset verification.
- Next: Publish v2.1.0 after the paired APK commit is ready.

## Latest Update - 2026-07-28 13:10
- Scope: Publish and independently verify the integrated v2.1.0 Launcher.
- Completed: Pushed commit `59f77e0`, tagged `v2.1.0`, and published all seven assets through the Windows release workflow.
- Validation: The public release workflow passed; all seven published assets downloaded successfully; the published EXE embedded-resource self-test passed; and the published Bridge/mobile ZIPs contain no Codex executable or `app.asar`.
- Problems / Blockers: None.
- Not Done: None for v2.1.0.
- Next: Monitor first-run installation feedback and keep the native companion contract covered by local and production smoke tests.

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

## Latest Update - 2026-07-28 01:39
- Scope: Publish and verify v2.0.1.
- Completed: Pushed commit `a98231a`, tagged `v2.0.1`, and published the GitHub Release through the Windows workflow.
- Validation: The release workflow passed; all seven assets downloaded successfully; the published EXE self-test passed; Bridge/mobile ZIPs contain no Codex executable or `app.asar`; final production login, model-list, Chat, Responses, and Bridge-ticket smoke checks passed.
- Problems / Blockers: None.
- Not Done: None for v2.0.1.
- Next: Monitor normal user feedback and keep future desktop/mobile protocol changes covered by the production contract test.

## Open Issues
- [x] GUI account login consumes `data.api_key` directly.
- [x] Desktop Bridge authenticates WSS with the dedicated API key header.
- [x] Mobile web mints and consumes one-use Bridge tickets.
- [x] Local release assets build successfully.
- [x] Publish and verify the v2.0.1 GitHub Release assets.
- [x] Embed a no-terminal native companion in the Launcher.
- [x] Stop reusing or updating the user's global Codex CLI.
- [x] Validate the native companion against the production Bridge.
- [x] Publish and verify the v2.1.0 GitHub Release assets.
