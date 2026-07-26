import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/utils/image_lookup.dart';
import 'package:http/http.dart' show Response, get;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class HomeWidgetConfig {
  static Future<void> update(DataModel firstCard) async {
    // ? Nothing to draw and nothing to download: the provider reads a blank
    // ? imageName as "use the built-in background".
    if (firstCard.imageName.isEmpty) {
      await updateWithoutImage(firstCard);
      return;
    }
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

  // ? A card whose lookup found nothing: the title, the distance and the
  // ? navigation target are all real, so only the image is left blank. The
  // ? provider reads that as "draw the built-in background".
  static Future<void> updateWithoutImage(DataModel firstCard) async {
    await HomeWidget.saveWidgetData('title', firstCard.title);
    await HomeWidget.saveWidgetData(
        'distance', getHumanizedDistance(firstCard.distance).$1);
    await HomeWidget.saveWidgetData('imageName', '');
    await HomeWidget.saveWidgetData('lat', firstCard.location.lat.toString());
    await HomeWidget.saveWidgetData('lng', firstCard.location.lng.toString());
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
      // ? upload.wikimedia.org, where a looked-up image comes from, answers a
      // ? request with no User-Agent with 403.
      Response response =
          await get(uri, headers: const {'User-Agent': wikimediaUserAgent});
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
