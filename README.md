<!--
Copyright © 2026 Michael Shields

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Mute on lock

Mute your Mac’s speakers when the screen locks, while leaving headphones
playing. Requires Apple Silicon and macOS 27.

The service watches both the default output and the system sound output. It also
watches device changes while locked, so disconnecting headphones mutes the newly
selected speakers. Unlocking leaves them muted; unmute manually when you want
sound again. Volume levels and microphones are untouched.

```sh
brew install shields/tap/mute-on-lock
brew services start shields/tap/mute-on-lock
mute-on-lock check
```

`check` reports the session state, output transports, and mute capabilities
without changing audio. `run` runs the service in the foreground. To inspect
errors, use
`log show --last 10m --predicate 'subsystem == "dev.msrl.mute-on-lock"'`.

```sh
brew upgrade shields/tap/mute-on-lock
brew services restart shields/tap/mute-on-lock
brew services stop shields/tap/mute-on-lock
```

Homebrew owns the login service; run these commands as your login user.
Applications that explicitly route sound to a different output are outside the
default-output policy. Speaker or unidentified devices without a complete
writable mute control cause a visible error and service restart; the service
never substitutes volume changes for muting.

## Device detection and overrides

CoreAudio stream terminal types distinguish headphones from speakers. For
built-in outputs, the selected hardware data source identifies the current
route. Connection type and device names never imply a headphone exemption.
Outputs with unknown or mixed types are muted.

Run `mute-on-lock check` to see each output’s UID and effective type. If a
device reports its type incorrectly, set an override using that stable UID:

```sh
mute-on-lock override "DEVICE_UID" headphones
mute-on-lock override "DEVICE_UID" speakers
mute-on-lock override "DEVICE_UID" auto
brew services restart shields/tap/mute-on-lock
```

`auto` removes an override. Preferences use macOS UserDefaults in the
`dev.msrl.mute-on-lock` domain. Inspect them with
`defaults read dev.msrl.mute-on-lock`; macOS manages the underlying plist.

## Development

Install Xcode 27, Bun, Lefthook, ShellCheck, shfmt, zizmor, ripgrep, and jq,
then run `make setup`. Use `make build`, `make test`, `make lint`, and
`make fmt`. `make run` starts the foreground service. Tests use Swift Testing
and run with coverage. Development binaries identify themselves as development
builds.

Release automation and installation updates are documented in
[Releases and updates](docs/releases.md). GitHub Actions builds and checks the
SwiftPM executable; signed releases begin after the one-time setup.

Copyright © 2026 Michael Shields. Licensed under Apache-2.0; see
[LICENSE](LICENSE).
