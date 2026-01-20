//
//  NFCNDEFDelegate.swift
//
//  Created by André Gonçalves on 13/04/2020.
//

import Foundation
import CoreNFC

@available(iOS 13.0, *)
class NFCNDEFWriterDelegate: NSObject, NFCNDEFReaderSessionDelegate {
    
    
    var session: NFCNDEFReaderSession?
    var completed: ([AnyHashable : Any]?, Error?) -> ()
    var ndefMessage: NSArray
    
    init(completed: @escaping ([AnyHashable: Any]?, Error?) -> (), alertMessage: String?, ndefMessage: NSArray) {
        self.completed = completed
        self.ndefMessage = ndefMessage;
        super.init()
        
        self.session = NFCNDEFReaderSession.init(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        if (self.session == nil) {
            self.completed(nil, "NFC is not available" as? Error);
            return
        }
        self.session!.alertMessage = alertMessage ?? ""
        self.session!.begin()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        /*if (self.textToWrite == ""){
            return;
        }*/
        // 1
       guard tags.count == 1 else {
           session.invalidate(errorMessage: "Can not write to more than one tag.")
           return
       }
       let currentTag = tags.first!
       
       // 2
       session.connect(to: currentTag) { error in
           
           guard error == nil else {
               session.invalidate(errorMessage: "Could not connect to tag.")
               return
           }
           
           // 3
           currentTag.queryNDEFStatus { status, capacity, error in
               
               guard error == nil else {
                   session.invalidate(errorMessage: "Could not query status of tag.")
                   return
               }
               
               switch status {
               case .notSupported: session.invalidate(errorMessage: "Tag is not supported.")
               case .readOnly:     session.invalidate(errorMessage: "Tag is only readable.")
               case .readWrite:

                // 2
                /*let textPayload = NFCNDEFPayload.wellKnownTypeTextPayload(
                    string: "no value passed",
                    locale: Locale.init(identifier: "en")
                )!*/
                var payloads = [NFCNDEFPayload]();
                
                for ndefMess in self.ndefMessage{
                    let payload = jsonToNdefRecords(ndefMessage: ndefMess as! NSDictionary);
                    payloads.append(payload);
                }
                
                let messge = NFCNDEFMessage.init(
                   records: payloads
               )
                
                /*let textPayload1 = NFCNDEFPayload.wellKnownTypeURIPayload(string: "https://github.com/agoncalvesos")
                let textPayload2 = NFCNDEFPayload.wellKnownTypeURIPayload(string: "https://github.com/chariotsolutions")
                
                let payload1 = NFCNDEFPayload.init(
                    format: NFCTypeNameFormat.nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data.init(count: 0),
                    payload: textPayload1!.payload,
                    chunkSize: 0
                )
                
                let payload2 = NFCNDEFPayload.init(
                    format: NFCTypeNameFormat.nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data.init(count: 0),
                    payload: textPayload2!.payload,
                    chunkSize: 0
                )
                
                let messge = NFCNDEFMessage.init(
                    records: [payload1, payload2]
                )*/
               // 4
                currentTag.writeNDEF(messge) { error in
                   
                    if error != nil {
                        self.completed(nil, error)
                        session.invalidate(errorMessage: "Failed to write message.")
                    } else {
                        self.completed(nil, nil)
                        session.alertMessage = "Successfully wrote data to tag!"
                        session.invalidate()
                    }
               }
                   
               @unknown default:   session.invalidate(errorMessage: "Unknown status of tag.")
               }
           }
       }
    }
    
    func readerSession(_: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        //do nothing
    }
    
    func readerSession(_: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        completed(nil, error)
    }
    
    func readerSessionDidBecomeActive(_: NFCNDEFReaderSession) {
        print("NDEF Reader session active")
    }
}