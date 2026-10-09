# Third-party plugins

Both were approved by the owner on 2026-10-08 (phase 5). They are vendored in `addons/` and committed, so builds don't download anything at edit time. Gradle still fetches the SDKs from Maven when it builds an APK.

| Plugin | Version | License | Source | What we use |
| --- | --- | --- | --- | --- |
| Poing Studios AdMob | 5.1.0 (2026-09-13), Google Mobile Ads Next-Gen SDK 1.4.0 | MIT | github.com/poingstudios/godot-admob-plugin | Rewarded, interstitial, adaptive banner |
| GodotGooglePlayBilling | 3.3.0 (2026-07-27), Play Billing Library 9.1.0 | MIT | github.com/godot-sdk-integrations/godot-google-play-billing | One-time product (Remove Ads) |

## What's vendored, and local changes

- `addons/admob/`: the release zip `poing-godot-admob-v5.1.0.zip`, without `csharp/`, `gdscript/sample/` and `skills/` (nothing at runtime or export uses them). `android/bin/` holds only the core `ads` library from `android-template-v4.7.2.zip`. No mediation adapters are included, and all `admob/mediation/*` settings are off.
- Local patch (`addons/admob/admob.gd`): `BinaryInstaller.install_missing_binaries_sync()` is commented out. When the editor starts headless (our test runner's `--import`), it would `curl` the iOS binaries from GitHub on every run. Re-apply this after updating the plugin.
- `addons/admob/android/.gitignore` no longer ignores `/bin`: the AARs are committed (about 270 KB).
- `project.godot` lists every `[admob]` setting explicitly. The plugin re-saves `project.godot` when one is missing, which drops our comments.
- `addons/GodotGooglePlayBilling/`: the release zip unchanged.
- Export presets use the Gradle build (`gradle_build/use_gradle_build=true`; the AdMob plugin refuses prebuilt export). The Godot 4.7.2 build template goes in `android/build/` (gitignored, 1.2 GB with build output). On a fresh clone, export once with `godot --headless --path . --install-android-build-template --export-debug "Android" build/android/swarm-survivor-debug.apk`. The AdMob exporter appends a `configurations.configureEach` block to `android/build/build.gradle` on each export (idempotent). `addons/admob/assets/*` and `addons/admob/internal/*` (editor menu, mocks, exporters) are excluded from the APK.

## How the game uses them

- `scripts/autoload/ads.gd` ("Ads") owns every rule: placements, limits, pacing, pausing. It talks to an `AdBackend`: `scripts/ads/admob_backend.gd` on a device with the native plugin, `FakeAdBackend` in debug builds without it. On desktop, the fake draws a pixel "TEST AD" screen (SKIP or GET REWARD after 3 s) and a "TEST BANNER" bar.
- `scripts/autoload/store.gd` ("Store") owns Remove Ads: `scripts/store/play_store_backend.gd` on Android, `FakeStoreBackend` in debug builds without it (every product "USD 1.99", buying always works).
- The fakes are used only in debug builds (editor, tests, debug APKs). A release build without a plugin gets an inert backend instead: no ads at all, and the shop shows STORE OFFLINE. So a release build never sells anything for free.
- The plugins' classes are only loaded on a device (`load()` behind `Engine.has_singleton`). Tests and desktop runs never touch them.

## Test ids (current) and what replaces them

All ids in the repo are Google's public test ids. **Real ids go in only with the owner's OK.**

| Where | Test value now | Replace with |
| --- | --- | --- |
| `project.godot` `admob/general/android/app_id` | `ca-app-pub-3940256099942544~3347511713` | AdMob app id (Android) |
| `project.godot` `admob/general/ios/app_id` | `ca-app-pub-3940256099942544~1458002511` | AdMob app id (iOS) |
| `data/rules/ads.json` `units.android` | banner `/9214589741`, interstitial `/1033173712`, rewarded `/5224354917` | AdMob ad unit ids |
| `data/rules/ads.json` `units.ios` | banner `/2934735716`, interstitial `/4411468910`, rewarded `/1712485313` | AdMob ad unit ids |
| `data/rules/store.json` `products.remove_ads.android` / `.ios` | `remove_ads` (placeholder) | Product id created in Play Console / App Store Connect |

Google Play has no public test product ids for Billing Library 8+. To test the real purchase flow: create the product in Play Console, add a license tester account, and install from a closed-testing track (or a build signed with the upload key, and the same package name).

## Not done yet (needs the owner, or a later phase)

- **Consent (UMP / GDPR):** AdMob requires a consent message for users in the EEA/UK before serving personalized ads. The plugin ships the UMP API (`addons/admob/gdscript/src/ump/`). Scheduled for phase 9 (owner, 2026-10-09), after the owner sets up the consent message in AdMob.
- **iOS:** the AdMob plugin supports iOS (binaries not vendored). Play Billing is Android only; iOS needs a StoreKit plugin, which needs approval before installing. Moved to phase 9 (owner, 2026-10-09); until then an iOS release build has no store and the shop shows STORE OFFLINE.
- **app-ads.txt** on the developer website, before release.
