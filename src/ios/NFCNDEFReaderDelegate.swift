//
//  NFCNDEFReaderDelegate.swift
//
//  Created by André Gonçalves on 13/04/2020.
//

import Foundation
import CoreNFC

class NFCNDEFReaderDelegate: NSObject, NFCNDEFReaderSessionDelegate {
    var session: NFCNDEFReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), message: String?) {
        self.completed = completed
        super.init()
        
        self.session = NFCNDEFReaderSession.init(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        self.session!.alertMessage = message ?? ""
        self.session!.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            self.fireNdefEvent(message: message)
        }
        self.session?.invalidate()
    }
    
    func readerSession(_: NFCNDEFReaderSession, didInvalidateWithError _: Error) {
        completed(nil, "NFCNDEFReaderSession error" as? Error)
    }
    
    func readerSessionDidBecomeActive(_: NFCNDEFReaderSession) {
        print("NDEF Reader session active")
    }
    
    func fireNdefEvent(message: NFCNDEFMessage) {
        let response = message.ndefMessageToJSON()
        completed(response, nil)
    }
}