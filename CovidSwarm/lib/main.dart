import 'dart:convert';

import 'package:CovidSwarm/get_location.dart';
import 'package:background_fetch/background_fetch.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';
import 'package:shared_preferences/shared_preferences.dart';

void updateGPS() {
  Pos location = Pos.err();
  getPosition().then((value) async {
    location = value;
    print("Location: ${location.toString()}");

    var deviceID = await _getDeviceID();
    var client = http.Client();
    try {
      var uriResponse = await client.post(
          'http://swarm.qrl.nz/location/' + deviceID.toString(),
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
  bool backgroundTaskEnabled = true;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    var fiveMinutes = Duration(minutes: 5);
    Timer.periodic(fiveMinutes, (timer) {
      setState(() {
        _getServerGPS();
        _refreshHeatmap();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ;
    _refreshHeatmap();
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
                GoogleMap (
                  mapType: MapType.hybrid,
                  heatmaps: _heatmaps,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(37.42796133580664, -122.085749655962),
                    zoom: 1.4746,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),
                Settings(this)
              ],
            )
        ));
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

  Future<void> _refreshHeatmap() async {
    var points = await _getPoints();
    print("Server Points: " + points.toString());
    setState(() {
      _heatmaps.add(Heatmap(
          heatmapId: HeatmapId("people_tracking"),
          points: points,
          radius: 50,
          visible: true,
          gradient: HeatmapGradient(
              colors: <Color>[Colors.blue, Colors.red],
              startPoints: <double>[0.2, 0.8])));
    });

    // controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  Future<List<WeightedLatLng>> _getPoints() async {
    final List<WeightedLatLng> points = <WeightedLatLng>[];

    print("Geting server points");
    final serverJSON = await _getServerGPS();
    final decodedGPS = json.decode(serverJSON);

    for (var jsonGpsPoint in decodedGPS) {
      points.add(_createWeightedLatLng(
          jsonGpsPoint["latitude"], jsonGpsPoint["longitude"], 1));
    }

    return points;
  }

  WeightedLatLng _createWeightedLatLng(double lat, double lng, int weight) {
    return WeightedLatLng(point: LatLng(lat, lng), intensity: weight);
  }

  Future<String> _getServerGPS() async {
    final response = await http.get('http://swarm.qrl.nz/location/32948');

    if (response.statusCode == 200) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: new Text('Brrrrrrrrrrrr'),
        duration: new Duration(seconds: 10),
      ));
      return response.body;
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.

      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content:
            new Text('Failed to contact server! Code: ${response.statusCode}'),
        duration: new Duration(seconds: 10),
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
    final response = await http.get('http://swarm.qrl.nz/device');
    if (response.statusCode == 200) {
      prefs.setInt("device_id", int.parse(response.body));
      return int.parse(response.body);
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      print(
          "Failed to reg with server, status:" + response.statusCode.toString());
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
        Text("Background upload is currently ${homePage.backgroundTaskEnabled ? "active" : "disabled"}"),
        MaterialButton(
          child: Text("Manual Update GPS"),
          onPressed: updateGPS,
        ),
        MaterialButton(
          child: Text("Toggle background task"),
          onPressed: () {
            homePage.setState(() {
              homePage.backgroundTaskEnabled = !homePage.backgroundTaskEnabled;
            });
          },
        ),
        MaterialButton(
          child: Text("Manual map update"),
          onPressed: () {
            homePage.setState(() {
              homePage._getServerGPS();
              homePage._refreshHeatmap();
            });
          }
        )
      ],
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
    );
  }

  Settings(this.homePage);
}
