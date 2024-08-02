import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/utils/add_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapping_page_scroll/snapping_page_scroll.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geo/geo.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.8);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadSeenData(Provider.of<ListModel>(context, listen: false)).then((value) => orderDataOnCurrLocation(Provider.of<ListModel>(context, listen: false)));
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
                    for (int i = 0; i < context.watch<ListModel>().length(); i++) carouselView(i),
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
          return addCard();
        }
        return carouselCard(context.watch<ListModel>().elem(index));
      },
    );
  }

  Widget addCard() {
    return Column(children: <Widget>[
      Expanded(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            // ? Open the new card form menu popup
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const AlertDialog(
                    title: Text("Add a new location"),
                    scrollable: true,
                    content: Padding(
                      padding: EdgeInsets.only(
                          top: 8.0, left: 8.0, right: 8.0),
                      child: AddForm(),
                    ),
                  );
                });
          },
          child: Hero(
            tag: "addCard",
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: const Color.fromARGB(255, 17, 17, 25),
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.white30,
                      )
                    ]),
                child: const SizedBox(
                  width: 300,
                  child: Icon(
                    Icons.add,
                    size: 100,
                    color: Colors.white70,
                  ),
                )),
          ),
        ),
      ))
    ]);
  }

  Widget carouselCard(DataModel data) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
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
                    Provider.of<ListModel>(context, listen: false).removeData(data);
                    //context.watch<ListModel>().removeData(data);

                    // insert it in the correct position based on distance
                    for (int i = 0; i < Provider.of<ListModel>(context, listen: false).length(); i++) {
                      if (Provider.of<ListModel>(context, listen: false).elem(i).alreadySeen ||
                          data.distance < Provider.of<ListModel>(context, listen: false).elem(i).distance) {
                        Provider.of<ListModel>(context, listen: false).insertData(data, i);
                        break;
                      }
                    }
                    if (!Provider.of<ListModel>(context, listen: false).contains(data)) {
                      Provider.of<ListModel>(context, listen: false).addData(data);
                    }
                  } else {
                    prefs.setInt(data.title, LocationStatus.seen.index);
                    Provider.of<ListModel>(context, listen: false).removeData(data);
                    data.alreadySeen = true;
                    Provider.of<ListModel>(context, listen: false).addData(data);
                  }
                  Provider.of<ListModel>(context, listen: false).notify();
                })
              },
              child: Hero(
                tag: data.imageName,
                child: CachedNetworkImage(
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        image: DecorationImage(
                            image: Image.network(
                              "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/404page.jpg?raw=true",
                              fit: BoxFit.cover,
                            ).image,
                            fit: BoxFit.cover,
                            colorFilter: data.alreadySeen
                                ? ColorFilter.mode(
                                    Colors.black.withOpacity(0.6),
                                    BlendMode.darken)
                                : null),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(0, 0),
                            blurRadius: 6,
                            color: Colors.white30,
                          )
                        ]),
                  ),
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
                                : null),
                        boxShadow: const [
                          BoxShadow(
                            offset: Offset(0, 0),
                            blurRadius: 6,
                            color: Colors.white30,
                          )
                        ]),
                  ),
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                ),
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

Future<void> loadSeenData(ListModel dataList) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  for (int i = 0; i < dataList.length(); i++) {
    int status = prefs.getInt(dataList.elem(i).title) ?? 0;
    if (status == LocationStatus.seen.index) {
      dataList.elem(i).alreadySeen = true;
    }
  }
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
