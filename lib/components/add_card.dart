import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:japan_travel/utils/add_form.dart';


class AddCard extends StatelessWidget {
  const AddCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Expanded(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            // ? Open the new card form menu popup
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const AlertDialog(
                    title: Text("Add a new location"),
                    scrollable: true,
                    content: Padding(
                      padding: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                      child: AddForm(),
                    ),
                  );
                });
          },
          child: Hero(
            tag: "addCard",
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: const Color.fromARGB(255, 17, 17, 25),
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.white30,
                      )
                    ]),
                child: const SizedBox(
                  width: 300,
                  child: Icon(
                    Icons.add,
                    size: 100,
                    color: Colors.white70,
                  ),
                )),
          ),
        ),
      ))
    ]);
  }
}
