import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:japan_travel/screens/home.dart';
import 'package:provider/provider.dart';
import 'package:japan_travel/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditCardForm extends StatefulWidget {
  final DataModel initialCardData;
  const EditCardForm({super.key, required this.initialCardData});

  @override
  EditCardFormState createState() {
    return EditCardFormState();
  }
}

// Define a corresponding State class.
// This class holds data related to the form.
class EditCardFormState extends State<EditCardForm> {
  // Create a global key that uniquely identifies the Form widget
  // and allows validation of the form.
  // Note: This is a `GlobalKey<FormState>`,
  // not a GlobalKey<MyCustomFormState>.
  final _formKey = GlobalKey<FormState>();
  late DataModel oldCardData;
  final titleText = TextEditingController();
  final descriptionText = TextEditingController();
  final addressText = TextEditingController();
  final imageUrlText = TextEditingController();
  final latLngText = TextEditingController();
  double _rating = 0.0;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    oldCardData = widget.initialCardData;
    titleText.text = widget.initialCardData.title;
    descriptionText.text = widget.initialCardData.description;
    addressText.text = widget.initialCardData.address;
    imageUrlText.text = widget.initialCardData.imageName;
    latLngText.text = widget.initialCardData.location.toString();
    // ? The slider has 0.5 steps, so an imported 4.3 has to land somewhere.
    _rating = (widget.initialCardData.rating.clamp(0.0, 5.0) * 2).round() / 2;
  }

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
              // ? Optional here for the same reason as in add_form: a card added
              // ? or imported without an address must stay editable.
              TextFormField(
                minLines: 5,
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
                      DataModel newCardData = DataModel(
                        titleText.text,
                        imageUrlText.text.isEmpty
                            ? urlTo404Page
                            : imageUrlText.text,
                        addressText.text,
                        tryParseLocationInput(latLngText.text)!,
                        descriptionText.text,
                        _rating,
                      );
                      // ? DataModel defaults alreadySeen to false, so without this
                      // ? any edit to a seen card silently marks it unseen again.
                      newCardData.alreadySeen = oldCardData.alreadySeen;
                      // ? Same idea for distance, which defaults to null ("--"):
                      // ? an edit that left the coordinates alone did not change it.
                      if (newCardData.location.toString() ==
                          oldCardData.location.toString()) {
                        newCardData.distance = oldCardData.distance;
                      }
                      Provider.of<ListModel>(context, listen: false)
                          .removeData(oldCardData);
                      Provider.of<ListModel>(context, listen: false)
                          .addData(newCardData);
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      if (context.mounted) {
                        Map<String, dynamic> newCards =
                            Provider.of<ListModel>(context, listen: false)
                                .toJson();
                        prefs.setString('dataList', jsonEncode(newCards));
                        // Update distance
                        updateCards(
                            Provider.of<ListModel>(context, listen: false), reloadFromMemory: false, reorderData: true, updateAllDistances: false);
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
