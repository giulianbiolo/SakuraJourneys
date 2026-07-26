import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/components/add_settings_card.dart';
import 'package:japan_travel/components/location_card.dart';
import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/utils/home_widget_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:share_handler/share_handler.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:japan_travel/components/check_mark_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  late IndicatorController _indicatorController;
  // ? An import that lands mid-boot would otherwise be overwritten by the load it
  // ? races: loadData reads the pref into the same model the import just extended.
  late Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _bootstrap();
    initPlatformState();
    _pageController = PageController(viewportFraction: 0.8);
    _indicatorController = IndicatorController();
  }

  // ? Never completes with an error: _handleSharedMedia awaits this future, and an
  // ? unhandled rejection there would drop the share that cold-started the app.
  Future<void> _bootstrap() async {
    LocationFixResult result;
    try {
      result =
          await updateCards(Provider.of<ListModel>(context, listen: false));
    } catch (e) {
      debugPrint('Initial load failed: $e');
      return;
    }
    _reportLocationResult(result);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    LocationFixResult result =
        await updateCards(Provider.of<ListModel>(context, listen: false));
    _reportLocationResult(result);
  }

  // ? Every location problem used to be the same silent false, so a denied
  // ? permission was indistinguishable from the app being broken.
  // ? A snackbar rather than a MaterialBanner: the banner is laid out inside the
  // ? Scaffold body, and the carousel's AspectRatio already claims the full screen
  // ? height, so it overflowed by exactly the banner's height.
  void _reportLocationResult(LocationFixResult result) {
    if (!mounted) return;
    ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (result == LocationFixResult.updated ||
        result == LocationFixResult.skipped) {
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(locationProblemText(result)),
        action: SnackBarAction(
          label: locationActionText(result),
          onPressed: () async => await _resolveLocationProblem(result),
        ),
      ));
  }

  Future<void> _resolveLocationProblem(LocationFixResult result) async {
    switch (result) {
      case LocationFixResult.serviceDisabled:
        await Geolocator.openLocationSettings();
        return;
      case LocationFixResult.permissionDeniedForever:
        await Geolocator.openAppSettings();
        return;
      case LocationFixResult.permissionDenied:
      case LocationFixResult.unavailable:
        // ? orderDataOnCurrLocation asks again on its own, so a plain retry is
        // ? both the "ask for permission" and the "try the GPS again" action.
        try {
          await _refresh();
        } catch (e) {
          debugPrint('Location retry failed: $e');
        }
        return;
      case LocationFixResult.updated:
      case LocationFixResult.skipped:
        return;
    }
  }

  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    // ? listen() must run before the first await: the plugin already handled the
    // ? launch intent while its eventSink was null, so that event was dropped and
    // ? getInitialSharedMedia() is the only way to see a cold-start share.
    handler.sharedMediaStream.listen(_handleSharedMedia);
    final SharedMedia? initial = await handler.getInitialSharedMedia();
    if (initial != null) {
      await _handleSharedMedia(initial);
      await handler.resetInitialSharedMedia();
    }
  }

  Future<void> _handleSharedMedia(SharedMedia media) async {
    await _boot;
    if (!mounted) return;
    // ? Expect a JSON string as content, or a JSON-ish file attachment.
    String? payload = media.content;
    if (payload == null || payload.isEmpty) {
      payload = await _readSharedJsonFile(media);
    }
    if (payload == null || payload.isEmpty) return;
    await _importJson(payload);
  }

  Future<String?> _readSharedJsonFile(SharedMedia media) async {
    for (final SharedAttachment? attachment
        in media.attachments ?? const <SharedAttachment?>[]) {
      if (attachment == null) continue;
      if (attachment.type != SharedAttachmentType.file) continue;
      if (!attachment.path.endsWith(".json") &&
          !attachment.path.endsWith(".txt") &&
          !attachment.path.endsWith(".md")) {
        continue;
      }
      try {
        return await File(attachment.path).readAsString();
      } catch (e) {
        // ? Unreadable path or revoked permission: try the next attachment.
        debugPrint('Could not read shared file ${attachment.path}: $e');
        continue;
      }
    }
    return null;
  }

  Future<void> _importJson(String raw) async {
    List<DataModel> receivedData;
    int offered;
    try {
      Map<String, dynamic> receivedJson = jsonDecode(raw);
      if (!isImportable(receivedJson)) {
        throw const FormatException('neither a "data" nor a "features" list');
      }
      final parsed = parseImport(receivedJson);
      receivedData = parsed.cards;
      offered = parsed.offered;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data')),
        );
      }
      return;
    }
    if (!mounted) return;
    ListModel model = Provider.of<ListModel>(context, listen: false);
    ImportCounts counts = model.loadData(receivedData);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(counts.summary(offered - receivedData.length)),
    ));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('dataList', jsonEncode(model.toJson()));
    try {
      LocationFixResult result = await updateCards(model,
          reloadFromMemory: false,
          reorderData: true,
          updateAllDistances: false);
      _reportLocationResult(result);
    } catch (e) {
      // ? A failed GPS fix is not an import failure; the cards are already saved.
      debugPrint('Distance refresh after import failed: $e');
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CheckMarkIndicator(
        controller: _indicatorController,
        // ? Errors propagate on purpose: the indicator has an error state, and
        // ? a location problem is reported by _refresh's banner instead.
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AspectRatio(
                  aspectRatio: MediaQuery.of(context).size.aspectRatio,
                  child: SnappingPageScroll(
                    onPageChanged: (value) => {
                      HapticFeedback.mediumImpact(),
                    },
                    controller: _pageController,
                    children: [
                      for (int i = 0;
                          i < context.watch<ListModel>().length();
                          i++)
                        carouselView(i),
                      carouselView(-1),
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }

  Widget carouselView(int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        if (index >= context.watch<ListModel>().length()) {
          return const SizedBox.shrink();
        }
        if (index == -1) {
          return const AddSettingsCard();
        }
        //return carouselCard(context.watch<ListModel>().elem(index));
        return SingleChildScrollView(
          dragStartBehavior: DragStartBehavior.down,
          primary: true,
          // ? The card is intrinsically sized now, so a short description can leave it
          // ? smaller than the viewport; without this, pull-to-refresh dies with it.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Container(
                  height:
                      75), // ? Padding (Cannot use the padding property otherwise it would clip the top of the card when scrolling)
              // ? Height comes from the card itself: a fixed slot either clipped the
              // ? description or left a gap, depending on the screen.
              LocationCard(data: context.watch<ListModel>().elem(index)),
              Container(
                  height:
                      25), // ? Padding (Cannot use the padding property otherwise it would clip the bottom of the card when scrolling)
            ],
          ),
        );
      },
    );
  }
}

/// Why a distance refresh did not happen, so the caller can say so.
enum LocationFixResult {
  /// A fix arrived and the distances were recomputed from it.
  updated,

  /// The caller asked for no reordering, so no fix was attempted.
  skipped,

  /// Location services are off device-wide.
  serviceDisabled,

  /// Permission refused, but askable again.
  permissionDenied,

  /// Permission refused permanently; only system settings can undo it.
  permissionDeniedForever,

  /// Allowed, but no position arrived (timeout, no provider, headless isolate).
  unavailable,
}

String locationProblemText(LocationFixResult result) {
  switch (result) {
    case LocationFixResult.serviceDisabled:
      return 'Location is off, so distances may be out of date.';
    case LocationFixResult.permissionDenied:
      return 'Location access is needed to sort places by distance.';
    case LocationFixResult.permissionDeniedForever:
      return 'Location access is blocked, so distances cannot update.';
    case LocationFixResult.unavailable:
    case LocationFixResult.updated:
    case LocationFixResult.skipped:
      return 'No location fix, so distances may be out of date.';
  }
}

String locationActionText(LocationFixResult result) {
  switch (result) {
    case LocationFixResult.serviceDisabled:
      return 'Turn on';
    case LocationFixResult.permissionDenied:
      return 'Allow';
    case LocationFixResult.permissionDeniedForever:
      return 'Settings';
    case LocationFixResult.unavailable:
    case LocationFixResult.updated:
    case LocationFixResult.skipped:
      return 'Retry';
  }
}

Future<LocationFixResult> updateCards(ListModel dataList,
    {bool reloadFromMemory = true,
    bool reorderData = true,
    bool updateAllDistances = true}) async {
  if (reloadFromMemory) {
    await loadData(dataList);
  }
  LocationFixResult result = LocationFixResult.skipped;
  if (reorderData) {
    result = await orderDataOnCurrLocation(dataList, updateAllDistances);
    // ? Without a fix the distances are at best from the previous one, so the
    // ? nearest card may well be one the user has already walked away from.
    // ? Leave the widget on its last good write rather than dating it.
    if (result != LocationFixResult.updated) {
      return result;
    }
  }
  await updateWidget(dataList);
  return result;
}

// ? Deliberately not deferred to a post-frame callback: the workmanager isolate
// ? never builds a frame, so the callback would be queued there and never run.
Future<void> updateWidget(ListModel dataList) async {
  await HomeWidgetConfig.initialize();
  if (dataList.length() == 0) {
    // ? Deleting the last card is the only way here, and elem(0) would throw.
    await HomeWidgetConfig.updateEmpty();
    return;
  }
  await HomeWidgetConfig.update(dataList.elem(0));
}

/// One position fix. Every failure is reported as a [LocationFixResult] rather
/// than thrown: a headless isolate has no activity to attach a permission request
/// to, and throwing makes workmanager retry with backoff. The position is null for
/// anything other than [LocationFixResult.updated].
Future<(LocationFixResult, Position?)> currentPosition() async {
  LocationPermission permission;
  try {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  } catch (e) {
    debugPrint('Location permission check failed: $e');
    return (LocationFixResult.unavailable, null);
  }
  switch (permission) {
    case LocationPermission.always:
    case LocationPermission.whileInUse:
      break;
    case LocationPermission.denied:
      return (LocationFixResult.permissionDenied, null);
    case LocationPermission.deniedForever:
      return (LocationFixResult.permissionDeniedForever, null);
    case LocationPermission.unableToDetermine:
      return (LocationFixResult.unavailable, null);
  }
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (LocationFixResult.serviceDisabled, null);
    }
  } catch (e) {
    debugPrint('Location service check failed: $e');
    return (LocationFixResult.unavailable, null);
  }
  SharedPreferences prefs = await SharedPreferences.getInstance();
  double lastCloserLocation = prefs.getDouble('lastCloserLocation') ?? 0.0;
  LocationAccuracy intelligentAccuracy =
      computeIntelligentAccuracy(lastCloserLocation);
  Position position;
  try {
    position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
            accuracy: intelligentAccuracy,
            timeLimit: const Duration(seconds: 10)));
  } on LocationServiceDisabledException {
    return (LocationFixResult.serviceDisabled, null);
  } catch (e) {
    debugPrint('Location fix failed: $e');
    return (LocationFixResult.unavailable, null);
  }
  // ? Stored before the caller does anything with it, so the next cold start can
  // ? order the deck from this fix even if the app is killed here.
  await saveLastFix(position.latitude, position.longitude);
  return (LocationFixResult.updated, position);
}

/// Takes a fix and, on success, recomputes distances and re-sorts the deck.
Future<LocationFixResult> orderDataOnCurrLocation(
    ListModel dataList, bool updateAllDistances) async {
  final (LocationFixResult result, Position? position) =
      await currentPosition();
  if (position == null) return result;
  dataList.applyDistancesFrom(
      LocationModel(position.latitude, position.longitude),
      onlyMissing: !updateAllDistances);
  dataList.sortData();
  if (dataList.length() > 0) {
    double? closest = dataList.elem(0).distance;
    if (closest != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lastCloserLocation', closest);
    }
  }
  return result;
}

/// Given the [lastCloserLocation] this function will return the intelligent accuracy
/// which is the best accuracy to use when computing the new distances
/// to maximize power efficiency by at the same time keeping the distance values
/// as accurate as possible, this is a trade-off between power consumption and accuracy
/// * If the last closer location is more than 100km away, then we can use LocationAccuracy.low
/// * If the last closer location is more than 10km away, then we can use LocationAccuracy.medium
/// * If the last closer location is more than 1km away, then we can use LocationAccuracy.high
/// * If the last closer location is less than 1km away, then we can use LocationAccuracy.best
LocationAccuracy computeIntelligentAccuracy(double lastCloserLocation) {
  if (lastCloserLocation > 100000.0) {
    return LocationAccuracy.low;
  }
  if (lastCloserLocation > 10000.0) {
    return LocationAccuracy.medium;
  }
  if (lastCloserLocation > 1000.0) {
    return LocationAccuracy.high;
  }
  return LocationAccuracy.best;
}
