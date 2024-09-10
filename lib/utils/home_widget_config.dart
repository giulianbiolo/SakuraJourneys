import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:japan_travel/models/models.dart';
import 'package:http/http.dart' show Response, get;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:palette_generator/palette_generator.dart';

class HomeWidgetConfig {
  static Future<void> update(DataModel firstCard) async {
    Uri uri = Uri.parse(firstCard.imageName);
    Response response = await get(uri);
    Directory documentDirectory = await getApplicationDocumentsDirectory();
    String firstPath = "${documentDirectory.path}/images";
    String filePathAndName = '${documentDirectory.path}/images/widget_preview.jpg';
    await Directory(firstPath).create(recursive: true);
    File file2 = File(filePathAndName);
    file2.writeAsBytesSync(response.bodyBytes);

    PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(
      NetworkImage(firstCard.imageName),
      size: const Size(1280, 720),
      region: const Rect.fromLTWH(0, 500, 1000, 200)
    );
    Color dominantColor = paletteGenerator.dominantColor?.color ?? Colors.black;
    String textColor = colorHex(invert(dominantColor));

    await HomeWidget.saveWidgetData('title', firstCard.title);
    await HomeWidget.saveWidgetData(
        'distance', getHumanizedDistance(firstCard.distance).$1);
    await HomeWidget.saveWidgetData('imageName', filePathAndName);
    await HomeWidget.saveWidgetData('textColor', textColor);
    await HomeWidget.saveWidgetData('lat', firstCard.location.lat.toString());
    await HomeWidget.saveWidgetData('lng', firstCard.location.lng.toString());

    await HomeWidget.updateWidget(
        iOSName: "japan_travel", androidName: "CustomHomeView");
  }

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId("com.example.japan_travel");
  }
}

Color invert(Color color) {
  final r = 255 - color.red;
  final g = 255 - color.green;
  final b = 255 - color.blue;
  return Color.fromARGB(255, r, g, b);
}

String colorHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2)}';
}
