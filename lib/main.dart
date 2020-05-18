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
    final random = new Random();
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
    return new charts.LineChart(seriesList, animate: animate, behaviors: [
      new charts.PanAndZoomBehavior(),
    ]);
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
      // theme: ThemeData(
      //     primarySwatch: Colors.lightBlue, brightness: Brightness.light),
      // themeMode: ThemeMode.dark,
      // darkTheme: ThemeData(brightness: Brightness.dark),
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

  Future<http.Response> postData(String sensorType, String value) {
    print("clicked");
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
                      child: Icon(Icons.cloud_upload),
                      onPressed: () => postData("3","466")),
                  SizedBox(
                    width: 5,
                  ),
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
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  static const String CHARACTERISTIC_UUID =
      // "be39a5dc-048b-4b8f-84cb-94c197edd26e";
      "00002a37-0000-1000-8000-00805f9b34fb";
  static const String WRITECHARACTERISTIC_UUID =
      "013dc1df-9b8c-4b5c-949b-262543eba78a";
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
    if (data.toLowerCase().startsWith('B')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      print(data);
      var temp = double.parse(data);
      assert(temp is double);
      baseData.add(temp);
    }
  }

  void getPressure(String data) {
    if (data.toLowerCase().startsWith('P') ||
        data.toLowerCase().startsWith('C')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      print(data);
      var temp = double.parse(data);
      assert(temp is double);
      baseData.add(temp);
    }
  }

  void getHumidity(String data) {
    if (data.toLowerCase().startsWith('W') ||
        data.toLowerCase().startsWith('H')) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      print(data);
      var temp = double.parse(data);
      assert(temp is double);
      baseData.add(temp);
    }
  }

  void getTemperature(String data) {
    if (data.toLowerCase().startsWith('T') ) {
      tempValue = data;
      data = data.replaceAll(new RegExp('[^0-9.]'), '');
      var temp = double.parse(data);
      assert(temp is double);
      baseData.add(temp);
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
      print(data);
    }
  }

  addStringToSF(String sfString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('stringValue', sfString);
  }

  String _dataParser(List<int> dataFromDevice) {
    // return utf8.decode(dataFromDevice);
    return utf8.decode(dataFromDevice);
  }

  Widget _tickMeasurement(BuildContext context) {
    void writeChar() async {
      List<BluetoothService> services = await device.discoverServices();
      services.forEach((service) {
        service.characteristics.forEach((character) {
          if (character.uuid.toString() == WRITECHARACTERISTIC_UUID) {
            character.write([0x01]);
          }
        });
      });
    }

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("T"), // needed
              child: Image.asset(
                "images/humidity.png",
                width: 40,
                color: Colors.black26,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("P"), // needed
              child: Icon(
                Icons.arrow_drop_down_circle,
                size: 40,
                color: Colors.black26,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("B"), // needed
              child: Icon(
                Icons.battery_alert,
                size: 40,
                color: Colors.black26,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _cleanData("H"), // needed
              child: Image.asset(
                "images/temperature.png",
                width: 40,
                color: Colors.black26,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "O", // needed
              child: Icon(
                Icons.text_fields,
                size: 40,
                color: Colors.black26,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => writeChar(), // needed
              child: Icon(
                Icons.lightbulb_outline,
                size: 40,
                color: Colors.black26,
              ),
            ),
          ),
          Material(
            // needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pushSaved(context), // needed
              child: Icon(
                Icons.list,
                size: 40,
                color: Colors.black26,
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
//            var tempValue;
              print(currentValue);
              _saved.add(
                  "$currentValue \n ${DateFormat('kk:mm:ss \n EEE d MMM').format(DateTime.now()).toString()}");
//            addStringToSF(currentValue);
              print(tempValue);
              _getNewDataSet(currentValue);

              if (typeM == "O") {
                return new Center(
                  child: Column(
                    children: <Widget>[
                      _tickMeasurement(context),
                      SizedBox(height: 50),
                      Text(
                        'Raw Message:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                      Text(
                        '$tempValue',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                );
              } else {
                return new Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _tickMeasurement(context),
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
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
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
    baseData = [0, 0];
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
            // Add 6 lines from here...
            appBar: AppBar(
              title: Text('Saved Data'),
            ),
            body: ListView(children: divided),
          ); // ... to here.
        },
      ),
    );
  }
}
