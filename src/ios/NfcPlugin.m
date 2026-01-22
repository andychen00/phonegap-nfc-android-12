#import "NfcPlugin.h"

static NFCTagReaderSession *_session = nil;
static id<NFCTag> _activeTag = nil;

@implementation NfcPlugin
@synthesize readerCommand;

// Start NFC Reader Mode
- (void)readerMode:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) {
        self.readerCommand = command;
        _session = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:dispatch_get_main_queue()];
        _session.alertMessage = @"Tempelkan kartu NFC Anda";
        [_session beginSession];
    } else {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"iOS version not supported"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

// NFCTagReaderSession Delegate
- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session {
    // session aktif
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error {
    _activeTag = nil;
    _session = nil;
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof NFCTag *> *)tags API_AVAILABLE(ios(13.0)) {
    _activeTag = [tags firstObject];

    [session connectToTag:_activeTag completionHandler:^(NSError * _Nullable error) {
        CDVPluginResult* result;
        if (error) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"CARD_DETECTED"];
        }
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:self.readerCommand.callbackId];
    }];
}

// Transceive APDU
- (void)transceive:(CDVInvokedUrlCommand*)command {
    if (!_activeTag) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No tag connected"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    NSArray* arr = [command.arguments objectAtIndex:0];
    NSMutableData* cmdData = [NSMutableData new];
    for (NSNumber* b in arr) {
        uint8_t byte = (uint8_t)[b unsignedIntValue];
        [cmdData appendBytes:&byte length:1];
    }

    if (@available(iOS 13.0, *)) {
        id<NFCISO7816Tag> isoTag = [_activeTag asNFCISO7816Tag];
        if (!isoTag) {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Tag is not ISO7816"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block NSData* resp = nil;

        [isoTag sendCommandAPDU:[[NFCISO7816APDU alloc] initWithData:cmdData] completionHandler:^(NSData * _Nonnull data, uint8_t sw1, uint8_t sw2, NSError * _Nullable error) {
            if (!error) {
                NSMutableData* fullRes = [NSMutableData dataWithData:data];
                uint8_t sw[2] = {sw1, sw2};
                [fullRes appendBytes:sw length:2];
                resp = fullRes;
            }
            dispatch_semaphore_signal(sem);
        }];

        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

        if (resp) {
            NSMutableArray* resultArr = [NSMutableArray new];
            const uint8_t* bytes = resp.bytes;
            for (NSUInteger i=0; i<resp.length; i++) {
                [resultArr addObject:@(bytes[i])];
            }
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultArr];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No response"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }
}

// Close session
- (void)close:(CDVInvokedUrlCommand*)command {
    if (_session) {
        [_session invalidateSession];
        _session = nil;
        _activeTag = nil;
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

@end
