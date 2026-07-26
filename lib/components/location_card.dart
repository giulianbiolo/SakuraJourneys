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
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          // ? The one measured height left on the card: everything below it sizes to
          // ? its content, so the image is what fixes the card's proportions.
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: GestureDetector(
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                navigateTo(data.location.lat, data.location.lng);
              },
              // ? Here we set the card as a "already seen" location
              onLongPress: () => _toggleSeen(context),
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
        SizedBox(
          width: double.infinity,
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
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Html(
                            data: _descriptionHtml(),
                            style: {
                              "p": Style(
                                color: data.alreadySeen
                                    ? Colors.white54
                                    : Colors.white70,
                                fontSize: FontSize(14),
                                fontWeight: FontWeight.normal,
                                textAlign: TextAlign.center,
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
                                  Map<String, dynamic> jsonData =
                                      ListModel.toJsonSingle(data);
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
                                onPressed: () => _delete(context),
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

  // ? Escaped rather than interpolated raw: flutter_html parses a description
  // ? containing "<" as markup and drops the text after it. Truncating first
  // ? keeps the cut away from the entities this introduces.
  String _descriptionHtml() {
    String body = data.description.length > maxDescriptionLength
        ? "${data.description.substring(0, maxDescriptionLength)}..."
        : data.description;
    return "<p>${htmlEscape.convert(body)}</p>";
  }

  // ? Branches on the state the UI is rendering, not on a per-title prefs key:
  // ? alreadySeen is already persisted inside dataList, so a second store could
  // ? only disagree with it (a card imported as seen had no key at all).
  void _toggleSeen(BuildContext context) {
    HapticFeedback.mediumImpact();
    ListModel model = Provider.of<ListModel>(context, listen: false);
    model.removeData(data);
    data.alreadySeen = !data.alreadySeen;
    if (data.alreadySeen) {
      model.addData(data); // ? Seen cards go to the end
    } else {
      // ? Back in, at the right position for its distance
      int insertAt = model.length();
      for (int i = 0; i < model.length(); i++) {
        if (model.elem(i).alreadySeen ||
            data.distance < model.elem(i).distance) {
          insertAt = i;
          break;
        }
      }
      model.insertData(data, insertAt);
    }
    _persist(model);
  }

  void _delete(BuildContext context) {
    ListModel model = Provider.of<ListModel>(context, listen: false);
    model.removeData(data);
    _persist(model);
  }

  Future<void> _persist(ListModel model) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('dataList', model.toString());
    await updateCards(model,
        reloadFromMemory: false, reorderData: false, updateAllDistances: false);
  }

  Future<void> navigateTo(double lat, double lng) async {
    var uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
