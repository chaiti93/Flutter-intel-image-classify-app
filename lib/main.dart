//Import flutter libraries
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


//Import tflite for ML
import 'package:tflite/tflite.dart';

//Import image picker package
import 'package:image_picker/image_picker.dart';

void main() => runApp(MyApp());

const String mobilenet = "Intel image classification";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intel_image_classify',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MyHomePage(title: 'Intel_image_classify'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  AnimationController _controller;
  static const List<IconData> icons = const [Icons.camera_alt, Icons.photo];

  File _image;
  List _predictions;
  
  List pred = new List(3);

  bool _busy = false;

  bool _hasImage;

  //All the major features wrapped in ImagePicker method
  selectFromImagePicker(ImageSource source, BuildContext context) async {
    var image = await ImagePicker.pickImage(source: source);

    if (image == null) return;
    setState(() {
      _image = image;
      print(_image);
    });

    predictImage(image);
  }

  //Async await model and predict the features of an image
  Future predictImage(File image) async {
    _hasImage = true;
    if (image == null) return;
    setState(() {
      _image = image;
    });

    setState(() {
      _busy = true;
      _predictions = null;
    });
    
    await Tflite.loadModel(
      model: "assets/intel_image_classify.tflite",
      labels: "assets/labels.txt",
    );
    await recognizeImage(image);

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  //State initialization
  @override
  void initState() {
    _controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    super.initState();
    _busy = false;
    _hasImage = false;
  }

  //Load the Tensorflow Lite model and corresponding label
  Future loadModel() async {
    Tflite.close();
    try {
      String res = await Tflite.loadModel(
            model: "assets/intel_image_classify.tflite",
            labels: "assets/labels.txt",
          );
      print("loadModel res: " + res);
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  //Set parameters for Intel image classification model
  Future recognizeImage(File image) async {
    var recognitions = await Tflite.runModelOnImage(
      path: image.path,
      imageMean: 0.0,
      imageStd: 255.0,
      numResults: 1,
      threshold: 0.2,
    );

    recognitions.map((re) {
      pred[0] = re["index"];
      pred[1] = re["label"];
      pred[2] = re["confidence"];
    }).toList();

    print("Prediction: $pred");
    print(recognitions);
    setState(() {
      _predictions = recognitions;
    });
  }


  @override
  Widget build(BuildContext context) {
    Color backgroundColor = Theme.of(context).cardColor;
    Color foregroundColor = Theme.of(context).accentColor;
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _busy ? Center(child: CircularProgressIndicator()) : buildList(),
      floatingActionButton: new Column(
        mainAxisSize: MainAxisSize.min,
        children: new List.generate(icons.length, (int index) {
          Widget child = new Container(
            height: 70.0,
            width: 56.0,
            alignment: FractionalOffset.topCenter,
            child: new ScaleTransition(
              scale: new CurvedAnimation(
                parent: _controller,
                curve: new Interval(0.0, 1.0 - index / icons.length / 2.0,
                    curve: Curves.easeOut),
              ),
              child: new FloatingActionButton(
                heroTag: null,
                backgroundColor: backgroundColor,
                mini: false,
                child: new Icon(icons[index], color: foregroundColor),
                onPressed: () {
                  _controller.reverse();
                  if (index == 0)
                    selectFromImagePicker(ImageSource.camera, context);
                  else if (index == 1)
                    selectFromImagePicker(ImageSource.gallery, context);
                },
              ),
            ),
          );
          return child;
        }).toList()
          ..add(
            new FloatingActionButton(
              heroTag: null,
              child: new AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget child) {
                  return new Transform.rotate(
                    angle: _controller.value * math.pi * 0.75,
                    alignment: FractionalOffset.center,
                    child: new Icon(
                      Icons.add,
                      size: 30.0,
                    ),
                  );
                },
              ),
              onPressed: () {
                if (_controller.isDismissed) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            ),
          ),
      ),
    );
  }

  Widget buildList() {
    if (_predictions != null) print(_predictions.length);
    List<Widget> stack = List();
    if (_image != null) {
      stack.add(Image.file(
        _image,
        width: MediaQuery.of(context).size.width,
      ));
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _image != null
              ? Stack(children: stack)
              : Center(
                  child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text("No image selected"),
                )),
          (_predictions != null && _predictions.length != 0)
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text("Category: ",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "${_predictions[0]['label']}\nConfidence ${(_predictions[0]['confidence'] * 100).toStringAsFixed(2)}%",
                        style: TextStyle(color: Colors.black, fontSize: 16)),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}