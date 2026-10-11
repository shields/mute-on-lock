<!-- Copyright © 2026 Michael Shields -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Releases and updates

GitHub Actions checks every branch and pull request. After release setup, each
passing push to `main` automatically tags the tested commit, signs and notarizes
its executable, builds a Homebrew bottle, publishes immutable assets, and opens
a formula update in `shields/homebrew-tap`. The tap checks the bottle before
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
`Check workflow security`. Restrict tag changes so published version tags remain
immutable. Install Renovate for dependency and action updates.

Create a `release` environment in the source repository, restricted to `main`.
Configure these environment secrets and variables:

| Name                           | Kind     | Value                                                                                    |
| ------------------------------ | -------- | ---------------------------------------------------------------------------------------- |
| `SIGNING_CERTIFICATE_P12`      | Secret   | Base64-encoded Developer ID Application certificate and private key, exported as PKCS#12 |
| `SIGNING_CERTIFICATE_PASSWORD` | Secret   | Password for the PKCS#12 export                                                          |
| `NOTARY_API_PRIVATE_KEY`       | Secret   | Contents of the App Store Connect API `.p8` key                                          |
| `NOTARY_KEY_ID`                | Secret   | API key ID                                                                               |
| `NOTARY_ISSUER_ID`             | Secret   | API issuer ID                                                                            |
| `DEVELOPER_TEAM_ID`            | Variable | Apple Developer team ID matching the signing certificate                                 |
| `TAP_APP_ID`                   | Variable | GitHub App ID for tap updates                                                            |
| `TAP_APP_PRIVATE_KEY`          | Secret   | GitHub App private key                                                                   |

The GitHub App needs repository Contents and Pull requests read/write access,
installed only on `shields/homebrew-tap`. Its short-lived installation token
opens PRs that trigger the tap's workflow. The source repository's normal
`GITHUB_TOKEN` cannot trigger a second workflow when it writes to another
repository. No long-lived personal access token is needed.

The signing job imports the certificate into a temporary keychain, validates the
Developer ID identity and team, signs with hardened runtime and a timestamp, and
submits the ZIP to Apple's notary service. It requires an accepted result and a
successful notarization-ticket check. A bare command-line executable and its ZIP
cannot be stapled; assessment can contact Apple for the notarization ticket.

The physical speaker/headphone lock test must pass before enabling releases. On
2026-10-10, the owner confirmed speaker muting on lock, uninterrupted
headphones, and speakers remaining muted after unlock. Repeat this test after
changes to lock detection or device classification. Hosted CI verifies policy
and cross-process notification delivery; it cannot exercise physical audio.

Set repository variable `RELEASE_ENABLED` to `true` only after credentials,
repository settings, and the tap are ready. Push the next reviewed `main` commit
to start the first release. Without that variable, CI runs checks and publishes
nothing. The current GitHub `xcode-27` Apple Silicon runner is a preview image;
confirm it is available for the repository before enabling releases.

## Release integrity and reruns

Lint and test dependencies run with read-only repository permissions. Separate
jobs create tags and publish releases. Signing credentials are available only to
the signing step. The tap token is limited to its repository and PR writes.
Artifacts are passed by immutable artifact ID within the same workflow run.

The bottle contains the exact signed executable from the notarized ZIP. The
workflow requires `any_skip_relocation`, pours the bottle, compares the
executable's SHA-256, and verifies its signature and notarization-ticket check.
Homebrew may relocate unsigned source builds, so only the prebuilt bottle is the
signed release artifact. `--build-from-source` remains available for developers.

Published assets are never overwritten. A rerun can replace an incomplete draft;
if the version is already published, it downloads the canonical published
formula and metadata, checks their checksums and source identity, and uses those
for any missing tap PR. An older rerun cannot replace the latest release or
downgrade the tap. Required up-to-date branches and tap checks also reject
obsolete formula PRs.

Each release provides a signed ZIP, the Homebrew bottle, formula, source
identity metadata, and `SHA256SUMS`. Signature verification authenticates the
executable; the checksums also catch asset corruption. The standard source
archive is available from the immutable version tag.

## Updating installations

```sh
brew update
brew upgrade shields/tap/mute-on-lock
brew services restart shields/tap/mute-on-lock
mute-on-lock check
```

The launchd service uses Homebrew's stable `opt` path. Restart after an upgrade
so the running process uses the new executable. Homebrew owns installation,
login startup, upgrades, and removal. There is no separate background updater.

| Option                       | Fit for this project                                                                  |
| ---------------------------- | ------------------------------------------------------------------------------------- |
| Homebrew formula and bottles | Chosen: integrates the CLI and per-user launchd service with normal provisioning      |
| Sparkle                      | Appropriate for a future GUI app; adds a second update system and signing keys        |
| Signed ZIP downloads         | Available for manual installation; users manage launchd and upgrades                  |
| Mac App Store                | Requires an app packaging and distribution model; adds review and sandbox constraints |

GitHub Actions keeps the SwiftPM CLI build, release assets, and tap PR in one
workflow. Xcode Cloud is an option for an Xcode app project, but does not remove
the need for GitHub release and Homebrew automation here.

## Dotfiles rollout

Dotfiles provisioning upgrades formulae through Homebrew Bundle, which starts
and restarts services declared in the Brewfile. After the first bottle is
published, add the tap and formula to the macOS Brewfile:

```sh
brew bundle add --file=brew/macos.Brewfile --tap shields/tap
brew bundle add --file=brew/macos.Brewfile --formula shields/tap/mute-on-lock
```

Set the formula entry's service option so Bundle starts the login service and
restarts it when the formula is installed or upgraded:

```ruby
brew "shields/tap/mute-on-lock", trusted: true, restart_service: :changed
```

Plain `brew upgrade` still needs the explicit service restart shown above. There
is no application-specific provisioning hook.

Review the tap's trust declaration using the existing Brewfile conventions and
commit those entries before running provisioning. Deferring these entries keeps
provisioning usable while the public formula does not exist.

Primary references:
[GitHub runner images](https://github.com/actions/runner-images),
[Homebrew bottles](https://docs.brew.sh/Bottles),
[Homebrew services](https://docs.brew.sh/Formula-Cookbook#service-files),
[Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile#advanced-brewfiles),
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[Apple release testing](https://developer.apple.com/forums/thread/130560), and
[GitHub automatic merges](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-auto-merge-for-pull-requests-in-your-repository).
