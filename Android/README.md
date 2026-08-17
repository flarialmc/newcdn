# Flarial CDN migration and distribution policy

This document describes the CDN fields consumed by the Android launcher startup gate.
The policy is directional: either installed flavor can be the source or the destination.

## JSON schema

The response must contain both fields as strings:

```json
{
  "showBackup": "toPS",
  "distributionTarget": "PS"
}
```

The accepted values are case-sensitive:

| Field | Values | Meaning |
|---|---|---|
| `showBackup` | `none` | Do not offer a new migration. Recovery of an interrupted migration remains enabled. |
| `showBackup` | `toPS` | Migrate Standard APK data to the Play Store flavor. |
| `showBackup` | `toStandard` | Migrate Play Store flavor data to the Standard APK. |
| `distributionTarget` | `none` | Do not force a distribution flavor. An enabled migration is optional. |
| `distributionTarget` | `PS` | Require the Play Store flavor. |
| `distributionTarget` | `standard` | Require the Standard APK flavor. |

The old boolean fields (`showMigrate` and `isPlayStoreBack`) are not parsed by the new
implementation. Missing fields, invalid values, or a malformed CDN response are rejected as a
policy update.

## Policy caching

Each flavor caches the last complete, valid policy in its own
`flarial_data_migration` preferences. A failed request or invalid response uses that cached
policy. If no valid policy has ever been cached, the effective policy is:

```json
{
  "showBackup": "none",
  "distributionTarget": "none"
}
```

A valid response replaces the cached policy. The cache is not automatically expired. The policy
is fetched during `MainActivity.onCreate`, so a cold start/relaunch is needed to observe a CDN
change.

## Route and precedence rules

`showBackup` selects a requested route:

- `toPS`: source `com.flarialmc.flarial_launcher`, target `xyz.flarial.client`.
- `toStandard`: source `xyz.flarial.client`, target `com.flarialmc.flarial_launcher`.
- `none`: no requested route.

`distributionTarget` has precedence over the requested route:

- If it matches the route destination, the migration is mandatory.
- If it is `none`, the requested migration is optional.
- If it contradicts the requested destination, the migration route is suppressed and the selected
  distribution target is enforced.
- If `showBackup` is `none`, no migration route is created even when a distribution target is
  selected.

## Combination table

| `showBackup` | `distributionTarget` | Effective behavior |
|---|---|---|
| `none` | `none` | Normal startup; no migration prompt. |
| `none` | `PS` | Standard is blocked until the PS flavor is installed; PS starts normally. |
| `none` | `standard` | PS is blocked until the Standard APK is installed; Standard starts normally. |
| `toPS` | `none` | Standard → PS migration is offered but optional. |
| `toPS` | `PS` | Standard → PS migration is mandatory on Standard. |
| `toPS` | `standard` | Contradictory route; migration is suppressed and Standard is enforced. |
| `toStandard` | `none` | PS → Standard migration is offered but optional. |
| `toStandard` | `standard` | PS → Standard migration is mandatory on PS. |
| `toStandard` | `PS` | Contradictory route; migration is suppressed and PS is enforced. |

### Installed-app truth table

This table assumes the installed peer, when present, has compatible migration components and that
the source has not already completed migration. `—` means that flavor is not installed. `Normal`
means the launcher is allowed to continue. An optional missing-destination prompt can be
dismissed with `Not now`, outside tap, or Back.

| `showBackup` | `distributionTarget` | Standard installed | PS installed | Standard result | PS result |
|---|---|---:|---:|---|---|
| `toPS` | `none` | No | No | — | — |
| `toPS` | `none` | No | Yes | — | Normal |
| `toPS` | `none` | Yes | No | Offer install PS (dismissible) | — |
| `toPS` | `none` | Yes | Yes | Offer move to PS | Offer import from Standard |
| `toPS` | `PS` | No | No | — | — |
| `toPS` | `PS` | No | Yes | — | Normal |
| `toPS` | `PS` | Yes | No | Mandatory install PS | — |
| `toPS` | `PS` | Yes | Yes | Mandatory move to PS | Offer import from Standard |
| `toPS` | `standard` | No | No | — | — |
| `toPS` | `standard` | No | Yes | — | Install Standard |
| `toPS` | `standard` | Yes | No | Normal | — |
| `toPS` | `standard` | Yes | Yes | Normal | Install Standard |
| `toStandard` | `none` | No | No | — | — |
| `toStandard` | `none` | No | Yes | Offer install Standard (dismissible) | Normal |
| `toStandard` | `none` | Yes | No | Normal | — |
| `toStandard` | `none` | Yes | Yes | Offer import from PS | Offer move to Standard |
| `toStandard` | `standard` | No | No | — | — |
| `toStandard` | `standard` | No | Yes | — | Mandatory install Standard |
| `toStandard` | `standard` | Yes | No | Normal | — |
| `toStandard` | `standard` | Yes | Yes | Offer import from PS | Mandatory move to Standard |
| `toStandard` | `PS` | No | No | — | — |
| `toStandard` | `PS` | No | Yes | — | Normal |
| `toStandard` | `PS` | Yes | No | Install PS | — |
| `toStandard` | `PS` | Yes | Yes | Install PS | Normal |

### `showBackup: "none"` truth table

With `showBackup` set to `none`, migration prompts and the manual migration wizard are disabled.
`distributionTarget` can still block the wrong flavor and require the selected flavor to be
installed.

| `distributionTarget` | Standard installed | PS installed | Standard result | PS result |
|---|---:|---:|---|---|
| `none` | No | No | — | — |
| `none` | No | Yes | — | Normal |
| `none` | Yes | No | Normal | — |
| `none` | Yes | Yes | Normal | Normal |
| `PS` | No | No | — | — |
| `PS` | No | Yes | — | Normal |
| `PS` | Yes | No | Install PS | — |
| `PS` | Yes | Yes | Install PS | Normal |
| `standard` | No | No | — | — |
| `standard` | No | Yes | — | Install Standard |
| `standard` | Yes | No | Normal | — |
| `standard` | Yes | Yes | Normal | Install Standard |

Recovery of an already interrupted transaction remains enabled even when `showBackup` is
`none`.

## Startup flow

1. The app performs early interrupted-session/recovery handling before normal launcher startup.
2. `MainActivity` fetches and caches the typed policy.
3. The startup UI remains behind a blocking gate while the policy and peer app are checked.
4. The app determines whether it is the configured route source or target from its application ID.
5. A forced distribution target blocks the wrong flavor and opens its install URL.
6. For an active route, the peer package, protocol metadata, migration components, and installer
   information are checked before migration is offered or started.
7. Normal launcher startup continues only after the policy gate allows it.

The migration routes are:

| Flavor | Application ID | Listing/download URL |
|---|---|---|
| Standard APK | `com.flarialmc.flarial_launcher` | `https://flarial.xyz/download/?p=android` |
| Play Store | `xyz.flarial.client` | `https://play.google.com/store/apps/details?id=xyz.flarial.client` |

## Migration UI behavior

For an optional route, the source app offers migration and can continue if the user declines. A
mandatory route cannot fall through to the old launcher. The transfer screen is undismissable,
keeps the display awake, and tells the user to keep both apps open. The target reports the
completed session to the source, which records completion and whether the source may now contain
newer data.

If an optional route is enabled but its destination app is not installed, the source shows a
dismissible install prompt containing the destination's listing/download link. `Not now`, an
outside tap, or Back returns to the source launcher; opening the link closes the current launcher
task until the user reopens it.

When `distributionTarget` matches the route destination, the source flavor remains hard-blocked
after a successful migration. For `toPS + PS`, Standard can only open the Play Store flavor,
migrate again when its data is newer or a rollback occurred, or exit. For `toStandard + standard`,
the same rule applies in reverse: PS cannot continue into its old launcher. There is no
`Continue using this app` option on either forced route. The target flavor is allowed to launch
normally after acknowledgement and healthy-launch recovery.

The transfer deliberately excludes disposable or package-bound browser data. The scanner and
manifest validator skip `cache/`, `code_cache/`, the generated content/texture/ART cache roots
(`app_pccache/`, `app_tmppccache/`, `app_textures/`, `PackManifestFactoryCache/`,
`premium_cache/`, and `oat/`), `files/cache/`, `app_webview/`, `app_webview_client/`,
`no_backup/.webview/`, and the WebView preference files
`shared_prefs/AwOriginVisitLoggerPrefs.xml` and `shared_prefs/WebViewChromiumPrefs.xml`.
These trees can contain large browser caches, native artifacts, databases, and live lock files;
the embedded browser recreates a clean profile in the destination app. Other private files remain
eligible, subject to the normal package-bound sanitization rules.

The Settings → Manage Files migration wizard follows the same policy. With `showBackup: "none"`
it displays the existing `Soon...` toast and does not start migration. With an active direction,
the wizard uses that route; opening it from the target hands off to the source for preparation.

## Interrupted migration processes

The destination watches the one-time stream for stalled byte progress. After a bounded period it
uses an authenticated control-provider heartbeat to wake a freezer-suspended source `:migration`
process. The heartbeat itself has a timeout, so a killed or unresponsive process cannot leave the
destination receiving screen stuck indefinitely. A dead source cannot safely resume its consumed
one-time stream; the current receive is closed, incomplete staging is discarded/recovered, and
the Retry action starts a fresh session. On the next app launch, incomplete source or target
session state is also surfaced as a fresh verified retry instead of entering the old launcher.

## Verification and debug testing

The peer must expose the expected migration activity, service, providers, process names, and
protocol version. The Play Store endpoint also normally requires `com.android.vending` as the
installer. During development, that installer check is bypassed only when both the local app and
the peer are debuggable. The certificate-pin set is currently empty, so certificate matching is
not yet enforced.

Consequences for testing:

- `standardDebug` plus `PSDebug` installed with ADB can migrate without Internal App Sharing;
  both apps are debuggable, so this exercises the transfer/verification/rollback path but not the
  production installer trust boundary.
- Internal App Sharing can install a debuggable PS artifact and is useful for checking the Play
  installer path. It uses an Internal App Sharing signing certificate, not the eventual Play App
  Signing certificate.
- A previous completion, pending session, rollback journal, or interrupted transaction can change
  the popup shown. Changing the CDN policy does not erase that migration state.

For a policy change, publish a complete valid JSON response, force-stop/relaunch the relevant
flavor, and verify the cached policy before interpreting the startup popup.

To reset a debug device for another migration test, stop both apps first. Clearing the entire
Standard package removes all of its private data; removing only the PS migration state preserves
the PS app's normal data:

```sh
adb shell am force-stop com.flarialmc.flarial_launcher
adb shell am force-stop xyz.flarial.client
adb shell pm clear --user 0 com.flarialmc.flarial_launcher
adb shell run-as xyz.flarial.client rm -rf \
  no_backup/.flarial_migration shared_prefs/flarial_data_migration.xml
```

The two APKs remain installed after these commands. The Standard reset is destructive and is
recoverable only from an external backup; the PS command removes migration metadata and policy
cache but leaves its ordinary app data intact.
