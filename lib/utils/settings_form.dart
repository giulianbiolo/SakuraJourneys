import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/screens/home.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class SettingsForm extends StatefulWidget {
  const SettingsForm({super.key});

  @override
  SettingsFormState createState() {
    return SettingsFormState();
  }
}

// Define a corresponding State class.
// This class holds data related to the form.
class SettingsFormState extends State<SettingsForm> {
  // Create a global key that uniquely identifies the Form widget
  // and allows validation of the form.
  //
  // Note: This is a `GlobalKey<FormState>`,
  // not a GlobalKey<MyCustomFormState>.
  final _formKey = GlobalKey<FormState>();
  bool _replaceOnImport = false;

  // ? A fixed name meant every export after the first landed next to the last one
  // ? as "exportData.json (1)".
  String _exportFileName() {
    DateTime now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return 'sakura-journeys-${now.year}-${pad(now.month)}-${pad(now.day)}.json';
  }

  Future<void> _importFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'md'],
    );
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
      return;
    }
    List<DataModel> receivedData;
    int offered;
    try {
      String fileContent = await File(result.files.single.path!).readAsString();
      Map<String, dynamic> receivedJson = jsonDecode(fileContent);
      if (!isImportable(receivedJson)) {
        throw const FormatException('neither a "data" nor a "features" list');
      }
      final parsed = parseImport(receivedJson);
      receivedData = parsed.cards;
      offered = parsed.offered;
    } catch (e) {
      debugPrint('Import failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data')),
        );
      }
      return;
    }
    if (!mounted) return;
    ListModel model = Provider.of<ListModel>(context, listen: false);
    ImportCounts counts =
        model.loadData(receivedData, replace: _replaceOnImport);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(counts.summary(offered - receivedData.length)),
    ));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('dataList', jsonEncode(model.toJson()));
    // ? reorderData: imported cards have no distance yet, so they read "--" and
    // ? sort to the end until a fix arrives.
    updateCards(model,
        reloadFromMemory: false, reorderData: true, updateAllDistances: false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareCards() async {
    String jsonString =
        jsonEncode(Provider.of<ListModel>(context, listen: false).toJson());
    try {
      // ? A .json attachment rather than a text blob: a whole deck pasted into a
      // ? chat is unreadable, and the receiving side already reads attachments.
      Directory directory = await getTemporaryDirectory();
      File file = File('${directory.path}/${_exportFileName()}');
      await file.writeAsString(jsonString);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sharing data')),
        );
      }
    }
  }

  // ? A delete can be undone from its snackbar; a reset drops the whole deck at
  // ? once and cannot, so it asks first.
  Future<bool> _confirmReset() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset to default?'),
          content: const Text(
              'Every card is removed and the sample places come back. This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: const ButtonStyle(
                foregroundColor:
                    WidgetStatePropertyAll(Color.fromARGB(255, 255, 0, 0)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false; // ? Dismissed by tapping outside
  }

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
                  onPressed: _importFromFile,
                  style: const ButtonStyle(
                    alignment: Alignment.center,
                    fixedSize: WidgetStatePropertyAll(Size(200, 50)),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import From File'),
                ),
              ),
              SizedBox(
                width: 240,
                child: CheckboxListTile(
                  value: _replaceOnImport,
                  onChanged: (bool? value) {
                    HapticFeedback.mediumImpact();
                    setState(() => _replaceOnImport = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Replace deck on import',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Drops cards the file does not list',
                      style: TextStyle(fontSize: 11)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Map<String, dynamic> jsonData =
                        Provider.of<ListModel>(context, listen: false).toJson();
                    String jsonString = jsonEncode(jsonData);
                    String? result;
                    try {
                      // ? On mobile the plugin writes these bytes to the chosen
                      // ? document itself. What it returns is a guessed Downloads
                      // ? path, not the real target, so it must not be written to
                      // ? nor shown.
                      result = await FilePicker.platform.saveFile(
                        dialogTitle: 'Save your data',
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        fileName: _exportFileName(),
                        bytes: utf8.encode(jsonString),
                      );
                    } catch (e) {
                      debugPrint('Export failed: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error saving data')),
                        );
                      }
                      return;
                    }
                    if (result == null) return; // ? Cancelled, not an error
                    // ? Desktop is the other half of that comment: there the plugin
                    // ? ignores bytes and only reports the chosen path, so without this
                    // ? the export writes nothing at all.
                    if (!Platform.isAndroid && !Platform.isIOS) {
                      try {
                        await File(result).writeAsString(jsonString);
                      } catch (e) {
                        debugPrint('Export write-back failed: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error saving data')),
                          );
                        }
                        return;
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data exported')),
                      );
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
                  onPressed: _shareCards,
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
                    if (!await _confirmReset()) return;
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    if (context.mounted) {
                      Provider.of<ListModel>(context, listen: false)
                          .clearAllData();
                      Provider.of<ListModel>(context, listen: false)
                          .loadData(dataListDefault());
                      Map<String, dynamic> defaultData =
                          Provider.of<ListModel>(context, listen: false)
                              .toJson();
                      prefs.setString('dataList', jsonEncode(defaultData));
                      await updateCards(
                          Provider.of<ListModel>(context, listen: false),
                          reloadFromMemory: false,
                          reorderData: true,
                          updateAllDistances: true);
                      if (context.mounted) {
                        Provider.of<ListModel>(context, listen: false).notify();
                        Navigator.pop(context);
                      }
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
