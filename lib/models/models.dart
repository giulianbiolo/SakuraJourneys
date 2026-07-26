import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geo/geo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationModel {
  final double lat;
  final double lng;
  LocationModel(this.lat, this.lng);
  // ? Returns null for anything that is not a parseable "(lat, lng)" pair, so
  // ? callers can skip the record instead of silently placing a card at (0, 0).
  static LocationModel? tryFromLatLngString(Object? latLng) {
    if (latLng is! String) return null;
    final List<String> latLngList =
        latLng.replaceAll(RegExp(r'[()]'), '').split(",");
    if (latLngList.length != 2) return null;
    final double? lat = double.tryParse(latLngList[0].trim());
    final double? lng = double.tryParse(latLngList[1].trim());
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90.0 || lng.abs() > 180.0) return null;
    return LocationModel(lat, lng);
  }

  @override
  String toString() {
    return "($lat, $lng)";
  }
}

// ? Ordered by how much the URL means it: an explicit query parameter is what the
// ? user asked for, !3d/!4d is the place a /maps/place/ link points at, and @ is
// ? only where the camera happened to be.
final List<RegExp> _mapsUrlPatterns = [
  RegExp(r'[?&](?:q|query|ll|destination|daddr)=(-?\d+(?:\.\d+)?),'
      r'(-?\d+(?:\.\d+)?)'),
  RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
  RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
];

/// Accepts what a user actually has to hand: "(lat, lng)", a bare "lat, lng", or
/// a pasted Google Maps URL. Short maps.app.goo.gl links are not covered, since
/// resolving them needs a network round trip.
LocationModel? tryParseLocationInput(Object? input) {
  if (input is! String) return null;
  String trimmed = input.trim();
  LocationModel? direct = LocationModel.tryFromLatLngString(trimmed);
  if (direct != null) return direct;
  for (RegExp pattern in _mapsUrlPatterns) {
    RegExpMatch? match = pattern.firstMatch(trimmed);
    if (match == null) continue;
    // ? Back through tryFromLatLngString for the range check.
    LocationModel? parsed = LocationModel.tryFromLatLngString(
        "(${match.group(1)}, ${match.group(2)})");
    if (parsed != null) return parsed;
  }
  return null;
}

double distanceBetween(LocationModel from, LocationModel to) {
  return computeDistanceBetween(
    LatLng(from.lat, from.lng),
    LatLng(to.lat, to.lng),
    radius: 6371008.8,
  ).toDouble();
}

// ? null is "no distance known yet", which is not the same as being there:
// ? distance is never persisted, so a run without a fix used to report 0.0 and
// ? claim the user was standing at every place at once.
(String, Color) getHumanizedDistance(double? dist) {
  if (dist == null) {
    return ("--", Colors.grey);
  }
  if (dist < 50.0) {
    return ("Here!", Colors.blue);
  }
  if (dist < 100.0) {
    return ("< 100 m", Colors.teal);
  }
  if (dist < 1000.0) {
    return ("${dist.toStringAsFixed(0)} m", Colors.green);
  }
  if (dist < 10000.0) {
    return ("${(dist / 1000.0).toStringAsFixed(2)} km", Colors.orange);
  }
  if (dist < 100000.0) {
    return ("${(dist / 1000.0).toStringAsFixed(1)} km", Colors.deepOrange);
  }
  return ("${(dist / 1000.0).toStringAsFixed(0)} km", Colors.purple);
}

class DataModel {
  final String title;
  final String imageName;
  final String address;
  final LocationModel location;
  double? distance;
  bool alreadySeen = false;
  final String description;
  final double rating;
  DataModel(
    this.title,
    this.imageName,
    this.address,
    this.location,
    this.description,
    this.rating,
  );

  DataModel copy() {
    DataModel copied =
        DataModel(title, imageName, address, location, description, rating);
    copied.distance = distance;
    copied.alreadySeen = alreadySeen;
    return copied;
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "imageName": imageName,
      "address": address,
      "location": location.toString(),
      "description": description,
      "rating": rating.toString(),
      "alreadySeen": alreadySeen ? "true" : "false",
    };
  }

  // ? Returns null instead of throwing: imported JSON is third-party input and is
  // ? not guaranteed to use the types toJson() writes, so a bad record is skipped.
  static DataModel? tryFromJson(Object? record) {
    if (record is! Map) return null;
    Object? title = record["title"];
    LocationModel? location =
        LocationModel.tryFromLatLngString(record["location"]);
    if (title is! String || title.isEmpty || location == null) return null;
    DataModel data = DataModel(
      title,
      record["imageName"] is String ? record["imageName"] : urlTo404Page,
      record["address"] is String ? record["address"] : "",
      location,
      record["description"] is String ? record["description"] : "",
      _ratingFromJson(record["rating"]),
    );
    data.alreadySeen =
        record["alreadySeen"] == "true" || record["alreadySeen"] == true;
    return data;
  }
}

// ? The deck's one ordering rule, shared by sortData and the re-insertion in
// ? location_card so an unseen card lands exactly where a sort would put it.
int compareCards(DataModel a, DataModel b) {
  if (a.alreadySeen != b.alreadySeen) {
    return a.alreadySeen ? 1 : -1;
  }
  double? distA = a.distance;
  double? distB = b.distance;
  if (distA == null && distB == null) return 0;
  if (distA == null) return 1; // ? Unknown distances sort after known ones
  if (distB == null) return -1;
  return distA.compareTo(distB);
}

const int maxTitleLength = 25;
const int maxDescriptionLength = 650;
const int maxAddressLength = 35;

class ListModel extends ChangeNotifier {
  final List<DataModel> _data = [];
  void addData(DataModel data) {
    _data.add(data);
    notifyListeners();
  }

  void clearAllData() {
    _data.clear();
    notifyListeners();
  }

  void removeData(DataModel data) {
    _data.remove(data);
    notifyListeners();
  }

  void updateData(DataModel data, int index) {
    _data[index] = data;
    notifyListeners();
  }

  void insertData(DataModel data, int index) {
    _data.insert(index, data);
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  int length() {
    return _data.length;
  }

  DataModel elem(int index) {
    return _data[index];
  }

  int indexOf(DataModel data) {
    return _data.indexOf(data);
  }

  bool contains(DataModel data) {
    return _data.contains(data);
  }

  /// Recomputes every card's distance from [origin]. With [onlyMissing] the cards
  /// that already have one are left alone, so a stale fix cannot overwrite a fresh
  /// one and only newly added cards are filled in.
  void applyDistancesFrom(LocationModel origin, {bool onlyMissing = false}) {
    for (DataModel card in _data) {
      if (onlyMissing && card.distance != null) continue;
      card.distance = distanceBetween(origin, card.location);
    }
    notifyListeners();
  }

  /// Merges [newData] in, replacing by title, and reports what happened so the
  /// caller can say so. With [replace] the cards whose title is absent from
  /// [newData] are dropped first, which is the only way an import can remove a
  /// card rather than only ever adding or overwriting.
  ImportCounts loadData(List<DataModel> newData, {bool replace = false}) {
    int removed = 0;
    if (replace) {
      Set<String> incoming = {for (DataModel data in newData) data.title};
      int before = _data.length;
      _data.removeWhere((DataModel data) => !incoming.contains(data.title));
      removed = before - _data.length;
    }
    int added = 0;
    int replaced = 0;
    for (DataModel data in newData) {
      if (_data.contains(data)) {
        continue;
      }
      // if _data contains an element with the same title, substitute with new one
      bool found = false;
      for (int i = 0; i < _data.length; i++) {
        if (_data[i].title == data.title) {
          _data[i] = data;
          found = true;
          replaced++;
          break;
        }
      }
      if (!found) {
        _data.add(data);
        added++;
      }
    }
    notifyListeners();
    return ImportCounts(added: added, replaced: replaced, removed: removed);
  }

  void sortData() {
    _data.sort(compareCards);
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      "data": [for (DataModel data in _data) data.toJson()],
    };
  }

  static List<DataModel> fromJson(Map<String, dynamic> jsonData) {
    List<DataModel> listModel = [];
    Object? records = jsonData["data"];
    if (records is! List) return listModel;
    for (Object? record in records) {
      DataModel? data = DataModel.tryFromJson(record);
      if (data != null) listModel.add(data);
    }
    return listModel;
  }

  /// How many records [jsonData] offered, readable or not. fromJson drops the
  /// unreadable ones silently, so this is what makes "3 skipped" reportable.
  static int countRecords(Map<String, dynamic> jsonData) {
    Object? records = jsonData["data"];
    return records is List ? records.length : 0;
  }
}

class ImportCounts {
  final int added;
  final int replaced;
  final int removed;
  const ImportCounts(
      {required this.added, required this.replaced, required this.removed});

  /// Reads as "1 added, 2 replaced, 3 skipped". Zero counts are kept for added
  /// and replaced so the message never implies a card went missing.
  String summary(int skipped) {
    List<String> parts = ['$added added', '$replaced replaced'];
    if (removed > 0) parts.add('$removed removed');
    if (skipped > 0) parts.add('$skipped skipped');
    return parts.join(', ');
  }
}

const String lastFixLatKey = 'lastFixLat';
const String lastFixLngKey = 'lastFixLng';

Future<void> saveLastFix(double lat, double lng) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(lastFixLatKey, lat);
  await prefs.setDouble(lastFixLngKey, lng);
}

LocationModel? readLastFix(SharedPreferences prefs) {
  double? lat = prefs.getDouble(lastFixLatKey);
  double? lng = prefs.getDouble(lastFixLngKey);
  if (lat == null || lng == null) return null;
  return LocationModel(lat, lng);
}

Future<void> loadData(ListModel dataList) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? stored = prefs.getString("dataList");
  if (stored == null) {
    // ? Only a fresh install has no key at all. An emptied deck stores an empty
    // ? "data" list, and must stay empty instead of resurrecting the samples.
    dataList.loadData(dataListDefault());
  } else {
    String trimmed = stored.trim();
    if (trimmed.isEmpty) return;
    if (!trimmed.startsWith("{")) {
      // ? Installs from before the JSON switch still hold the |;|-delimited blob.
      dataList.loadData(dataFromLegacyString(trimmed));
      await prefs.setString('dataList', jsonEncode(dataList.toJson()));
    } else {
      try {
        dataList.loadData(ListModel.fromJson(jsonDecode(trimmed)));
      } catch (e) {
        // ? Keep the unreadable blob on disk: the next mutation overwrites it, and
        // ? discarding it here would destroy the only copy of the user's cards.
        debugPrint('Stored cards are not readable JSON: $e');
      }
    }
  }
  // ? Distances are not part of the stored card, so the deck would come up in
  // ? whatever order it was written in, every badge reading "--", until a fix
  // ? arrives. The previous fix is close enough to order by in the meantime.
  LocationModel? lastFix = readLastFix(prefs);
  if (lastFix != null) {
    dataList.applyDistancesFrom(lastFix, onlyMissing: true);
    dataList.sortData();
  }
}

List<DataModel> dataFromLegacyString(String datastr) {
  List<DataModel> listModel = [];
  List<String> dataList = datastr.split("|;|");
  for (String data in dataList) {
    List<String> dataFields = data.split("|:|");
    if (dataFields.length != 7) {
      continue;
    }
    LocationModel? location = LocationModel.tryFromLatLngString(dataFields[3]);
    if (location == null) {
      continue;
    }
    listModel.add(DataModel(
      dataFields[0],
      dataFields[1],
      dataFields[2],
      location,
      dataFields[5],
      double.tryParse(dataFields[6].trim()) ?? 0.0,
    ));
    listModel.last.alreadySeen = dataFields[4] == "true";
  }
  return listModel;
}

/// Google Takeout's "Saved Places.json" is a GeoJSON FeatureCollection: the
/// coordinates arrive as [lng, lat], the title sits under
/// `properties.location.name`, and there is no image or rating to read.
List<DataModel> dataFromTakeoutJson(Map<String, dynamic> jsonData) {
  List<DataModel> cards = [];
  Object? features = jsonData["features"];
  if (features is! List) return cards;
  for (Object? feature in features) {
    if (feature is! Map) continue;
    Object? coordinates = (feature["geometry"] is Map)
        ? (feature["geometry"] as Map)["coordinates"]
        : null;
    if (coordinates is! List || coordinates.length < 2) continue;
    Object? lng = coordinates[0];
    Object? lat = coordinates[1];
    if (lat is! num || lng is! num) continue;
    LocationModel? location = LocationModel.tryFromLatLngString("($lat, $lng)");
    if (location == null) continue;
    Map properties = feature["properties"] is Map
        ? feature["properties"] as Map
        : const <String, Object?>{};
    Map place = properties["location"] is Map
        ? properties["location"] as Map
        : const <String, Object?>{};
    Object? name = place["name"] ?? place["address"] ?? properties["title"];
    if (name is! String || name.isEmpty) continue;
    cards.add(DataModel(
      name,
      urlTo404Page, // ? Takeout carries no photo; the card is editable afterwards
      place["address"] is String ? place["address"] as String : "",
      location,
      "",
      0.0,
    ));
  }
  return cards;
}

/// Reads either the app's own export or a Takeout saved-places file, and reports
/// how many records the file offered so the caller can count what it skipped.
({List<DataModel> cards, int offered}) parseImport(
    Map<String, dynamic> jsonData) {
  Object? features = jsonData["features"];
  if (features is List) {
    return (cards: dataFromTakeoutJson(jsonData), offered: features.length);
  }
  return (
    cards: ListModel.fromJson(jsonData),
    offered: ListModel.countRecords(jsonData),
  );
}

/// Whether [jsonData] is a shape the importer understands at all.
bool isImportable(Map<String, dynamic> jsonData) {
  return jsonData["data"] is List || jsonData["features"] is List;
}

double _ratingFromJson(Object? rating) {
  if (rating is num) return rating.toDouble();
  if (rating is String) return double.tryParse(rating.trim()) ?? 0.0;
  return 0.0;
}

String urlTo404Page =
    "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/404page.jpg?raw=true";

// ? Hands out copies: the model stores the instances it is given and mutates
// ? distance/alreadySeen, so sharing the template would accumulate state across resets.
List<DataModel> dataListDefault() =>
    _dataListDefaultTemplate.map((d) => d.copy()).toList();

final List<DataModel> _dataListDefaultTemplate = [
  /*
   * DataModel(
    * String title,            [Tokyo Sky Tree]
    * String imageName,        [assets/...]
    * String address,          [Shinjuku, Tokyo] // Max 25 chars
    * LocationModel location,  [LatLng(Latitude, Longitude)]
    * String description,      [The description of the place] // Max 200 chars
    * double rating,           [0 - 5]
   * ),
  */
  DataModel(
      "Tokyo Sky Tree",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/tokyo_sky_tree.jpg?raw=true",
      "Sumida, Tokyo",
      LocationModel(35.7101, 139.8107),
      "The Tokyo Skytree is a broadcasting and observation tower in Sumida, Tokyo. It became the tallest structure in Japan in 2010 and reached its full height of 634.0 meters in March 2011, making it the tallest tower in the world.",
      4.0),
  DataModel(
      "Akihabara",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/akihabara.jpg?raw=true",
      "Akihabara, Tokyo",
      LocationModel(35.698333, 139.773056),
      "Akihabara is a neighborhood in Tokyo located less than five minutes by rail from Tokyo Station. Akihabara is a major shopping area for electronic, computer, anime, games, and otaku goods.",
      5.0),
  DataModel(
      "TeamLab BorderLess",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/teamlab_borderless.jpg?raw=true",
      "6-chome, Toyosu, Koto-ku, Tokyo",
      LocationModel(35.649074249937755, 139.78983024721975),
      "teamLab Planets is an art facility that utilizes digital technology and was established by teamLab and DMM.com. The art space is vast, and the visitor is encouraged to move around the space with others.",
      4.0),
  DataModel(
      "Tokyo Imperial Palace",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/tokyo_imperial_palace.jpg?raw=true",
      "1-1 Chiyoda, Chiyoda-ku 100-0001 Tokyo",
      LocationModel(35.6825, 139.7521),
      "The Tokyo Imperial Palace is the main residence of the Emperor of Japan. It is a large park-like area located in the Chiyoda ward of Tokyo and contains private residences, the main palace, museums and more.",
      4.5),
];
