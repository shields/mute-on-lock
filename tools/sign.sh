#!/bin/bash
# Copyright © 2026 Michael Shields
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
cd "$(dirname "$0")/.."
source tools/release-lib.sh
require_release_context
read_metadata
: "${SIGNING_CERTIFICATE_P12:?Missing base64 Developer ID Application certificate}"
: "${SIGNING_CERTIFICATE_PASSWORD:?Missing certificate password}"
: "${NOTARY_API_PRIVATE_KEY:?Missing notarization API private key}"
: "${NOTARY_KEY_ID:?Missing notarization key ID}"
: "${NOTARY_ISSUER_ID:?Missing notarization issuer ID}"
: "${DEVELOPER_TEAM_ID:?Missing developer team ID}"
signing_directory=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mute-on-lock-sign.XXXXXX")
signing_keychain=$signing_directory/signing.keychain-db
set_keychain_search() {
	local keychain_line
	while IFS= read -r keychain_line; do
		[[ $keychain_line == *\"*\" ]] || die "Unexpected keychain search-list format"
		keychain_line=${keychain_line#*\"}
		keychain_line=${keychain_line%\"}
		set -- "$@" "$keychain_line"
	done <"$signing_directory/original-keychains.txt"
	security list-keychains -d user -s "$@"
}
cleanup_signing() {
	if [[ -f $signing_directory/original-keychains.txt ]]; then set_keychain_search; fi
	if [[ -f $signing_keychain ]]; then security delete-keychain "$signing_keychain"; fi
	rm -rf "$signing_directory"
}
trap cleanup_signing EXIT
keychain_password=$(openssl rand -hex 32)
printf '%s' "$SIGNING_CERTIFICATE_P12" | base64 --decode >"$signing_directory/certificate.p12"
printf '%s' "$NOTARY_API_PRIVATE_KEY" >"$signing_directory/notary.p8"
chmod 600 "$signing_directory/certificate.p12" "$signing_directory/notary.p8"
security list-keychains -d user >"$signing_directory/original-keychains.txt"
security create-keychain -p "$keychain_password" "$signing_keychain"
security set-keychain-settings -lut 21600 "$signing_keychain"
security unlock-keychain -p "$keychain_password" "$signing_keychain"
security import "$signing_directory/certificate.p12" -k "$signing_keychain" \
	-P "$SIGNING_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
set_keychain_search "$signing_keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$signing_keychain" >/dev/null
signing_identity=$(security find-identity -v -p codesigning "$signing_keychain" | awk '/Developer ID Application:/ { print $2 }')
[[ $signing_identity =~ ^[0-9A-F]{40}$ ]] || die "Expected exactly one valid Developer ID Application identity"
chmod +x dist/mute-on-lock
codesign --force --sign "$signing_identity" --keychain "$signing_keychain" \
	--identifier dev.msrl.mute-on-lock --options runtime --timestamp dist/mute-on-lock
codesign --verify --strict --verbose=2 dist/mute-on-lock
codesign --display --verbose=4 dist/mute-on-lock 2>"$signing_directory/signature.txt"
rg --fixed-strings --line-regexp "TeamIdentifier=$DEVELOPER_TEAM_ID" "$signing_directory/signature.txt"
rg --fixed-strings --line-regexp 'Identifier=dev.msrl.mute-on-lock' "$signing_directory/signature.txt"
archive_directory=dist/mute-on-lock-$release_version-macos-arm64
mkdir -p "$archive_directory"
cp -p dist/mute-on-lock "$archive_directory/"
cp LICENSE README.md "$archive_directory/"
ditto -c -k --keepParent "$archive_directory" "$archive_directory.zip"
xcrun notarytool submit "$archive_directory.zip" --key "$signing_directory/notary.p8" \
	--key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait --output-format json \
	>"$signing_directory/notary.json"
jq --exit-status '.status == "Accepted"' "$signing_directory/notary.json"
# Standalone executables require codesign's notarization check.
codesign --verify --strict --verbose=4 --test-requirement '=notarized' --check-notarization dist/mute-on-lock
jq --arg team "$DEVELOPER_TEAM_ID" --arg hash "$(shasum -a 256 dist/mute-on-lock | awk '{print $1}')" \
	'. + {teamID: $team, executableSHA256: $hash, notarization: "Accepted"}' dist/release.json \
	>dist/signed-release.json
mv dist/signed-release.json dist/release.json
