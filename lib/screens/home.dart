import 'dart:convert';
import 'dart:io';

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
            Provider.of<ListModel>(context, listen: false), true));
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.8);
  }

  Future<void> initPlatformState() async {
    final handler = ShareHandlerPlatform.instance;
    media = await handler.getInitialSharedMedia();

    handler.sharedMediaStream.listen((SharedMedia media) async {
      if (!mounted) return;
      print('Received shared media: $media');
      print(
          'Received media.conversationIdentifier: ${media.conversationIdentifier}');
      print('Received media.content: ${media.content}');

      // ? Expect a JSON string as content -> use it to update our list
      if (media.content != null && media.content!.isNotEmpty) {
        // check for the content to start with: {"data": [{"title":
        try {
          Map<String, dynamic> receivedJson = jsonDecode(media.content!);
          if (receivedJson.containsKey("data") && receivedJson["data"] is List) {
            List<DataModel> receivedData = dataFromJson(receivedJson);
            Provider.of<ListModel>(context, listen: false).loadData(receivedData);
          }
        } catch (e) {
          print("Error decoding the JSON string: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading data')),
          );
        }
      } else {
        if (media.attachments != null && media.attachments!.isNotEmpty) {
          for(int i = 0; i < media.attachments!.length; i++) {
            SharedAttachment attachment = media.attachments![i]!;
            if (attachment.type == SharedAttachmentType.file && (attachment.path.endsWith(".json") || attachment.path.endsWith(".txt") || attachment.path.endsWith(".md"))) {
              File file = File(attachment.path);
              String fileContent = await file.readAsString();
              try {
                Map<String, dynamic> receivedJson = jsonDecode(fileContent);
                if (receivedJson.containsKey("data") && receivedJson["data"] is List) {
                  List<DataModel> receivedData = dataFromJson(receivedJson);
                  if (mounted) {
                    Provider.of<ListModel>(context, listen: false).loadData(receivedData);
                  }
                }
              } catch (e) {
                print("Error decoding the JSON string: $e");
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
                  Container(height: 75), // ? Padding (Cannot use the padding property otherwise it would clip the top of the card when scrolling)
                  Container(
                    height: 1190.0,
                    alignment: Alignment.center,
                    //transform: Matrix4.translationValues(0.0, 50.0, 0.0),
                    child: LocationCard(
                        data: context.watch<ListModel>().elem(index)),
                  ),
                  Container(height: 25), // ? Padding (Cannot use the padding property otherwise it would clip the bottom of the card when scrolling)
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

Future<void> orderDataOnCurrLocation(ListModel dataList, bool updateAllDistances) async {
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
    DataModel currCard = dataList.elem(i);
    if (!updateAllDistances && currCard.distance > 1.0) { continue; }
    LatLng p1 = LatLng(position.latitude, position.longitude);
    LatLng p2 =
        LatLng(currCard.location.lat, currCard.location.lng);
    num distance = computeDistanceBetween(p1, p2, radius: 6371008.8);
    currCard.distance = distance.toDouble();
    dataList.updateData(currCard, i);
  }
  // ? Sort the array based on distance but also always put to the end of the list the already seen locations
  dataList.sortData();
}
