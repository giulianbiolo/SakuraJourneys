import 'package:flutter/material.dart';
import 'package:japan_travel/models/models.dart';

class CardWidget extends StatelessWidget {
  final DataModel firstCard;
  const CardWidget({
    super.key,
    required this.firstCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: const BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        children: [
          Image.network(firstCard.imageName),
          Text(firstCard.title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text(firstCard.distance.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
