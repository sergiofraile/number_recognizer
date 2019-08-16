import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' hide Image;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:tflite/tflite.dart';
import 'package:flutter/services.dart';

final Paint drawingPaint = Paint()
  ..strokeCap = (Platform.isAndroid) ? StrokeCap.butt : StrokeCap.round
  ..isAntiAlias = true
  ..color = Colors.black
  ..strokeWidth = 7.0;

class RecognizerScreen extends StatefulWidget {
  RecognizerScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _RecognizerScreen createState() => _RecognizerScreen();
}

class _RecognizerScreen extends State<RecognizerScreen> {

  final String calculatingString = 'Calculating...';
  final String waitingForInputTopString = 'Please draw a number in the box below';
  final String waitingForInputBottomString = 'Let me guess...';
  final String guessingInputString = 'The number you draw is';

  List<Offset> points = List();
  String mainMessage = '';
  String topMessage = '';
  String number = '';

  void _cleanDrawing() {
    setState(() {
      topMessage = waitingForInputTopString;
      mainMessage = waitingForInputBottomString;
      number = '';
      points = List();
    });
  }

  void saveToImage(List<Offset> points) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromPoints(Offset(0.0, 0.0), Offset(200.0, 200.0)));

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], drawingPaint);
      }
    }

    final picture = recorder.endRecording();
    final img = picture.toImage(200, 200);
    final pngBytes = await img.toByteData(format: ImageByteFormat.png);

    Uint8List pngUint8List = pngBytes.buffer.asUint8List(pngBytes.offsetInBytes, pngBytes.lengthInBytes);
    _predictImage(pngUint8List);
//    List<int> pngListInt = pngUint8List.cast<int>();
//
//    im.Image imImage = im.decodeImage(pngListInt);
//    im.Image mnistSize = im.copyResize(imImage, width: 28, height: 28);
  }

  Future _loadModel() async {
    Tflite.close();
    try {
      String res = await Tflite.loadModel(model: "assets/converted_mnist_model.tflite",);
      print(res);
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  Future _predictImage(Uint8List imageBinary) async {
    var recognitions = await Tflite.runModelOnBinary(
        binary: imageBinary,
        numResults: 10,
    );

    print(recognitions);
  }

  @override
  void initState() {
    super.initState();
    _loadModel();
    _cleanDrawing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    topMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headline,
                  ),
                ],
              ),
            ),
            flex: 1,
          ),
          Expanded(
            child: Container(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: new BoxDecoration(
                        border: new Border.all(
                          width: 3.0,
                          color: Colors.black,
                        ),
                      ),
                      child: Builder(
                        builder: (BuildContext context) {
                          return GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                RenderBox renderBox =
                                    context.findRenderObject();
                                points.add(renderBox
                                    .globalToLocal(details.globalPosition));
                              });
                            },
                            onPanStart: (details) {
                              setState(() {
                                RenderBox renderBox =
                                    context.findRenderObject();
                                points.add(renderBox
                                    .globalToLocal(details.globalPosition));
                              });
                            },
                            onPanEnd: (details) {
                              setState(() {
                                points.add(null);
                                saveToImage(points);
                                // ToDo: Trigger calculation
//                                final picture = recorder.endRecording();
//                                final img = picture.toImage(200, 200);
//                                final pngBytes = await img.toByteData(format: new ui.EncodingFormat.png());
//                                new Image.memory(new Uint8List.view(imgBytes.buffer));

                              });
                            },
                            child: ClipRect(
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: DrawingPainter(
                                  offsetPoints: points,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flex: 6,
          ),
          Expanded(
            child: Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    mainMessage,
                    style: Theme.of(context).textTheme.headline,
                  ),
                  Text(
                    number,
                    style: Theme.of(context).textTheme.display1,
                  ),
                ],
              ),
            ),
            flex: 1,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cleanDrawing,
        tooltip: 'Clean',
        child: Icon(Icons.delete),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class DrawingPainter extends CustomPainter {


  DrawingPainter({this.offsetPoints});
  List<Offset> offsetPoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < offsetPoints.length - 1; i++) {
      if (offsetPoints[i] != null && offsetPoints[i + 1] != null) {
        canvas.drawLine(offsetPoints[i], offsetPoints[i + 1], drawingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
