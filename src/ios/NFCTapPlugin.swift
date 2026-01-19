//
//  NFCTapPlugin.swift
//
//  Created by André Gonçalves on 13/04/2020.
//

import Foundation
import UIKit
import CoreNFC

// Main class handling the plugin functionalities.
@objc(NfcPlugin) class NfcPlugin: CDVPlugin {
    var nfcController: NSObject? // ST25DVReader downCast as NSObject for iOS version compatibility
    var nfcTagReaderController: NSObject? // NFCTagReader downCast as NSObject for iOS version compatibility - Used to read tags on iOS >= 13
    var ndefReaderController: NFCNDEFReaderDelegate? //Used to read NDEF messages on iOS < 13
    var ndefWriterController: NSObject? //Used to write tags
    var lastError: Error?
    var channelCommand: CDVInvokedUrlCommand?
    var isListeningNDEF = false
    var iso14443Reader: ISO14443?

    // helper to return a string
    func sendSuccess(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to return a boolean
    private func sendSuccess(command: CDVInvokedUrlCommand, result: Bool) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to return a String with keeping the callback
    func sendSuccessWithResponse(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: result
        )
        pluginResult!.setKeepCallbackAs(true)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    // helper to send back an error
    func sendError(command: CDVInvokedUrlCommand, result: String) {
        let pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR,
            messageAs: result
        )
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(connect:)
    func connect(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "connect is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            print("Begin session \(self.nfcController)")
            if self.nfcController == nil {
                self.nfcController = ST25DVReader()
            }

            (self.nfcController as! ST25DVReader).initSession(alertMessage: "Bring your phone close to the Tap.", completed: {
                (error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        self.sendSuccess(command: command, result: "")
                    }
                }
            })
        }
    }

    @objc(close:)
    func close(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "close is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session to terminate")
                return
            }

            (self.nfcController as! ST25DVReader).invalidateSession(message: "Sesssion Ended!")
            self.nfcController = nil
        }
    }

    @objc(transceive:)
    func transceive(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "transceive is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            print("sending ...")
            if self.nfcController == nil {
                self.sendError(command: command, result: "no session available")
                return
            }

            // we need data to send
            if command.arguments.count <= 0 {
                self.sendError(command: command, result: "SendRequest parameter error")
                return
            }

            guard let data: NSData = command.arguments[0] as? NSData else {
                self.sendError(command: command, result: "Tried to transceive empty string")
                return
            }
            let request = data.map { String(format: "%02x", $0) }
                .joined()
            print("send request  - \(request)")

            (self.nfcController as! ST25DVReader).send(request: request, completed: {
                (response: Data?, error: Error?) -> Void in

                DispatchQueue.main.async {
                    if error != nil {
                        self.lastError = error
                        self.sendError(command: command, result: error!.localizedDescription)
                    } else {
                        print("responded \(response!.hexEncodedString())")
                        self.sendSuccess(command: command, result: response!.hexEncodedString())
                    }
                }
            })
        }
    }

    @objc(connect:)
    func connect(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "iOS 13+ required")
            return
        }
        
        DispatchQueue.main.async {
            let message = command.arguments.first as? String ?? "Hold e-money card"
            
            self.iso14443Reader = ISO14443(completed: { (response, error) in
                if let error = error {
                    self.sendError(command: command, result: error.localizedDescription)
                } else {
                    self.sendSuccess(command: command, result: response ?? [:])
                }
            }, message: message)
        }
    }
    
    @objc(transceive:)
    func transceive(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "iOS 13+ required")
            return
        }
        
        guard let apduHex = command.arguments.first as? String else {
            sendError(command: command, result: "APDU hex required")
            return
        }
        
        guard let reader = self.iso14443Reader else {
            sendError(command: command, result: "Not connected to tag")
            return
        }
        
        reader.sendAPDU(apduHex: apduHex) { (response, error) in
            if let error = error {
                self.sendError(command: command, result: error.localizedDescription)
            } else {
                self.sendSuccess(command: command, result: response ?? "")
            }
        }
    }
    
    @objc(close:)
    func close(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            self.iso14443Reader?.session?.invalidate()
            self.iso14443Reader = nil
            self.sendSuccess(command: command, result: "Disconnected")
        }
    }

    // TAMBAH INI DI CLASS:

    @objc(connectIOS:)
    func connectIOS(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {    
        sendError(command: command, result: "iOS 13+ required")
        return
        }
    
        let message = command.arguments.first as? String ?? "Hold near card"
    
        DispatchQueue.main.async {
            print("iOS: Starting NFC session")
        
            self.iso14443Reader = ISO14443(
                completed: { (tagInfo, error) in
                    if let error = error {  
                    self.sendError(command: command, result: error.localizedDescription)
                    } else {
                        // Kirim tag info ke JavaScript
                        self.sendSuccess(command: command, result: tagInfo ?? [:])
                    }
                },
                message: message
            )
        }
    }

    @objc(sendAPDUIOS:)
    func sendAPDUIOS(command: CDVInvokedUrlCommand) {
        guard #available(iOS 13.0, *) else {
            sendError(command: command, result: "iOS 13+ required")
            return
        }
    
        guard let apduHex = command.arguments.first as? String else {
        sendError(command: command, result: "APDU hex required")
        return
        }
    
        guard let reader = self.iso14443Reader else {
        sendError(command: command, result: "Not connected to tag")
        return
        }
    
        reader.sendAPDU(apduHex: apduHex) { (response, error) in
        if let error = error {
            self.sendError(command: command, result: error.localizedDescription)
        } else {
            self.sendSuccess(command: command, result: response ?? "")
        }
        }
    }

    @objc(closeIOS:)    
    func closeIOS(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            print("iOS: Closing NFC session")
            self.iso14443Reader?.session?.invalidate()
            self.iso14443Reader = nil
            self.sendSuccess(command: command, result: "Disconnected")
        }
    }

    @objc(registerNdef:)
    func registerNdef(command: CDVInvokedUrlCommand) {
        print("Registered NDEF Listener")
        isListeningNDEF = true // Flag for the AppDelegate
        sendSuccess(command: command, result: "NDEF Listener is on")
    }
    
    @objc(removeNdef:)
    func removeNdef(command: CDVInvokedUrlCommand) {
        print("removeNdef")
        isListeningNDEF = false;
        sendSuccess(command: command, result: "NDEF Listener is off")
    }

    @objc(registerMimeType:)
    func registerMimeType(command: CDVInvokedUrlCommand) {
        print("Registered Mi Listener")
        sendSuccess(command: command, result: "NDEF Listener is on")
    }
    
    @objc(beginSession:)
    func beginSession(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            print("Begin NDEF reading session")
            
            var alertMessage: String?
            if command.arguments.count != 0 {
               alertMessage = command.arguments[0] as? String ?? ""
            }
            if #available(iOS 13.0, *) {
                self.nfcTagReaderController = NFCTagReaderDelegate(completed: {
                    (response: [AnyHashable: Any]?, error: Error?) -> Void in
                    DispatchQueue.main.async {
                        print("handle NDEF")
                        if error != nil {
                            self.lastError = error
                            self.sendError(command: command, result: error!.localizedDescription)
                        } else {
                            // self.sendSuccess(command: command, result: response ?? "")
                            self.sendThroughChannel(jsonDictionary: response ?? [:])
                        }
                    }
                }, alertMessage: alertMessage)
            } else {
                self.ndefReaderController = NFCNDEFReaderDelegate(completed: {
                    (response: [AnyHashable: Any]?, error: Error?) -> Void in
                    DispatchQueue.main.async {
                        print("handle NDEF")
                        if error != nil {
                            self.lastError = error
                            self.sendError(command: command, result: error!.localizedDescription)
                        } else {
                            // self.sendSuccess(command: command, result: response ?? "")
                            self.sendThroughChannel(jsonDictionary: response ?? [:])
                        }
                        self.ndefReaderController = nil
                        self.ndefWriterController = nil
                    }
                }, message: alertMessage)
            }
       }
    }
    
    @objc(writeTag:)
    func writeTag(command: CDVInvokedUrlCommand) {
        if #available(iOS 13.0, *) {
            if command.arguments.count <= 0 {
                self.sendError(command: command, result: "WriteTag parameter error")
                return
            }
        
            DispatchQueue.main.async {
                print("Begin NDEF writing session")

                if self.ndefWriterController == nil {
                    let alertMessage = ""
                    var ndefMessage: NSArray?
                    if command.arguments.count != 0 {
                        ndefMessage = command.arguments[0] as? NSArray
                    }
                    
                    self.ndefWriterController = NFCNDEFWriterDelegate(completed: {
                        (response: [AnyHashable: Any]?, error: Error?) -> Void in
                        DispatchQueue.main.async {
                            print("handle NDEF")
                            if error != nil {
                                self.lastError = error
                                self.sendError(command: command, result: error!.localizedDescription)
                            } else {
                                // self.sendSuccess(command: command, result: response ?? "")
                                //self.sendThroughChannel(jsonDictionary: response ?? [:])
                                self.sendSuccess(command: command, result: true)
                            }
                            self.ndefWriterController = nil
                        }
                    }, alertMessage: alertMessage, ndefMessage: ndefMessage!)
                }
            }
        } else {
            self.sendError(command: command, result: "Write is only available on iOS 13+")
        }
    }

    @objc(invalidateSession:)
    func invalidateSession(command: CDVInvokedUrlCommand) {
        guard #available(iOS 11.0, *) else {
            sendError(command: command, result: "close is only available on iOS 13+")
            return
        }
        DispatchQueue.main.async {
            if #available(iOS 13.0, *) {
                guard let session = (self.nfcTagReaderController as! NFCTagReaderDelegate).session else {
                    self.sendError(command: command, result: "no session to terminate")
                    return
                }
                session.invalidate()
            } else {
               guard let session = self.ndefReaderController?.session else {
                   self.sendError(command: command, result: "no session to terminate")
                   return
               }
               session.invalidate()
            }
            self.nfcController = nil
            self.nfcTagReaderController = nil;
            self.sendSuccess(command: command, result: "Session Ended!")
        }
    }

    @objc(channel:)
    func channel(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            print("Creating NDEF Channel")
            self.channelCommand = command
            self.sendThroughChannel(message: "Did create NDEF Channel")
        }
    }

    func sendThroughChannel(message: String) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            print("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: message) else {
            print("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)
    }

    func sendThroughChannel(jsonDictionary: [AnyHashable: Any]) {
        guard let command: CDVInvokedUrlCommand = self.channelCommand else {
            print("Channel is not set")
            return
        }
        guard let response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonDictionary) else {
            print("sendThroughChannel Did not create CDVPluginResult")
            return
        }

        response.setKeepCallbackAs(true)
        commandDelegate!.send(response, callbackId: command.callbackId)

//        self.sendSuccessWithResponse(command: command, result: message)
    }

    @objc(enabled:)
    func enabled(command: CDVInvokedUrlCommand) {
        if #available(iOS 11.0, *) {
            let enabled = NFCNDEFReaderSession.readingAvailable
            sendSuccess(command: command, result: enabled)
        } else {
            sendError(command: command, result: "enabled is only available on iOS 11+")
        }
    }
}