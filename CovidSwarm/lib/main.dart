import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:CovidSwarm/get_location.dart';
import 'package:background_fetch/background_fetch.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appVersion = [1,0,0];

void updateGPS() {
  print("Updating GPS location");
  Pos location = Pos.err();
  getPosition().then((value) async {
    if (!value.error) {
      location = value;
      print("Location: ${location.toString()}");
      var deviceID = await _getDeviceID();
      var client = http.Client();
      try {
        var uriResponse = await client.post(
            'http://swarmapi.qrl.nz/location/' + deviceID.toString(),
            body: jsonEncode({
              "covid_status": false,
              "latitude": location.latitude.toString(),
              "longitude": location.longitude.toString()
            }));
        print("Server status code: " + uriResponse.statusCode.toString());
      } catch (e) {
        print("Error on server post: " + e.toString());
      } finally {
        client.close();
      }
    } else {
      print("GPS failed: "+value.error.toString());
    }
  });
}

Future<void> backgroundFetchHeadless(String taskId) {
  updateGPS();
  BackgroundFetch.finish(taskId);
}

void main() {
  runApp(MyApp());

  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadless);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Covid Swarm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Covid Swarm Map'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Completer<GoogleMapController> _controller = Completer();
  Set<Heatmap> _heatmaps = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldState> _mapScaffoldKey =
      new GlobalKey<ScaffoldState>();
  bool backgroundTaskEnabled = true;
  double currentZoom = 1;
  double heatmapZoom = 1;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    var fiveMinutes = Duration(minutes: 5);
    Timer.periodic(fiveMinutes, (timer) {
      setState(() {
        _refreshHeatmap();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text(widget.title),
              bottom: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.map)),
                  Tab(icon: Icon(Icons.settings))
                ],
              ),
            ),
            body: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: [
                MapPage(this),
                Settings(this)
              ],
            )));
  }

  Future<void> initPlatformState() async {
    BackgroundFetch.configure(
            BackgroundFetchConfig(
                minimumFetchInterval: 30,
                stopOnTerminate: false,
                enableHeadless: true,
                requiresBatteryNotLow: true,
                requiresCharging: false,
                requiresStorageNotLow: false,
                requiresDeviceIdle: false,
                requiredNetworkType: NetworkType.ANY), (String taskId) async {
      print("[BackgroundFetch], received $taskId]");
    })
        .then((int status) =>
            {print("[BackgroundFetch], configure success: $status")})
        .catchError((e) => {print("[BackgroundFetch], configure failure: $e")});

    if (!mounted) return;
  }

  void _cameraIdle() async {
    if (heatmapZoom != currentZoom) {
      heatmapZoom = currentZoom;
      print("Zoom in camera change function: " + currentZoom.toString());
      _refreshHeatmap();
    }
  }

  void _cameraMove(CameraPosition position) async {
    currentZoom = position.zoom;
  }

  Future<void> _refreshHeatmap() async {
    print("Refreshing Heatmap, Scaled points radis: " +
        (10 * currentZoom).round().toString());
    print("Zoom in refresh heatmap function: " + currentZoom.toString());
    var points = await _getPoints();
    print("Server Points: " + points.toString());
    setState(() {
      _heatmaps.add(Heatmap(
          heatmapId: HeatmapId("people_tracking"),
          points: points,
          radius: (10 * currentZoom).round().clamp(5, 50),
          visible: true,
          gradient: HeatmapGradient(
              colors: <Color>[Colors.blue, Colors.red],
              startPoints: <double>[0.2, 0.8])));
    });

    // controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  Future<bool>_checkAppVersion() async {
    final response = await http.get('http://swarmapi.qrl.nz/app/version');

    if (response.statusCode == 200) {
      print("Server responded with: " + response.body);
      var remoteVersionJson = jsonDecode(response.body);
      return ListEquality().equals( [remoteVersionJson["major_version"] + remoteVersionJson["minor_version"] + remoteVersionJson["patch_version"]],appVersion);

    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.

      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            new Text('Failed to check version! Code: ${response.statusCode}'),
        duration: new Duration(seconds: 5),
      ));
    }
  }

  Future<List<WeightedLatLng>> _getPoints() async {
    final List<WeightedLatLng> points = <WeightedLatLng>[];

    print("Geting server points");
    final serverJSON = await _getServerGPS();
    final decodedGPS = json.decode(serverJSON);
    final currentTime = DateTime.now();
    int numberOfPoints = 0;
    for (var jsonGpsPoint in decodedGPS) {
      numberOfPoints++;

      //Weight is based off how recent the data point is
      var pointTime = DateTime.parse(jsonGpsPoint["latest_time"]);
      print("Time diff: " +
          ((1 / ((currentTime.difference(pointTime).inSeconds) / 600)) * 10)
              .round()
              .toString());
      var pointWeight =
          ((1 / ((currentTime.difference(pointTime).inSeconds) / 600)) * 10)
              .round();
      if (pointWeight > 0) {
        points.add(_createWeightedLatLng(
          jsonGpsPoint["latitude"], 
          jsonGpsPoint["longitude"], 
          pointWeight));
      }
    }
    return points;
  }

  WeightedLatLng _createWeightedLatLng(double lat, double lng, int weight) {
    return WeightedLatLng(point: LatLng(lat, lng), intensity: weight);
  }

  Future<String> _getServerGPS() async {
    final response = await http.get('http://swarmapi.qrl.nz/location');

    if (response.statusCode == 200) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: new Text('Brrrrrrrrrrrr'),
        duration: new Duration(seconds: 5),
      ));
      print("Server responded with: " + response.body);
      return response.body;
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.

      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            new Text('Failed to contact server! Code: ${response.statusCode}'),
        duration: new Duration(seconds: 5),
      ));
      return "[]";
    }
  }
}

Future<int> _getDeviceID() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey("device_id")) {
    return prefs.getInt("device_id");
  } else {
    final response = await http.get('http://swarmapi.qrl.nz/device');
    if (response.statusCode == 200) {
      prefs.setInt("device_id", int.parse(response.body));
      return int.parse(response.body);
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print("Failed to reg with server, status:" +
          response.statusCode.toString());
      return -1;
    }
  }
}

class Settings extends StatelessWidget {
  _MyHomePageState homePage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            PaddedText("Enable background GPS upload"),
            Switch(
              value: homePage.backgroundTaskEnabled,
              onChanged: (value) {
                homePage.setState(() {
                  homePage.backgroundTaskEnabled = value;
                });
              },
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        MaterialButton(
          child: PaddedText("Push current location"),
          onPressed: () {
            print("Manule GPS push");
            updateGPS();
          },
        ),
        MaterialButton(
            child: PaddedText("Manual map update"),
            onPressed: () {
              homePage.setState(() {
                homePage._refreshHeatmap();
              });
            }),
        MaterialButton (
          child: PaddedText("Register as new device"),
          onPressed: () async {
            final SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.clear();
          },
          ),
        MaterialButton (
          child: PaddedText("Check for updates"),
          onPressed: () async {
            homePage._checkAppVersion();
          },
        ),
          PaddedText("App Version: " + appVersion[0].toString() + "." + appVersion[1].toString() + "." + appVersion[2].toString())
      ],
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Settings(this.homePage);
}

class PaddedText extends StatelessWidget {
  String text;
  PaddedText(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      child: Text(text),
      padding: EdgeInsets.all(10),
    );
  }
}
class MapPage extends StatelessWidget {

  _MyHomePageState parent;

  MapPage(this.parent);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: parent._mapScaffoldKey,
      body: GoogleMap(
        mapType: MapType.hybrid,
        heatmaps: parent._heatmaps,
        minMaxZoomPreference: MinMaxZoomPreference(1, 18),
        initialCameraPosition: CameraPosition(
          target: LatLng(-40.501210, 174.050287),
          zoom: 5,
        ),
        onMapCreated: (GoogleMapController controller) {
          if (!parent._controller.isCompleted) {
            parent._controller.complete(controller);
          }
        },
        onCameraMove: parent._cameraMove,
        onCameraIdle: parent._cameraIdle,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: parent._refreshHeatmap,
        label: Text("Refresh"),
        icon: Icon(Icons.refresh) ,
      ),
    );
  }

}