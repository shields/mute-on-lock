#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/mute-on-lock-bottle-test.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT
mkdir -p "$test_directory/tools" "$test_directory/bin" "$test_directory/dist"
cp tools/release-lib.sh tools/bottle.sh "$test_directory/tools/"
export MOCK_BREW_ROOT=$test_directory
export GITHUB_ACTIONS=true GITHUB_REPOSITORY=shields/mute-on-lock GITHUB_REF=refs/heads/main
export GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export PATH=$test_directory/bin:$PATH
jq --null-input --arg revision "$GITHUB_SHA" '{version:"0.20261111.1",revision:$revision}' >"$test_directory/dist/release.json"
printf '# fixture formula\n' >"$test_directory/dist/mute-on-lock.rb"
cat >"$test_directory/bin/brew" <<'BREW'
#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
root=$MOCK_BREW_ROOT
case $1 in
 tap) ;;
 --repository) printf '%s/tap\n' "$root" ;;
 trust) touch "$root/trusted" ;;
 style | audit | test) test -f "$root/trusted" ;;
 install)
  test -f "$root/trusted"
  mkdir -p "$root/prefix/bin"
  printf '#!/bin/bash\nprintf "0.20261111.1 (aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)\\n"\n' >"$root/prefix/bin/mute-on-lock"
  chmod +x "$root/prefix/bin/mute-on-lock"
  ;;
 --prefix) printf '%s/prefix\n' "$root" ;;
 uninstall) rm "$root/trusted" ;;
 bottle)
  if [[ $2 == --json ]]; then
   printf fixture >mute-on-lock--0.20261111.1.arm64_golden_gate.bottle.tar.gz
   printf '%s\n' '{"shields/tap/mute-on-lock":{"bottle":{"cellar":"any_skip_relocation","tags":{"arm64_golden_gate":{"filename":"mute-on-lock-0.20261111.1.arm64_golden_gate.bottle.tar.gz"}}}}}' >mute-on-lock--0.20261111.1.arm64_golden_gate.bottle.json
  fi
  ;;
 *) printf 'Unexpected brew invocation: %s\n' "$*" >&2; exit 1 ;;
esac
BREW
chmod +x "$test_directory/bin/brew"
bash "$test_directory/tools/bottle.sh"
test -f "$test_directory/dist/mute-on-lock-0.20261111.1.arm64_golden_gate.bottle.tar.gz"
(cd "$test_directory/dist" && shasum -a 256 --check SHA256SUMS)
