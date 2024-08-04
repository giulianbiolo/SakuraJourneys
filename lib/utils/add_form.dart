import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
  final ratingText = TextEditingController();

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
                  if (value.length > 20) {
                    return 'Title must be less than 20 characters';
                  }
                  return null;
                },
                controller: titleText,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "Enter the description",
                  icon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  if (value.length > 200) {
                    return 'Description must be less than 200 characters';
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
                  if (value.length > 25) {
                    return 'Address must be less than 25 characters';
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
                  hintText: "Enter the latitude in the form (lat, lng)",
                  icon: Icon(Icons.gps_fixed),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  try {
                    LocationModel.fromLatLngString(value);
                  } catch (e) {
                    return 'Please enter the latitude and longitude in the form (lat, lng)';
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
                    return 'Rating must be between 0 and 5';
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () async {
                    // ? Open the file selector
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (result != null) {
                      File file = File(result.files.single.path!);
                      String fileContent = await file.readAsString();
                      Map<String, dynamic> loadedData = jsonDecode(fileContent);
                      try {
                        List<DataModel> dataList = dataFromJson(loadedData);
                        if (context.mounted) {
                          Provider.of<ListModel>(context, listen: false).loadData(dataList);
                          SharedPreferences prefs = await SharedPreferences.getInstance();
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
                            imageUrlText.text,
                            addressText.text,
                            LocationModel.fromLatLngString(latLngText.text),
                            descriptionText.text,
                            double.parse(ratingText.text),
                          );
                          Provider.of<ListModel>(context, listen: false)
                              .addData(data);
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          if (context.mounted) {
                            String settingString =
                                Provider.of<ListModel>(context, listen: false)
                                    .toString();
                            print("Now saving the following string:\n$settingString");
                            prefs.setString('dataList',settingString);
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
