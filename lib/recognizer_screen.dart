import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' hide Image;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:tflite/tflite.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:number_recognizer/constants.dart';
//import 'package:image_gallery_saver/image_gallery_saver.dart';
//import 'package:simple_permissions/simple_permissions.dart';

final Paint drawingPaint = Paint()
  ..strokeCap = StrokeCap.square
  ..isAntiAlias = kIsAntiAlias
  ..color = kBrushColor
  ..strokeWidth = kStrokeWidth;

final Paint whitePaint = Paint()
  ..strokeCap = StrokeCap.square
  ..isAntiAlias = kIsAntiAlias
  ..color = kBrushWhite
  ..strokeWidth = kStrokeWidth;

class RecognizerScreen extends StatefulWidget {
  RecognizerScreen({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _RecognizerScreen createState() => _RecognizerScreen();
}

class _RecognizerScreen extends State<RecognizerScreen> {
  List<Offset> points = List();
  String mainMessage = '';
  String topMessage = '';
  Uint8List imageBytes;
  List<BarChartGroupData> items = List();

  void _cleanDrawing() {
    setState(() {
      topMessage = kWaitingForInputTopString;
      mainMessage = kWaitingForInputBottomString;
      points = List();
    });
  }

  void processCanvasPoints(List<Offset> points) async {
    final canvasSizeWithPadding = kCanvasSize + (2 * kCanvasInnerOffset);
    final canvasOffset = Offset(kCanvasInnerOffset, kCanvasInnerOffset);
    final recorder = PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromPoints(
        Offset(0.0, 0.0),
        Offset(canvasSizeWithPadding, canvasSizeWithPadding),
      ),
    );

    final backgroundPaint = Paint();

    backgroundPaint.color = Colors.black;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSizeWithPadding, canvasSizeWithPadding),
        backgroundPaint);

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
            points[i] + canvasOffset, points[i + 1] + canvasOffset, whitePaint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        canvasSizeWithPadding.toInt(), canvasSizeWithPadding.toInt());
    final imgBytes = await img.toByteData(format: ImageByteFormat.png);
    Uint8List pngUint8List = imgBytes.buffer.asUint8List();

//    List<int> pngListInt = pngUint8List.cast<int>();
//    final result = await ImageGallerySaver.save(pngUint8List);

    im.Image imImage = im.decodeImage(pngUint8List);
    im.Image resizedImage = im.copyResize(
      imImage,
      width: kModelInputSize,
      height: kModelInputSize,
    );
//    await ImageGallerySaver.saveImage(im.encodePng(resizedImage));
    _predictImage(resizedImage);
  }

  Uint8List imageToByteListFloat32(im.Image image, int inputSize) {
    var convertedBytes = Float32List(inputSize * inputSize);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] =
            (im.getRed(pixel) + im.getGreen(pixel) + im.getBlue(pixel)) /
                3 /
                255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  double convertPixel(int color) {
    return (255 -
            (((color >> 16) & 0xFF) * 0.299 +
                ((color >> 8) & 0xFF) * 0.587 +
                (color & 0xFF) * 0.114)) /
        255.0;
  }

  Future _loadModel() async {
    Tflite.close();
    try {
      await Tflite.loadModel(
        model: "assets/converted_mnist_model.tflite",
        labels: "assets/labels.txt",
      );
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  Future _predictImage(im.Image image) async {
    var recognitions = await Tflite.runModelOnBinary(
      binary: imageToByteListFloat32(image, kModelInputSize),
    );

    final predictedLabel = recognitions.first['label'];
    setState(() {
      mainMessage = predictedLabel;
      _buildBarChartInfo(recognitions: recognitions);
    });
  }

//  void _requestStoragePermission() async {
//    final permission = Permission.WriteExternalStorage;
//    bool permissionAlreadyGranted =
//        await SimplePermissions.checkPermission(permission);
//    print("permission is " + permissionAlreadyGranted.toString());
//    if (!permissionAlreadyGranted) {
//      final res = await SimplePermissions.requestPermission(permission);
//      print("permission request result is " + res.toString());
//    }
//  }

  BarChartGroupData _makeGroupData(int x, double y) {
    return BarChartGroupData(x: x, barRods: [
      BarChartRodData(
        y: y,
        color: kBarColor,
        width: kChartBarWidth,
        isRound: true,
        backDrawRodData: BackgroundBarChartRodData(
          show: true,
          y: 1,
          color: kBarBackgroundColor,
        ),
      ),
    ]);
  }

  void _buildBarChartInfo({List recognitions= const []}) {
    items = List();
    for( var i = 0 ; i<10 ; i++ ) {
      var barGroup = _makeGroupData(i, 0);
      items.add(barGroup);
    }
    print(recognitions);
    for (var recognition in recognitions) {

      final idx = recognition["index"];
      if (0 <= idx && idx <= 9) {
        final confidence = recognition["confidence"];
        items[idx] = _makeGroupData(idx, confidence);
      }
    }
  }


  @override
  void initState() {
    super.initState();
    _loadModel();
    _cleanDrawing();
//    _requestStoragePermission();
    _buildBarChartInfo();
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
                child: SizedBox(
                  width: kCanvasSize,
                  height: kCanvasSize,
                  child: Container(
                    decoration: new BoxDecoration(
                      border: new Border.all(
                        width: 3.0,
                        color: Colors.blue,
                      ),
                    ),
                    child: Builder(
                      builder: (BuildContext context) {
                        return GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              RenderBox renderBox = context.findRenderObject();
                              points.add(renderBox
                                  .globalToLocal(details.globalPosition));
                            });
                          },
                          onPanStart: (details) {
                            setState(() {
                              RenderBox renderBox = context.findRenderObject();
                              points.add(renderBox
                                  .globalToLocal(details.globalPosition));
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              points.add(null);
                              processCanvasPoints(points);
                            });
                          },
                          child: ClipRect(
                            child: CustomPaint(
                              size: Size(kCanvasSize, kCanvasSize),
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
            flex: 4,
          ),
          Expanded(
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Center(
                    child: Text(
                      mainMessage,
                      style: Theme.of(context).textTheme.headline,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(32, 32, 32, 16),
                      child: FlChart(
                        chart: BarChart(
                          BarChartData(
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: SideTitles(
                                  showTitles: true,
                                  textStyle: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  margin: 6,
                                  getTitles: (double value) {
                                    return value.toInt().toString();
                                  }),
                              leftTitles: SideTitles(
                                showTitles: false,
                              ),
                            ),
                            borderData: FlBorderData(
                              show: false,
                            ),
                            barGroups: items,
                            // read about it in the below section
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: Container(),
            flex: 1,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _cleanDrawing();
          _buildBarChartInfo();
        },
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
