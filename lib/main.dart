import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_ble_app/widgets.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() {
  runApp(FlutterBlueApp());
}

class LineAnimationZoomChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  LineAnimationZoomChart(this.seriesList, {this.animate});

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
        id: 'Sales',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.year,
        measureFn: (LinearSales sales, _) => sales.sales,
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
  final int year;
  final double sales;

  LinearSales(this.year, this.sales);
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
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
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
                  .subhead
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
                                                DeviceScreen(device: d))),
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
                            return DeviceScreen(device: r.device);
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

class DeviceScreen extends StatelessWidget {
  Future<http.Response> postData(String sensorType, String value) {
    return http.post(
      'http://sensor-dashboards.herokuapp.com/api/add-data/',
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'sensor_type': sensorType,
        'value': value,
      }),
    );
  }

  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

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
  static Set<String> _saved = Set<String>(); // Add this line.
  static bool switchDataSet = false;
  final int sizeOfArray = 10;
  static var tempValue;
  static var typeM;

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

  void getBattery(String data) {
    if (data.toUpperCase().startsWith('B')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      if (data.isNotEmpty) {
        var temp = double.parse(data);
        assert(temp is double);
        baseData.add(temp);
      }
    }
  }

  void getPressure(String data) {
    if (data.toUpperCase().startsWith('P') ||
        data.toUpperCase().startsWith('C')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      if (data.isNotEmpty) {
        var temp = double.parse(data);
        assert(temp is double);
        baseData.add(temp);
      }
    }
  }

  void getHumidity(String data) {
    if (data.toUpperCase().startsWith('W') ||
        data.toUpperCase().startsWith('H')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      if (data.isNotEmpty) {
        var temp = double.parse(data);
        assert(temp is double);
        baseData.add(temp);
      }
    }
  }

  void getTemperature(String data) {
    if (data.toUpperCase().startsWith('T')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      if (data.isNotEmpty) {
        var temp = double.parse(data);
        assert(temp is double);
        baseData.add(temp);
      }
    }
  }

  _getNewDataSet(String data) {
    if (data.isEmpty) return;

    if (typeM == "T") {
      getTemperature(data);
    } else if (typeM == "B") {
      getBattery(data);
    } else if (typeM == "P") {
      getPressure(data);
    } else if (typeM == "H") {
      getHumidity(data);
    } else if (typeM == "O") {
      tempValue = data;
    }
  }

  addStringToSF(String sfString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('stringValue', sfString);
  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  Widget _tickMeasurement(
      BuildContext context, List<BluetoothService> services) {
    final _writeController = TextEditingController();

    void _writeChar() async {
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
                        if (character.uuid.toString() ==
                            WRITECHARACTERISTIC_UUID) {
                          if (character.properties.write) {
                            character.write(
                                utf8.encode(_writeController.value.text));
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

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("T"),
              child: Image.asset(
                "images/humidity.png",
                width: 40,
                color: Colors.white70,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("P"),
              child: Icon(
                Icons.arrow_drop_down_circle,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("B"),
              child: Icon(
                Icons.battery_alert,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("H"),
              child: Image.asset(
                "images/temperature.png",
                width: 40,
                color: Colors.white70,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "O",
              child: Icon(
                Icons.text_fields,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _writeChar(),
              child: Icon(
                Icons.lightbulb_outline,
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
              _saved.add(
                  "$currentValue \n ${DateFormat('kk:mm:ss \n EEE d MMM').format(DateTime.now()).toString()}");
              _getNewDataSet(currentValue);

              if (typeM == "O") {
                return new Center(
                  child: Column(
                    children: <Widget>[
                      _tickMeasurement(context, services),
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
                          "$tempValue",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return new Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _tickMeasurement(context, services),
                      SizedBox(height: 50),
                      new Container(
                        width: 300.0,
                        height: 200.0,
                        child: Expanded(
                            flex: 5,
                            child: LineAnimationZoomChart.withRandomData(
                                baseData)),
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
                    _tickMeasurement(context, services),
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
                  print("error");
                  onPressed = null;
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
            FloatingActionButton(
                child: Icon(Icons.cloud_upload),
                onPressed: () => postData(
                    tempValue.replaceAll(new RegExp('[^0-9.]'), ''), "466")),
          ],
        ),
      ),
    );
  }

  void _cleanData(String parameter) {
    if (parameter == "O") {
      typeM = "O";
    } else if (parameter == "T") {
      typeM = "T";
    } else if (parameter == "P") {
      typeM = "P";
    } else if (parameter == "H") {
      typeM = "H";
    } else if (parameter == "B") {
      typeM = "B";
    }
    baseData = [];
  }

  void _pushSaved(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final Iterable<ListTile> tiles = _saved.map(
            (String pair) {
              return ListTile(
                title: Text(
                  pair,
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                  ),
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
          );
        },
      ),
    );
  }
}
