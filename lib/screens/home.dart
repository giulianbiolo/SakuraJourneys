import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/components/add_settings_card.dart';
import 'package:japan_travel/components/location_card.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geo/geo.dart';
import 'package:provider/provider.dart';
import 'package:share_handler/share_handler.dart';
import 'package:share_handler_platform_interface/share_handler_platform_interface.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  final int _currentPage = 0;
  SharedMedia? media;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    loadData(Provider.of<ListModel>(context, listen: false)).then((value) =>
        orderDataOnCurrLocation(
            Provider.of<ListModel>(context, listen: false)));
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.8);
  }

  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    media = await handler.getInitialSharedMedia();

    handler.sharedMediaStream.listen((SharedMedia media) {
      if (!mounted) return;
      print('Received shared media: $media');
      print(
          'Received media.conversationIdentifier: ${media.conversationIdentifier}');
      print('Received media.content: ${media.content}');

      // ? Expect a JSON string as content -> use it to update our list
      if (media.content != null && media.content!.isNotEmpty) {
        // check for the content to start with: {"data": [{"title":
        if (media.content!.startsWith("{\"data\":[{\"title\":")) {
          Map<String, dynamic> receivedJson = jsonDecode(media.content!);
          List<DataModel> receivedData = dataFromJson(receivedJson);
          Provider.of<ListModel>(context, listen: false).loadData(receivedData);
        }
      }
    });
    if (!mounted) return;
  }

  @override
  void dispose() {
    super.dispose();
    _pageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            AspectRatio(
                aspectRatio: 0.55,
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
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Container(
                    height: 1100.0,
                    alignment: Alignment.center,
                    child: LocationCard(
                        data: context.watch<ListModel>().elem(index)),
                  ),
                ],
              )),
        );
      },
    );
  }
}

Future<void> loadData(ListModel dataList) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String dataString = (prefs.getString("dataList") ?? "")
      .trim()
      .replaceAll("\n", "")
      .replaceAll("[", "")
      .replaceAll("]", "");
  print("Now loading the following string:\n$dataString");
  List<DataModel> savedList = dataFromString(dataString);
  dataList.loadData(savedList);
}

Future<void> orderDataOnCurrLocation(ListModel dataList) async {
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
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  for (int i = 0; i < dataList.length(); i++) {
    LatLng p1 = LatLng(position.latitude, position.longitude);
    LatLng p2 =
        LatLng(dataList.elem(i).location.lat, dataList.elem(i).location.lng);
    num distance = computeDistanceBetween(p1, p2, radius: 6371008.8);
    DataModel data = dataList.elem(i);
    data.distance = distance.toDouble();
    dataList.updateData(data, i);
  }
  // ? Sort the array based on distance but also always put to the end of the list the already seen locations
  dataList.sortData();
}
