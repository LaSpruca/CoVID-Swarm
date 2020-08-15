import 'dart:convert';
import 'dart:ffi';

import 'package:CovidSwarm/get_location.dart';
import 'package:background_fetch/background_fetch.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_heatmap/google_maps_flutter_heatmap.dart';

Future<void> backgroundFetchHeadless(String taskID) {
  Pos location = Pos.err();
  getPosition().then((value) => {location = value});
  print("Location: ${location.toString()}");
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Completer<GoogleMapController> _controller = Completer();
  final Set<Heatmap> _heatmaps = {};
  LatLng _heatmapLocation = LatLng(37.42796133580664, -122.085749655962);
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: GoogleMap(
        mapType: MapType.hybrid,
        heatmaps: _heatmaps,
        initialCameraPosition: CameraPosition(
          target: LatLng(37.42796133580664, -122.085749655962),
          zoom: 14.4746,
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refreshHeatmap,
        label: Text('Refresh Heatmap'),
        icon: Icon(Icons.refresh),
      ),
    );
  }

  Future<void> initPlatformState() async {
    BackgroundFetch.configure(BackgroundFetchConfig(
      minimumFetchInterval: 30,
      stopOnTerminate: false,
      enableHeadless: true,
      requiresBatteryNotLow: true,
      requiresCharging: false,
      requiresStorageNotLow: false,
      requiresDeviceIdle: false,
      requiredNetworkType: NetworkType.ANY
    ), (String taskId) async {
      print("[BackgroundFetch], received $taskId]");
    }).then((int status) => {
      print("[BackgroundFetch], configure success: $status")
    }).catchError((e) => {
      print("[BackgroundFetch], configure failure: $e")
    });

    if (!mounted) return;
  }

  Future<void> _refreshHeatmap() async {
    final points = await _getPoints(_heatmapLocation);
    setState(() {
      _heatmaps.add(Heatmap(
          heatmapId: HeatmapId(_heatmapLocation.toString()),
          points: points,
          radius: 20,
          visible: true,
          gradient: HeatmapGradient(
              colors: <Color>[Colors.green, Colors.red],
              startPoints: <double>[0.2, 0.8])));
    });

    // controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  Future<List<WeightedLatLng>> _getPoints(LatLng location) async {
    final List<WeightedLatLng> points = <WeightedLatLng>[];
    final serverJSON = await _getServerGPS();
    print(json.decode(serverJSON));
    points.add(_createWeightedLatLng(-35.7288, 174.3304, 1));
    return points;
  }

  WeightedLatLng _createWeightedLatLng(double lat, double lng, int weight) {
    return WeightedLatLng(point: LatLng(lat, lng), intensity: weight);
  }

  Future<String> _getServerGPS() async {
    final response = await http.get('http://swarm.qrl.nz/location/32948');
    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
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
    }
  }
}
