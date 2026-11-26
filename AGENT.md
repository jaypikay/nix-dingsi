# Instructions for coding agents

These instructions apply to the whole repository. See `README.md` for detailed
examples and package-specific updater commands.

## Repository model

- `flake.nix` is the canonical entry point. It exposes packages as
  `packages.<system>.<name>` and modules as `nixosModules`.
- `pkgs/default.nix` registers packages with `pkgs.callPackage`. Package
  definitions live in `pkgs/<name>/package.nix`.
- `default.nix` supports non-flake `nix-build -A <name>` commands, but uses
  `<nixpkgs>` rather than the flake lock by default. Prefer flake commands.
- `modules/default.nix` imports NixOS modules and `lib/default.nix` contains
  shared functions.
- The declared formatter is Alejandra; run `nix fmt` after changing Nix files.

Keep changes scoped. Do not overwrite, delete, or stage unrelated user work.
Do not commit unless the user asks. Do not add generated `result` symlinks.

New files must be known to Git before a local flake can access them. When adding
files, use `git add -N <path>` to mark intent-to-add if staging content is not
desired.

## Making package changes

1. Read the complete package definition before editing it. Identify every
   version, immutable source revision, fixed-output hash, updater, and test.
2. Preserve the existing builder, platform restrictions, and code style unless
   the task requires changing them.
3. For a new package, add `pkgs/<name>/package.nix`, register it in
   `pkgs/default.nix`, and provide accurate metadata and `meta.mainProgram`
   where applicable. Add tests and an update script when practical.
4. Update version, source revision/tag, release metadata, and all affected hashes
   together. Never point to a moving branch when an immutable release or commit
   is available.
5. Build and test the result. Evaluation alone is not a build, and a build alone
   is not a passing integration test.

## Update commands

Run from the repository root. Replace example versions rather than using them
literally.

```sh
# Silverbullet: refreshes all platform-specific sources.
nix run .#silverbullet.updateScript -- <new-version>

# Stash: discovers the latest release and updates release metadata and hashes.
./pkgs/stash/update.sh

# Update the locked nixpkgs input; validate all affected packages afterwards.
nix flake update
```

For Stash, set `GITHUB_TOKEN` if GitHub API rate limits interfere. Its updater
updates `version`, `appDate`, and `gitHash`; still inspect `srcHash`,
`vendorHash`, and `fetchPnpmDeps.hash`, and refresh the pnpm hash manually if
needed.

Manual package-specific requirements:

- `controld-exporter`: update `version` and the full commit in `src.rev`, then
  refresh `src.hash` and, when Go dependencies change, `vendorHash`.
- `whisparr`: update `version` and the top-level `hash`; only `x86_64-linux` is
  currently supported.
- `silverbullet`: when not using its updater, update every affected
  `passthru.sources.<system>.hash`, not just the host platform's hash.
- `stash`: source, Go vendor, and frontend pnpm dependencies have independent
  hashes. Keep `pnpmHash` consistent with `fetchPnpmDeps.hash`.

## Hash refresh procedure

Use Nix's fixed-output hash mismatch rather than guessing a prefetch command:

1. Change the source/version as required.
2. Replace only the affected hash with `lib.fakeHash`.
3. Run `nix build .#<package> -L --no-link`.
4. Copy the complete SRI value from the **`got:`** line into the definition.
   Never copy the `specified:` value.
5. Rebuild. Repeat for remaining source or dependency hashes one at a time.

Use the same procedure for `vendorHash = lib.fakeHash;` and for `hash` inside
`fetchPnpmDeps`. For a platform-specific source, build the explicit output, for
example `nix build .#packages.aarch64-linux.silverbullet -L --no-link`. A foreign
platform may require an appropriate remote builder.

Never leave `lib.fakeHash`, an empty hash, or a knowingly incorrect old hash in
a completed change. Do not weaken fetcher verification to bypass a mismatch.

## Required validation

Use the locked flake and show build logs:

```sh
nix build .#<package> -L
```

Run all applicable declared tests for a changed package:

```sh
nix build .#stash.tests.version -L --no-link
nix build .#stash.tests.stash -L --no-link
nix build .#silverbullet.tests.silverbullet -L --no-link
```

Whisparr's intended test command is
`nix build .#whisparr.tests.smoke-test -L --no-link`, but it currently fails at
evaluation because the locked nixpkgs does not provide `nixosTests.whisparr`.
Fix the reference in `pkgs/whisparr/package.nix` before expecting that test to
run; do not report it as passing.

The NixOS tests require Linux and suitable VM support and can be slow.
`controld-exporter` has no declared package test, so build it and smoke-test its
binary where practical. `passthru.tests` are not wired into a flake `checks`
output; `nix flake check` does not run them automatically. Always build this
flake's package directly because inherited nixpkgs NixOS tests may exercise the
nixpkgs package instead.

Before finishing:

```sh
nix fmt
nix flake check
git diff --check
git status --short
```

Review the final diff for unintended edits, stale metadata, and fake hashes. In
the final response, list the builds/tests that passed and explicitly identify
anything not run because of platform, VM, network, or time constraints. Never
claim an unexecuted test passed.
