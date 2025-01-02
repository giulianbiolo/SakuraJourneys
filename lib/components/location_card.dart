import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/screens/home.dart';
import 'package:japan_travel/utils/edit_card_form.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';

class LocationCard extends StatelessWidget {
  final DataModel data;
  const LocationCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 1,
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
                    if (context.mounted) {
                      Provider.of<ListModel>(context, listen: false)
                          .removeData(data);
                    }
                    //context.watch<ListModel>().removeData(data);

                    // insert it in the correct position based on distance
                    if (!context.mounted) return;
                    for (int i = 0;
                        i <
                            Provider.of<ListModel>(context, listen: false)
                                .length();
                        i++) {
                      if (Provider.of<ListModel>(context, listen: false)
                              .elem(i)
                              .alreadySeen ||
                          data.distance <
                              Provider.of<ListModel>(context, listen: false)
                                  .elem(i)
                                  .distance) {
                        Provider.of<ListModel>(context, listen: false)
                            .insertData(data, i);
                        break;
                      }
                    }
                    if (!Provider.of<ListModel>(context, listen: false)
                        .contains(data)) {
                      Provider.of<ListModel>(context, listen: false)
                          .addData(data);
                    }
                  } else {
                    prefs.setInt(data.title, LocationStatus.seen.index);
                    if (context.mounted) {
                      Provider.of<ListModel>(context, listen: false)
                          .removeData(data);
                      data.alreadySeen = true;
                      Provider.of<ListModel>(context, listen: false)
                          .addData(data);
                    }
                  }
                  // ? Save data to SharedPreferences
                  if (!context.mounted) return;
                  prefs.setString(
                      "dataList",
                      jsonEncode(Provider.of<ListModel>(context, listen: false)
                          .toJson()));
                  updateCards(Provider.of<ListModel>(context, listen: false),
                      reloadFromMemory: false,
                      reorderData: false,
                      updateAllDistances: false);
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
                              urlTo404Page,
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: LinearProgressIndicator(
            value: data.rating / 5.0,
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
        Expanded(
          flex: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                // *** Card Title ***
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  data.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: data.alreadySeen ? Colors.grey : Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                // *** Card Location & Distance Badge ***
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: SizedBox(
                  width: (MediaQuery.of(context).size.width),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          data.address,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              color: data.alreadySeen
                                  ? Colors.white70
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.normal),
                        ),
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
                // *** Description & Action Buttons For Single Card ***
                padding:
                    const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
                child: SizedBox(
                    height: 450,
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Html(
                            data: data.description.length > maxDescriptionLength
                                ? "<p>${data.description.substring(0, maxDescriptionLength)}...</p>"
                                : "<p>${data.description}</p>",
                            style: {
                              "p": Style(
                                color: data.alreadySeen
                                    ? Colors.white54
                                    : Colors.white70,
                                fontSize: FontSize(14),
                                fontWeight: FontWeight.normal,
                                textAlign: TextAlign.center,
                                height: Height(370),
                              ),
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // *** Quick Share Of Single Card ***
                              IconButton(
                                onPressed: () async {
                                  ListModel singleCard = ListModel();
                                  singleCard.addData(data);
                                  Map<String, dynamic> jsonData =
                                      singleCard.toJson();
                                  String jsonString = jsonEncode(jsonData);
                                  Share.share(jsonString);
                                },
                                style: const ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                        Color.fromARGB(24, 0, 200, 255))),
                                icon: const Icon(Icons.share,
                                    size: 32, color: Colors.blue),
                              ),
                              // *** Edit Of Single Card ***
                              IconButton(
                                onPressed: () async {
                                  // ? Edit Form here
                                  await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Edit Card Info"),
                                        scrollable: true,
                                        content: Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8.0, left: 8.0, right: 8.0),
                                          child: EditCardForm(
                                            initialCardData: data,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                style: const ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                        Color.fromARGB(25, 255, 100, 0))),
                                icon: const Icon(Icons.edit_note,
                                    size: 32, color: Colors.orange),
                              ),

                              // *** Delete Of Single Card ***
                              IconButton(
                                onPressed: () => {
                                  // ? Remove the card
                                  Provider.of<ListModel>(context, listen: false)
                                      .removeData(data),
                                  SharedPreferences.getInstance().then((prefs) {
                                    if (context.mounted) {
                                      Map<String, dynamic> newCards =
                                          Provider.of<ListModel>(context,
                                                  listen: false)
                                              .toJson();
                                      prefs.setString(
                                          'dataList', jsonEncode(newCards));
                                    }                                    
                                    updateCards(
                                        Provider.of<ListModel>(context,
                                            listen: false),
                                        reloadFromMemory: false,
                                        reorderData: false,
                                        updateAllDistances: false);
                                  }),
                                },
                                style: const ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                        Color.fromARGB(25, 255, 0, 0))),
                                icon: const Icon(
                                  Icons.close,
                                  size: 32,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          )
                        ])),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> navigateTo(double lat, double lng) async {
    var uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
