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
  final int _currentPage = 0;
  SharedMedia? media;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    updateCards(Provider.of<ListModel>(context, listen: false));
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.8);
    _indicatorController = IndicatorController();
  }

  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    media = await handler.getInitialSharedMedia();

    handler.sharedMediaStream.listen((SharedMedia media) async {
      if (!mounted) return;
      // ? Expect a JSON string as content -> use it to update our list
      if (media.content != null && media.content!.isNotEmpty) {
        // check for the content to start with: {"data": [{"title":
        try {
          Map<String, dynamic> receivedJson = jsonDecode(media.content!);
          if (receivedJson.containsKey("data") &&
              receivedJson["data"] is List) {
            List<DataModel> receivedData = dataFromJson(receivedJson);
            Provider.of<ListModel>(context, listen: false)
                .loadData(receivedData);
            SharedPreferences prefs = await SharedPreferences.getInstance();
            if (mounted) {
              prefs.setString('dataList',
                  Provider.of<ListModel>(context, listen: false).toString());
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error loading data')),
            );
          }
        }
      } else {
        if (media.attachments != null && media.attachments!.isNotEmpty) {
          for (int i = 0; i < media.attachments!.length; i++) {
            SharedAttachment attachment = media.attachments![i]!;
            if (attachment.type == SharedAttachmentType.file &&
                (attachment.path.endsWith(".json") ||
                    attachment.path.endsWith(".txt") ||
                    attachment.path.endsWith(".md"))) {
              File file = File(attachment.path);
              String fileContent = await file.readAsString();
              try {
                Map<String, dynamic> receivedJson = jsonDecode(fileContent);
                if (receivedJson.containsKey("data") &&
                    receivedJson["data"] is List) {
                  List<DataModel> receivedData = dataFromJson(receivedJson);
                  if (mounted) {
                    Provider.of<ListModel>(context, listen: false)
                        .loadData(receivedData);
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    if (mounted) {
                      prefs.setString(
                          'dataList',
                          Provider.of<ListModel>(context, listen: false)
                              .toString());
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error loading data')),
                  );
                }
              }
            }
          }
        }
      }
    });
    if (!mounted) return;
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
              throw Exception("Context is not mounted");
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              Container(
                  height:
                      75), // ? Padding (Cannot use the padding property otherwise it would clip the top of the card when scrolling)
              Container(
                height: 1190.0,
                alignment: Alignment.center,
                //transform: Matrix4.translationValues(0.0, 50.0, 0.0),
                child:
                    LocationCard(data: context.watch<ListModel>().elem(index)),
              ),
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
    bool updateAllDistances = true,
    LocationAccuracy desiredAccuracy = LocationAccuracy.high}) async {
  if (reloadFromMemory) {
    await loadData(dataList);
  }
  if (reorderData) {
    await orderDataOnCurrLocation(dataList, updateAllDistances);
  }
  updateWidget(dataList);
}

void updateWidget(ListModel dataList) {
  WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
    HomeWidgetConfig.initialize().then((value) async {
      HomeWidgetConfig.update(dataList.elem(0));
    });
  });
}

Future<void> orderDataOnCurrLocation(
    ListModel dataList, bool updateAllDistances) async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
    }
  } catch (e) {
    return;
  }
  SharedPreferences prefs = await SharedPreferences.getInstance();
  double lastCloserLocation = prefs.getDouble('lastCloserLocation') ?? 0.0;
  LocationAccuracy intelligentAccuracy = computeIntelligentAccuracy(lastCloserLocation);
  Position position =
      await Geolocator.getCurrentPosition(desiredAccuracy: intelligentAccuracy);
  for (int i = 0; i < dataList.length(); i++) {
    DataModel currCard = dataList.elem(i);
    if (!updateAllDistances && currCard.distance > 1.0) {
      continue;
    }
    LatLng p1 = LatLng(position.latitude, position.longitude);
    LatLng p2 = LatLng(currCard.location.lat, currCard.location.lng);
    num distance = computeDistanceBetween(p1, p2, radius: 6371008.8);
    currCard.distance = distance.toDouble();
    dataList.updateData(currCard, i);
  }
  dataList.sortData();
  prefs.setDouble('lastCloserLocation', dataList.elem(0).distance);
}

/// Given the [lastCloserLocation] this function will return the intelligent accuracy
/// which is the best accuracy to use when computing the new distances
/// to maximize power efficiency by at the same time keeping the distance values
/// as accurate as possible, this is a trade-off between power consumption and accuracy
/// * If the last closer location is more than 1000km away, then we can use LocationAccuracy.lowest
/// * If the last closer location is more than 100km away, then we can use LocationAccuracy.low
/// * If the last closer location is more than 10km away, then we can use LocationAccuracy.medium
/// * If the last closer location is more than 1km away, then we can use LocationAccuracy.high
/// * If the last closer location is less than 1km away, then we can use LocationAccuracy.best
LocationAccuracy computeIntelligentAccuracy(double lastCloserLocation) {
  if (lastCloserLocation > 1000000.0) {
    return LocationAccuracy.lowest;
  } else if (lastCloserLocation > 100000.0) {
    return LocationAccuracy.low;
  } else if (lastCloserLocation > 10000.0) {
    return LocationAccuracy.medium;
  } else if (lastCloserLocation > 1000.0) {
    return LocationAccuracy.high;
  } else {
    return LocationAccuracy.best;
  }
}
