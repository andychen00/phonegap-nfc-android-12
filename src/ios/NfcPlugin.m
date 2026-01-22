#import "NfcPlugin.h"

@implementation NfcPlugin

#pragma mark - Plugin Commands

- (void)enabled:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        if ([NFCNDEFReaderSession readingAvailable]) {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"NFC_OK"] callbackId:command.callbackId];
        } else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NFC_DISABLED"] callbackId:command.callbackId];
        }
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NFC_NOT_SUPPORTED"] callbackId:command.callbackId];
    }
}

- (void)readerMode:(CDVInvokedUrlCommand*)command {
    self.readerModeCommand = command;

    if (@available(iOS 13.0, *)) {
        self.tagSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCTagReaderSessionPollingISO7816 delegate:self queue:nil];
        self.tagSession.alertMessage = @"Hold your iPhone near the card.";
        [self.tagSession beginSession];
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"] callbackId:command.callbackId];
    }
}

- (void)disableReaderMode:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
    }
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

- (void)connect:(CDVInvokedUrlCommand*)command {
    if (!self.isoTag) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag"] callbackId:command.callbackId];
        return;
    }

    NSDictionary *result = @{@"maxTransceiveLength": @(self.isoTag.maximumTransceiveLength)};
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result] callbackId:command.callbackId];
}

- (void)transceive:(CDVInvokedUrlCommand*)command {
    if (!self.isoTag) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"IsoDep not connected"] callbackId:command.callbackId];
        return;
    }

    NSData *commandData = (NSData *)[command.arguments objectAtIndex:0];
    if (![commandData isKindOfClass:[NSData class]]) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid command data"] callbackId:command.callbackId];
        return;
    }

    // Parse commandData to APDU components
    const uint8_t *bytes = commandData.bytes;
    if (commandData.length < 5) { // minimum CLA INS P1 P2 Le
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"APDU data too short"] callbackId:command.callbackId];
        return;
    }

    uint8_t cla = bytes[0];
    uint8_t ins = bytes[1];
    uint8_t p1  = bytes[2];
    uint8_t p2  = bytes[3];
    uint8_t le  = bytes[4];
    NSData *data = nil;
    if (commandData.length > 5) {
        data = [commandData subdataWithRange:NSMakeRange(5, commandData.length - 5)];
    }

    NFCISO7816APDU *apdu = [[NFCISO7816APDU alloc] initWithInstructionClass:cla
                                                             instructionCode:ins
                                                                       p1:p1
                                                                       p2:p2
                                                                     data:data
                                                      expectedResponseLength:le];

    [self.isoTag sendCommandAPDU:apdu completionHandler:^(NSData * _Nullable responseData, uint8_t sw1, uint8_t sw2, NSError * _Nullable error) {
        if (error) {
            NSString *errorStr = [NSString stringWithFormat:@"SW=%02X%02X", sw1, sw2];
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorStr] callbackId:command.callbackId];
        } else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:responseData] callbackId:command.callbackId];
        }
    }];
}

- (void)close:(CDVInvokedUrlCommand*)command {
    if (self.tagSession) {
        [self.tagSession invalidateSession];
        self.tagSession = nil;
    }
    self.isoTag = nil;
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags {
    if (tags.count == 0) return;

    id<NFCTag> tag = tags.firstObject;

    if (tag.type == NFCTagTypeISO7816) {
        self.isoTag = (NFCISO7816Tag *)tag.ISO7816;
        if (self.readerModeCommand) {
            NSDictionary *json = @{
                @"id": [self.isoTag identifier],
                @"techList": @[@"ISO7816"]
            };
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:json];
            [result setKeepCallback:@YES];
            [self.commandDelegate sendPluginResult:result callbackId:self.readerModeCommand.callbackId];
        }
    }

    [session restartPolling];
}

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {
    // session aktif
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    if (self.readerModeCommand) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription] callbackId:self.readerModeCommand.callbackId];
        self.readerModeCommand = nil;
    }
}

@end
