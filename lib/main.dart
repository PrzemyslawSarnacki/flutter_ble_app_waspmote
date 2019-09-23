import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_ble_app/widgets.dart';
import 'package:flutter_sparkline/flutter_sparkline.dart';

void main() {
  runApp(FlutterBlueApp());
}

class FlutterBlueApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
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
              'Bluetooth Adapter is ${state.toString().substring(15)}.',
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
        title: Text('Find Devices'),
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
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;

  static const String CHARACTERISTIC_UUID = "be39a5dc-048b-4b8f-84cb-94c197edd26e";
  static List<double> baseData = [0, 0];
  static List<double> dataSetA = <double>[];
  static List<double> dataSetB = <double>[];
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

  _getNewDataSet(String data) {
    if (data.isEmpty) return;
    
    if (typeM == "T") {
      if (data.startsWith('T') == true) {
        tempValue = data;
        data = data.substring(12,18);
        print(data);
        var temp = double.parse(data);
        assert(temp is double);

        if (switchDataSet) {
          baseData = setDataSet(dataSetB, dataSetA, temp);
        } else {
          baseData = setDataSet(dataSetA, dataSetB, temp);
        }
        switchDataSet = !switchDataSet;
      }
    }
    else if (typeM == "B"){
      if (data.startsWith('B') == true) {
        tempValue = data;
        data = data.substring(8,14);
        print(data);
        var temp = double.parse(data);
        assert(temp is double);

        if (switchDataSet) {
          baseData = setDataSet(dataSetB, dataSetA, temp);
        } else {
          baseData = setDataSet(dataSetA, dataSetB, temp);
        }
        switchDataSet = !switchDataSet;
      }
    } else if (typeM == "P"){
      if (data.startsWith('P') == true) {
        tempValue = data;
        data = data.substring(6,15);
        print(data);
        var temp = double.parse(data);
        assert(temp is double);

        if (switchDataSet) {
          baseData = setDataSet(dataSetB, dataSetA, temp);
        } else {
          baseData = setDataSet(dataSetA, dataSetB, temp);
        }
        switchDataSet = !switchDataSet;
      }
    } else if (typeM == "H"){
      if (data.startsWith('W') == true) {
        tempValue = data;
        data = data.substring(11,17);
        print(data);
        var temp = double.parse(data);
        assert(temp is double);

        if (switchDataSet) {
          baseData = setDataSet(dataSetB, dataSetA, temp);
        } else {
          baseData = setDataSet(dataSetA, dataSetB, temp);
        }
        switchDataSet = !switchDataSet;
      }
    }

  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  Widget _tickMeasurement(){
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Material(// needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "T", // needed
              child: Image.asset(
                "images/humidity.png",
                width: 40,
                color: Colors.red,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Material(// needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "P", // needed
              child: Icon(
                Icons.arrow_drop_down_circle,
                size: 40,
                color: Colors.red,
              ),
            ),
          ),
          Material(// needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "B", // needed
              child: Icon(
                Icons.battery_alert,
                size: 40,
                color: Colors.red,
              ),
            ),
          ),
          Material(// needed
            color: Colors.transparent,
            child: InkWell(
              onTap: () => typeM = "H", // needed
              child: Image.asset(
                "images/temperature.png",
                width: 40,
                color: Colors.red,
                fit: BoxFit.cover,
              ),
            ),
          )
        ],
      ),
    );


  }

  Widget _myService(List<BluetoothService> services){
    Stream<List<int>> stream;

    services.forEach((service){
      service.characteristics.forEach((character){
        if(character.uuid.toString() == CHARACTERISTIC_UUID){
          character.setNotifyValue(!character.isNotifying);
          stream = character.value;
        }
      });
    });


    return Container(
      child: StreamBuilder<List<int>>(stream: stream,
        builder: (BuildContext context, AsyncSnapshot<List<int>> snapshot){
          if (snapshot.hasError)
            return Text('Error : ${snapshot.error}');

          if (snapshot.connectionState == ConnectionState.active){

            var currentValue = _dataParser(snapshot.data);
//            var tempValue;
            print(currentValue);
            print(tempValue);
            _getNewDataSet(currentValue);


            return new Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _tickMeasurement(),
                  SizedBox(height: 50),
                  new Container(
                    width: 300.0,
                    height: 200.0,
                    child: new Sparkline(
                      data: baseData,
                      lineGradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        stops: [0.1, 0.5, 0.7, 0.9],
                        colors: [
                          Colors.indigo[100],
                          Colors.indigo[400],
                          Colors.indigo[600],
                          Colors.indigo[900]
                        ],
                      ),
                      lineWidth: 4,
                      fillMode: FillMode.none,
                      pointsMode: PointsMode.last,
                      pointSize: 10.0,
                      pointColor: Colors.red,
                      sharpCorners: false,
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    '$tempValue',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  )

                ],
              ),

            );

          } else {
            return Center(child: Column(
              children: <Widget>[
                _tickMeasurement(),
                Text('Check the stream')
              ],
            ),

            )
          ;
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
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        .copyWith(color: Colors.white),
                  ));
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
}

//class DisplayScreen extends StatelessWidget {
//
//  const DisplayScreen({Key key, this.device}) : super(key: key);
//
//  final BluetoothDevice device;
//  final String _temperature = "?";
//  final String _humidity = "?";
////  bool get isConnected => (device != null);
////
////  List<BluetoothService> services = new List();
////  Map<Guid, StreamSubscription> valueChangedSubscriptions = {};
////  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;
//
//  _TurnOnCharServ(){
//    services.forEach((service))
//
//  }
//
//  void TurnOnNotify() async {
//    //const String characteristic = "be39a5dc-048b-4b8f-84cb-94c197edd26e";
//
//    await device.connect();
//    List<BluetoothService> services = await device.discoverServices();
//    services.forEach((service) async {
//      var characteristics = service.characteristics;
//      for(BluetoothCharacteristic characteristic in characteristics) {
//        await characteristic.setNotifyValue(true);
//        characteristic.value.listen((value) {
//          // do something with new
//        });
//      }
//      // do something with service
//    });
//
//
//
//
//  }
//  @override
//  void initState(){
//    TurnOnNotify();
//  }
//
//
//  @override
//  Widget build(BuildContext context) {
//    return Center(
//      child: Row(
//        mainAxisAlignment: MainAxisAlignment.center,
//        crossAxisAlignment: CrossAxisAlignment.center,
//        children: <Widget>[
//          Card(
//            child: Container(
//              width: 150,
//              height: 200,
//              child: Column(
//                crossAxisAlignment: CrossAxisAlignment.center,
//                children: <Widget>[
//                  SizedBox(
//                    height: 10,
//                  ),
//                  Container(
//                    width: 100,
//                    height: 100,
//                    child: Image.asset('images/temperature.png'),
//                  ),
//                  SizedBox(
//                    height: 10,
//                  ),
//                  Text(
//                    "Temperature",
//                    style: TextStyle(fontWeight: FontWeight.bold),
//                  ),
//                  Expanded(
//                    child: Container(),
//                  ),
//                  Text(
//                    _temperature,
//                    style: TextStyle(fontSize: 30),
//                  ),
//                  SizedBox(
//                    height: 10,
//                  ),
//                ],
//              ),
//            ),
//          ),
//          Card(
//            child: Container(
//              width: 150,
//              height: 200,
//              child: Column(
//                crossAxisAlignment: CrossAxisAlignment.center,
//                children: <Widget>[
//                  SizedBox(
//                    height: 10,
//                  ),
//                  Container(
//                    width: 100,
//                    height: 100,
//                    child: Image.asset('images/humidity.png'),
//                  ),
//                  SizedBox(
//                    height: 10,
//                  ),
//                  Text(
//                    "Humidity",
//                    style: TextStyle(fontWeight: FontWeight.bold),
//                  ),
//                  Expanded(
//                    child: Container(),
//                  ),
//                  Text(
//                    _humidity,
//                    style: TextStyle(fontSize: 30),
//                  ),
//                  SizedBox(
//                    height: 10,
//                  ),
//                ],
//              ),
//            ),
//          )
//        ],
//      ),
//    );
//  }
//
////  _DataParser(String data) {
////    if (data.isNotEmpty) {
////      var tempValue = data.split(",")[0];
////      var humidityValue = data.split(",")[1];
////
////      print("tempValue: ${tempValue}");
////      print("humidityValue: ${humidityValue}");
////
////      setState(() {
////        _temperature = tempValue + "'C";
////        _humidity = humidityValue + "%";
////      });
////    }
////  }
//
////  _setNotification(BluetoothCharacteristic c) async {
////    if (c.isNotifying) {
////      await device.setNotifyValue(c, false);
////      // Cancel subscription
////      valueChangedSubscriptions[c.uuid]?.cancel();
////      valueChangedSubscriptions.remove(c.uuid);
////    } else {
////      await device.setNotifyValue(c, true);
////      // ignore: cancel_subscriptions
////      final sub = device.onValueChanged(c).listen((d) {
////        final decoded = utf8.decode(d);
////        _DataParser(decoded);
////
//////        setState(() {
//////          print('onValueChanged $d');
//////        });
////      });
////      // Add to map
////      valueChangedSubscriptions[c.uuid] = sub;
////    }
////    setState(() {});
////  }
//
//}

