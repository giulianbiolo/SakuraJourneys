import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:japan_travel/screens/home.dart';
import 'package:provider/provider.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';


class AddForm extends StatefulWidget {
  const AddForm({super.key});

  @override
  AddFormState createState() {
    return AddFormState();
  }
}

// Define a corresponding State class.
// This class holds data related to the form.
class AddFormState extends State<AddForm> {
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
  double _rating = 4.0;
  bool _locating = false;

  // ? Typing coordinates by hand was the only way to add a place you are standing
  // ? in front of.
  Future<void> _fillCurrentLocation() async {
    HapticFeedback.mediumImpact();
    setState(() => _locating = true);
    final (LocationFixResult result, Position? position) =
        await currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locationProblemText(result))),
      );
      return;
    }
    latLngText.text =
        LocationModel(position.latitude, position.longitude).toString();
  }

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey created above.
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Column(
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "Enter the title",
                  icon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (value.length > maxTitleLength) {
                    return 'Title must be less than $maxTitleLength characters';
                  }
                  return null;
                },
                controller: titleText,
              ),
              // ? Description, address and image URL are optional: tryFromJson
              // ? already defaults all three for imported cards, so requiring
              // ? them only made hand-entry stricter than sharing.
              TextFormField(
                minLines: 1,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: "Description (optional)",
                  hintText: "Enter the description",
                  icon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value != null && value.length > maxDescriptionLength) {
                    return 'Description must be less than $maxDescriptionLength characters';
                  }
                  return null;
                },
                controller: descriptionText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Address (optional)",
                  hintText: "Enter the address",
                  icon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value != null && value.length > maxAddressLength) {
                    return 'Address must be less than $maxAddressLength characters';
                  }
                  return null;
                },
                controller: addressText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Image URL (optional)",
                  hintText: "Leave empty for a placeholder",
                  icon: Icon(Icons.image),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (!Uri.parse(value).isAbsolute) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
                controller: imageUrlText,
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: "Latitude & Longitude",
                  hintText: "(lat, lng) or a Google Maps link",
                  icon: const Icon(Icons.gps_fixed),
                  suffixIcon: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          tooltip: 'Use my current location',
                          onPressed: _fillCurrentLocation,
                          icon: const Icon(Icons.my_location),
                        ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (tryParseLocationInput(value) == null) {
                    return 'Enter (lat, lng) or paste a Google Maps link';
                  }
                  return null;
                },
                controller: latLngText,
              ),
              // ? A slider rather than a free-text double: the old field accepted
              // ? "4,5" and any out-of-range number until the validator caught it.
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.star),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 0.0,
                        max: 5.0,
                        divisions: 10,
                        label: _rating.toStringAsFixed(1),
                        onChanged: (double value) =>
                            setState(() => _rating = value),
                      ),
                    ),
                    SizedBox(
                        width: 32,
                        child: Text(_rating.toStringAsFixed(1),
                            textAlign: TextAlign.right)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    // ? Open the file selector
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (result == null) return;
                    File file = File(result.files.single.path!);
                    String fileContent = await file.readAsString();
                    if (!context.mounted) return;
                    try {
                      Map<String, dynamic> loadedData = jsonDecode(fileContent);
                      if (!isImportable(loadedData)) {
                        throw const FormatException(
                            'neither a "data" nor a "features" list');
                      }
                      final parsed = parseImport(loadedData);
                      ListModel model =
                          Provider.of<ListModel>(context, listen: false);
                      ImportCounts counts = model.loadData(parsed.cards);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(counts
                            .summary(parsed.offered - parsed.cards.length)),
                      ));
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      if (!context.mounted) return;
                      prefs.setString('dataList', jsonEncode(model.toJson()));
                      updateCards(model,
                          reloadFromMemory: false,
                          reorderData: true,
                          updateAllDistances: false);
                      Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error loading data')),
                        );
                      }
                    }
                  },
                  child: const Text('Load from file'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: const ButtonStyle(
                        overlayColor:
                            WidgetStatePropertyAll(Color.fromARGB(25, 255, 0, 0)),
                        foregroundColor:
                            WidgetStatePropertyAll(Color.fromARGB(255, 255, 0, 0)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Validate returns true if the form is valid, or false otherwise.
                        if (_formKey.currentState!.validate()) {
                          // If the form is valid, display a snackbar. In the real world,
                          // you'd often call a server or save the information in a database.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Processing Data')),
                          );
                          // ? Here we need to add the data to the dataList and update the UI
                          DataModel data = DataModel(
                            titleText.text,
                            imageUrlText.text.isEmpty
                                ? urlTo404Page
                                : imageUrlText.text,
                            addressText.text,
                            tryParseLocationInput(latLngText.text)!,
                            descriptionText.text,
                            _rating,
                          );
                          Provider.of<ListModel>(context, listen: false)
                              .addData(data);
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          if (context.mounted) {
                            Map<String, dynamic> newCards =
                                Provider.of<ListModel>(context, listen: false)
                                    .toJson();
                            prefs.setString('dataList', jsonEncode(newCards));
                            // ? reorderData: a new card starts at distance 0.0, which renders as "Here!" and sorts first.
                            updateCards(Provider.of<ListModel>(context, listen: false), reloadFromMemory: false, reorderData: true, updateAllDistances: false);
                            Navigator.pop(context);
                          }
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ]
            )
          )
        ],
      ),
    );
  }
}
