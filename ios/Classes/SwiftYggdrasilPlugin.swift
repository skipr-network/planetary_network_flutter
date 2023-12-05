import Flutter
import NetworkExtension
import Yggdrasil
import UIKit

enum ChannelName {
    static let methodChannel = "yggdrasil_plugin"
    static let eventChannel = "yggdrasil_plugin/events"
}

public class SwiftYggdrasilPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let vpnService: VpnService
    private var eventSink: FlutterEventSink?

    override init() {
        self.vpnService = VpnService()
        super.init()
        
        NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil, using: { notification in
            if let conn = notification.object as? NEVPNConnection {
                NSLog("Yggdrasil: ConnectionStatus \(conn.status.rawValue)")
                if (conn.status == .connected) {
                    NSLog("Yggdrasil: Connection made")
                    
                    self.vpnService.makeIPCRequests()
                }
            }
        })
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onYggdrasilSelfUpdated), name: NSNotification.Name.YggdrasilSelfUpdated, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onYggdrasilSelfIPUpdated), name: NSNotification.Name.YggdrasilSelfIPUpdated, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onYggdrasilPeersUpdated), name: NSNotification.Name.YggdrasilPeersUpdated, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onYggdrasilSettingsUpdated), name: NSNotification.Name.YggdrasilSettingsUpdated, object: nil)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: ChannelName.methodChannel, binaryMessenger: registrar.messenger())
        let instance = SwiftYggdrasilPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        
        let eventChannel = FlutterEventChannel(name: ChannelName.eventChannel, binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        if (call.method == "getPlatformVersion") {
            result("iOS " + UIDevice.current.systemVersion)
        } else if (call.method == "start_vpn") {
            guard let dictionary = call.arguments as? Dictionary<String, String>,
                  let keys = YggdrasilKeys.Create(dictionary: dictionary) else {
                result(false)
                return
            }
            
            startVpn(with: keys) { success in
                result(success)
            }
        } else if (call.method == "stop_vpn") {
            stopVpn()
            result(true);
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    private func sendIpAddressEvent() {
        guard let eventSink = eventSink else {
          return
        }

        eventSink(self.vpnService.yggdrasilSelfIP)
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
    
    private func startVpn(with keys: YggdrasilKeys, completionHandler:@escaping (Bool) -> Void) {
        
        if !vpnService.canStartVPNTunnel() {
            NSLog("Yggdrasil: Cannot start VPN tunnel")
            
            completionHandler(false)
            return
        }
        
        vpnService.initVPNConfiguration(with: keys) { result in
            if (!result) {
                NSLog("Yggdrasil: Could not init VPN configuration")
                
                completionHandler(false)
                return
            }
            
            NSLog("Yggdrasil: Start VPN tunnel")
            self.vpnService.startVpnTunnel() { result in
                completionHandler(result)
            }
        }
    }
    
    private func stopVpn() {
        NSLog("Yggdrasil: Stop VPN tunnel")
        self.vpnService.stopVpnTunnel()
    }
    
    func logYggdrasilData() {
        NSLog("IP Address: \(self.vpnService.yggdrasilSelfIP)")
        NSLog("Subnet: \(self.vpnService.yggdrasilSelfSubnet)")

        //var peer = String(data: try! JSONSerialization.data(withJSONObject: peer, options: .prettyPrinted), encoding: .utf8)!
    }
    
    @objc func onYggdrasilSelfUpdated(notification: NSNotification) {
        NSLog("Yggdrasil: Notification onYggdrasilSelfUpdated received")
        self.logYggdrasilData()
    }
    
    @objc func onYggdrasilSelfIPUpdated(notification: NSNotification) {
        NSLog("Yggdrasil: Notification onYggdrasilSelfIPUpdated received")
        self.logYggdrasilData()
        
        sendIpAddressEvent()
    }
    
    @objc func onYggdrasilPeersUpdated(notification: NSNotification) {
        NSLog("Yggdrasil: Notification onYggdrasilPeersUpdated received")
        self.logYggdrasilData()
    }
    
    @objc func onYggdrasilSwitchPeersUpdated(notification: NSNotification) {
        NSLog("Yggdrasil: Notification onYggdrasilSwitchPeersUpdated received")
        self.logYggdrasilData()
    }
    
    @objc func onYggdrasilSettingsUpdated(notification: NSNotification) {
        NSLog("Yggdrasil: Notification onYggdrasilSettingsUpdated received")
        self.logYggdrasilData()
    }
}
