import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:japan_travel/models/models.dart';
import 'package:http/http.dart' show Response, get;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class HomeWidgetConfig {
  static Future<void> update(DataModel firstCard) async {
    Directory documentDirectory = await getApplicationDocumentsDirectory();
    String imageDirectory = "${documentDirectory.path}/images";
    String filePathAndName = '$imageDirectory/widget_preview.jpg';
    File previewFile = File(filePathAndName);

    await HomeWidget.saveWidgetData('title', firstCard.title);
    await HomeWidget.saveWidgetData(
        'distance', getHumanizedDistance(firstCard.distance).$1);
    await HomeWidget.saveWidgetData('imageName', filePathAndName);
    await HomeWidget.saveWidgetData('lat', firstCard.location.lat.toString());
    await HomeWidget.saveWidgetData('lng', firstCard.location.lng.toString());

    // ? The download is the whole cost of an update, and it only changes when the
    // ? first card does, so skip it while the file still matches.
    String? cachedUrl =
        await HomeWidget.getWidgetData<String>('cachedImageUrl');
    if (cachedUrl != firstCard.imageName || !await previewFile.exists()) {
      Uint8List? bytes = await _download(firstCard.imageName);
      if (bytes != null) {
        await Directory(imageDirectory).create(recursive: true);
        await previewFile.writeAsBytes(bytes);
        // ? Written only after the file is on disk, so a failed download retries.
        await HomeWidget.saveWidgetData('cachedImageUrl', firstCard.imageName);
      }
    }

    await HomeWidget.updateWidget(
        iOSName: "japan_travel", androidName: "CustomHomeView");
  }

  // ? An empty deck used to leave the widget advertising the card that was just
  // ? deleted. imageName is cleared rather than pointed at the stale preview file,
  // ? which is what the provider reads as "no card, no navigation target".
  static Future<void> updateEmpty() async {
    await HomeWidget.saveWidgetData('title', 'No places yet');
    await HomeWidget.saveWidgetData('distance', 'Tap to add one');
    await HomeWidget.saveWidgetData('imageName', '');
    await HomeWidget.saveWidgetData('lat', '');
    await HomeWidget.saveWidgetData('lng', '');
    await HomeWidget.updateWidget(
        iOSName: "japan_travel", androidName: "CustomHomeView");
  }

  // ? Returns null instead of throwing: a dead URL or a non-http imageName must
  // ? leave the last good preview in place, not write an error page over it.
  static Future<Uint8List?> _download(String imageName) async {
    try {
      Uri uri = Uri.parse(imageName);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        debugPrint('Widget image is not an http(s) URL: $imageName');
        return null;
      }
      Response response = await get(uri);
      if (response.statusCode != 200) {
        debugPrint('Widget image download failed: HTTP ${response.statusCode}');
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('Widget image download failed: $e');
      return null;
    }
  }

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId("com.example.japan_travel");
  }
}
