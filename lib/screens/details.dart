import 'package:japan_travel/models/models.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';


class DetailsScreen extends StatefulWidget {
  final DataModel data;
  const DetailsScreen({super.key, required this.data});

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                child: Hero(
                  tag: widget.data.imageName,
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        image: DecorationImage(
                            image: AssetImage(
                              widget.data.imageName,
                            ),
                            fit: BoxFit.fill),
                        boxShadow: const [
                          BoxShadow(
                              offset: Offset(0, 4),
                              blurRadius: 4,
                              color: Colors.black26)
                        ]),
                  ),
                ),
              )),
          Text(
            widget.data.title,
            style: const TextStyle(
                color: Colors.black45,
                fontSize: 25,
                fontWeight: FontWeight.bold
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Text(
                "Rating: ${widget.data.rating}",
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
          // Make a small padding and then a button to open google maps using the navigateTo function
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ElevatedButton(
              onPressed: () {
                navigateTo(35.710063, 139.8107);
              },
              // use the navigation icon
              child: const Icon(Icons.navigation),
            ),
          )


        ],
      ),
    );
  }
}

navigateTo(double lat, double lng) async {
   var uri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
   if (await canLaunchUrl(uri)) { await launchUrl(uri); }
   else { throw 'Could not launch ${uri.toString()}'; }
}
