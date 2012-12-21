//
//  AMSerialPort_Deprecated.h
//  AMSerialTest
//
//  Created by Andreas on 26.07.06.
//  Copyright 2006 Andreas Mayer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"


@interface AMSerialPort (Deprecated)

- (id)init:(NSString *)path withName:(NSString *)name;
// replaced by  -init:withName:type:

- (NSDictionary *)getOptions;
// renamed to -options

- (long)getSpeed;
// renamed to -speed

- (int)getDataBits;
// renamed to -dataBits

- (BOOL)testParity;			// NO for "no parity"
- (BOOL)testParityOdd;		// meaningful only if TestParity == YES
- (void)setParityNone;
- (void)setParityEven;
- (void)setParityOdd;
// replaced by  -parity  and  -setParity:

- (int)getStopBits;
// renamed to -stopBits;
- (void)setStopBits2:(BOOL)two;		// YES for 2 stop bits, NO for 1 stop bit
// replaced by  -setStopBits:

- (BOOL)testEchoEnabled;
// renamed to -echoEnabled

- (BOOL)testRTSInputFlowControl;
// renamed to -RTSInputFlowControl

- (BOOL)testDTRInputFlowControl;
// renamed to -DTRInputFlowControl

- (BOOL)testCTSOutputFlowControl;
// renamed to -CTSOutputFlowControl

- (BOOL)testDSROutputFlowControl;
// renamed to -DSROutputFlowControl

- (BOOL)testCAROutputFlowControl;
// renamed to -CAROutputFlowControl

- (BOOL)testHangupOnClose;
// renamed to -hangupOnClose

- (BOOL)getLocal;
// renamed to -localMode

- (void)setLocal:(BOOL)local;
// renamed to -setLocalMode:

- (int)checkRead;
// renamed to -bytesAvailable

- (NSString *)readString;
// replaced by  -readStringUsingEncoding:error:

- (NSString *)readStringOfLength:(unsigned int)length;
// replaced by  -readBytes:usingEncoding:error:

- (int)writeString:(NSString *)string;
// replaced by  -writeString:usingEncoding:error:


@end
