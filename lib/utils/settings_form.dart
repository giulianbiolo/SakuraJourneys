import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({super.key});

  @override
  AddFormState createState() {
    return AddFormState();
  }
}

// Define a corresponding State class.
// This class holds data related to the form.
class AddFormState extends State<SettingsForm> {
  // Create a global key that uniquely identifies the Form widget
  // and allows validation of the form.
  //
  // Note: This is a `GlobalKey<FormState>`,
  // not a GlobalKey<MyCustomFormState>.
  final _formKey = GlobalKey<FormState>();
  final titleText = TextEditingController();
  final descriptionText = TextEditingController();
  final addressText = TextEditingController();
  final imageUrlText = TextEditingController();
  final latLngText = TextEditingController();
  final ratingText = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey created above.
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // ? Make some big buttons: Load From File, Export as File, Reset To Default
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // ? Open the file selector
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json', 'txt', 'md'],
                    );
                    if (result != null) {
                      File file = File(result.files.single.path!);
                      String fileContent = await file.readAsString();
                      if (fileContent.isNotEmpty && fileContent.startsWith("{\"data\":[{\"title\":")) {
                        Map<String, dynamic> loadedData = jsonDecode(fileContent);
                        try {
                          List<DataModel> dataList = dataFromJson(loadedData);
                          if (context.mounted) {
                            Provider.of<ListModel>(context, listen: false)
                                .loadData(dataList);
                            SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            prefs.setString('dataList', fileContent);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error loading data')),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid data format')),
                          );
                        }
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No file selected')),
                        );
                      }
                    }
                  },
                  style: const ButtonStyle(
                    alignment: Alignment.center,
                    fixedSize: WidgetStatePropertyAll(Size(200, 50)),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import From File'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Map<String, dynamic> jsonData =
                        Provider.of<ListModel>(context, listen: false).toJson();
                    String jsonString = jsonEncode(jsonData);
                    String? result = await FilePicker.platform.saveFile(
                        dialogTitle: 'Save your data',
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        fileName: 'exportData.json',
                        bytes: Uint8List(524288) // 512 KiB
                        );
                    if (result != null) {
                      File file = File(result);
                      await file.writeAsString(jsonString);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error saving data')),
                        );
                      }
                    }
                  },
                  style: const ButtonStyle(
                    alignment: Alignment.center,
                    fixedSize: WidgetStatePropertyAll(Size(200, 50)),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Export To File'),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Map<String, dynamic> jsonData =
                        Provider.of<ListModel>(context, listen: false).toJson();
                    String jsonString = jsonEncode(jsonData);
                    Share.share(jsonString);
                  },
                  style: const ButtonStyle(
                    alignment: Alignment.center,
                    fixedSize: WidgetStatePropertyAll(Size(200, 50)),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share Cards'),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    if (context.mounted) {
                      Provider.of<ListModel>(context, listen: false).clearAllData();
                      Provider.of<ListModel>(context, listen: false)
                          .loadData(dataListDefault);
                      String defaultData =
                          Provider.of<ListModel>(context, listen: false)
                              .toString();
                      prefs.setString('dataList', defaultData);
                      Provider.of<ListModel>(context, listen: false).notify();
                      Navigator.pop(context);
                    }
                  },
                  style: const ButtonStyle(
                    overlayColor:
                        WidgetStatePropertyAll(Color.fromARGB(25, 255, 0, 0)),
                    foregroundColor:
                        WidgetStatePropertyAll(Color.fromARGB(255, 255, 0, 0)),
                    alignment: Alignment.center,
                    fixedSize: WidgetStatePropertyAll(Size(200, 50)),
                  ),
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset To Default'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  // style: const ButtonStyle(
                  //   overlayColor:
                  //       WidgetStatePropertyAll(Color.fromARGB(25, 255, 0, 0)),
                  //   foregroundColor:
                  //       WidgetStatePropertyAll(Color.fromARGB(255, 255, 0, 0)),
                  // ),
                  child: const Text('Close'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
