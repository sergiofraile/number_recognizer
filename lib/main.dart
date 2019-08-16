import 'package:flutter/material.dart';
import 'package:number_recognizer/recognizer_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Recognizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RecognizerScreen(title: 'Number Recognizer'),
    );
  }
}