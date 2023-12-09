//
//  VpnService.swift
//  yggdrasil_plugin
//
//  Created by Robert Van Haecke on 16/04/2021.
//

import Foundation
import NetworkExtension

class VpnService {
    var vpnManager: NETunnelProviderManager
    let bestPeersService: BestPeersService
    
    let yggdrasilComponent = "org.jimber.yggdrasil.extension"
    var yggdrasilConfig: ConfigurationProxy? = nil
    var yggdrasilAdminTimer: DispatchSourceTimer?
    var yggdrasilSelfIP: String = "N/A"
    var yggdrasilSelfSubnet: String = "N/A"
    var yggdrasilSelfCoords: String = "[]"
    var yggdrasilPeers: [[String: Any]] = [[:]]
    var yggdrasilSwitchPeers: [[String: Any]] = [[:]]
    var yggdrasilNodeInfo: [String: Any] = [:]

    init() {
        vpnManager = NETunnelProviderManager()
        bestPeersService = BestPeersService()
    }
    
    func initVPNConfiguration(with keys: YggdrasilKeys, completionHandler:@escaping (Bool) -> Void) {
        NSLog("Yggdrasil: initVPNConfiguration started!")

        self.loadPreferences {
                NSLog("Yggdrasil: Inside loadPreferences completion")

            self.getVPNConfiguration() { result, config in
                NSLog("Yggdrasil: getVPNConfiguration result ")

                if (!result) {
                    NSLog("Yggdrasil: result is NULL")
                    completionHandler(false)
                    return
                }
                
                guard let config = config else {
                    NSLog("Yggdrasil: Could not retrieve VPN configuration")
                    completionHandler(false)
                    return
                }
                
                config.set("SigningPublicKey", to: keys.signingPublicKey)
                config.set("SigningPrivateKey", to: keys.signingPrivateKey)
                config.set("EncryptionPublicKey", to: keys.encryptionPublicKey)
                config.set("EncryptionPrivateKey", to: keys.encryptionPrivateKey)
                
                self.saveConfiguration(config) { result in
                    /// loadPreferences must be called again after saving VPN configuration for the first time to avoid error: The operation couldn’t be completed. (NEVPNErrorDomain error 1.)
                    self.loadPreferences {
                        completionHandler(result)
                    }
                }
            }
        }
    }
    
    private func saveConfiguration(_ config: ConfigurationProxy, completionHandler:@escaping (Bool) -> Void) {
        
        self.yggdrasilConfig = config
        self.vpnManager.localizedDescription = "Yggdrasil"
        self.vpnManager.isEnabled = true
        
        do {
            try config.save(to: &self.vpnManager) { result in
                completionHandler(result)
            }
        } catch {
            completionHandler(false)
        }
    }
    
    private func loadPreferences(completionHandler:@escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { (savedManagers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                print(error)
            }
            
            if let savedManagers = savedManagers {
                for manager in savedManagers {
                    if (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.yggdrasilComponent {
                        print("Found saved VPN Manager")
                        self.vpnManager = manager
                    }
                }
            }
            
            self.vpnManager.loadFromPreferences(completionHandler: { (error: Error?) in
                if let error = error {
                    print(error)
                }
                
                completionHandler()
            })
        }
    }

    private func getVPNConfiguration(completionHandler: @escaping (Bool, ConfigurationProxy?) -> Void) {
    if let vpnConfig = self.vpnManager.protocolConfiguration as? NETunnelProviderProtocol,
        let confJson = vpnConfig.providerConfiguration?["json"] as? Data {
        
        NSLog("Yggdrasil: Found existing VPN configuration")
        
        self.getExistingVPNConfiguration(from: confJson) { result, yggdrasilConfig in
            if result {
                NSLog("Yggdrasil: Successfully retrieved existing VPN configuration")
            } else {
                NSLog("Yggdrasil: Failed to retrieve existing VPN configuration")
            }
            completionHandler(result, yggdrasilConfig)
        }
    } else {
        
        NSLog("Yggdrasil: Generating new VPN configuration")
        self.generateVPNConfiguration() { result, yggdrasilConfig in
            if result {
                NSLog("Yggdrasil: Successfully generated new VPN configuration")
            } else {
                NSLog("Yggdrasil: Failed to generate new VPN configuration")
            }
            completionHandler(result, yggdrasilConfig)
        }
    }
}


    
    // private func getVPNConfiguration(completionHandler:@escaping (Bool, ConfigurationProxy?) -> Void) {
    //     if let vpnConfig = self.vpnManager.protocolConfiguration as? NETunnelProviderProtocol,
    //         let confJson = vpnConfig.providerConfiguration!["json"] as? Data {
            
    //         NSLog("Yggdrasil: Found existing VPN configuration")
            
    //         self.getExistingVPNConfiguration(from: confJson) { result, yggdrasilConfig in
    //             completionHandler(result, yggdrasilConfig)
    //         }
    //     } else  {
            
    //         NSLog("Yggdrasil: Generating new VPN configuration")
    //         self.generateVPNConfiguration() { result, yggdrasilConfig in
    //             completionHandler(result, yggdrasilConfig)
    //         }
            
    //     }
    // }


    private func getExistingVPNConfiguration(from json: Data, completionHandler: @escaping (Bool, ConfigurationProxy?) -> Void) {
    do {
        let config = try ConfigurationProxy(json: json)

        NSLog("Yggdrasil: Clearing peers")
        config.clear(key: "Peers")

        self.addPeers(to: config) { result in
            if result {
                completionHandler(true, config)
            } else {
                NSLog("Yggdrasil: Failed to add peers to existing VPN configuration")
                completionHandler(false, nil)
            }
        }

    } catch {
        NSLog("Yggdrasil: Error parsing existing VPN configuration")
        completionHandler(false, nil)
    }
}

    
    // private func getExistingVPNConfiguration(from json: Data, completionHandler:@escaping (Bool, ConfigurationProxy?) -> Void) {
        
    //     do {
            
    //         let config = try ConfigurationProxy(json: json)
           
    //         NSLog("Yggdrasil: Clearing peers")
    //         config.clear(key: "Peers")
            
    //         self.addPeers(to: config) { result in
    //             completionHandler(result, config)
    //         }
            
    //     } catch {
    //         completionHandler(false, nil)
    //     }
    // }

    private func generateVPNConfiguration(completionHandler: @escaping (Bool, ConfigurationProxy?) -> Void) {
    let config = ConfigurationProxy()

    self.addPeers(to: config) { result in
        if result {
            completionHandler(true, config)
        } else {
            NSLog("Yggdrasil: Failed to generate new VPN configuration")
            completionHandler(false, nil)
        }
    }
}
    
    // private func generateVPNConfiguration(completionHandler:@escaping (Bool, ConfigurationProxy?) -> Void) {
    //     let config = ConfigurationProxy()
        
    //     self.addPeers(to: config) { result in
    //         completionHandler(result, config)
    //     }
    // }
    
    private func addPeers(to config: ConfigurationProxy, completionHandler:@escaping (Bool) -> Void) {
        self.bestPeersService.GetBestPeers() { bestPeersResult in
            
            if (!bestPeersResult.isSuccessful) {
                completionHandler(false)
                return
            }
                        
            for peer in bestPeersResult.peers.prefix(3) {
                NSLog("Yggdrasil: Adding peer \(peer.toString())")
                config.add(peer.toString(), in: "Peers")
            }
            
            completionHandler(true)
        }
    }
    
    func startVpnTunnel(completionHandler:@escaping (Bool) -> Void) {
        do {
            NSLog("Yggdrasil: Start VPN Tunnel")
            self.yggdrasilSelfIP = "N/A"
            
            try self.vpnManager.connection.startVPNTunnel()
            completionHandler(true)
        } catch {
            NSLog(error.localizedDescription)
            completionHandler(false)
        }
    }
    
    func stopVpnTunnel() {
        self.vpnManager.connection.stopVPNTunnel()
    }

   

// func makeIPCRequests() {
//     if self.vpnManager.connection.status != .connected {
        // NSLog("Yggdrasil: VPN connection is not connected.")
//         return
//     }

//     guard let session = self.vpnManager.connection as? NETunnelProviderSession else {
//         NSLog("Yggdrasil: VPN session is not available.")
//         return
//     }

//     // Function to handle errors and log messages
//     func handleProviderMessageError(_ message: String, _ error: Error?) {
//         if let error = error {
//             NSLog("Yggdrasil: Error sending '\(message)' provider message - \(error.localizedDescription)")
//         } else {
//             NSLog("Yggdrasil: Received '\(message)' data is nil or cannot be converted to string.")
//         }
//     }

//     NSLog("Yggdrasil: Sending provider message for address")
//     try? session.sendProviderMessage("address".data(using: .utf8)!) { (address, error) in
//         handleProviderMessageError("address", error)

//         guard let addressData = address, let addressString = String(data: addressData, encoding: .utf8) else {
//             return
//         }

//         NSLog("Yggdrasil: Received address: \(addressString)")

//         if self.yggdrasilSelfIP != addressString {
//             self.yggdrasilSelfIP = addressString
//             NotificationCenter.default.post(name: .YggdrasilSelfIPUpdated, object: nil)
//         }
//     }

//     NSLog("Yggdrasil: Sending provider message for subnet")
//     try? session.sendProviderMessage("subnet".data(using: .utf8)!) { (subnet, error) in
//         handleProviderMessageError("subnet", error)

//         guard let subnetData = subnet, let subnetString = String(data: subnetData, encoding: .utf8) else {
//             return
//         }

//         NSLog("Yggdrasil: Received subnet: \(subnetString)")

//         self.yggdrasilSelfSubnet = subnetString
//         NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
//     }

//     NSLog("Yggdrasil: Sending provider message for coords")
//     try? session.sendProviderMessage("coords".data(using: .utf8)!) { (coords, error) in
//         handleProviderMessageError("coords", error)

//         guard let coordsData = coords, let coordsString = String(data: coordsData, encoding: .utf8) else {
//             return
//         }

//         NSLog("Yggdrasil: Received coords: \(coordsString)")

//         self.yggdrasilSelfCoords = coordsString
//         NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
//     }

//     NSLog("Yggdrasil: Sending provider message for peers")
//     try? session.sendProviderMessage("peers".data(using: .utf8)!) { (peers, error) in
//         handleProviderMessageError("peers", error)

//         guard let peersData = peers, let parsedPeers = try? JSONSerialization.jsonObject(with: peersData, options: []) as? [[String: Any]] else {
//             return
//         }

//         NSLog("Yggdrasil: Received peers: \(parsedPeers)")

//         self.yggdrasilPeers = parsedPeers
//         NotificationCenter.default.post(name: .YggdrasilPeersUpdated, object: nil)
//     }
// }



    func makeIPCRequests() {
    if self.vpnManager.connection.status != .connected {
        NSLog("Yggdrasil: VPN connection is not connected.")
        return
    }

    if let session = self.vpnManager.connection as? NETunnelProviderSession {
        NSLog("Yggdrasil: Sending provider message for address")
        
        try? session.sendProviderMessage("address".data(using: .utf8)!) { (address) in
            let address = String(data: address!, encoding: .utf8)!
            NSLog("Yggdrasil: Received address: \(address)")

            if (self.yggdrasilSelfIP != address) {
                self.yggdrasilSelfIP = address
                NotificationCenter.default.post(name: .YggdrasilSelfIPUpdated, object: nil)
            }
        }

        NSLog("Yggdrasil: Sending provider message for subnet")
        try? session.sendProviderMessage("subnet".data(using: .utf8)!) { (subnet) in
            let subnet = String(data: subnet!, encoding: .utf8)!
            NSLog("Yggdrasil: Received subnet: \(subnet)")

            self.yggdrasilSelfSubnet = subnet
            NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
        }

        NSLog("Yggdrasil: Sending provider message for coords")
        try? session.sendProviderMessage("coords".data(using: .utf8)!) { (coords) in
            let coords = String(data: coords!, encoding: .utf8)!
            NSLog("Yggdrasil: Received coords: \(coords)")

            self.yggdrasilSelfCoords = coords
            NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
        }

        NSLog("Yggdrasil: Sending provider message for peers")
        try? session.sendProviderMessage("peers".data(using: .utf8)!) { (peers) in
            let peers = try? JSONSerialization.jsonObject(with: peers!, options: []) as? [[String: Any]] ?? []
            NSLog("Yggdrasil: Received peers: \(peers)")

            self.yggdrasilPeers = peers ?? []
            NotificationCenter.default.post(name: .YggdrasilPeersUpdated, object: nil)
        }
    }
}

    
    // func makeIPCRequests() {
    //     if self.vpnManager.connection.status != .connected {
    //         return
    //     }
    //     if let session = self.vpnManager.connection as? NETunnelProviderSession {
    //         try? session.sendProviderMessage("address".data(using: .utf8)!) { (address) in
                
    //             let address = String(data: address!, encoding: .utf8)!
    //             if (self.yggdrasilSelfIP != address) {
    //                 self.yggdrasilSelfIP = address
    //                 NotificationCenter.default.post(name: .YggdrasilSelfIPUpdated, object: nil)
    //             }
    //         }
    //         try? session.sendProviderMessage("subnet".data(using: .utf8)!) { (subnet) in
    //             self.yggdrasilSelfSubnet = String(data: subnet!, encoding: .utf8)!
    //             NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
    //         }
    //         try? session.sendProviderMessage("coords".data(using: .utf8)!) { (coords) in
    //             self.yggdrasilSelfCoords = String(data: coords!, encoding: .utf8)!
    //             NotificationCenter.default.post(name: .YggdrasilSelfUpdated, object: nil)
    //         }
    //         try? session.sendProviderMessage("peers".data(using: .utf8)!) { (peers) in
    //             if let jsonResponse = try? JSONSerialization.jsonObject(with: peers!, options: []) as? [[String: Any]] {
    //                 self.yggdrasilPeers = jsonResponse
    //                 NotificationCenter.default.post(name: .YggdrasilPeersUpdated, object: nil)
    //             }
    //         }
    //     }
    // }
    
    func canStartVPNTunnel() -> Bool {
        return self.vpnManager.connection.status == .disconnected ||             self.vpnManager.connection.status == .invalid
    }
}
