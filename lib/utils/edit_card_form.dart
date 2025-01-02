import 'dart:convert';

import 'package:flutter/material.dart';
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
  final ratingText = TextEditingController();

  @override
  void initState() {
    super.initState();
    oldCardData = widget.initialCardData;
    titleText.text = widget.initialCardData.title;
    descriptionText.text = widget.initialCardData.description;
    addressText.text = widget.initialCardData.address;
    imageUrlText.text = widget.initialCardData.imageName;
    latLngText.text = widget.initialCardData.location.toString();
    ratingText.text = widget.initialCardData.rating.toString();
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
              TextFormField(
                minLines: 5,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter the description",
                  icon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (value.length > maxDescriptionLength) {
                    return 'Description must be less than $maxDescriptionLength characters';
                  }
                  return null;
                },
                controller: descriptionText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Address",
                  hintText: "Enter the address",
                  icon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (value.length > maxAddressLength) {
                    return 'Address must be less than $maxAddressLength characters';
                  }
                  return null;
                },
                controller: addressText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Image URL",
                  hintText: "Enter the image URL",
                  icon: Icon(Icons.image),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (!Uri.parse(value).isAbsolute) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
                controller: imageUrlText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Latitude & Longitude",
                  hintText: "Enter value as (lat, lng) in decimal notation",
                  icon: Icon(Icons.gps_fixed),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  try {
                    LocationModel.fromLatLngString(value);
                  } catch (e) {
                    return 'Please enter: (lat, lng) in decimal base notation';
                  }
                  return null;
                },
                controller: latLngText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Rating",
                  hintText: "Enter the rating",
                  icon: Icon(Icons.star),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a number';
                  }
                  if (double.parse(value) < 0 || double.parse(value) > 5) {
                    return 'Must be between 0 and 5';
                  }
                  return null;
                },
                controller: ratingText,
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
                        imageUrlText.text,
                        addressText.text,
                        LocationModel.fromLatLngString(latLngText.text),
                        descriptionText.text,
                        double.parse(ratingText.text),
                      );
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
                        print(
                            "Now saving the following string:\n$newCards");
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
