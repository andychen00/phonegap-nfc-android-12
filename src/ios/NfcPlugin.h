#import <Cordova/CDVPlugin.h>
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin : CDVPlugin <NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate>

@property (nonatomic, strong) NFCTagReaderSession *tagSession;
@property (nonatomic, strong) id<NFCISO7816Tag> isoTag;

@property (nonatomic, strong) CDVInvokedUrlCommand *readerModeCommand;

- (void)enabled:(CDVInvokedUrlCommand*)command;
- (void)readerMode:(CDVInvokedUrlCommand*)command;
- (void)disableReaderMode:(CDVInvokedUrlCommand*)command;

- (void)connect:(CDVInvokedUrlCommand*)command;
- (void)transceive:(CDVInvokedUrlCommand*)command;
- (void)close:(CDVInvokedUrlCommand*)command;

@end
