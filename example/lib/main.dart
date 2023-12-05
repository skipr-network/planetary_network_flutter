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
  BuildContext _context;

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
          child: new Row (
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            RaisedButton(
              color: Colors.redAccent,
              textColor: Colors.white,
              onPressed: () {
                startVPN(context);
              },
              child: Text("Start"),
            ),
            RaisedButton(
              color: Colors.redAccent,
              textColor: Colors.white,
              onPressed: () {
                stopVPN(context);
              },
              child: Text("Stop"),
            )
          ])
      ),
    );
  }

  showAlertDialog(String message) {
    showDialog(
      context: _context,
      builder: (_) => new AlertDialog(
        title: const Text("Your IP"),
        content: new Text(message),
        actions: [
          new FlatButton(
            child: const Text("Ok"),
            onPressed: () {
              Navigator.pop(_context);
            },
          ),
        ],
      ),
    );
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

  void startVPN(BuildContext context) async {
    await plugin.startVpn({
      'signingPublicKey': '620ed6d70c54fdf4accfdadef94a60091f791664566d7423fa4877a62bdc60cc',
      'signingPrivateKey': '760b5fbb02cfec5fd1899d943060957a17ba5a6383402b7e6c363bb6bcddd451620ed6d70c54fdf4accfdadef94a60091f791664566d7423fa4877a62bdc60cc', 
      'encryptionPublicKey': '36fc3adb1a3f0a1d62d8e721e37e66e59cbcc0ca347043e82c5ed248f72a6a04',
      'encryptionPrivateKey': 'f8cff6bb9ffdcf196dca5d7c9aebe97c2bcf6ca554e7110a9f9f597b9b2a7975'
    });
  }

  void stopVPN(BuildContext context) async {
    await plugin.stopVpn();
  }
}
