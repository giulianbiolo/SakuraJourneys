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
import 'package:geo/geo.dart';
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
    _boot = updateCards(Provider.of<ListModel>(context, listen: false))
        .catchError((Object e) => debugPrint('Initial load failed: $e'));
    initPlatformState();
    _pageController = PageController(viewportFraction: 0.8);
    _indicatorController = IndicatorController();
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
    try {
      Map<String, dynamic> receivedJson = jsonDecode(raw);
      if (!receivedJson.containsKey("data") || receivedJson["data"] is! List) {
        throw const FormatException('missing "data" list');
      }
      receivedData = ListModel.fromJson(receivedJson);
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
    model.loadData(receivedData);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('dataList', jsonEncode(model.toJson()));
    try {
      await updateCards(model,
          reloadFromMemory: false,
          reorderData: true,
          updateAllDistances: false);
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
        onRefresh: () async {
          // ? Load the data from the shared media
          if (context.mounted) {
            try {
              await updateCards(Provider.of<ListModel>(context, listen: false));
            } catch (e) {
              // ? The indicator only shows an error state, so keep the cause.
              rethrow;
            }
          } else {
            throw Exception("Context is not mounted");
          }
        },
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

Future<void> updateCards(ListModel dataList,
    {bool reloadFromMemory = true,
    bool reorderData = true,
    bool updateAllDistances = true}) async {
  if (reloadFromMemory) {
    await loadData(dataList);
  }
  if (reorderData) {
    // ? Distances are never persisted, so without a fix they are all 0.0 and the
    // ? widget would label an arbitrary card "Here!". Keep the last good write.
    if (!await orderDataOnCurrLocation(dataList, updateAllDistances)) {
      return Future.value();
    }
  }
  await updateWidget(dataList);
  return Future.value();
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

/// Returns whether a position fix was obtained and the distances updated.
Future<bool> orderDataOnCurrLocation(
    ListModel dataList, bool updateAllDistances) async {
  LocationPermission permission;
  try {
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  } catch (e) {
    // ? Reported, not thrown: a headless isolate has no activity to attach a
    // ? permission request to, and throwing makes workmanager retry with backoff.
    debugPrint('Location permission check failed: $e');
    return false;
  }
  // ? Covers deniedForever from the initial check and unableToDetermine, both of
  // ? which would otherwise fall through to a getCurrentPosition that always fails.
  if (permission != LocationPermission.always &&
      permission != LocationPermission.whileInUse) {
    return false;
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
  } catch (e) {
    return false;
  }
  for (int i = 0; i < dataList.length(); i++) {
    DataModel currCard = dataList.elem(i);
    if (!updateAllDistances && currCard.distance > 1.0) {
      continue;
    }
    LatLng p1 = LatLng(position.latitude, position.longitude);
    LatLng p2 = LatLng(currCard.location.lat, currCard.location.lng);
    num distance = computeDistanceBetween(p1, p2, radius: 6371008.8);
    // ? currCard is _data[i] itself, so updateData would only re-notify: one full
    // ? carousel rebuild per card. sortData() below notifies once for the batch.
    currCard.distance = distance.toDouble();
  }
  dataList.sortData();
  if (dataList.length() > 0) {
    prefs.setDouble('lastCloserLocation', dataList.elem(0).distance);
  }
  return true;
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
