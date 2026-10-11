<!-- Copyright © 2026 Michael Shields -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Releases and updates

GitHub Actions checks every branch and pull request. After release setup, each
passing push to `main` automatically tags the tested commit, builds and verifies
a Homebrew bottle, publishes immutable assets, and opens a formula update in
`shields/homebrew-tap`. The tap checks the bottle and login service before
GitHub auto-merges the pull request.

Versions come from gitcalver as `0.YYYYMMDD.N`, with release tags
`v0.YYYYMMDD.N`. The executable reports both the version and full source
revision. Development builds report `development`; release scripts reject
development versions, pull-request contexts, and mismatched source revisions.

## One-time setup

Local policy leaves GitHub repository creation, settings, and pushes to the
repository owner. Create public repositories `shields/mute-on-lock` and
`shields/homebrew-tap`, add their SSH remotes to the prepared local
repositories, and push the reviewed `main` branches. Publish the tap scaffold
first so the bottle job can tap it. Both repositories use Apache-2.0.

Enable native GitHub auto-merge and squash merges in both repositories. Protect
`main` with pull requests, required checks, and branches that must be up to date
before merging. Required source checks are `Check native service` and
`Check workflow security`; tap checks are `Check tap` and
`Check workflow security`. Use zero required approvals in the tap so passing
formula updates can merge unattended. Restrict tag changes so published version
tags remain immutable. Install Renovate for dependency and action updates.

Create a `release` environment in the source repository, restricted to `main`.
Configure these environment settings:

| Name                  | Kind     | Value                              |
| --------------------- | -------- | ---------------------------------- |
| `TAP_APP_ID`          | Variable | GitHub App ID for tap updates      |
| `TAP_APP_PRIVATE_KEY` | Secret   | Contents of the GitHub App PEM key |

The GitHub App needs repository Contents and Pull requests read/write access,
installed only on `shields/homebrew-tap`. Its short-lived installation token
opens PRs that trigger the tap’s workflow. The source repository’s normal
`GITHUB_TOKEN` cannot access the tap repository. The App private key is the only
configured release secret; no Apple certificate, notarization key, or personal
access token is needed.

Create the App under GitHub Settings → Developer settings → GitHub Apps. Use the
tap repository as its homepage, disable webhooks, and install it only on the
tap. Copy its App ID into `TAP_APP_ID`. Generate a PEM key under Credentials →
Key pairs and upload its entire contents as `TAP_APP_PRIVATE_KEY`.

The physical speaker/headphone lock test must pass before enabling releases. On
2026-10-10, the owner confirmed speaker muting on lock, uninterrupted
headphones, and speakers remaining muted after unlock. Repeat this test after
changes to lock detection or device classification. Hosted CI verifies policy
and cross-process notification delivery; it cannot exercise physical audio.

Set repository variable `RELEASE_ENABLED` to `true` only after the App,
repository settings, and the tap are ready. Merge the next reviewed commit into
`main` to start the first release. Without that variable, CI runs checks and
publishes nothing. The GitHub `xcode-27` Apple Silicon runner has passed this
repository’s native checks.

## Release integrity and reruns

Lint and test dependencies run with read-only repository permissions. Separate
jobs create tags and publish releases. The tap token is limited to its
repository and PR writes. Metadata and release assets pass between jobs by
immutable artifact ID within the same workflow run.

Homebrew builds the executable from the tested source tag and a checksummed
argument-parser resource. The workflow records the installed executable’s
SHA-256, requires a bottle that needs no relocation, pours that bottle, compares
the executable’s bytes, and runs the formula tests. The tap independently checks
the executable checksum and version against published release metadata and tests
service start, restart, and stop. `--build-from-source` remains available.

These releases use the Homebrew formula distribution model. They have no
Developer ID signature or Apple notarization; users trust this repository, its
CI builds, and the checksums in the tap. The tap is independently maintained and
does not receive the review provided by Homebrew’s official repositories.

Published assets are never overwritten. A rerun can replace an incomplete draft;
if the version is already published, it downloads the canonical published
formula and metadata, checks their checksums and source identity, and uses those
for any missing tap PR. An older rerun cannot replace the latest release or
downgrade the tap. Required up-to-date branches and tap checks also reject
obsolete formula PRs.

Each release provides the Homebrew bottle, formula, source identity metadata,
and `SHA256SUMS`. The standard source archive is available from the immutable
version tag. Manual executable ZIP downloads are not part of this release path.

## Updating installations

```sh
brew update
brew upgrade shields/tap/mute-on-lock
brew services restart shields/tap/mute-on-lock
mute-on-lock check
```

The launchd service uses Homebrew’s stable `opt` path. Restart after an upgrade
so the running process uses the new executable. Homebrew owns installation,
login startup, upgrades, and removal. There is no separate background updater.

GitHub Actions keeps the SwiftPM CLI build, release assets, and tap PR in one
workflow. Xcode Cloud requires an Xcode project and App Store Connect app
record, which this CLI does not otherwise need. A future GUI application could
use Sparkle or signed downloads with its own distribution credentials.

## Dotfiles rollout

Dotfiles provisioning upgrades formulae through Homebrew Bundle, which starts
and restarts services declared in the Brewfile. After the first bottle is
published, add the tap and formula to the macOS Brewfile:

```sh
brew bundle add --file=brew/macos.Brewfile --tap shields/tap
brew bundle add --file=brew/macos.Brewfile --formula shields/tap/mute-on-lock
```

Set the formula entry’s service option so Bundle starts the login service and
restarts it when the formula is installed or upgraded:

```ruby
brew "shields/tap/mute-on-lock", trusted: true, restart_service: :changed
```

Plain `brew upgrade` still needs the explicit service restart shown above. There
is no application-specific provisioning hook.

Review the tap’s trust declaration using the existing Brewfile conventions and
commit those entries before running provisioning. Deferring these entries keeps
provisioning usable while the public formula does not exist.

Primary references:
[GitHub runner images](https://github.com/actions/runner-images),
[Homebrew bottles](https://docs.brew.sh/Bottles),
[Homebrew’s distribution trust model](https://docs.brew.sh/Homebrew-Security-and-Supply-Chain),
[Homebrew services](https://docs.brew.sh/Formula-Cookbook#service-files),
[Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile#advanced-brewfiles),
[GitHub App registration](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app),
[GitHub App private keys](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps),
and
[GitHub automatic merges](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-auto-merge-for-pull-requests-in-your-repository).
