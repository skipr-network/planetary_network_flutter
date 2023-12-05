//
//  YggdrasilKeys.swift
//  yggdrasil_plugin
//
//  Created by Robert Van Haecke on 24/04/2021.
//

import Foundation

struct YggdrasilKeys {
    let signingPublicKey: String
    let signingPrivateKey: String
    let encryptionPublicKey: String
    let encryptionPrivateKey: String
    
    private init(_ signingPublicKey: String, _ signingPrivateKey: String, _ encryptionPublicKey: String, _ encryptionPrivateKey: String) {
        self.signingPublicKey = signingPublicKey
        self.signingPrivateKey = signingPrivateKey
        self.encryptionPublicKey = encryptionPublicKey
        self.encryptionPrivateKey = encryptionPrivateKey
    }
    
    static func Create(dictionary: [String: String]) -> YggdrasilKeys? {
        guard let signingPublicKey = dictionary["signingPublicKey"],
              let signingPrivateKey = dictionary["signingPrivateKey"],
              let encryptionPublicKey = dictionary["encryptionPublicKey"],
              let encryptionPrivateKey = dictionary["encryptionPrivateKey"] else {
            return nil
        }
        
        return YggdrasilKeys(signingPublicKey, signingPrivateKey, encryptionPublicKey, encryptionPrivateKey)
    }
}
