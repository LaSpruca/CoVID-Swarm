import 'package:flutter/material.dart';

void main() => runApp(CoVID19Swarm());

class CoVID19Swarm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(title: Text("CoVID Swarm")),
      body: Center(
        child: Text("Hello world"),
      ),
    ));
  }
}
