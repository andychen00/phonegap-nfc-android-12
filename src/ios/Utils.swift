//
//  Utils.swift
//
//  Created by André Gonçalves on 13/04/2020.
//

import Foundation
import CoreNFC

extension NFCNDEFMessage {
    func ndefMessageToJSON() -> [AnyHashable: Any] {
        let array = NSMutableArray()
        for record in self.records {
            let recordDictionary = self.ndefToNSDictionary(record: record)
            array.add(recordDictionary)
        }
        let wrapper = NSMutableDictionary()
        wrapper.setObject(array, forKey: "ndefMessage" as NSString)
        
        let returnedJSON = NSMutableDictionary()
        returnedJSON.setValue("ndef", forKey: "type")
        returnedJSON.setObject(wrapper, forKey: "tag" as NSString)

        return returnedJSON as! [AnyHashable : Any]
    }
    
    func ndefToNSDictionary(record: NFCNDEFPayload) -> NSDictionary {
        let dict = NSMutableDictionary()
        dict.setObject(record.typeNameFormat.rawValue, forKey: "tnf" as NSString)
        dict.setObject([UInt8](record.type), forKey: "type" as NSString)
        dict.setObject([UInt8](record.identifier), forKey: "id" as NSString)
        dict.setObject([UInt8](record.payload), forKey: "payload" as NSString)
        
        return dict
    }
}

@available(iOS 13.0, *)
func jsonToNdefRecords(ndefMessage: NSDictionary) -> NFCNDEFPayload{
    //let id = ndefMessage.object(forKey: "id")
    let tnf = ndefMessage.object(forKey: "tnf") as! UInt8
    
    let payload = ndefMessage.object(forKey: "payload") as! NSArray
    let dataPayload = Data.init(payload as! [UInt8])
    
    let type = ndefMessage.object(forKey: "type") as! NSArray
    let dataType = Data.init(bytes: type as! [UInt8])
    
    let message = NFCNDEFPayload.init(
        format: NFCTypeNameFormat.init(rawValue: tnf)!,
        type: dataType,
        identifier: Data.init(count: 0),
        payload: dataPayload,
        chunkSize: 0)
    
    return message;
}