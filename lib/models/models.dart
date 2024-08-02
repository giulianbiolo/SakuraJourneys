class LocationModel {
  final double lat;
  final double lng;
  LocationModel(this.lat, this.lng);
}

class DataModel {
  final String title;
  final String imageName;
  final String address;
  final LocationModel location;
  double distance = 0.0;
  bool alreadySeen = false;
  final String description;
  final double rating;
  DataModel(
    this.title,
    this.imageName,
    this.address,
    this.location,
    this.description,
    this.rating,
  );
}

enum LocationStatus { unseen, seen }

List<DataModel> dataList = [
  /*
   * DataModel(
    * String title,            [Tokyo Sky Tree]
    * String imageName,        [assets/...]
    * String address,          [Shinjuku, Tokyo] // Max 25 chars
    * LocationModel location,  [LatLng(Latitude, Longitude)]
    * String description,      [The description of the place] // Max 200 chars
    * double rating,           [0 - 300]
   * ),
  */
  DataModel(
      "Tokyo Sky Tree",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/tokyo_sky_tree.jpg?raw=true",
      "Sumida, Tokyo",
      LocationModel(35.7101, 139.8107),
      "The Tokyo Skytree is a broadcasting and observation tower in Sumida, Tokyo. It became the tallest structure in Japan in 2010 and reached its full height of 634.0 meters in March 2011, making it the tallest tower in the world.",
      200.0),
  DataModel(
      "Akihabara",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/akihabara.jpg?raw=true",
      "Akihabara, Tokyo",
      LocationModel(35.698333, 139.773056),
      "Akihabara is a neighborhood in Tokyo located less than five minutes by rail from Tokyo Station. Akihabara is a major shopping area for electronic, computer, anime, games, and otaku goods.",
      300.0),
  DataModel(
      "TeamLab BorderLess",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/teamlab_borderless.jpg?raw=true",
      "6-chome, Toyosu, Koto-ku, Tokyo",
      LocationModel(35.649074249937755, 139.78983024721975),
      "teamLab Planets is an art facility that utilizes digital technology and was established by teamLab and DMM.com. The art space is vast, and the visitor is encouraged to move around the space with others.",
      200.0),
  DataModel(
      "Tokyo Imperial Palace",
      "https://github.com/giulianbiolo/SakuraJourneys/blob/main/assets/tokyo_imperial_palace.jpg?raw=true",
      "1-1 Chiyoda, Chiyoda-ku 100-0001 Tokyo",
      LocationModel(35.6825, 139.7521),
      "The Tokyo Imperial Palace is the main residence of the Emperor of Japan. It is a large park-like area located in the Chiyoda ward of Tokyo and contains private residences, the main palace, museums and more.",
      250.0),
];
