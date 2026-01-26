#import "NfcPlugin.h"

@implementation NfcPlugin

#pragma mark - Cordova Methods

// Check if NFC is available
- (void)enabled:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* result;
    if (@available(iOS 11.0, *)) {
        if ([NFCNDEFReaderSession readingAvailable]) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NO_NFC"];
        }
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"];
    }
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

// Start reader mode
- (void)readerMode:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        self.readerModeCommand = command;
        self.tagSession = [[NFCTagReaderSession alloc]
                           initWithPollingOption:(NFCPollingISO14443 | NFCPollingISO15693)
                           delegate:self
                           queue:dispatch_get_main_queue()];
        self.tagSession.alertMessage = @"Tempelkan kartu NFC Anda";
        [self.tagSession beginSession];
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

// Disable reader mode / invalidate session
- (void)disableReaderMode:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
        self.isoTag = nil;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

// Connect to detected ISO7816 tag
- (void)connect:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        if (!self.isoTag) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag detected"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CONNECTED"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

// Send APDU command and receive response
- (void)transceive:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        if (!self.isoTag) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag connected"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }

        NSArray* apduArray = [command.arguments objectAtIndex:0];
        NSMutableData* cmdData = [NSMutableData data];
        for (NSNumber* num in apduArray) {
            uint8_t b = [num unsignedCharValue];
            [cmdData appendBytes:&b length:1];
        }

        [self.isoTag sendCommandAPDU:[[NFCISO7816APDU alloc] initWithData:cmdData]
                  completionHandler:^(NSData * _Nonnull response, uint8_t sw1, uint8_t sw2, NSError * _Nullable error) {
            if (error) {
                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                NSMutableData* fullRes = [NSMutableData dataWithData:response];
                uint8_t sw[2] = {sw1, sw2};
                [fullRes appendBytes:sw length:2];

                NSMutableArray* resArray = [NSMutableArray array];
                const uint8_t* bytes = fullRes.bytes;
                for (NSUInteger i=0; i<fullRes.length; i++) {
                    [resArray addObject:@(bytes[i])];
                }

                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resArray];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        }];
    }
}

// Close session
- (void)close:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
        self.isoTag = nil;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {
    // session aktif
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    self.isoTag = nil;
    self.tagSession = nil;
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags API_AVAILABLE(ios(13.0)) {
    if (tags.count > 0) {
        id<NFCTag> tag = tags.firstObject;
        self.isoTag = [tag asNFCISO7816Tag];
        [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {
            CDVPluginResult* result;
            if (error) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
            } else {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"TAG_DETECTED"];
            }
            if (self.readerModeCommand) {
                [result setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:result callbackId:self.readerModeCommand.callbackId];
            }
        }];
    }
}

@end
