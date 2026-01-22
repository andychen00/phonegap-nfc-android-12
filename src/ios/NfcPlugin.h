#import <Cordova/CDV.h>
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin : CDVPlugin <NFCTagReaderSessionDelegate>

@property (nonatomic, strong) CDVInvokedUrlCommand* readerCommand;

- (void)startReaderMode:(CDVInvokedUrlCommand*)command;
- (void)connect:(CDVInvokedUrlCommand*)command;
- (void)transceive:(CDVInvokedUrlCommand*)command;
- (void)close:(CDVInvokedUrlCommand*)command;

@end
