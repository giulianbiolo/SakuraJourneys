import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geo/geo.dart';
import 'package:cached_network_image/cached_network_image.dart';


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
    loadSeenData().then((value) => orderDataOnCurrLocation());
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
                    for (int i = 0; i < dataList.length; i++) carouselView(i),
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
        if (index >= dataList.length) {
          return const SizedBox.shrink();
        }
        return carouselCard(dataList[index]);
      },
    );
  }

  Widget carouselCard(DataModel data) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Hero(
              tag: data.imageName,
              child: GestureDetector(
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  navigateTo(data.location.lat, data.location.lng);
                },
                onLongPress: () => {
                  // ? Here we set the card as a "already seen" location
                  HapticFeedback.mediumImpact(),
                  SharedPreferences.getInstance().then((prefs) {
                    // we want a toggle behaviour
                    int currentStatus = prefs.getInt(data.title) ?? 0;
                    if (currentStatus == LocationStatus.seen.index) {
                      prefs.setInt(data.title, LocationStatus.unseen.index);
                      data.alreadySeen = false;
                      dataList.remove(data);
                      // insert it in the correct position based on distance
                      for (int i = 0; i < dataList.length; i++) {
                        if (dataList[i].alreadySeen ||
                            data.distance < dataList[i].distance) {
                          dataList.insert(i, data);
                          break;
                        }
                      }
                      if (!dataList.contains(data)) {
                        dataList.add(data);
                      }
                    } else {
                      prefs.setInt(data.title, LocationStatus.seen.index);
                      dataList.remove(data);
                      data.alreadySeen = true;
                      dataList.add(data);
                    }
                    rebuildAllChildren(context);
                  })
                },
                //child: Container(

                  child: CachedNetworkImage(
                    imageUrl: data.imageName,
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            colorFilter: data.alreadySeen
                                ? ColorFilter.mode(
                                    Colors.black.withOpacity(0.6),
                                    BlendMode.darken)
                                : null
                        ),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(0, 0),
                            blurRadius: 6,
                            color: Colors.white30,
                          )
                        ]
                      ),
                    ),
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),

                  /*
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      image: DecorationImage(
                        image: Image.network(data.imageName).image,
                        fit: BoxFit.cover,
                        colorFilter: data.alreadySeen
                            ? ColorFilter.mode(
                                Colors.black.withOpacity(0.6), BlendMode.darken)
                            : null,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          offset: Offset(0, 0),
                          blurRadius: 6,
                          color: Colors.white30,
                        )
                      ]
                  ),
                  */

                //),
              ),
            ),
          ),
        ),
        Padding(
          // ******* Rating Indicator *******
          padding: const EdgeInsets.only(left: 25.0, right: 25.0),
          child: LinearProgressIndicator(
            value: data.rating / 300,
            backgroundColor: data.alreadySeen
                ? const Color.fromARGB(40, 195, 191, 255)
                : const Color.fromARGB(77, 195, 191, 255),
            valueColor: data.alreadySeen
                ? const AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(100, 244, 17, 95))
                : const AlwaysStoppedAnimation<Color>(
                    Color.fromARGB(224, 244, 17, 95)),
            borderRadius: BorderRadius.circular(15),
            minHeight: 15,
          ),
        ),
        Padding(
          // ******* Title *******
          padding: const EdgeInsets.only(top: 10.0, left: 10.0, right: 10.0),
          child: Text(
            data.title,
            style: TextStyle(
                color: data.alreadySeen ? Colors.grey : Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          // ******* Location *******
          padding: const EdgeInsets.only(bottom: 10.0),
          child: SizedBox(
            width: 250,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  textAlign: TextAlign.left,
                  data.address.length > 25
                      ? "${data.address.substring(0, 25)}..."
                      : data.address,
                  style: TextStyle(
                      color: data.alreadySeen ? Colors.white70 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.normal),
                ),
                Badge(
                  alignment: Alignment.center,
                  backgroundColor: getHumanizedDistance(data.distance).$2,
                  label: Text(
                    textAlign: TextAlign.right,
                    getHumanizedDistance(data.distance).$1,
                    style: TextStyle(
                        color: data.alreadySeen
                            ? const Color.fromARGB(150, 255, 255, 255)
                            : const Color.fromARGB(210, 255, 255, 255),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
        Padding(
            // ******* Description *******
            padding: const EdgeInsets.all(0.0),
            child: SizedBox(
              height: 120,
              width: 300,
              child: Center(
                child: Text(
                  data.description.length > 200
                      ? "${data.description.substring(0, 200)}..."
                      : data.description,
                  style: TextStyle(
                      color: data.alreadySeen ? Colors.white54 : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.normal),
                  textAlign: TextAlign.center,
                ),
              ),
            )),
      ],
    );
  }
}

(String, Color) getHumanizedDistance(double distance) {
  if (distance < 50.0) {
    return ("Here!", Colors.blue);
  }
  if (distance < 100.0) {
    return ("< 100 m", Colors.teal);
  }
  if (distance < 1000.0) {
    return ("${distance.toStringAsFixed(0)} m", Colors.green);
  }
  if (distance < 10000.0) {
    return ("${(distance / 1000.0).toStringAsFixed(2)} km", Colors.orange);
  }
  if (distance < 100000.0) {
    return ("${(distance / 1000.0).toStringAsFixed(1)} km", Colors.deepOrange);
  }
  return ("${(distance / 1000.0).toStringAsFixed(0)} km", Colors.purple);
}

Future<void> navigateTo(double lat, double lng) async {
  var uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> loadSeenData() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  for (int i = 0; i < dataList.length; i++) {
    int status = prefs.getInt(dataList[i].title) ?? 0;
    if (status == LocationStatus.seen.index) {
      dataList[i].alreadySeen = true;
    }
  }
}

Future<void> orderDataOnCurrLocation() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
  }
  Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  for (int i = 0; i < dataList.length; i++) {
    LatLng p1 = LatLng(position.latitude, position.longitude);
    LatLng p2 = LatLng(dataList[i].location.lat, dataList[i].location.lng);
    num distance = computeDistanceBetween(p1, p2, radius: 6371008.8);
    dataList[i].distance = distance.toDouble();
  }
  // ? Sort the array based on distance but also always put to the end of the list the already seen locations
  // dataList.sort((a, b) => a.distance.compareTo(b.distance)); # this only sorts based on distance
  dataList.sort((a, b) {
    if (a.alreadySeen && !b.alreadySeen) {
      return 1;
    }
    if (!a.alreadySeen && b.alreadySeen) {
      return -1;
    }
    return a.distance.compareTo(b.distance);
  });
}

void rebuildAllChildren(BuildContext context) {
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}
