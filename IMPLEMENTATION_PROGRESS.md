# Implementation Progress

## Current Focus
- v2.3.0 Portable Desktop is published; monitor first-run installation feedback on additional Windows x64 machines.

## Latest Update - 2026-08-02 23:05
- Scope: Publish v2.3.0 source, normal release assets, and the locally built fixed-version Portable Desktop edition.
- Completed: Pushed source commit `e8455cb` to `main`, tagged `v2.3.0`, completed GitHub Actions run `30752481868`, and uploaded `FluxGate-Codex-Desktop-Portable_2.3.0.exe` with its JSON provenance/hash manifest to `https://github.com/CuizXuan/fluxgate-codex-launcher/releases/tag/v2.3.0`.
- Validation: GitHub Actions rebuilt and validated the normal Launcher/Full assets. GitHub Release reports the Portable asset as 855,639,098 bytes with server digest `sha256:1cac3c055380a98fe12df672161bd2f1b636a151a644af7aa7d85cd8746677cd`, exactly matching the local manifest. The local published artifact passed `--self-test-portable`, archive inspection, and ordinary-directory runtime launch before upload.
- Problems / Blockers: A redundant full download through `gh release download` made no file progress for 16 minutes and was terminated; no partial file or process was retained. Server-side Release size/digest verification succeeded, so this is recorded as a CDN/client transfer limitation rather than an artifact mismatch.
- Not Done: No source or release work remains for v2.3.0. A second-machine public-download/install check remains useful when another clean Windows x64 machine is available.
- Next: Direct offline users to the explicitly labeled Portable asset and retain Full for Store-backed Desktop installation.

## Latest Update - 2026-08-02 22:33
- Scope: Add a locally sourced, version-pinned Codex Desktop payload for users who choose the FluxGateAI portable copy instead of Microsoft Store installation.
- Completed: Added the opt-in local Desktop archive builder, SHA-256 overlay footer, synchronized bootstrapper extraction/self-test, Portable/official/terminal GUI modes, transactional `desktop-app` replacement, installed source-version manifest, GitHub token-aware CLI release lookup, and detailed repository/release documentation. The Desktop payload remains outside git and GitHub Actions.
- Validation: Seven production-contract tests, PowerShell parsing, WPF XAML parsing, native companion integration, online/Full/Portable self-tests, manifest size/hash checks, archive entry/user-data inspection, and a real launch from an extracted ordinary `H:\Temp` directory passed. The final Portable EXE is 855,639,098 bytes with SHA-256 `1cac3c055380a98fe12df672161bd2f1b636a151a644af7aa7d85cd8746677cd`; it contains Desktop source version `26.727.6591.0`, and the paired manifest declares `user_data_included: false`.
- Problems / Blockers: A truly clean Windows machine was not available, but the copied Desktop launched outside WindowsApps with nine portable `ChatGPT`/`codex` processes and an isolated 359-file profile. No implementation blocker remains.
- Not Done: Commit, push, GitHub release/tag, upload of the 816 MiB Portable asset, and independent download verification.
- Next: Commit and push the source branch, publish v2.3.0, upload the locally built Portable EXE plus JSON manifest, then verify the public assets.

## Latest Update - 2026-07-28 15:30
- Scope: Complete the corrected v2.2.0 release and independently verify every public asset.
- Completed: Published commits `eb4feeb` and `0f10e65`, tagged the release commit, completed GitHub Actions run `30337489114`, and released eight public assets at `https://github.com/CuizXuan/fluxgate-codex-launcher/releases/tag/v2.2.0`.
- Validation: Downloaded all public assets. Every local file size and SHA-256 matched the GitHub asset metadata; the public Full EXE was 120,107,520 bytes with SHA-256 `9181045dd0b06ab720323abd312a8d2a3175fc94363707bc1ebc46525f5d3db4`, passed `--self-test-full`, and exposed all five expected embedded resources. The public Bridge and Mobile Web ZIPs contained zero Codex executables or `app.asar` files.
- Problems / Blockers: None.
- Not Done: None for v2.2.0.
- Next: Recommend `FluxGate-Codex-Full_2.2.0.exe` to new Windows x64 users; retain the online Launcher and ZIPs only for advanced/manual deployments.

## Latest Update - 2026-07-28 15:05
- Scope: Build and validate the v2.2.0 Full Launcher requested for users who expect a complete, ready-to-run package rather than a small online bootstrapper.
- Completed: Embedded the exact official x64 Codex CLI ZIP, native companion, GUI installer, NOTICE, and third-party licenses into a 120,105,984-byte Full EXE. Added Microsoft Store Codex Desktop installation/detection, an isolated Desktop profile and `CODEX_HOME`, automatic Desktop plus CLI launch, model restoration, and content scanning for advanced Bridge/mobile ZIPs.
- Validation: Seven production contract tests, PowerShell/XAML parsing, native companion integration, Full/online resource self-tests, ZIP entry and SHA-256 checks, and a real Full GUI upgrade installation passed. The installed Codex CLI 0.145.0 returned `FULL_CLI_OK` through `gpt-5.4-mini`; the installed companion completed the production ticket/WSS/real-CLI loop; and the Store Desktop ran as a second process with the isolated `desktop-data` path while the global `~/.codex/config.toml` remained unchanged.
- Problems / Blockers: Official Codex Desktop is a licensed Microsoft Store MSIX with package identity and cannot be legally or technically repacked as a portable payload; the Full installer handles it through Store product `9PLM9XGG6VKS` instead.
- Not Done: Commit, push, v2.2.0 tag, GitHub Release workflow, and independent public-asset verification.
- Next: Publish v2.2.0, download the public Full EXE, rerun resource checks, and confirm advanced ZIPs remain free of Codex Desktop/CLI payloads.

## Latest Update - 2026-07-28 15:18
- Scope: Repair the v2.2.0 GitHub Release gate after the Full build itself succeeded but the following workflow step could not execute the same large self-extracting EXE a second time on the Windows runner.
- Completed: Kept the executable self-test inside the build step and replaced the cross-step rerun with direct PE Assembly Manifest validation of all five embedded resources and their minimum lengths. Added a production contract assertion for this release gate.
- Validation: The revised gate read the local Full EXE and confirmed the setup script, native companion, 119,947,181-byte official CLI archive, NOTICE, and third-party license resources. All seven contract tests still pass.
- Problems / Blockers: The first two CI attempts failed only at the redundant cross-step EXE invocation; both had already completed the build and its in-step Full self-test successfully, and neither created a GitHub Release.
- Not Done: Push the gate fix, retarget the unpublished v2.2.0 tag, complete the workflow, and verify public assets.
- Next: Publish the corrected tag and independently download and inspect the public Full package.

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

## Latest Update - 2026-07-28 14:15
- Scope: Repair the v2.1.0 first-run CLI failure and make the desktop terminal the primary experience.
- Completed: Replaced the broad Windows ZIP match with the exact official Codex main asset name, preserved all bundled helper executables, added SHA-256 and post-install `codex-cli` validation, automatically repairs incomplete isolated installs, opens the terminal after GUI/CLI installation, and creates one obvious `FluxGateAI Codex` desktop shortcut. The user's existing global Codex remains untouched.
- Validation: The affected local install was repaired with official Codex CLI 0.145.0; `codex doctor` reported 17 OK, 0 warnings, and 0 failures; a real production `gpt-5.4-mini` CLI call returned `CLI_OK`; and the installed tray companion completed a production phone-ticket/device/real-Codex/output/done loop returning `REMOTE_CLI_OK`. PowerShell parsing, six contract tests, companion integration, and the v2.1.1 seven-asset release build passed.
- Problems / Blockers: v2.1.0 can install the wrong executable from the official multi-asset Windows release and does not open the CLI terminal automatically.
- Not Done: Commit, push, v2.1.1 tag, GitHub Release workflow, and published-asset verification.
- Next: Publish v2.1.1 immediately and direct v2.1.0 users to rerun the patch installer for automatic repair.

## Latest Update - 2026-07-28 14:20
- Scope: Publish and independently verify the v2.1.1 CLI repair release.
- Completed: Pushed commit `c9834a4`, tagged `v2.1.1`, and published all seven assets through the Windows release workflow.
- Validation: The public workflow passed; all seven assets downloaded successfully; the public EXE self-test passed; the published GUI script contains the exact official main-asset selector and automatic terminal launch; and the Bridge/mobile ZIPs contain no Codex executable or `app.asar`.
- Problems / Blockers: None in v2.1.1.
- Not Done: None for the v2.1.1 repair release.
- Next: Treat v2.1.1 as the minimum supported Launcher version and monitor first-run downloads on additional Windows architectures.

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
- [x] Publish and verify the v2.1.1 CLI repair release.
- [x] Build, publish, install, and independently verify the v2.2.0 Full Launcher.
