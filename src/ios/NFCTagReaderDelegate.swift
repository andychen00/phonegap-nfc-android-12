//
//  NFCNDEFReaderDelegate.swift
//
//  Created by André Gonçalves on 13/04/2020.
//

import Foundation
import CoreNFC

@available(iOS 13.0, *)
class NFCTagReaderDelegate: NSObject, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), alertMessage: String?) {
        self.completed = completed
        super.init()
        //iso14443 => detection for ISO 7816-compatible and MIFARE
        //iso15693 => detection for ISO 15693
        session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil )
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        session?.alertMessage = alertMessage ?? ""
        session?.begin()
    }
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print( "tagReaderSessionDidBecomeActive" )
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print( "tagReaderSession:didInvalidateWithError - \(error)" )
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        
        print( "tagReaderSession:didDectectTag" )
        guard let session = self.session else {
            return;
        }
        if tags.count > 1 {
            // Restart polling in 500 milliseconds.
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 Tap is detected. Please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        guard let tag = tags.first else {
            return;
        }
        
        session.connect(to: tag) { (error: Error?) in
            let defTag = self.getTagInstance(tag: tag);
            
            if (defTag != nil){
                defTag!.queryNDEFStatus { (status: NFCNDEFStatus, maxSize: Int, error: Error?) in
                    /*guard error == nil else {
                        session.invalidate(errorMessage: "Could not query status of tag.")
                        return
                    }*/
                    
                    defTag!.readNDEF { (message: NFCNDEFMessage?, error: Error?) in
                        //if (message != nil){
                        self.fireNdefEvent(message: self.prepareTag(tag: defTag!, message: message, isWritable: status == .readWrite, maxSize: maxSize))
                            self.session?.invalidate()
                        //}
                    }
                }
            }
        }
    }
    
    func prepareTag(tag: NFCNDEFTag, message: NFCNDEFMessage?, isWritable: Bool, maxSize: Int) -> [AnyHashable: Any] {
        let array = NSMutableArray()
        if (message != nil){
            for record in message!.records {
                let recordDictionary = message!.ndefToNSDictionary(record: record)
                array.add(recordDictionary)
            }
        }
        let wrapper = NSMutableDictionary()
        wrapper.setObject(array, forKey: "ndefMessage" as NSString)

        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue("ndef", forKey: "type")
        returnedJSON.setObject(getIdentifier(defTag: tag), forKey: "id" as NSString)
        returnedJSON.setValue(isWritable, forKey: "isWritable")
        returnedJSON.setValue(maxSize, forKey: "maxSize")
        returnedJSON.setObject(wrapper, forKey: "tag" as NSString)
        returnedJSON.setObject([self.getFamily(defTag: tag)], forKey: "techTypes" as NSString)
        return returnedJSON as! [AnyHashable : Any]
    }
    
    func fireNdefEvent(message: [AnyHashable: Any]) {
        completed(message, nil)
    }
    
    func getIdentifier(defTag: NFCNDEFTag) -> [UInt8]{
        if let defTagMiFare = defTag as? NFCMiFareTag {
            return [UInt8](defTagMiFare.identifier)
        } else if let defTagIso15693 = defTag as? NFCISO15693Tag {
            return [UInt8](defTagIso15693.identifier)
        } else if let defTagIso7816 = defTag as? NFCISO7816Tag {
            return [UInt8](defTagIso7816.identifier)
        }
        return [UInt8]();
    }
    
    //https://developer.apple.com/documentation/corenfc/nfcmifarefamily
    func getFamily(defTag: NFCNDEFTag) -> String{
        if let defTagMiFare = defTag as? NFCMiFareTag {
            if NFCMiFareFamily.unknown == defTagMiFare.mifareFamily {
                return "Type A"
            } else if NFCMiFareFamily.ultralight == defTagMiFare.mifareFamily {
                return "MIFARE Ultralight"
            } else if NFCMiFareFamily.plus == defTagMiFare.mifareFamily {
                return "MIFARE Plus"
            } else {
                return "MIFARE DESFire"
            }
        }
        return "";
    }
    
    func getTagInstance(tag: NFCTag) -> NFCNDEFTag?{
        if case let NFCTag.iso15693(ndefTag) = tag{
            return ndefTag;
        } else if case let NFCTag.iso7816(ndefTag) = tag{
            return ndefTag;
        } else if case let NFCTag.miFare(ndefTag) = tag{
            return ndefTag;
        }
        return nil;
    }
}