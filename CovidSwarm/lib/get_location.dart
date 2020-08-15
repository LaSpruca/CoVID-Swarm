import 'package:geolocator/geolocator.dart';

class Pos {
  double longitude;
  double latitude;

  Pos(double longitude, double latitude) {
    this.longitude = longitude;
    this.latitude = latitude;
  }

  @override
  String toString() {
    return "{ long:" +
        longitude.toString() +
        ", lati : " +
        latitude.toString() +
        " }";
  }
}

Future<Pos> getPosition() async {
  var geoLocator = Geolocator();
  Position position = await Geolocator()
      .getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  return Pos(position.longitude, position.latitude);
}
