//
//  ISO14443.swift
//  Modified for e-money support
//

import Foundation
import CoreNFC

@available(iOS 13.0, *)
class ISO14443: NSObject, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    var currentTag: NFCTag? // TAMBAH INI
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), message: String?) {
        self.completed = completed
        super.init()
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil )
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        session?.alertMessage = message ?? ""
        session?.begin()
    }
    
    // TAMBAH FUNGSI INI UNTUK E-MONEY
    func sendAPDU(apduHex: String, completion: @escaping (String?, Error?) -> Void) {
        guard let tag = currentTag else {
            completion(nil, "No tag connected" as? Error)
            return
        }
        
        // Convert hex string to Data
        let apduData = hexStringToData(apduHex)
        
        switch tag {
        case .iso7816(let iso7816Tag):
            // UNTUK E-MONEY (ISO 7816)
            let apdu = NFCISO7816APDU(data: apduData)
            iso7816Tag.sendCommand(apduCommand: apdu) { (data, sw1, sw2, error) in
                if let error = error {
                    completion(nil, error)
                } else {
                    var response = data ?? Data()
                    response.append(sw1)
                    response.append(sw2)
                    completion(dataToHexString(response), nil)
                }
            }
            
        case .miFare(let miFareTag):
            // Untuk MIFARE (opsional)
            completion(nil, "MIFARE not supported for APDU" as? Error)
            
        default:
            completion(nil, "Tag type not supported" as? Error)
        }
    }
    
    // MODIFIKASI FUNGSI didDetect
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print( "tagReaderSession:didDetectTag" )
        
        if tags.count > 1 {
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 card detected."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        guard let tag = tags.first else {
            return
        }
        
        session.connect(to: tag) { (error: Error?) in
            if let error = error {
                self.completed(nil, error)
                return
            }
            
            // SIMPAN TAG YANG TERCONNECT
            self.currentTag = tag
            
            // Untuk e-money, langsung return tag info (tanpa baca NDEF)
            let tagInfo = self.getTagInfo(tag: tag)
            self.completed(tagInfo, nil)
        }
    }
    
    // FUNGSI BARU: Get tag info
    func getTagInfo(tag: NFCTag) -> [AnyHashable: Any] {
        var info: [String: Any] = [:]
        info["connected"] = true
    
        switch tag {
        case .iso7816(let iso7816Tag):
            info["type"] = "iso7816"
            info["id"] = [UInt8](iso7816Tag.identifier)
            
        case .miFare(let miFareTag):
            info["type"] = "mifare"
            info["id"] = [UInt8](miFareTag.identifier)
            
        default:
            info["type"] = "unknown"
        }
    
        // FIX: Convert properly
        var result: [AnyHashable: Any] = [:]
        for (key, value) in info {
            result[key] = value
        }
        return result
    }
    
    // Helper functions
    private func hexStringToData(_ hex: String) -> Data {
        var hex = hex
        hex = hex.replacingOccurrences(of: " ", with: "")
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }
    
    private func dataToHexString(_ data: Data) -> String {
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // Biarkan fungsi lainnya TANPA PERUBAHAN
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print( "tagReaderSessionDidBecomeActive" )
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print( "tagReaderSession:didInvalidateWithError - \(error)" )
    }
    
    func fireNdefEvent(message: [AnyHashable: Any]) {
        completed(message, nil)
    }
}