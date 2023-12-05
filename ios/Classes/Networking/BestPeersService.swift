import Foundation
import SwiftSocket

public class BestPeersResult {
    var isSuccessful: Bool
    var message: String?
    var peers: [PeerInfo]
    
    private init(isSuccessful: Bool, message: String?, peers: [PeerInfo]) {
        self.isSuccessful = isSuccessful
        self.message = message
        self.peers = peers
    }
    
    static func Error(message: String) -> BestPeersResult {
        return BestPeersResult(isSuccessful: false, message: message, peers: [PeerInfo]())
    }
    
    static func Success(peers: [PeerInfo]) -> BestPeersResult {
        return BestPeersResult(isSuccessful: true, message: nil, peers: peers)
    }
}

public class BestPeersService : NSObject {
    var peers = [PeerInfo]()
    
    public func GetBestPeers(completionHandler: (BestPeersResult) -> Void) -> Void {
        guard let url = URL(string: "https://jimber.io/peers.html") else {
            completionHandler(BestPeersResult.Error(message: "Invalid url"))
            return
        }
        
        do {
            let htmlData = try String(contentsOf: url, encoding: .ascii)
        
            let pattern = "((tcp|tls):\\/\\/(.*?))<\\/"
            let regex = try! NSRegularExpression(pattern: pattern)
            
            var fastPeers = 0
            
            regex.enumerateMatches(in: htmlData, options: [], range: NSRange(location: 0, length: htmlData.utf16.count)) { (result, _, stop) in
                guard let group = result?.range(at: 1), let range = Range(group, in: htmlData) else {
                    return
                }
            
                let fullAddress = String(htmlData[range])
                let scheme = fullAddress.contains("tls://") ? Scheme.tls : Scheme.tcp
                var split = fullAddress.components(separatedBy: ":")
                let port = Int32(split.popLast()!)!
                let address = split.joined(separator: ":")
                    .replacingOccurrences(of: "tls://", with: "")
                    .replacingOccurrences(of: "tcp://", with: "")
                                
                NSLog("Ping \(fullAddress)")
                
                let startTime = DispatchTime.now()
                let client = TCPClient(address: address, port: port)
                switch client.connect(timeout: 1) {
                    case .success:
                        let endTime = DispatchTime.now()
                        let ping = self.CalculateMillisecondsBetween(startTime, endTime)
                        
                        let peer = PeerInfo(scheme: scheme, address: client.address, port: UInt16(client.port), ping: ping)
                        
                        peers.append(peer)
                        
                        if (ping < 75) {
                            NSLog("Found fast host \(address)")
                            fastPeers += 1
                        }
                    case .failure:
                        NSLog("Ping failed for host \(address)")
                }
                
                if (fastPeers > 2) {
                    NSLog("Found 3 fast hosts (<75ms)");
                    stop.pointee = true
                }
            }
            
            peers.sort {
                $0.ping < $1.ping
            }
            
            completionHandler(BestPeersResult.Success(peers: peers))
        } catch {
            completionHandler(BestPeersResult.Error(message: error.localizedDescription))
        }
    }
    
    private func CalculateMillisecondsBetween(_ startTime: DispatchTime, _ endTime: DispatchTime) -> UInt64 {
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let timeInterval = nanoTime / 1_000_000
        
        return timeInterval
    }
}
