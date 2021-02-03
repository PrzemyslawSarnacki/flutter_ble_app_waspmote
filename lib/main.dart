import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_ble_app/widgets.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(FlutterBlueApp());
}

class LineAnimationZoomChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  LineAnimationZoomChart(this.seriesList, {this.animate = false});

  // EXCLUDE_FROM_GALLERY_DOCS_START
  // This section is excluded from being copied to the gallery.
  // It is used for creating random series data to demonstrate animation in
  // the example app only.
  factory LineAnimationZoomChart.withRandomData(List<double> countList) {
    return new LineAnimationZoomChart(_createRandomData(countList));
  }

  /// Create random data.
  static List<charts.Series<LinearSales, num>> _createRandomData(
      List<double> countList) {
    final data = <LinearSales>[];

    for (var i = 0; i < countList.length; i++) {
      data.add(new LinearSales(i, countList[i]));
    }

    return [
      new charts.Series<LinearSales, int>(
        id: 'Line',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.x,
        measureFn: (LinearSales sales, _) => sales.y,
        data: data,
      )
    ];
  }
  // EXCLUDE_FROM_GALLERY_DOCS_END

  @override
  Widget build(BuildContext context) {
    var axis = charts.NumericAxisSpec(
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(
                fontSize: 10, color: charts.MaterialPalette.white),
            lineStyle: charts.LineStyleSpec(
                thickness: 0,
                color: charts.MaterialPalette.gray.shadeDefault)));

    return new charts.LineChart(
      seriesList,
      animate: animate,
      behaviors: [
        new charts.PanAndZoomBehavior(),
      ],
      primaryMeasureAxis: axis,
      domainAxis: axis,
    );
  }
}

/// Sample linear data type.
class LinearSales {
  final int x;
  final double y;

  LinearSales(this.x, this.y);
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      theme: ThemeData(
          primarySwatch: Colors.lightBlue, brightness: Brightness.light),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen(this.state);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    assert(context != null);
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subtitle1
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find BT Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return RaisedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            r.device.connect();
                            return DeviceScreen(r.device);
                          })),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return Container(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FloatingActionButton(
                      child: Icon(Icons.search),
                      onPressed: () => FlutterBlue.instance
                          .startScan(timeout: Duration(seconds: 4))),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceScreen(this.device);

  @override
  _DeviceScreenState createState() => _DeviceScreenState(device);
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothDevice device;
  _DeviceScreenState(this.device); //constructor

  static const String CHARACTERISTIC_UUID =
      "be39a5dc-048b-4b8f-84cb-94c197edd26e";
  // "00002a37-0000-1000-8000-00805f9b34fb";
  // "013dc1df-9b8c-4b5c-949b-262543eba78a";
  static const String WRITECHARACTERISTIC_UUID =
      "013dc1df-9b8c-4b5c-949b-262543eba78a";
  // "0000aab0-0000-1000-8000-aabbccddeeff";
  static List<double> baseData = [0, 0];
  static List<double> dataSetA = <double>[];
  static List<double> dataSetB = <double>[];
  static Set<List<String>> _saved = Set<List<String>>(); // Add this line.
  static bool switchDataSet = false;
  final int sizeOfArray = 10;
  static String tempValue;
  static String typeM;

  final _parserController = TextEditingController();
  final _writeController = TextEditingController();

  Widget _tickMeasurement(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
              width: 40,
              child: TextField(
                decoration: InputDecoration(
                    border: InputBorder.none, hintText: "First character"),
                controller: _parserController,
                maxLength: 1,
                maxLengthEnforced: true,
              )),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setPlot(_parserController.value.text),
              child: Icon(
                Icons.show_chart,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setChat(),
              child: Icon(
                Icons.message,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pushSaved(context),
              child: Icon(
                Icons.list,
                size: 40,
                color: Colors.white70,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _myService(List<BluetoothService> services) {
    Stream<List<int>> stream;

    services.forEach((service) {
      service.characteristics.forEach((character) {
        if (character.uuid.toString() == CHARACTERISTIC_UUID) {
          character.setNotifyValue(!character.isNotifying);
          stream = character.value;
        }
      });
    });

    return Container(
      child: StreamBuilder<List<int>>(
          stream: stream,
          builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
            if (snapshot.hasError) return Text('Error : ${snapshot.error}');

            if (snapshot.connectionState == ConnectionState.active) {
              var currentValue = _dataParser(snapshot.data);
              _saved.add([
                "$currentValue",
                "${DateFormat('kk:mm:ss \n EEE d MMM').format(DateTime.now()).toString()}"
              ]);
              _getNewDataSet(currentValue);

              if (typeM == "O") {
                return Center(
                  child: Column(
                    children: <Widget>[
                      _tickMeasurement(context),
                      SizedBox(height: 50),
                      Text(
                        'Raw Message:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                            topLeft: Radius.circular(10),
                            bottomLeft: Radius.circular(10),
                          ),
                          color: Color(0XFF2c75fd),
                        ),
                        child: Text(
                          '${tempValue == null ? "Waiting for the data" : "$tempValue"}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      RaisedButton(
                        onPressed: () => _writeChar(services),
                        child: Text("Write Characteristic"),
                        color: Colors.deepPurple,
                        padding: EdgeInsets.all(10),
                      ),
                    ],
                  ),
                );
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _tickMeasurement(context),
                      SizedBox(height: 50),
                      new Container(
                        width: 300.0,
                        height: 200.0,
                        child: Column(
                          children: [
                            Expanded(
                                flex: 5,
                                child: LineAnimationZoomChart.withRandomData(
                                    baseData)),
                          ],
                        ),
                      ),
                      SizedBox(height: 30),
                      Text(
                        '$tempValue',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24),
                      )
                    ],
                  ),
                );
              }
            } else {
              return Center(
                child: Column(
                  children: <Widget>[
                    _tickMeasurement(context),
                    Text('Check the stream')
                  ],
                ),
              );
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = () => print("error");
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return Row(
                children: <Widget>[
                  FlatButton(
                    onPressed: onPressed,
                    child: Text(
                      text,
                      style: Theme.of(context)
                          .primaryTextTheme
                          .button
                          .copyWith(color: Colors.white),
                    ),
                  )
                ],
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 5,
            ),
            // StreamBuilder<int>(
            //   stream: device.mtu,
            //   initialData: 0,
            //   builder: (c, snapshot) => ListTile(
            //     title: Text('MTU Size'),
            //     subtitle: Text('${snapshot.data} bytes'),
            //     trailing: IconButton(
            //       icon: Icon(Icons.edit),
            //       onPressed: () => device.requestMtu(223),
            //     ),
            //   ),
            // ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return _myService(snapshot.data);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (typeM != "O")
              FloatingActionButton(
                child: Icon(Icons.cloud_upload),
                onPressed: () => postData("1",
                    tempValue.replaceAll(new RegExp('[^0-9.]'), ''), context),
              ),
          ],
        ),
      ),
    );
  }

  void postData(String sensorType, String value, BuildContext context) async {
    final http.Response response = await http
        .post(
          'http://sensor-dashboards.herokuapp.com/api/add-data/',
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'sensor_type': sensorType,
            'value': value,
          }),
        )
        .catchError(
            (onError) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Some Error occured'),
                  duration: const Duration(seconds: 1),
                  action: SnackBarAction(
                    label: 'ACTION',
                    onPressed: () {},
                  ),
                )));
    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Data Uploaded successully!'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'ACTION',
          onPressed: () {},
        ),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Some Error occured'),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'ACTION',
          onPressed: () {},
        ),
      ));
    }
  }

  void _setChat() {
    setState(() {
      typeM = "O";
    });
  }

  void _setPlot(String parameter) {
    setState(() {
      typeM = parameter;
      if (parameter.isNotEmpty) baseData = [];
    });
  }

  void _pushSaved(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final Iterable<ListTile> tiles = _saved.map(
            (List pair) {
              return ListTile(
                trailing: Text(
                  pair[1],
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pair[0],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          final List<Widget> divided = ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Saved Data'),
            ),
            body: ListView(children: divided),
            floatingActionButton: Container(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  FloatingActionButton(
                    child: Icon(Icons.cloud_download),
                    onPressed: () => _saveToFile(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveToFile() async {
    List<List<dynamic>> listOfLists = _saved.toList();
    String csv = ListToCsvConverter().convert(listOfLists);
    final directory = await getExternalStorageDirectory();
    final pathOfTheFileToWrite = directory.path + "/myCsvFile.csv";
    File file = File(pathOfTheFileToWrite);
    file.writeAsString(csv);
  }

  List<double> setDataSet(List<double> currentDataSet,
      List<double> previousDataSet, double newData) {
    currentDataSet.clear();
    currentDataSet.addAll(previousDataSet);
    currentDataSet.add(newData);
    if (currentDataSet.length >= sizeOfArray) {
      for (int i = 0; i <= currentDataSet.length - sizeOfArray; i++) {
        currentDataSet.removeAt(i);
      }
    }
    return currentDataSet;
  }

  void _getValue(String data, String parameter) {
    if (parameter == null) {
      parameter = "";
    }
    if (data.toUpperCase().startsWith(parameter.toUpperCase())) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      if ((data.isNotEmpty) && (data != null)) {
        var temp = double.parse(data);
        assert(temp is double);
        baseData.add(temp);
      }
    }
  }

  void _getNewDataSet(String data) {
    if (data.isEmpty) return;

    if (typeM == "O") {
      tempValue = data;
    } else {
      _getValue(data, typeM);
    }
  }

  void addStringToSF(String sfString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('stringValue', sfString);
  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  void _writeChar(List<BluetoothService> services) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Write"),
            content: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _writeController,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              FlatButton(
                child: Text("Send"),
                onPressed: () {
                  print("ok");
                  services.forEach((service) {
                    service.characteristics.forEach((character) {
                      if (character.uuid.toString() == CHARACTERISTIC_UUID) {
                        if (character.properties.write) {
                          character
                              .write(utf8.encode(_writeController.value.text));
                          Navigator.pop(context);
                        }
                      }
                    });
                  });
                },
              ),
              FlatButton(
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }
}
