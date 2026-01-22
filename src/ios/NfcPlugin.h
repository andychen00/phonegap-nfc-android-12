#import <Cordova/CDV.h>
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin : CDVPlugin <NFCTagReaderSessionDelegate>

@property (strong, nonatomic) NFCTagReaderSession *tagSession;
@property (strong, nonatomic) NFCISO7816Tag *isoTag;
@property (strong, nonatomic) CDVInvokedUrlCommand *readerModeCommand;

- (void)enabled:(CDVInvokedUrlCommand*)command;
- (void)readerMode:(CDVInvokedUrlCommand*)command;
- (void)disableReaderMode:(CDVInvokedUrlCommand*)command;
- (void)connect:(CDVInvokedUrlCommand*)command;
- (void)transceive:(CDVInvokedUrlCommand*)command;
- (void)close:(CDVInvokedUrlCommand*)command;

@end
