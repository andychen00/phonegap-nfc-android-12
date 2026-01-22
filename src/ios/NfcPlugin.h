#import <Cordova/CDV.h>
#import <CoreNFC/CoreNFC.h>

@interface NfcPlugin : CDVPlugin <NFCTagReaderSessionDelegate>
@property (nonatomic, strong) CDVInvokedUrlCommand* readerCommand;
@end
