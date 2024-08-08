import 'package:home_widget/home_widget.dart';
import 'package:japan_travel/models/models.dart';
import 'package:japan_travel/screens/home_widget.dart';
import 'package:http/http.dart' show get;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HomeWidgetConfig {
  static Future<void> update(context, CardWidget widget) async {
    Uri uri = Uri.parse(widget.firstCard.imageName);
    var response = await get(uri);
    var documentDirectory = await getApplicationDocumentsDirectory();
    var firstPath = "${documentDirectory.path}/images";
    var filePathAndName = '${documentDirectory.path}/images/widget_preview.jpg';
    await Directory(firstPath).create(recursive: true);
    File file2 = File(filePathAndName);
    file2.writeAsBytesSync(response.bodyBytes);
    print("File saved to $filePathAndName");

    await HomeWidget.saveWidgetData('title', widget.firstCard.title);
    await HomeWidget.saveWidgetData(
        'distance', getHumanizedDistance(widget.firstCard.distance).$1);
    await HomeWidget.saveWidgetData('imageName', filePathAndName);

    await HomeWidget.updateWidget(
        iOSName: "japan_travel", androidName: "CustomHomeView");
  }

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId("com.example.japan_travel");
  }
}
