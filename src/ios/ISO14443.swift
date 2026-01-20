//
//  NFCNDEFReaderDelegate.swift

//  Created by André Gonçalves on 14/04/2020.
//

import Foundation
import CoreNFC

@available(iOS 13.0, *)
class ISO14443: NSObject, NFCTagReaderSessionDelegate {
    var session: NFCTagReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), message: String?) {
        self.completed = completed
        super.init()
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil )
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        session?.alertMessage = ""
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
            if case let NFCTag.miFare(tag) = tags.first! {
                tag.queryNDEFStatus { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                    guard error == nil else {
                        session.invalidate(errorMessage: "Could not query status of tag.")
                        return
                    }
                    
                    tag.readNDEF { (message: NFCNDEFMessage?, error: Error?) in
                        if (message != nil){
                            self.fireNdefEvent(message: self.prepareTag(tag: tag, message: message!, isWritable: status == .readWrite))
                            self.session?.invalidate()
                        }
                    }
                }
            }
        }
    }
    
    func prepareTag(tag: NFCMiFareTag, message: NFCNDEFMessage, isWritable: Bool) -> [AnyHashable: Any] {
        let array = NSMutableArray()
        for record in message.records {
            let recordDictionary = message.ndefToNSDictionary(record: record)
            array.add(recordDictionary)
        }
        let wrapper = NSMutableDictionary()
        wrapper.setObject(array, forKey: "ndefMessage" as NSString)

        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue("ndef", forKey: "type")
        returnedJSON.setObject([UInt8](tag.identifier), forKey: "id" as NSString)
        returnedJSON.setValue(isWritable, forKey: "isWritable")
        returnedJSON.setObject(wrapper, forKey: "tag" as NSString)

        return returnedJSON as! [AnyHashable : Any]
    }
    
    func fireNdefEvent(message: [AnyHashable: Any]) {
        completed(message, nil)
    }
}