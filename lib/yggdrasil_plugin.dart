
import 'dart:async';

import 'package:flutter/services.dart';

typedef void onReportIpFnc(String ip);

class YggdrasilPlugin {

  MethodChannel _channel =  const MethodChannel('yggdrasil_plugin');
  late onReportIpFnc _reportFnc;
  static final YggdrasilPlugin _singleton = YggdrasilPlugin._internal();

  init(){
    _singleton._channel.setMethodCallHandler(_onCall);
  }

  factory YggdrasilPlugin() {
    _singleton.init();
    return _singleton;
  }

  YggdrasilPlugin._internal();


  void setOnReportIp(onReportIpFnc fnc){
    _reportFnc = fnc;
  }

  Future<void> _onCall(MethodCall call) async {
    switch(call.method) {
      case "reportIp":
        final String ipAddress = call.arguments;
        _reportFnc(ipAddress);
    }
  }

  Future<String> platformVersion() async {

    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  Future<bool> startVpn(Map<String, String> keys) async {
    final dynamic result = await _channel.invokeMethod('start_vpn',keys);
    
  
    final bool boolResult = result as bool;
    return boolResult; //@todo notation

  }
  Future<void> stopVpn() async {
     await _channel.invokeMethod('stop_vpn'); //@todo notation

  }
}
