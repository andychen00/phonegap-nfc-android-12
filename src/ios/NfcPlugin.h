//
//  NfcPlugin.h
//  PhoneGap NFC - Cordova Plugin
//
//  (c) 2107-2020 Don Coleman

#ifndef NfcPlugin_h
#define NfcPlugin_h

#import <Cordova/CDVPlugin.h>
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin : CDVPlugin <NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate> {
}

// iOS Specific API

// deprecated use scanNdef or scanTag
- (void)beginSession:(CDVInvokedUrlCommand *)command;
// deprecated use stopScan
- (void)invalidateSession:(CDVInvokedUrlCommand *)command;

// Added iOS 13
- (void)scanNdef:(CDVInvokedUrlCommand *)command;
- (void)scanTag:(CDVInvokedUrlCommand *)command;
- (void)cancelScan:(CDVInvokedUrlCommand *)command;

// Standard PhoneGap NFC API
- (void)registerNdef:(CDVInvokedUrlCommand *)command;
- (void)removeNdef:(CDVInvokedUrlCommand *)command;
- (void)enabled:(CDVInvokedUrlCommand *)command;
- (void)writeTag:(CDVInvokedUrlCommand *)command API_AVAILABLE(ios(13.0));

// Internal implementation
- (void)channel:(CDVInvokedUrlCommand *)command;

@end

#endif
