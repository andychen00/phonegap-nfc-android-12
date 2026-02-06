#import "NfcPlugin.h"

@implementation NfcPlugin

#pragma mark - ENABLED  

- (void)enabled:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *result;

    if (@available(iOS 13.0, *)) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:@"IOS_TOO_LOW"];
    }

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}


#pragma mark - READER MODE

- (void)readerMode:(CDVInvokedUrlCommand*)command {
    if (!@available(iOS 13.0, *)) {
        CDVPluginResult *err =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:@"IOS_TOO_LOW"];
        [self.commandDelegate sendPluginResult:err
                                    callbackId:command.callbackId];
        return;
    }

    self.readerModeCommand = command;

    self.tagSession =
        [[NFCTagReaderSession alloc]
            initWithPollingOption:(NFCPollingISO14443 | NFCPollingISO15693)
                          delegate:self
                             queue:nil];

    // 🔴 DEBUG SIGNAL 1 (PASTI KELIHATAN DI DEVICE)
    self.tagSession.alertMessage = @"[DEBUG] NFC SESSION STARTED - TAP CARD";

    [self.tagSession beginSession];
}


#pragma mark - DISABLE READER MODE

- (void)disableReaderMode:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
        self.isoTag = nil;
    }

    CDVPluginResult *result =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}

#pragma mark - CONNECT (LOGICAL CONNECT)

- (void)connect:(CDVInvokedUrlCommand*)command {
    if (!self.isoTag) {
        CDVPluginResult *err =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:@"NO_TAG_DETECTED"];
        [self.commandDelegate sendPluginResult:err
                                    callbackId:command.callbackId];
        return;
    }

    CDVPluginResult *ok =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                           messageAsString:@"CONNECTED"];

    [self.commandDelegate sendPluginResult:ok
                                callbackId:command.callbackId];
}

#pragma mark - TRANSCEIVE (APDU)

- (void)transceive:(CDVInvokedUrlCommand*)command {
    if (!self.isoTag) {
        CDVPluginResult *err =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:@"NO_TAG"];
        [self.commandDelegate sendPluginResult:err
                                    callbackId:command.callbackId];
        return;
    }

    NSData *apduData = command.arguments.firstObject;
    if (![apduData isKindOfClass:[NSData class]]) {
        CDVPluginResult *err =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                               messageAsString:@"INVALID_APDU"];
        [self.commandDelegate sendPluginResult:err
                                    callbackId:command.callbackId];
        return;
    }

    NFCISO7816APDU *apdu =
        [[NFCISO7816APDU alloc] initWithData:apduData];

    [self.isoTag sendCommandAPDU:apdu
               completionHandler:^(NSData * _Nullable responseData,
                                   uint8_t sw1,
                                   uint8_t sw2,
                                   NSError * _Nullable error) {

        if (error) {
            CDVPluginResult *err =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                   messageAsString:error.localizedDescription];
            [self.commandDelegate sendPluginResult:err
                                        callbackId:command.callbackId];
            return;
        }

        NSMutableData *full =
            [NSMutableData dataWithData:responseData];
        uint8_t status[] = { sw1, sw2 };
        [full appendBytes:status length:2];

        CDVPluginResult *ok =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                               messageAsArrayBuffer:full];

        [self.commandDelegate sendPluginResult:ok
                                    callbackId:command.callbackId];
    }];
}

#pragma mark - CLOSE

- (void)close:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
        self.isoTag = nil;
    }

    CDVPluginResult *result =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:result
                                callbackId:command.callbackId];
}

#pragma mark - NFC DELEGATE

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {
    // session aktif
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {

    if (self.readerModeCommand) {
        CDVPluginResult *res =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                messageAsString:@"SESSION_CLOSED"];

        [self.commandDelegate sendPluginResult:res
            callbackId:self.readerModeCommand.callbackId];
    }

    self.tagSession = nil;
    self.isoTag = nil;
}


- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags
API_AVAILABLE(ios(13.0)) {

    id<NFCTag> tag = tags.firstObject;

    CDVPluginResult *dbg1 =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                           messageAsString:@"IOS_TAG_CALLBACK"];
    [dbg1 setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:dbg1
        callbackId:self.readerModeCommand.callbackId];

    CDVPluginResult *dbg2 =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                           messageAsString:@"TAG_DETECTED"];
    [dbg2 setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:dbg2
        callbackId:self.readerModeCommand.callbackId];

    // === ISO7816 (EMONEY BARU) ===
    if ([tag conformsToProtocol:@protocol(NFCISO7816Tag)]) {

        [session connectToTag:tag completionHandler:^(NSError *error) {

            if (error) {
                CDVPluginResult *err =
                    [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                        messageAsString:error.localizedDescription];
                [self.commandDelegate sendPluginResult:err
                        callbackId:self.readerModeCommand.callbackId];
                return;
            }

            self.isoTag = [tag asNFCISO7816Tag];

            CDVPluginResult *ok =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                    messageAsString:@"ISO7816_READY"];

            [ok setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:ok
                    callbackId:self.readerModeCommand.callbackId];
        }];

        return;
    }


    // === MIFARE (EMONEY LAMA) ===
    if (tag.type == NFCTagTypeMiFare) {

        id<NFCMiFareTag> mifare = [tag asNFCMiFareTag];
        NSData *uid = mifare.identifier;

        NSString *uidHex = @"";
        const unsigned char *b = uid.bytes;
        for (NSUInteger i = 0; i < uid.length; i++) {
            uidHex = [uidHex stringByAppendingFormat:@"%02X", b[i]];
        }

        CDVPluginResult *res =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                messageAsString:
                [NSString stringWithFormat:@"MIFARE_UID:%@", uidHex]];

        [res setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:res
                callbackId:self.readerModeCommand.callbackId];
        return;
    }


    // === TAG LAIN (ANTI SILENCE) ===
    CDVPluginResult *unknown =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
            messageAsString:@"TAG_UNSUPPORTED"];

    [unknown setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:unknown
            callbackId:self.readerModeCommand.callbackId];


    // [session connectToTag:tag completionHandler:^(NSError * _Nullable error) {

    //     if (error) {
    //         CDVPluginResult *err =
    //             [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
    //                                messageAsString:error.localizedDescription];
    //         [self.commandDelegate sendPluginResult:err
    //                 callbackId:self.readerModeCommand.callbackId];
    //         return;
    //     }

    //     self.isoTag = [tag asNFCISO7816Tag];

    //     CDVPluginResult *ok =
    //         [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
    //                            messageAsString:@"TAG_DETECTED"];

    //     [ok setKeepCallbackAsBool:YES];
    //     [self.commandDelegate sendPluginResult:ok
    //             callbackId:self.readerModeCommand.callbackId];

    //     // ❌ JANGAN invalidateSession DI SINI
    // }];
}

@end
