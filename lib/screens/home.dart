import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/components/add_card.dart';
import 'package:japan_travel/components/location_card.dart';
import 'package:japan_travel/components/settings_card.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geo/geo.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  final int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    loadData(Provider.of<ListModel>(context, listen: false)).then((value) =>
        orderDataOnCurrLocation(
            Provider.of<ListModel>(context, listen: false)));
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.8);
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
                    carouselView(-2),
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
          return const AddCard();
        }
        if (index == -2) {
          return const SettingsCard();
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
                    child: LocationCard(data: context.watch<ListModel>().elem(index)),
                  ),
                  /*
                  Container(
                    color: const Color.fromARGB(255, 17, 17, 25),
                    height: 100.0,
                    alignment: Alignment.center,
                    child: const Text(
                      'Bottom',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                    */
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
