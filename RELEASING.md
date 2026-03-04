# Releasing `ACPSwiftSDK`

This document defines the release contract for publishing the Swift package.

## Release Contract

- Stable releases only.
- Tag format must be `vMAJOR.MINOR.PATCH`.
- The tag commit must be reachable from `main`.
- Release publication requires green `swift build` and `swift test` in GitHub Actions.
- GitHub Release notes are auto-generated.

## Operator Runbook

1. Confirm your local `main` branch is up to date.
2. Run preflight checks:
   ```bash
   swift build
   swift test
   ```
3. Maintain `CHANGELOG.md` with an active `## [Unreleased]` section during development.
4. Choose the next semantic version, for example `v0.2.0` (changelog version is `0.2.0`).
5. Promote `Unreleased` to the release version before tagging:
   ```bash
   bash scripts/update-changelog.sh 0.2.0 2026-03-04
   ```
6. Ensure the Git tag version matches the changelog version exactly (`v0.2.0` ↔ `0.2.0`).
7. Create an annotated tag:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   ```
8. Push the tag:
   ```bash
   git push origin vX.Y.Z
   ```
9. Verify the `Release` workflow succeeded in GitHub Actions.
10. Verify the GitHub Release exists and includes generated notes.

## Rejected Tags

The release workflow fails for:

- malformed tags, such as `v1`, `1.2.3`, `v1.2.3.4`
- prerelease tags, such as `v1.2.3-rc.1`
- tags not reachable from `origin/main`
- tags where build or tests fail

## Rollback

If a release tag was wrong:

1. Delete the GitHub Release in the repository Releases UI.
2. Delete the local tag:
   ```bash
   git tag -d vX.Y.Z
   ```
3. Delete the remote tag:
   ```bash
   git push --delete origin vX.Y.Z
   ```
4. Create and push the corrected tag.

## Repository Settings

Apply these repository settings in GitHub:

1. Protect `main` and require pull requests.
2. Require status check `build-and-test`.
3. Restrict tag push permissions if your organization policy supports it.
