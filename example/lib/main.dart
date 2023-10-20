import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:yggdrasil_plugin/yggdrasil_plugin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TestPage());
  }
}

class TestPage extends StatelessWidget {
  String _platformVersion = 'Unknown';
  YggdrasilPlugin plugin = YggdrasilPlugin();
  late BuildContext _context;

  TestPage() {
    plugin.setOnReportIp(reportIp);
    initPlatformState();
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Scaffold(
      appBar: AppBar(title: Text("Test")),
      body: Container(
        child: Center(
          child: ElevatedButton(
            onPressed: () {
              testAlert(context);
            },
            child: Text("PressMe", style: TextStyle(color: Colors.white),),
          ),
        ),
      ),
    );
  }

  showAlertDialog(String message) {
    showDialog(
        context: _context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Your IP"),
            content: new Text(message),
            actions: [
              new TextButton(
                child: const Text("Ok"),
                onPressed: () {
                  Navigator.pop(_context);
                },
              ),
            ],
          );
        });
  }

  void reportIp(String ip) {
    print("EVEN IN THE UI FFS...");
    showAlertDialog(ip);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    platformVersion = await plugin.platformVersion();
  }

  void testAlert(BuildContext context) {
    plugin.startVpn({
      'signingPublicKey':
          'bca5b820f642861b7316aedb5572838a3fe8f5062c9a9469d6d3e179ae2ac478',
      'signingPrivateKey':
          'a407e6dadcd6ce7ac5193982fd9dab3b4f595e0f295547f4d04c66f6307e1247bca5b820f642861b7316aedb5572838a3fe8f5062c9a9469d6d3e179ae2ac478',
      'encryptionPublicKey':
          '4a247ad102b42a813fc03de92306a9fba1dcdf0ef08e166e7e91d0eca431c42c',
      'encryptionPrivateKey':
          'e8d3809b3d57e8a8472bb0f87a779e087e02d4034052a315976286f2ef45c261'
    });
    //   var alert = AlertDialog(
    //     title: Text("Test"),
    //     content: Text("Done..!"),
    //   );
    //
    //   showDialog(
    //       context: context,
    //       builder: (BuildContext context) {
    //         return alert;
    //       });
    // }
  }
}
