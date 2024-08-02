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
      "https://imgcdn.dev/i/bkYN0",
      "Sumida, Tokyo",
      LocationModel(35.7101, 139.8107),
      "The Tokyo Skytree is a broadcasting and observation tower in Sumida, Tokyo. It became the tallest structure in Japan in 2010 and reached its full height of 634.0 meters in March 2011, making it the tallest tower in the world.",
      200.0),
  DataModel(
      "Akihabara",
      "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Flp-cms-production.imgix.net%2Ffeatures%2F2010%2F07%2Fakihabara_lights_tokyo-fa3cbf4bacab.jpg%3Fauto%3Dformat%26fit%3Dcrop%26sharp%3D10%26vib%3D20%26ixlib%3Dreact-8.6.4%26w%3D850%26q%3D23%26dpr%3D4&f=1&nofb=1&ipt=d77984042467ca220f12423abb45e49da272541e669c8a7d8e7620c101201644&ipo=images",
      "Akihabara, Tokyo",
      LocationModel(35.698333, 139.773056),
      "Akihabara is a neighborhood in Tokyo located less than five minutes by rail from Tokyo Station. Akihabara is a major shopping area for electronic, computer, anime, games, and otaku goods.",
      300.0),
  DataModel(
      "TeamLab BorderLess",
      "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fimages.squarespace-cdn.com%2Fcontent%2Fv1%2F5d91f0811b06bc4c5b873679%2F1571492391091-1Z8JAA9ZPLLE7WBUYVV5%2F20191018_222551.jpg&f=1&nofb=1&ipt=0f56f31887f5ee7cbf68930510a0a4384d7096483f78636f930067a5a51805f2&ipo=images",
      "6-chome, Toyosu, Koto-ku, Tokyo",
      LocationModel(35.649074249937755, 139.78983024721975),
      "teamLab Planets is an art facility that utilizes digital technology and was established by teamLab and DMM.com. The art space is vast, and the visitor is encouraged to move around the space with others.",
      200.0),
  DataModel(
      "Tokyo Imperial Palace",
      "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fgaijinpot.scdn3.secure.raxcdn.com%2Fwp-content%2Fuploads%2Fsites%2F6%2F2016%2F07%2FTokyo-Imperial-Palace.jpg&f=1&nofb=1&ipt=feb1325f0cd102daf8675f410fc7c69b709ae7de23f5f85805aab2d2f45c2443&ipo=images",
      "1-1 Chiyoda, Chiyoda-ku 100-0001 Tokyo",
      LocationModel(35.6825, 139.7521),
      "The Tokyo Imperial Palace is the main residence of the Emperor of Japan. It is a large park-like area located in the Chiyoda ward of Tokyo and contains private residences, the main palace, museums and more.",
      250.0),
];
