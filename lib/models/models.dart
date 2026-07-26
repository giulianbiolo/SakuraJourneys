import 'dart:convert';

import 'package:flutter/material.dart';
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

(String, Color) getHumanizedDistance(double dist) {
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
  double distance = 0.0;
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

  bool contains(DataModel data) {
    return _data.contains(data);
  }

  void loadData(List<DataModel> newData) {
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
          break;
        }
      }
      if (!found) _data.add(data);
    }
    notifyListeners();
  }

  void sortData() {
    _data.sort((a, b) {
      if (a.alreadySeen && !b.alreadySeen) {
        return 1;
      }
      if (!a.alreadySeen && b.alreadySeen) {
        return -1;
      }
      return a.distance.compareTo(b.distance);
    });
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
}

Future<void> loadData(ListModel dataList) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? stored = prefs.getString("dataList");
  if (stored == null) {
    // ? Only a fresh install has no key at all. An emptied deck stores an empty
    // ? "data" list, and must stay empty instead of resurrecting the samples.
    dataList.loadData(dataListDefault());
    return;
  }
  String trimmed = stored.trim();
  if (trimmed.isEmpty) return;
  if (!trimmed.startsWith("{")) {
    // ? Installs from before the JSON switch still hold the |;|-delimited blob.
    dataList.loadData(dataFromLegacyString(trimmed));
    await prefs.setString('dataList', jsonEncode(dataList.toJson()));
    return;
  }
  try {
    dataList.loadData(ListModel.fromJson(jsonDecode(trimmed)));
  } catch (e) {
    // ? Keep the unreadable blob on disk: the next mutation overwrites it, and
    // ? discarding it here would destroy the only copy of the user's cards.
    debugPrint('Stored cards are not readable JSON: $e');
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
    * double rating,           [0 - 300]
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
