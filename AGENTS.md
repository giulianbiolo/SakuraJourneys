# AGENTS.md

Flutter app (package name `japan_travel`, product name "Sakura Journeys", repo `SakuraJourneys`): a swipeable
card deck of places of interest, sorted by GPS distance from the user, with a completed/"already seen"
toggle per card, JSON import/export/share, and an Android home-screen widget showing the nearest card.

## Setup and commands

- `flutter pub get` after any checkout or `flutter clean`. If `.dart_tool/` is stale, `flutter analyze --no-pub`
  emits ~168 bogus `Target of URI doesn't exist` / `undefined_identifier` errors; those are resolution
  failures, not real errors.
- `flutter analyze` is the only static check. There is no `test/` directory, so `flutter test` has nothing
  to run; do not claim tests pass. `ios/RunnerTests/` is the untouched template.
- Verified green from a clean tree (`flutter clean` + `flutter pub get`) on Flutter 3.44.8 / Dart 3.12.2 with
   JDK 21.0.12: `flutter build apk --debug` (~24 s, 152 MB) and `flutter build apk --release` (~50 s, 55.4 MB).
   Two messages are noise, not failures: the repeated `source/target value 8 is obsolete` javac warnings from
   old plugins, and `Caught exception: Already watching path: .../android`.
- Baseline analyze output is 2 `info`-level findings, no errors: `withOpacity` twice in `location_card.dart`.
  Not regressions. Keep the output diffable: do not mass-fix them unasked. (It was 20 until the
  `use_build_context_synchronously` cluster went away with the `SharedPreferences.getInstance().then(...)`
  blocks in `location_card.dart`, then 6 until the `Color.red/.green/.blue/.value` uses went with the
  widget's dominant-colour code.)
- `dart format` matches most of the tree but is not enforced; `lib/utils/add_form.dart` (the whole
  `Padding`/`Row` block from line 158) and the `updateCards(...)` call on `lib/utils/edit_card_form.dart:217` are
  still unformatted. Format only files you touch, and only the lines you touch: the formatter reindents whole
  unrelated blocks. `lib/models/models.dart` is the live example, and the reason `dataListDefault()` returns
  copies of a separate `_dataListDefaultTemplate` list rather than being written as `=> [ ... ]` directly:
  the arrow form makes the formatter reindent all 40 lines of the literal.
- Most dependencies are still old on purpose (`share_plus ^7`, `flutter_html 3.0.0-beta.2`, `flutter_lints ^4`).
  Do not bump versions as a side effect of another task. `geolocator` and `workmanager` are the exception:
  they had to go to `^14` / `^0.9` because their old Android code used the removed v1 embedding
  (`PluginRegistry.Registrar`), which Flutter 3.44 no longer provides. Any other plugin that still
  references v1 embedding will fail the same way and can only be fixed by upgrading it.
- `palette_generator` was dropped when the widget stopped deriving a text colour from the image; it was
  **discontinued** on pub.dev, so do not reintroduce it.

## Running on an emulator

There is no test suite, so behaviour changes are verified by driving a debug build on an emulator. The
procedure below is the one used to verify the background widget refresh, the empty-list guards, both JSON
import paths and the cold-start share. Reuse it instead of inventing a new one.

The SDK is at `~/Android/Sdk` and `ANDROID_HOME` is **not** exported in the shell. `adb` on `PATH` is
`/opt/platform-tools/adb`; `sdkmanager`, `avdmanager` and `emulator` are not on `PATH` at all, so call them by
full path.

### One-time: create a phone AVD

This machine's SDK ships only Wear OS system images, and the only pre-existing AVD is `Wear_OS_Large_Round`
(454x454 round, no home-screen widget host, so useless for the widget). Create a phone AVD once:

```sh
export ANDROID_HOME=$HOME/Android/Sdk
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install "system-images;android-35;google_apis;x86_64"
echo no | $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
  -n phone_api35 -k "system-images;android-35;google_apis;x86_64" -d medium_phone
```

`google_apis` rather than `google_apis_playstore`, because the non-Play image allows `adb root`. The
`Error: .../android-wear-signed/.../devices.xml` lines printed during `create` are the Wear images failing to
parse; they are noise. The result is 1080x2400 at density 420, `hw.gps=yes`, 10 G data partition.

### Launch

```sh
export ANDROID_HOME=$HOME/Android/Sdk
setsid nohup $ANDROID_HOME/emulator/emulator -avd phone_api35 -memory 4096 -no-boot-anim -gpu auto \
  < /dev/null > /tmp/emulator.log 2>&1 & disown
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 5; done
```

`setsid` is required: without it the emulator dies with the launching command's process group, which happens
as soon as an agent shell hits its timeout. Boot from the existing snapshot takes ~10 s. `-memory 4096`
overrides the AVD's 2 G without editing `config.ini`.

### Install and set up state

```sh
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.example.japan_travel android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.japan_travel android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.example.japan_travel android.permission.ACCESS_BACKGROUND_LOCATION
adb emu geo fix 139.7700 35.6900                 # longitude first, then latitude
adb shell settings put secure location_mode 3    # 0 turns location off, for the no-fix paths
```

`install` does not grant `ACCESS_BACKGROUND_LOCATION`, and the background isolate needs it. `adb emu geo fix`
is not reliably honoured a second time in one session: a background run once produced a distance identical to
the *previous* fix's to 16 significant digits. Cross-check `lastCloserLocation` before concluding the app
ignored an injected position.

### Where to assert

The debug build is debuggable, so `run-as` reads private app data without root. Everything observable lives in
four files under `/data/data/com.example.japan_travel/`:

- `shared_prefs/FlutterSharedPreferences.xml` - `flutter.dataList` (the JSON deck) and
  `flutter.lastCloserLocation`. Note `dataList` does not exist until the first mutation; a fresh install runs
  on `dataListDefault()` with nothing persisted. Overwriting this file (app force-stopped, then
  `adb shell "cat /sdcard/Download/prefs.xml | run-as com.example.japan_travel sh -c 'cat > <path>'"`) is the
  cheapest way to exercise the deserialisers: crafted records reach `ListModel.fromJson`, or
  `dataFromLegacyString` when the value does not start with `{`, on the next cold start without any UI driving.
- `shared_prefs/HomeWidgetPreferences.xml` - `title`, `distance`, `imageName`, `lat`, `lng`, plus
  `cachedImageUrl`, which is the source URL of the image currently on disk. `HomeWidgetConfig.update` skips the
  download while that key matches the first card, so it is what to check when no image appears. A stale
  `textColor` survives here on installs that predate the scrim; nothing reads or rewrites it. Note the writes
  are `apply()`d, so a read seconds after a launch can catch a half-written file: `title` and `distance`
  updated with `imageName`/`lat`/`lng` still blank is a flush lag, not a partial update.
- `app_flutter/images/widget_preview.jpg` - mtime and size say whether `HomeWidgetConfig.update` actually ran.
  Size distinguishes which card's image it is.
- `shared_prefs/flutter_workmanager_plugin.xml` - the Dart callback handle workmanager resolves.

```sh
adb shell run-as com.example.japan_travel cat \
  /data/data/com.example.japan_travel/shared_prefs/HomeWidgetPreferences.xml
adb shell run-as com.example.japan_travel ls -la \
  /data/data/com.example.japan_travel/app_flutter/images/
adb logcat -d -s flutter:V WM-WorkerWrapper:V WM-Processor:V WM-SystemJobService:V AndroidRuntime:E
```

Unfiltered `logcat` on this image is unusable: `SemanticLocation` and `SettingsToPropertiesMapper` bury
everything. Always pass `-s`.

### Testing the 15-minute background refresh

Do the UI tests **first**. Every app launch re-runs `main()`, which re-registers the periodic task and resets
its clock, and a rebuild plus reinstall invalidates the callback handle in `flutter_workmanager_plugin.xml`.

1. Launch the app once so `registerPeriodicTask` runs, then read the next window:
   `adb shell dumpsys jobscheduler | grep -A2 "JobStatus{.*japan_travel"` -> `TIME=+13m20s...`.
2. Move the geo fix so the expected first card changes.
3. `adb shell input keyevent KEYCODE_HOME`, then `adb shell am kill com.example.japan_travel`. Use `am kill`,
   **not** `am force-stop`: force-stop puts the app in the stopped state and its jobs stop running. Confirm
   with `adb shell pidof com.example.japan_travel` (empty output).
4. Poll `HomeWidgetPreferences.xml` and the image mtime until they change.

`adb shell cmd jobscheduler run -f -n androidx.work.systemjobscheduler com.example.japan_travel <id>` does
**not** work. It bypasses JobScheduler's constraints but not WorkManager's own period gate, which logs
`Status ... is ENQUEUED; not doing any work and rescheduling for later execution` and never starts the Dart
callback. Waiting for a real window is the only option. Note the job sits in the
`androidx.work.systemjobscheduler` namespace, so plain `cmd jobscheduler run` answers
`Could not find job 0 in package`.

A successful run, with no pid beforehand:

```
WM-WorkerWrapper: Starting work for dev.fluttercommunity.workmanager.BackgroundWorker
flutter : Using the Impeller rendering backend        <- the Dart isolate started
WM-WorkerWrapper: Worker result SUCCESS
```

A first update takes a few seconds in the background isolate, nearly all of it the image download. A fast
worker is no longer proof that nothing happened: `HomeWidgetConfig.update` skips the download when
`cachedImageUrl` still matches the first card, so an unchanged first card legitimately finishes in
milliseconds. Delete `widget_preview.jpg` or move the geo fix if you need the slow path.

### Testing a cold-start share

```sh
adb shell am force-stop com.example.japan_travel
JSON='{"data":[{"title":"Shibuya Crossing","imageName":"https://example/img.jpg","address":"Shibuya, Tokyo","location":"(35.6595, 139.7005)","description":"...","rating":"4.5","alreadySeen":"false"}]}'
adb shell "am start -a android.intent.action.SEND -t text/plain \
  -n com.example.japan_travel/.MainActivity --es android.intent.extra.TEXT '$JSON'"
```

Double quotes on the host side, single quotes on the device side; the JSON must contain no single quotes. Then
assert on `flutter.dataList`. `am force-stop` is correct here, unlike in the background test: a cold start is
the point.

### Testing the home-screen widget

`CustomHomeView.onUpdate` runs only for widget IDs that exist, so a widget must be placed on the launcher by
hand (long-press the home screen, drag it in) before anything is observable. Check first: the instance on
`phone_api35` has survived across sessions.

```sh
adb shell dumpsys appwidget | grep -A4 "japan_travel/com.example.japan_travel.CustomHomeView"
```

To re-run `onUpdate` from the shell, use `adb install -r`. `am broadcast -a
android.appwidget.action.APPWIDGET_UPDATE` does **not** work: it is a protected broadcast and the shell is
refused with `Permission Denial: not allowed to send broadcast ... from unknown caller`. Launching the app also
works, but only when a GPS fix succeeds, since `updateCards` skips the widget write otherwise.

The provider's `println` calls land under the `System.out` tag, not `flutter`:

```sh
adb logcat -d -s System.out:V
```

The launcher **does** publish an accessibility tree, so `uiautomator dump` gives the widget's exact bounds
(`android.widget.ImageView` under a `LauncherAppWidgetHostView`). That is the only reliable way to measure what
the widget actually rendered; to check the image is not distorted, build the candidate renderings offline from
`widget_preview.jpg` and compare against the screenshot region rather than judging by eye. On `phone_api35` the
instance measures 699x614 px, and a correct rendering scores a mean absolute channel difference of ~3.5 against
a source-aspect `centerCrop` and ~17.5 against a forced square.

Two things about the provider cannot be observed on this emulator:

- The **landscape** `RemoteViews` of the pair. This launcher build has no "Allow Home screen rotation" entry in
  `com.android.launcher3.settings.SettingsActivity`, and `cmd window user-rotation lock 1` leaves the home screen
  in portrait, so only the portrait tree is ever inflated.
- `onAppWidgetOptionsChanged`, which needs a resize by hand; there is no `adb` command for it.

Tapping the widget is observable, and which branch ran shows up in the launched intent:

```sh
adb shell input tap <widget centre>
adb logcat -d | grep "ActivityTaskManager: START"
```

A card gives `act=android.intent.action.VIEW dat=google.navigation:`; the empty state gives
`cmp=com.example.japan_travel/.MainActivity`. With the app **force-stopped** the first tap only un-stops the
package and starts nothing, so tap twice or use `am kill`.

### Driving the Flutter UI

Flutter publishes no accessibility tree unless an accessibility service is running, so `adb shell uiautomator
dump` returns one full-screen node for the app. It does work for native surfaces, which is how to drive the SAF
file picker. For the app's own UI, find targets by colour in a screenshot instead:

```sh
adb exec-out screencap -p > /tmp/s.png    # 1080x2400, 1:1 with input coordinates
```

```python
from PIL import Image
im = Image.open('/tmp/s.png').convert('RGB'); w, h = im.size; px = im.load()
pts = [(x, y) for y in range(int(h * 0.8), h) for x in range(w)
       if px[x, y][0] > 180 and px[x, y][1] < 90 and px[x, y][2] < 90]
print(sum(x for x, _ in pts) // len(pts), sum(y for _, y in pts) // len(pts))  # red delete button
```

Do not estimate coordinates by eye from a scaled screenshot: a first attempt at the delete button was 68 px
low and silently hit nothing.

```sh
adb shell input swipe 900 1200 150 1200 200   # next card
adb shell input swipe 150 1200 900 1200 200   # previous card
adb shell input swipe 540 1800 540 700 400    # scroll down inside a card, to reach share/edit/delete
adb shell input tap <x> <y>
```

Each card is its own scroll view and sizes to its description, so where the action row sits depends on the card:
a short description puts share/edit/delete on screen already, a 600-character one needs two scrolls. After every
delete the new front card starts scrolled to the top, so N deletions means N locate cycles. The add/settings tile
is one page past the last card (`+` at ~`(540, 730)`, gear at ~`(540, 1772)` on a 6-card deck). `input swipe`
flings past its target, so use a one-card deck when a specific card must be tapped.

The settings dialog is easier than colour-matching arbitrary widgets suggests: its `ElevatedButton` labels are
the only purple text on screen, so clustering pixels where `b - r > 35 and b - g > 50` locates Import / Export /
Share / Close in one pass. "Reset To Default" is red and needs its own.

Snackbars are gone in under 4 s, so screenshot about 1 s after the action or the evidence is an empty screen.

The file picker is `com.google.android.documentsui`. For opening a file it starts on "Recent", which does not
list freshly `adb push`ed files; tap the hamburger at ~`(73, 126)`, then "Downloads", then the file, locating
both by `uiautomator dump`. The save dialog is simpler: it opens on Downloads with the filename prefilled and a
`SAVE` button, both of which `uiautomator dump` reports directly.

### Clean up after a session

```sh
adb shell settings put secure location_mode 3
adb shell svc power stayon false
adb shell rm /sdcard/Download/<pushed files> /sdcard/ui*.xml
```

Wrap the whole command in double quotes and single-quote each path when a filename contains parentheses, which
is what SAF produces on a second save (`exportData.json (1)`). Unquoted, the device shell answers
`syntax error: unexpected '('` and deletes nothing, silently.

## Android build config: hand-patched, do not "clean up"

The toolchain versions are a matched set, pinned to satisfy both Flutter 3.44's hard floors and JDK 21:

| Piece | Version | Why not lower |
| --- | --- | --- |
| Gradle (`gradle-wrapper.properties`) | 8.14 | Gradle < 8.5 crashes on JDK 21 class files (`major version 65`); Flutter errors below 8.7 |
| AGP (`settings.gradle`) | 8.11.1 | Flutter 3.44 errors below AGP 8.6; 8.11.1 is its warn floor |
| Kotlin (`settings.gradle`) | 2.2.20 | KGP 2.0.x cannot read the `kotlin-stdlib 2.2.0` metadata pulled in by newer plugins |
| Java / jvmTarget (`app/build.gradle`) | 17 | Flutter errors below 17 |

Flutter's own floors live in `flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`; check there
before changing any of the above. Do not "upgrade" to the Flutter 3.44 template defaults (Gradle 9.1 / AGP 9.0 /
Kotlin 2.3): AGP 9 drops the legacy DSL these old plugins rely on.

Two edits in `android/build.gradle` look like cruft. Both are inside `subprojects { afterEvaluate { ... } }`;
the first is load-bearing, the second is a guard:

- `namespace project.group` backfills `namespace` for old plugins that predate AGP 8. Removing it breaks the build.
- `options.compilerArgs.removeAll { it == '-Werror' }` strips `-Werror` from plugin javac tasks. This one is a
  guard, not currently load-bearing: no `android/**/*.gradle*` in any of the 123 packages in `pubspec.lock`
  contains `-Werror` any more. `geolocator_android` had it at 3.2.1, compiled with Java 8 source/target, and
  JDK 21's "source value 8 is obsolete" warning failed the build; 5.0.3 dropped it. Kept because a plugin bump
  can bring the condition back.

`kotlin { compilerOptions { jvmTarget = ... JVM_17 } }` in `android/app/build.gradle` must stay in step with
`compileOptions`; KGP otherwise defaults jvmTarget to the JDK (21) and AGP aborts with
"Inconsistent JVM-target compatibility".

`applicationId` is still the template default `com.example.japan_travel`. It is coupled to three other places:
the Kotlin package path `android/app/src/main/kotlin/com/example/japan_travel/`, the home-widget app group in
`lib/utils/home_widget_config.dart:99`, and the `<receiver android:name="CustomHomeView">` in the manifest.
Changing one without the others silently breaks the widget.

## Platform reality

Android is the only fully implemented target, despite `ios/`, `linux/`, `macos/`, `web/`, `windows/` existing:

- Navigation uses the Android-only `google.navigation:q=lat,lng&mode=d` intent
  (`lib/components/location_card.dart:309`, mirrored in `CustomHomeView.kt`), declared in the manifest `<queries>`.
- Export (`lib/utils/settings_form.dart:120`) relies on `file_picker`'s Android/iOS behaviour, where `saveFile`
  writes the bytes into the chosen SAF document. On desktop it only returns a path, so the JSON is written back
  with `File(result).writeAsString` behind a `Platform.isAndroid || Platform.isIOS` check. That branch has never
  been run.
- `HomeWidget.updateWidget(iOSName: "japan_travel", ...)` is called, but `ios/Runner.xcodeproj` has **no** widget
  extension target and the iOS bundle id is `com.example.japanTravel`. The iOS widget does not exist.

## Architecture

Single-screen app. No routing, no repository layer, no codegen, no DI beyond one `ChangeNotifierProvider`.

State: one `ListModel extends ChangeNotifier` (`lib/models/models.dart:113`) provided at the root
(`lib/main.dart:48`), wrapping a private `List<DataModel>`. It exposes imperative mutators
(`addData` / `insertData` / `updateData` / `removeData` / `clearAllData` / `sortData` / `loadData`) that each call
`notifyListeners()`, plus accessors `length()`, `elem(i)`, `contains()` and a manual `notify()` escape hatch.
There is no immutable state, no selector, no `copyWith`.

UI: `HomeScreen` (`lib/screens/home.dart`) renders a `SnappingPageScroll` carousel of `LocationCard`s built in
`carouselView` (`lib/screens/home.dart:175`), with a synthetic index `-1` appended for the `AddSettingsCard`
(add + settings tiles). Pull-to-refresh is the custom `CheckMarkIndicator`
(`lib/components/check_mark_indicator.dart`) wrapping `CustomMaterialIndicator`.

The one orchestration function is `updateCards(...)` (`lib/screens/home.dart:213`), called after every mutation
with explicit flags:

```dart
updateCards(model, reloadFromMemory: false, reorderData: false, updateAllDistances: false);
```

It runs `loadData` -> `orderDataOnCurrLocation` -> `updateWidget` in that order, awaiting each.
`orderDataOnCurrLocation` (`lib/screens/home.dart:244`) requests location permission, picks a GPS accuracy from
the last known nearest distance via `computeIntelligentAccuracy` (`lib/screens/home.dart:304`, a power/accuracy
tradeoff keyed on the `lastCloserLocation` pref), computes distances with `geo`'s `computeDistanceBetween`
(earth radius 6371008.8), then `sortData()`. `sortData` (`lib/models/models.dart:175`) pushes `alreadySeen`
cards to the end, then sorts by ascending distance.

`orderDataOnCurrLocation` returns `bool`: `false` when no fix was obtained, and `updateCards` then skips
`updateWidget` entirely. That guard exists because `distance` is never persisted, so a run without a fix has
every distance at `0.0` and would label an arbitrary card "Here!" on the home screen. Keep it when adding
call sites.

Sharing: `share_handler` receives inbound shares in `initPlatformState` (`lib/screens/home.dart:44`), which
registers the `sharedMediaStream` listener **before** its first `await` and then handles
`getInitialSharedMedia()` for the share that cold-started the process (the plugin drops that event because its
`eventSink` is still null when the activity attaches). Both routes funnel into `_handleSharedMedia` ->
`_readSharedJsonFile` / `_importJson` (`lib/screens/home.dart:57-115`), accepting either a JSON string payload
or a shared `.json` / `.txt` / `.md` attachment. `share_plus` sends. The manifest declares a `SEND` + `text/*`
intent filter for this.

`_handleSharedMedia` first awaits `_boot` (`lib/screens/home.dart:37`), the future of the `updateCards` call
`initState` fires. Without it an import landing mid-boot writes `dataList` before the boot load has added the
stored cards to the model, and the file ends up holding only the shared card until the next mutation.

### Home widget pipeline

Dart writes key/value pairs (`title`, `distance`, `imageName`, `lat`, `lng`) via `HomeWidgetConfig.update`
(`lib/utils/home_widget_config.dart:10`) for the **first card only**. It downloads the card image to
`<appDocs>/images/widget_preview.jpg` (the widget reads a file path, not a URL). `CustomHomeView.kt` reads those
keys in `onUpdate` and inflates `res/layout/card_widget_layout.xml` (`widget_image`, `widget_title`,
`widget_distance`).

Text legibility is a fixed scrim, not a computed text colour. The title/distance container carries
`@drawable/widget_text_scrim`, a bottom-anchored black gradient (0% at the band top, 60% at its centre, 85% at
the baseline), and both labels are hardcoded white with a `shadowRadius=6` halo. The earlier approach wrote a
`textColor` derived by inverting the image's dominant colour; it failed for four separate reasons, and the first
two are worth keeping in mind before anyone tries to "improve" the scrim away:

- Inversion is a complement, not a luminance opposite: `invert(#808080)` is `#7F7F7F`, contrast 1.0:1.
- One colour cannot clear a *distribution* of background pixels. A neon or foliage photo spans the whole
  luminance range under the text, so some strokes always vanish.
- The sampled band was fixed in a 1280x720 resize while the provider re-crops per orientation and widget size,
  so the measured pixels were often not the pixels under the text.
- `shadowRadius=2` with a 1px offset is invisible under 25sp bold.

The band is content-sized (`wrap_content` plus a 64dp `paddingTop`), so the title always lands at t~0.46 of the
gradient regardless of how the widget is resized. That is what makes the contrast bound hold: 60% black under
white text is 4.8:1 even if the pixel underneath is pure white. Measured on `phone_api35` against
`akihabara.jpg`, which has pure-white pixels in both label bands: 4.83:1 at the title and 8.59:1 at the
distance, against 1.00:1 for the same pixels with no scrim. Changing either the centre stop or `paddingTop`
moves those numbers, so re-derive them if you touch either.

An empty deck goes through `HomeWidgetConfig.updateEmpty` (`:44`) instead, which writes the "No places yet"
placeholder and blanks `imageName`/`lat`/`lng`. The provider reads a blank `imageName` as "draw
`R.drawable.widget_background`" and blank coordinates as "tap opens `MainActivity`" rather than a
`google.navigation:` route. `cachedImageUrl` is left alone on purpose, so a card that comes back with the same
URL still hits the on-disk preview.

The provider hands `updateAppWidget` a `RemoteViews(landscape, portrait)` pair, each holding a bitmap cropped to
that orientation's box: `(MIN_WIDTH, MAX_HEIGHT)` in portrait, `(MAX_WIDTH, MIN_HEIGHT)` in landscape, since the
host reports both orientations as one range and MAX x MAX is the landscape box. The file is decoded once, at the
coarsest `inSampleSize` both boxes tolerate, then cropped twice; cropping rather than scaling alone is what keeps
the landscape bitmap at 1321x359 (1.9 MB) instead of 1323x1654 (8.8 MB), because a tall source covering a wide
box overshoots in height. `onAppWidgetOptionsChanged` re-runs `onUpdate` so a resize gets bitmaps for the new box.

Background refresh: `workmanager` runs `callbackDispatcher` (`lib/main.dart:10`) every 15 minutes. It builds a
**fresh** `ListModel()`, so background updates read from `SharedPreferences` and never see the UI's instance.
`@pragma('vm:entry-point')` on that function is mandatory; do not remove it.

### Persistence: one JSON format, plus a legacy reader

`SharedPreferences` key `dataList` holds `jsonEncode(ListModel.toJson())`, the same format used for
import/export/share. `toJson` writes `location` as the `"(lat, lng)"` string and `rating` / `alreadySeen` as
strings. Reading goes through `ListModel.fromJson` (`lib/models/models.dart:194`) -> `DataModel.tryFromJson`
(`:89`), which reads defensively because the same path takes third-party JSON: a `num` or `String` rating, a
`bool` or `"true"` for `alreadySeen`, missing `imageName` / `address` / `description` defaulted, and any record
without a usable `title` or `location` skipped. Do not replace that with `double.parse` / direct casts; a
shared card that writes `rating` as a number then throws.

Before this, the key held a delimiter blob: records joined by `|;|`, fields joined by `|:|` in the order
`title | imageName | address | (lat, lng) | alreadySeen | description | rating`. `loadData`
(`lib/models/models.dart:206`) still reads it, through `dataFromLegacyString` (`:232`), for any install that
predates the switch, and rewrites the key as JSON on that first load. The branch is chosen on whether the
stored string starts with `{`, so `jsonDecode` is never handed a delimiter blob (it throws, and every stored
card would be lost). Verified on the emulator by injecting a crafted blob: both records survived, including
`alreadySeen: true`. Keep the legacy reader until a release has shipped that migrates every install.

`loadData` seeds `dataListDefault()` only when the key is **absent**, which is a fresh install. A deck emptied
by deleting the last card stores `{"data":[]}` and stays empty; keying that off `length() == 0` instead
resurrects the samples the user just deleted.

`title` is the de-facto primary key: `ListModel.loadData` dedupes and replaces by title. Duplicate titles will
overwrite each other. `alreadySeen` inside `dataList` is the only store for the seen state; there is no
per-title prefs key any more.

## Conventions to follow

- Read state with `context.watch<ListModel>()` inside `build`; mutate with
  `Provider.of<ListModel>(context, listen: false)` in callbacks. Both appear repeatedly and interchangeably.
- Write sequence after **any** mutation, in this order: mutate the model ->
  `prefs.setString('dataList', jsonEncode(model.toJson()))` -> `updateCards(model, ...)` with the narrowest
  flags. `lib/utils/edit_card_form.dart:212` and `lib/utils/settings_form.dart:199` are the reference
  implementations.
- Guard every `context` use after an `await` with `if (context.mounted)` / `if (mounted)`. Existing code does this
  consistently, sometimes twice in a chain; keep it.
- Forms live in `lib/utils/` (`add_form.dart`, `edit_card_form.dart`, `settings_form.dart`) even though they are
  widgets. They are `StatefulWidget` + `GlobalKey<FormState>` + one `TextEditingController` per field, shown via
  `showDialog` inside an `AlertDialog(scrollable: true)`, and close with `Navigator.pop(context)`. Validators
  enforce `maxTitleLength` / `maxDescriptionLength` / `maxAddressLength` (`lib/models/models.dart:109-111`).
  `AddFormState` in `add_form.dart` is the only state class with that name now; `settings_form.dart:23` is
  `SettingsFormState`.
- Reusable presentational widgets go in `lib/components/`, screens in `lib/screens/`.
- Imports are absolute (`package:japan_travel/...`), never relative.
- Colours are inline `Color.fromARGB` literals; the dark background `Color.fromARGB(255, 17, 17, 25)` is repeated
  rather than themed. There is no design-token file. Cards are `BorderRadius.circular(30)` with a white30 glow.
- Every gesture calls `HapticFeedback.mediumImpact()` first.
- Comments use the `// ? ` prefix for explanatory notes and `// *** Label ***` for section markers inside long
  widget trees.
- Dart 3 records are used for small returns: `getHumanizedDistance` returns `(String, Color)` accessed as `.$1` / `.$2`.
- Text is English, hardcoded; there is no localization setup.

## Known traps

- `ListModel.elem` has no bounds check, and `dataList.elem(0)` is reachable with an empty list by deleting the
  last card (that path passes `reloadFromMemory: false`, so the fall-back-to-defaults net is bypassed). Both
  call sites are now guarded, `lib/screens/home.dart:235` and `:290`. Keep the guard on any new one; the
  `RangeError` it used to throw landed inside a `.then` callback and surfaced only as the widget silently
  ceasing to update.
- The card's height is intrinsic apart from the image, which is `MediaQuery.size.height * 0.7`
  (`lib/components/location_card.dart:27`). A short description therefore leaves the card smaller than the
  viewport, which is why `carouselView`'s `SingleChildScrollView` sets `AlwaysScrollableScrollPhysics`: without
  it that card is not scrollable and pull-to-refresh stops working on it.
- `orderDataOnCurrLocation` reports every location problem as `false` and never throws: a permission failure, a
  `deniedForever`/`unableToDetermine` verdict and a GPS timeout all return `false` after a `debugPrint`. So a
  failed fix produces no user-visible error. The widget keeps its last good contents, but the in-app cards all
  read "Here!" because `distance` is never persisted and defaults to `0.0`. Confirmed on the emulator with
  location services off, and with the permission set to `USER_FIXED` denied.
- Nothing on the `updateCards` path throws for an expected condition any more, so `callbackDispatcher`'s
  `Future.error(e)` (and the WorkManager backoff behind it) is reserved for genuinely unexpected failures.
  Keep it that way: do not reintroduce a throw for "no GPS" or "image download failed".
- Widget `updatePeriodMillis` is 86400000 (24h) in `res/xml/card_widget.xml`; the real refresh cadence comes from
  workmanager, not the widget provider.
- `geolocator ^14` and `workmanager ^0.9` have now been exercised on the emulator (API 35): the periodic task
  scheduled and ran, the Dart callback executed in the background isolate, and a fix was obtained in both the
  foreground and the background with `ACCESS_BACKGROUND_LOCATION` granted. workmanager 0.9 rewrote
  periodic-task scheduling and dropped `isInDebugMode`; geolocator 14 tightened Android 14+ background-location
  rules. Re-verify on real hardware before a release, since the emulator's GPS is injected.

## Adding AI features

No AI, network client abstraction, or API-key handling exists yet. `http` is a direct dependency but is used only
to download the widget preview image. Insertion points: `ListModel`/`DataModel` (`lib/models/models.dart`) for
generated card content, and `updateCards` (`lib/screens/home.dart:213`) as the single place already responsible
for enrich-then-persist-then-refresh. Any new secret must not be committed; there is currently no `.env` loading,
no `--dart-define` usage, and no gitignored config file for one.
