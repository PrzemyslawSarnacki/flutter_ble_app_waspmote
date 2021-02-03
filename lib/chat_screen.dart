import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_ble_app/flat_widgets/flat_action_btn.dart';
import 'package:flutter_ble_app/flat_widgets/flat_chat_message.dart';
import 'package:flutter_ble_app/flat_widgets/flat_message_input_box.dart';
import 'package:flutter_ble_app/flat_widgets/flat_page_header.dart';
import 'package:flutter_ble_app/flat_widgets/flat_page_wrapper.dart';
import 'package:flutter_ble_app/widgets.dart';
import 'package:flutter_ble_app/main.dart';
import 'package:flutter_blue/flutter_blue.dart';

class ChatScreen extends StatefulWidget {
  final BluetoothDevice device;
  final List<BluetoothService> services;
  const ChatScreen(this.device, this.services);

  @override
  _ChatScreenState createState() => _ChatScreenState(device, services);
}

class _ChatScreenState extends State<ChatScreen> {
  BluetoothDevice device;
  List<BluetoothService> services;
  _ChatScreenState(this.device, this.services); //constructor
  List<FlatChatMessage> messageList = [];
  TextEditingController _writerController = TextEditingController();
  Stream<List<int>> stream;

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  void _addNewMessage(String message) {
    setState(() {
      messageList.add(FlatChatMessage(
        message: message,
        messageType: MessageType.received,
        showTime: false,
        time: "",
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    services.forEach((service) {
      service.characteristics.forEach((character) {
        if (character.uuid.toString() == DeviceScreen.CHARACTERISTIC_UUID) {
          character.setNotifyValue(!character.isNotifying);
          stream = character.value;
        }
      });
    });

    return Scaffold(
      body: FlatPageWrapper(
        scrollType: ScrollType.floatingHeader,
        reverseBodyList: false,
        header: FlatPageHeader(
          prefixWidget: FlatActionButton(
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: "Read/Write",
          suffixWidget: Text(""),
        ),
        children: <Widget>[
          StreamBuilder<List<int>>(
              stream: stream,
              builder:
                  (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
                if (snapshot.hasError) return Text('Error : ${snapshot.error}');

                if (snapshot.connectionState == ConnectionState.active) {
                  var currentValue = _dataParser(snapshot.data);
                  _addNewMessage(currentValue);
                  return Container(
                      child: Column(
                    children: [...messageList],
                  ));
                }
              }),
        ],
        footer: FlatMessageInputBox(
          roundedCorners: true,
          controller: _writerController,
          onPressed: () {
            print(_writerController.value.text);
            setState(() {
              messageList.add(FlatChatMessage(
                message: _writerController.value.text,
                messageType: MessageType.sent,
                showTime: false,
                time: "",
              ));
            });
            services.forEach((service) {
              service.characteristics.forEach((character) {
                if (character.uuid.toString() ==
                    DeviceScreen.CHARACTERISTIC_UUID) print(character.read());
              });
            });

            //       if (character.properties.write) {
            //         character
            //             .write(utf8.encode(_writeController.value.text));
            //         Navigator.pop(context);
            //       }
            //     }
            //   });
            // });
          },
        ),
      ),
    );
  }
}
