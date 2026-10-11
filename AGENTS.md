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

# Agents

Use [right-answers](https://github.com/shields/right-answers) as the canonical
source for shared conventions, especially `swift.md` and `ci.md`.

Use `make build`, `make test`, `make lint`, `make fmt`, and `make run`. Install
development dependencies with `make setup`.

The service changes only output mute controls. Confirmed headphone outputs must
receive no writes. Unlock never restores sound. Core policy tests use injected
devices; hosted CI cannot establish real screen-lock behavior.

Published releases are immutable. Release versions come from gitcalver at the
tested main-branch commit. Never publish development builds or downgrade the
tap.
