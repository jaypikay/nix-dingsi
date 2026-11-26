# nix-dingsi

Nix packages, library functions, and NixOS modules used in the goatseverse.

## Repository layout

- `flake.nix`: pinned `nixpkgs` input and flake outputs. Packages are exposed as
  `packages.<system>.<name>`; NixOS modules are exposed through `nixosModules`.
- `default.nix`: non-flake entry point. It also exposes package names at the top
  level, so `nix-build -A stash` works.
- `pkgs/default.nix`: package registry. Every package must be added here with
  `pkgs.callPackage`.
- `pkgs/<name>/package.nix`: package definition and, where appropriate, its
  update script and tests.
- `modules/`: NixOS modules, imported by `modules/default.nix`.
- `lib/`: shared library functions.

Flake commands use the locked `nixpkgs` revision in `flake.lock`. Commands using
`default.nix` use `<nixpkgs>` from `NIX_PATH` unless `pkgs` is supplied, so their
results can differ. Prefer flake commands for reproducible development.

## Prerequisites and routine commands

Install Nix with the `nix-command` and `flakes` experimental features enabled.
Run commands from the repository root.

```sh
# List available outputs for the current system.
nix flake show

# Format Nix files with the formatter declared by the flake.
nix fmt

# Evaluate flake outputs. This is not a substitute for the package tests below.
nix flake check

# Build a package, show its logs, and create ./result.
nix build .#stash --print-build-logs

# Build without creating a result symlink.
nix build .#stash -L --no-link

# Select a particular system explicitly.
nix build .#packages.x86_64-linux.silverbullet -L
```

There is no default package, so use an explicit attribute such as `.#stash`
rather than `.#`. After a build, inspect `./result/bin` and run the program's
version or help command where supported. Some packages are services, so do not
run them without suitable configuration.

For non-flake use:

```sh
nix-build -A stash
nix-build -A silverbullet
```

A build for another architecture or operating system requires a compatible
local or remote builder. In particular, NixOS VM tests require Linux and may
need working KVM/VM support.

## Adding, changing, or removing a package

To add a package:

1. Create `pkgs/<name>/package.nix`. Accept dependencies as function arguments
   and build with the appropriate nixpkgs builder.
2. Set an accurate `pname`, `version`, source, hash, and `meta` information,
   including `meta.mainProgram` when the package provides a main executable.
3. Register the package in `pkgs/default.nix`:

   ```nix
   <name> = pkgs.callPackage ./<name>/package.nix {};
   ```

4. Add `passthru.tests` and an `updateScript` when useful.
5. Build and test the package before submitting the change.

Use the package attribute name consistently in the registry and updater. Keep
source revisions immutable: prefer a release tag or full commit hash over a
moving branch. Do not disable a dependency hash just to make a build succeed.

To remove a package, remove both its registry entry and its package directory,
then run `nix flake show` and `nix flake check` to catch stale references.

**Flakes only include files known to Git.** After creating files, add them to
Git's index before expecting flake commands to see them. `git add -N <path>` is
sufficient to mark a new file as intent-to-add without staging its contents.

## Updating a package

First inspect the package definition to identify its version/revision and every
fixed-output hash. Update the version or source revision, refresh all affected
hashes, and then rebuild. A source update often changes dependency hashes even
when the package definition itself is otherwise unchanged.

### Packages with update support

**Silverbullet** has an updater that refreshes every platform-specific source
hash. Pass the new version explicitly:

```sh
nix run .#silverbullet.updateScript -- 3.0.2
```

Review the resulting diff and build each platform you can support. Its source
hashes live under `passthru.sources`.

**Stash** declares `pkgs/stash/update.sh` as its update script. Run it directly
to update to the latest GitHub release:

```sh
./pkgs/stash/update.sh
```

The script updates `version`, `appDate`, and `gitHash`, then invokes
`nix-update`. Set `GITHUB_TOKEN` if unauthenticated GitHub API requests are rate
limited. Review the source and Go dependency changes, and check the pnpm hash
separately; a frontend dependency update can require a manual pnpm refresh.
For a specific release or a partial update, use the manual procedure below.

### Manual version and source updates

**controld-exporter:** update `version`, set `src.rev` to the corresponding
immutable upstream commit, refresh `src.hash`, and then refresh `vendorHash` if
Go dependencies changed.

**whisparr:** update `version` and the top-level `hash`. Its release URL uses
that version automatically. It currently supports only `x86_64-linux`.

For other manual updates, change `version`, `rev`/`tag`, and any release metadata
together. Never update only a URL while leaving an old hash in place.

### Refreshing hashes

The most reliable general method is to let the fixed-output derivation report
the new hash. This handles normalization performed by fetchers such as
`fetchzip` and avoids accidentally hashing a ZIP file when Nix expects the hash
of its unpacked contents.

1. Temporarily replace the old value with `lib.fakeHash`, for example:

   ```nix
   src = fetchFromGitHub {
     # owner, repo, and rev/tag remain unchanged
     hash = lib.fakeHash;
   };
   ```

   For a Go module use `vendorHash = lib.fakeHash;`; for pnpm dependencies set
   `hash = lib.fakeHash;` inside `fetchPnpmDeps`.

2. Build and read the mismatch:

   ```sh
   nix build .#<package> -L --no-link
   ```

   Copy the SRI hash from the **`got:`** line, not the `specified:` line.

3. Replace `lib.fakeHash` with that value and build again. Repeat for each
   remaining fixed-output hash, preferably one at a time. Never leave a fake or
   empty hash in the finished change.

Hash fields commonly used in this repository:

| Hash | When to refresh it |
| --- | --- |
| `src.hash`, or a top-level `hash` inherited by `src` | Upstream source, tag, commit, version, or URL changed |
| `vendorHash` | Go source or `go.mod`/`go.sum` dependencies changed |
| `fetchPnpmDeps.hash` | Frontend source, pnpm lockfile, or dependencies changed |
| `passthru.sources.<system>.hash` | The Silverbullet release for that system changed |

Stash has all three kinds of dependency/source hash: `srcHash`, `vendorHash`,
and the hash inside `fetchPnpmDeps`. Keep its top-level `pnpmHash` value in sync
with the actual `fetchPnpmDeps.hash` value when refreshing the frontend hash.
For multi-platform packages, select the output explicitly while refreshing a
platform hash, for example:

```sh
nix build .#packages.aarch64-linux.silverbullet -L --no-link
```

Do not assume a successful build on one platform validates the source hashes of
all other platforms.

## Building and testing changes

Always build the changed package with the locked flake inputs:

```sh
nix build .#<package> -L
```

Then run its applicable `passthru.tests`. The currently declared tests are:

```sh
# Fast executable version test.
nix build .#stash.tests.version -L --no-link

# NixOS VM integration tests.
nix build .#stash.tests.stash -L --no-link
nix build .#silverbullet.tests.silverbullet -L --no-link
```

Whisparr declares its test as `whisparr.tests.smoke-test`, but that attribute
currently fails during evaluation because the locked nixpkgs no longer provides
`nixosTests.whisparr` (it provides versioned alternatives such as
`whisparr_2`). Correct the reference in `pkgs/whisparr/package.nix` before
running:

```sh
nix build .#whisparr.tests.smoke-test -L --no-link
```

`controld-exporter` currently has no package test attribute; at minimum, build
it and smoke-test the resulting exporter binary where practical. Always perform
the direct package build as well: inherited nixpkgs NixOS tests can exercise the
package from nixpkgs rather than this flake's derivation.

Tests in `passthru.tests` are **not** automatically run by `nix flake check`
because this flake does not expose a `checks` output. Run them explicitly. If a
test cannot run on the current host, say so rather than treating evaluation as
a passing test.

Before finishing a package change:

```sh
nix fmt
nix flake check
git diff --check
git diff -- pkgs/<name> flake.lock
```

Check that the diff contains only intended version/source/hash changes, no fake
hashes, and no generated `result` symlink. Report exactly which builds and tests
were run and which were skipped.

## Updating nixpkgs

Update `flake.lock` as a separate maintenance operation when possible:

```sh
nix flake update
nix flake check
```

A nixpkgs update can change builders and transitive dependencies for every
package, so rebuild all packages supported by the current host and rerun their
tests. Do not treat a nixpkgs-only update as validated merely because the lock
file was generated successfully.
