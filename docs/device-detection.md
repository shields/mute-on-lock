<!--
Copyright © 2026 Michael Shields
SPDX-License-Identifier: Apache-2.0
-->

# Device detection

The exemption is for headphones. Bluetooth, USB, wired, HDMI, and virtual
transports do not determine whether an output is exempt. Unknown outputs mute.

[CoreAudio terminal types](https://developer.apple.com/documentation/coreaudio/kaudiostreampropertyterminaltype)
include speakers and headphones. Some drivers expose
[USB Audio terminal codes](https://www.usb.org/sites/default/files/termt10.pdf)
(Table 2-3): `0x0302` for headphones and `0x0301`, `0x0304` through `0x0307` for
speakers. A live read-only probe finds a USB display using CoreAudio's `spkr`
and built-in speakers using `0x0301`.

For built-in devices, selected data-source IDs from Apple's
[IOAudioTypes](https://github.com/apple-oss-distributions/IOAudioFamily/blob/main/IOAudioTypes.h)
identify the current route: `hdpn`, `ispk`, and `espk`. Subscribe to data-source
changes as well as default-device changes because a jack can change the route
without changing the default device object.

A device is exempt only when all reported output streams identify headphones. A
speaker stream makes a mixed device eligible for muting. An unrecognized stream
also prevents exemption. HDMI and line outputs cannot reveal what is physically
attached. Driver reports can be incomplete or wrong; persistent per-UID
overrides resolve those cases without relying on editable device names.

Overrides use
[UserDefaults](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UserDefaults/AboutPreferenceDomains/AboutPreferenceDomains.html),
in the `dev.msrl.mute-on-lock` domain. macOS owns its storage; change overrides
through the CLI and restart the service. A malformed override is an error.
