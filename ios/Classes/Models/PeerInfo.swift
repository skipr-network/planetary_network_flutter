//
//  PeerInfo.swift
//  Pods-Runner
//
//  Created by Robert Van Haecke on 11/04/2021.
//

import Foundation

enum Scheme {
    case tcp
    case tls
}

public class PeerInfo {
    var address: String
    var port: UInt16
    var ping: UInt64
    var scheme: Scheme
    
    init(scheme: Scheme, address: String, port: UInt16, ping: UInt64) {
        self.scheme = scheme
        self.address = address
        self.port = port
        self.ping = ping
    }
    
    func toString() -> String {
        return "\(scheme)://\(address):\(port)"
    }
}
