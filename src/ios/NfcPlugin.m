#import "NfcPlugin.h"

static id<NFCTag> _activeTag = nil;
static NFCTagReaderSession *_session = nil;

@implementation NfcPlugin
@synthesize readerCommand;

#pragma mark - Cordova Commands

- (void)startReaderMode:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        self.readerCommand = command;
        _session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:dispatch_get_main_queue()];
        _session.alertMessage = @"Hold your card near the iPhone";
        [_session beginSession];
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)connect:(CDVInvokedUrlCommand*)command {
    if (_activeTag == nil) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag detected"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"TAG_CONNECTED"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)transceive:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        if (_activeTag == nil) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag connected"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }

        NSData *cmdData = [command.arguments objectAtIndex:0];
        if (![cmdData isKindOfClass:[NSData class]]) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid command data"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }

        id<NFCISO7816Tag> isoTag = [_activeTag asNFCISO7816Tag];
        if (!isoTag) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tag is not ISO7816"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block NSData *responseData = nil;

        [isoTag sendCommandAPDU:[[NFCISO7816APDU alloc] initWithData:cmdData]
               completionHandler:^(NSData * _Nonnull data, uint8_t sw1, uint8_t sw2, NSError * _Nullable error) {
            if (!error) {
                NSMutableData *fullRes = [NSMutableData dataWithData:data];
                uint8_t sw[2] = {sw1, sw2};
                [fullRes appendBytes:sw length:2];
                responseData = fullRes;
            }
            dispatch_semaphore_signal(sem);
        }];

        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

        if (responseData) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:responseData];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"APDU failed"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }

    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)close:(CDVInvokedUrlCommand*)command {
    _activeTag = nil;
    if (_session) {
        [_session invalidateSession];
        _session = nil;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    _activeTag = nil;
    _session = nil;
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof NFCTag *> *)tags {
    _activeTag = [tags firstObject];
    [session connectToTag:_activeTag completionHandler:^(NSError * _Nullable error) {
        if (!error && self.readerCommand) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CARD_DETECTED"];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:self.readerCommand.callbackId];
        }
    }];
}

@end
