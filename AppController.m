//
//  AppController.m
//  MagTool
//
//  Created by Dustin Li on 7/12/09.
//  Copyright 2009 iForgot Systems. All rights reserved.
//

#import "AppController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"

@implementation AppController

#pragma mark Helper methods

- (AMSerialPort *)port
{
    return port;
}

- (NSData *)convertToNSData:(NSString *)str
{
	return [[NSData dataWithBytes:[str cStringUsingEncoding:NSASCIIStringEncoding] length:[str length]] retain];
}

// Display data previously read in
// track1DataRead, track2DataRead, and track3DataRead must be strings (not nil)
- (void)displayReadData
{
	// Check whether we should display the values as hex or ASCII
	//if ([[[readDisplay selectedCell] title] isEqualToString:@"ASCII"])
		
	if ([readDisplay selectedSegment] == 0)
	{
		// Display as ASCII
		//DLOG(@"Displaying as ASCII");
		[track1Read setStringValue:track1DataRead];
		[track2Read setStringValue:track2DataRead];
		[track3Read setStringValue:track3DataRead];
	} else {
		// Display as hex
		//DLOG(@"Displaying as hex");
		[track1Read setStringValue:
		 [[[self convertToNSData:track1DataRead] autorelease] description]];
		[track2Read setStringValue:
		 [[[self convertToNSData:track2DataRead] autorelease] description]];
		[track3Read setStringValue:
		 [[[self convertToNSData:track3DataRead] autorelease] description]];
	}
	
	// Check if there are any empty tracks (designated by [1B 2B])
	if ([track1DataRead isEqualToString:@"\x1b\x2b"])
		[track1Read setStringValue:@"[Empty track]"];
	if ([track2DataRead isEqualToString:@"\x1b\x2b"])
		[track2Read setStringValue:@"[Empty track]"];
	if ([track3DataRead isEqualToString:@"\x1b\x2b"])
		[track3Read setStringValue:@"[Empty track]"];
}

// helper function to manage opening and closing ports
// called by initPort
- (void)setPort:(AMSerialPort *)newPort
{
    id old = nil;
	
    if (newPort != port) {
        old = port;
        port = [newPort retain];
        [old release];
    }
}

// helper function to clear the dataBuffer
- (void)clearDataBuffer
{
	[dataBuffer setLength:0];
}

- (void)flushSerialInputBuffer
{
	if ([port bytesAvailable] > 0) {
		// flush buffer
		NSData *flushed = [port readBytes:[port bytesAvailable] error:nil];
		DLOG(@"Flushed bytes: %@", flushed);
		flushed = nil;	// work around warning in Release mode
		if ([port bytesAvailable] > 0) {
			// throw an error
			DLOG(@"Could not flush the input buffer.");
		}
	}
}

// Check that serial port is okay... return YES if it is, NO if it isn't
- (BOOL)checkPort
{
	if (!port || ![port isOpen]) {
		DLOG(@"Port is not open!");
		[deviceModel setStringValue:@"No device detected."];
		[deviceFirmware setStringValue:@""];
		// throw an error
		return NO;
	} else {
		return YES;
	}
}

// Helper function to reset and test the device
// Should be called only after the port is opened
- (void)initDevice
{
	if (![self checkPort])
		return;
	
	// Reset the device
	if (![port writeString:resetCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		DLOG(@"Reset error occured!");
		// throw error
	}
	
	[self flushSerialInputBuffer];
	
	// Test communication
	if (![port writeString:commTestCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		DLOG(@"Test comm occured!");
		// throw error
	}
	NSData *response = [port readBytes:2 error:nil];
	if (![response isEqualToData:[NSData dataWithBytes:"\x1B\x79" length:2]])
	{
		DLOG(@"WARNING: Comm test bad (response: %@)", response);
		// throw a warning
	}
	
	
	// Reset the device
	if (![port writeString:resetCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		DLOG(@"Reset error occured!");
		// throw error
	}
	
	// Flash LEDs
	[port writeString:allLEDOnCommand usingEncoding:NSASCIIStringEncoding error:NULL];

	[port setReadTimeout:0.05];
	// Get model and firmware
	[port writeString:getDeviceModelCommand usingEncoding:NSASCIIStringEncoding error:NULL];
	response = [port readAndReturnError:nil];
	if (![response length]) {
		[deviceModel setStringValue:@"No device detected."];
		[deviceFirmware setStringValue:@""];
		return;
	}
	NSString *modelNum = [[[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding] autorelease];
	modelNum = [modelNum stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\x1BS"]];
	[deviceModel setStringValue:modelNum];
	
	[port writeString:getFirmwareVersionCommand usingEncoding:NSASCIIStringEncoding error:NULL];
	response = [port readAndReturnError:nil];
	NSString *versionNum = [[[NSString alloc] initWithData:response encoding:NSASCIIStringEncoding] autorelease];
	versionNum = [versionNum stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\x1B"]];
	[deviceFirmware setStringValue:versionNum];
	
	// Get coercivity
	[port writeString:getCoercivity usingEncoding:NSASCIIStringEncoding error:NULL];
	NSString *coerc = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	//DLOG(@"Coercivity: %@", coerc);
	if ([coerc isEqualToString:@"\x1Bh"]) {
		// HiCo
		[writeCoercivity setSelectedSegment:0];
	} else {
		[writeCoercivity setSelectedSegment:1];
	}
	
	[port setReadTimeout:readTimeOut];
	[self checkLeadingZeros];
}

// Query device for # of leading zeros on each track
- (void)checkLeadingZeros
{
	[port writeString:checkLeadingZerosCommand usingEncoding:NSASCIIStringEncoding error:NULL];
	NSData *response = [port readBytes:3 error:nil];
	if (![response length]) {
		DLOG(@"ERROR: No response to checkLeadingZeros");
		return;
		// throw error
	}
	const unsigned char *data = [response bytes];
	leadingZerosTracks13 = data[1];
	leadingZerosTrack2 = data[2];
	//DLOG(@"Track 1 & 3: %d    Track 2: %d", leadingZerosTracks13, leadingZerosTrack2);
}

// opens and initializes the port selected in the device list UI
// called by didAddPorts and awakeFromNib
// should call initDevice after this method runs. For some reason, calling initDevice from within this method 
// doesn't work well and causes the comm test to fail.
- (void)initPort
{
	NSString *deviceName = [deviceSelector titleOfSelectedItem];
	if (![deviceName isEqualToString:[port name]]) {
		[port close];
		
		[self setPort:[[[AMSerialPort alloc] 
						init:deviceName 
						withName:deviceName 
						type:(NSString*)CFSTR(kIOSerialBSDModemType)] 
					   autorelease]];
		
		// register as self as delegate for port
		[port setDelegate:self];
		
#ifdef DEBUG
		[outputTextView insertText:
		 [NSString stringWithFormat:@"Attempting to open port %@.\n", 
		  [port bsdPath]]];
		[outputTextView setNeedsDisplay:YES];
		[outputTextView displayIfNeeded];
#endif
		
		// open port - may take a few seconds ...
		if ([port open]) {
			[port setReadTimeout:readTimeOut];	// allows 9600/8*0.25 = 300 characters per read
#ifdef DEBUG
			[outputTextView insertText:@"Port opened.\r"];
			[outputTextView setNeedsDisplay:YES];
			[outputTextView displayIfNeeded];
#endif
		} else { // an error occured while creating port
			[outputTextView insertText:@"Couldn't open port: "];
			[outputTextView insertText:deviceName];
			[outputTextView insertText:@"\r"];
			[outputTextView setNeedsDisplay:YES];
			[outputTextView displayIfNeeded];
			[self setPort:nil];
		}
	}
}

// not working (reader always returns <1B4F>)
- (BOOL)setDeviceBPI
{
	if (![self checkPort])
		return NO;
	[self flushSerialInputBuffer];
	
	// track1 BPI
	NSData *BPIcommand;
	if ([[track1BPI titleOfSelectedItem] isEqualToString:@"75 bpi"])
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\xA0" length:3];
	else
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\xA1" length:3];
	DLOG(@"track1BPICommand: %@", BPIcommand);
	[port writeData:BPIcommand error:nil];
	NSData *response = [port readBytes:2 error:nil];
	if (![response isEqual:[@"\x1B\x30" dataUsingEncoding:NSASCIIStringEncoding]])
	{
		// select failed
		DLOG(@"Set BPI failed (response: %@)", response);
		return NO;
	}
	// track2 BPI
	if ([[track2BPI titleOfSelectedItem] isEqualToString:@"75 bpi"])
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\x4B" length:3];
	else
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\xD2" length:3];
	DLOG(@"track2BPICommand: %@", BPIcommand);
	[port writeData:BPIcommand error:nil];
	response = [port readBytes:2 error:nil];
	if (![response isEqual:[@"\x1B\x30" dataUsingEncoding:NSASCIIStringEncoding]])
	{
		// select failed
		DLOG(@"Set BPI failed (response: %@)", response);
		return NO;
	}
	// track3 BPI
	if ([[track3BPI titleOfSelectedItem] isEqualToString:@"75 bpi"])
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\xC0" length:3];
	else
		BPIcommand = [NSData dataWithBytes:"\x1B\x62\xC1" length:3];
	DLOG(@"track3BPICommand: %@", BPIcommand);
	[port writeData:BPIcommand error:nil];
	response = [port readBytes:2 error:nil];
	if (![response isEqual:[@"\x1B\x30" dataUsingEncoding:NSASCIIStringEncoding]])
	{
		// select failed
		DLOG(@"Set BPI failed (response: %@)", response);
		return NO;
	}	
	
	return YES;
}

- (BOOL)setDeviceBPC
{
	if (![self checkPort])
		return NO;
	[self flushSerialInputBuffer];
	NSString *byte2;
	NSString *byte3;
	NSString *byte4;
	byte2 = [NSString stringWithFormat:@"%c", (unsigned char)([track1BPC indexOfSelectedItem]+5)];
	byte3 = [NSString stringWithFormat:@"%c", (unsigned char)([track2BPC indexOfSelectedItem]+5)];
	byte4 = [NSString stringWithFormat:@"%c", (unsigned char)([track3BPC indexOfSelectedItem]+5)];
	NSString *BPCcommand = [NSString stringWithFormat:@"%@%@%@%@", setBPCCommand, byte2, byte3, byte4];
	[port writeString:BPCcommand usingEncoding:NSASCIIStringEncoding error:nil];
	NSString *response = [port readBytes:5 usingEncoding:NSASCIIStringEncoding error:nil];
	if (![response isEqualToString:[NSString stringWithFormat:@"\x1B\x30%@%@%@", byte2, byte3, byte4]])
	{
		// set failed
		DLOG(@"Set BPC failed (response: %@)", [response dataUsingEncoding:NSASCIIStringEncoding]);
		return NO;
	}
	return YES;
}

- (BOOL)setDeviceCoercivity
{
	if (![self checkPort])
		return NO;
	[self flushSerialInputBuffer];
	
	NSString *command;
	if ([writeCoercivity selectedSegment] == 0)
	{
		command = setHiCoercivityCommand;
	} else {
		command = setLoCoercivityCommand;
	}
	
	[port writeString:command usingEncoding:NSASCIIStringEncoding error:nil];
	NSString *response = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	if (![response isEqualToString:@"\x1B\x30"])
	{
		// failed
		DLOG(@"Set coercivity failed (response: %@)", [response dataUsingEncoding:NSASCIIStringEncoding]);
		return NO;
	}
	
	return YES;
}

// write ISO, AAMVA, or CA DMV cards
// (AAMVA and CA DMV are pseudo-ISO)
// To ignore a track, pass the string as nil
- (MTCommandStatus)writeISOCard:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3 format:(MTDataFormat)format
{
	if ([track1 isEqualToString:@""] && [track2 isEqualToString:@""] && [track3 isEqualToString:@""])
		return MTStatusEmptyStrings;
	
	if (![self checkPort])
		return MTStatusPortBroken;
	[self flushSerialInputBuffer];
	
	/* set BPI and BPC */
	//[self setDeviceBPI];	// not working
	if (![self setDeviceBPC])
		return MTStatusBPCBroken;
	
	// set coercivity
	if (![self setDeviceCoercivity])
		return MTStatusCoercivityBroken;
	
	// write it!
	NSString *commandString;
	NSData *commandData;
	if (format == MTASCII)	// ASCII
	{
		NSString *track1Str;
		NSString *track2Str;
		NSString *track3Str;
		
		// check characters fall within BPC constraints
		
		// check track enables & validity of start and stop sentinels (and trim them)
		if ([track1 length] > 0)
		{
			if (([track1 length] < 2) || [track1 characterAtIndex:0] != '%' || [track1 characterAtIndex:([track1 length]-1)] != '?')
			{
				DLOG(@"Bad start/end sentinel for track 1");
				// throw error
				return MTStatusBadSentinel;
			}
			track1Str = [@"\x1B\x01" stringByAppendingString:[track1 substringWithRange:NSMakeRange(1, [track1 length] - 2)]];
		}
		else
			track1Str = @"";
		
		if ([track2 length] > 0)
		{
			if (([track2 length] < 2) || [track2 characterAtIndex:0] != ';' || [track2 characterAtIndex:([track2 length]-1)] != '?')
			{
				DLOG(@"Bad start/end sentinel for track 2");
				// throw error
				return MTStatusBadSentinel;
			}
			track2Str = [@"\x1B\x02" stringByAppendingString:[track2 substringWithRange:NSMakeRange(1, [track2 length] - 2)]];
		}
		else
			track2Str = @"";
		
		if ([track3 length] > 0)
		{
			if (([track3 length] < 2) || [track3 characterAtIndex:0] != ';' || [track3 characterAtIndex:([track3 length]-1)] != '?')
			{
				DLOG(@"Bad start/end sentinel for track 3");
				// throw error
				return MTStatusBadSentinel;
			}
			track3Str = [@"\x1B\x03" stringByAppendingString:[track3 substringWithRange:NSMakeRange(1, [track3 length] - 2)]];
		}
		else
			track3Str = @"";
		
		// ASCII format
		//commandString = [NSString stringWithFormat:@"%@\x1B\x73\x1B\x01%@\x1B\x02%@\x1B\x03%@\x3F\x1C", writeCommand, track1Str, track2Str, track3Str];
		commandString = [NSString stringWithFormat:@"%@\x1B\x73%@%@%@\x3F\x1C", writeCommand, track1Str, track2Str, track3Str];
		commandData = [commandString dataUsingEncoding:NSMacOSRomanStringEncoding];
	} else {	// Hex
		NSString *oneByte;
		NSRange subString;
		NSScanner *scanner;
		unsigned int buffer[1];
		unsigned char charByte;
		NSCharacterSet *invalidCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789AaBbCcDdEeFf"] invertedSet];
		NSCharacterSet *invalidAlphaNum = [NSCharacterSet characterSetWithCharactersInString:@"GgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvXxYyZz;?"];
		
		// check characters fall within BPC constraints
		
		// check if there are any non-obvious invalid characters in the hex representation
		NSRange track1InvalidRange = [track1 rangeOfCharacterFromSet:invalidAlphaNum];
		NSRange track2InvalidRange = [track2 rangeOfCharacterFromSet:invalidAlphaNum];
		NSRange track3InvalidRange = [track3 rangeOfCharacterFromSet:invalidAlphaNum];
		if (track1InvalidRange.location != NSNotFound) {
			DLOG(@"Invalid characters in track 1");
			return MTStatusInvalidHexChars;
		} else if (track2InvalidRange.location != NSNotFound) {
			DLOG(@"Invalid characters in track 2");
			return MTStatusInvalidHexChars;
		} else if (track3InvalidRange.location != NSNotFound) {
			DLOG(@"Invalid characters in track 3");
			return MTStatusInvalidHexChars;
		}
		
		// remove the invalid characters & change case
		track1 = [[[track1 componentsSeparatedByCharactersInSet:invalidCharacters] componentsJoinedByString: @""] uppercaseString];
		track2 = [[[track2 componentsSeparatedByCharactersInSet:invalidCharacters] componentsJoinedByString: @""] uppercaseString];
		track3 = [[[track3 componentsSeparatedByCharactersInSet:invalidCharacters] componentsJoinedByString: @""] uppercaseString];
		NSMutableData *track1Data = [NSMutableData dataWithCapacity:[track1 length]];
		NSMutableData *track2Data = [NSMutableData dataWithCapacity:[track2 length]];
		NSMutableData *track3Data = [NSMutableData dataWithCapacity:[track3 length]];
		if ([track1 length] % 2 || [track2 length] % 2 || [track3 length] % 2)
		{
			// uneven # of chars
			DLOG(@"Uneven # of hex chars");
			// throw an error
			return MTStatusHexUneven;
		}
		
		// check start & end sentinals and trim them
		if ([track1 length] > 0)
		{
			if (([track1 length] < 4) || ![[track1 substringToIndex:2] isEqualToString:@"25"] || ![[track1 substringFromIndex:[track1 length]-2] isEqualToString:@"3F"])
			{
				DLOG(@"Bad start/end sentinel for track 1");
				// throw error
				return MTStatusBadSentinel;
			}
			track1 = [track1 substringWithRange:NSMakeRange(2, [track1 length] - 4)];
		}
		
			
		if ([track2 length] > 0)
		{
			if (([track2 length] < 4) || ![[track2 substringToIndex:2] isEqualToString:@"3B"] || ![[track2 substringFromIndex:[track2 length]-2] isEqualToString:@"3F"])
			{
			DLOG(@"Bad start/end sentinel for track 2");
			// throw error
				return MTStatusBadSentinel;
			}
			track2 = [track2 substringWithRange:NSMakeRange(2, [track2 length] - 4)];
		}

		
		if ([track3 length] > 0)
		{
			if (([track3 length] < 4) || ![[track3 substringToIndex:2] isEqualToString:@"3B"] || ![[track3 substringFromIndex:[track3 length]-2] isEqualToString:@"3F"])
			{
				DLOG(@"Bad start/end sentinel for track 3");
				// throw error
				return MTStatusBadSentinel;
			}
			track3 = [track3 substringWithRange:NSMakeRange(2, [track3 length] - 4)];
		}
		
		// convert hex representation in NSString to NSData
		for (int i=0; i < [track1 length]/2; i++)
		{
			// scan first digit
			subString.location = i*2;
			subString.length = 2;
			oneByte = [track1 substringWithRange:subString];
			//DLOG(@"oneByte: %@", [oneByte dataUsingEncoding:NSMacOSRomanStringEncoding]);
			scanner = [NSScanner scannerWithString:oneByte];
			[scanner scanHexInt:buffer];
			//DLOG(@"buffer: %u", buffer[0]);
			charByte = (unsigned char) buffer[0];
			[track1Data appendBytes:&charByte length:1];
			//DLOG(@"Appending %u to track1Data: %@", buffer[0], track1Data);
		}
		DLOG(@"Track1Data: %@", track1Data);
		
		for (int i=0; i < [track2 length]/2; i++)
		{
			// scan first digit
			subString.location = i*2;
			subString.length = 2;
			oneByte = [track2 substringWithRange:subString];
			//DLOG(@"oneByte: %@", [oneByte dataUsingEncoding:NSMacOSRomanStringEncoding]);
			scanner = [NSScanner scannerWithString:oneByte];
			[scanner scanHexInt:buffer];
			//DLOG(@"buffer: %u", buffer[0]);
			charByte = (unsigned char) buffer[0];
			[track2Data appendBytes:&charByte length:1];
			//DLOG(@"Appending %u to track1Data: %@", buffer[0], track1Data);
		}
		DLOG(@"Track2Data: %@", track2Data);
		
		for (int i=0; i < [track3 length]/2; i++)
		{
			// scan first digit
			subString.location = i*2;
			subString.length = 2;
			oneByte = [track3 substringWithRange:subString];
			//DLOG(@"oneByte: %@", [oneByte dataUsingEncoding:NSMacOSRomanStringEncoding]);
			scanner = [NSScanner scannerWithString:oneByte];
			[scanner scanHexInt:buffer];
			//DLOG(@"buffer: %u", buffer[0]);
			charByte = (unsigned char) buffer[0];
			[track3Data appendBytes:&charByte length:1];
			//DLOG(@"Appending %u to track1Data: %@", buffer[0], track1Data);
		}
		DLOG(@"Track3Data: %@", track3Data);
		
		// check track enables
		if ([track1 length] > 0)
			track1Data = [NSData data];
		if ([track2 length] > 0)
			track2Data = [NSData data];
		if ([track3 length] > 0)
			track3Data = [NSData data];
		
		NSMutableData *commandDataMut;
		commandDataMut = [NSMutableData dataWithCapacity:300];
		[commandDataMut appendData:[writeCommand dataUsingEncoding:NSMacOSRomanStringEncoding]];
		[commandDataMut appendBytes:"\x1B\x73\x1B\x01"	length:4];	// start & 1st track delimiter
		[commandDataMut appendData:track1Data];
		[commandDataMut appendBytes:"\x1B\x02" length:2];	// 2nd track delimiter
		[commandDataMut appendData:track2Data];
		[commandDataMut appendBytes:"\x1B\x03" length:2];	// 3rd track delimiter
		[commandDataMut appendData:track3Data];
		[commandDataMut appendBytes:"\x3F\x1C" length:2];	// end
		commandData = commandDataMut;
	}
	DLOG(@"Data: %@", commandData);
	[port writeData:commandData	error:nil];
	//[port writeString:command usingEncoding:NSASCIIStringEncoding error:nil];
	
	// Wait for the user to swipe card before trying to read the response
	while(![port bytesAvailable])
	{
		if ([writeOperation respondsToSelector:@selector(isCancelled)]) // check for cancellation if we were called in a new thread
			if ([writeOperation isCancelled])
				return MTStatusCancelled;
		if ([duplicateOperation respondsToSelector:@selector(isCancelled)]) // check for cancellation if we were called in a new thread
			if ([duplicateOperation isCancelled])
				return MTStatusCancelled;
		[NSThread sleepForTimeInterval:0.01];
	}
	
	NSString *response = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	if (![response isEqualToString:@"\x1B\x30"])
	{
		// write failed
		DLOG(@"Write failed (response: %@)", [response dataUsingEncoding:NSASCIIStringEncoding]);
		return MTStatusBadResponse;
	}
	return MTStatusSuccess;
}

- (void)writeRawCard:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3
{
	
	// call writeRawCard w/ NSData
}

- (void)writeRawCardWithData:(NSData *)track1data track2:(NSData *)track2data track3:(NSData *)track3data
{
	
}

// returns an NSArray of NSStrings that represent the data on each track
// index 0 = Track 1, index 1 = Track 2, index 2 = Track 3
- (NSArray *)readISOCard
{
	if (![self checkPort])
		return nil;
	
	[self flushSerialInputBuffer];
	
	if (![port writeString:readCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		// throw an error
	}
	
	// Wait for the user to swipe card before trying to read the data
	while(![port bytesAvailable])
	{
		if ([readOperation respondsToSelector:@selector(isCancelled)]) // check for cancellation if we were called in a new thread
			if ([readOperation isCancelled])
				return nil;
		if ([duplicateOperation respondsToSelector:@selector(isCancelled)]) // check for cancellation if we were called in a new thread
			if ([duplicateOperation isCancelled])
				return nil;
		[NSThread sleepForTimeInterval:0.01];
	}
	
	// Read the data and status
	NSString *unparsedData = [port readUpToChar:'\x1C' usingEncoding:NSASCIIStringEncoding error:nil];
	DLOG(@"Data: %@", unparsedData);	// display ASCII string
	DLOG(@"Data: %@", [[self convertToNSData:unparsedData] autorelease]);								// display as hex
	
	// There's a bug in readUpToChar - doesn't always work correctly the second time
	// Can return all data read, even data beyond that character specified
	NSString *deviceStatus = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	if (deviceStatus == nil) {
		// bugged out, parse unparsedData for the status
		deviceStatus = [[unparsedData componentsSeparatedByString:@"\x3F\x1C"] objectAtIndex:1];
	}
	//DLOG(@"deviceStatus: %@", deviceStatus);	// display ASCII string
	//DLOG(@"deviceStatus: %@", [[self convertToNSData:deviceStatus] autorelease]);						// display as hex
	NSArray *substrings = [unparsedData componentsSeparatedByString:@"\x1B"];
	
	// Verify that there isn't data before the first delimeter (ESC)
	if (![[substrings objectAtIndex:0] isEqualToString:@""]) {
		DLOG(@"Error parsing data.");
		// throw an error
	}
	
	// Verify that the first response code is correct (should be 73)
	if (![[substrings objectAtIndex:1] isEqualToString:@"\x73"]) {
		DLOG(@"Error parsing data.");
		// throw an error
	}
	
	NSString *track1Data, *track2Data, *track3Data;
	
	// Find track 1 data between [1B 01] and [1B 02]
	NSString *firstPart = [[unparsedData componentsSeparatedByString:@"\x1B\x01"] objectAtIndex:1];
	track1Data = [[firstPart componentsSeparatedByString:@"\x1B\x02"] objectAtIndex:0];
	DLOG(@"Track 1 data: %@", [[self convertToNSData:track1Data] autorelease]);
	
	// Find track 2 data between [1B 02] and [1B 03]
	NSString *secondPart = [[unparsedData componentsSeparatedByString:@"\x1B\x02"] objectAtIndex:1];
	track2Data = [[secondPart componentsSeparatedByString:@"\x1B\x03"] objectAtIndex:0];
	DLOG(@"Track 2 data: %@", [[self convertToNSData:track2Data] autorelease]);
	
	// Find track 3 data between [1B 03] and [3F 1C]
	NSString *thirdPart = [[unparsedData componentsSeparatedByString:@"\x1B\x03"] objectAtIndex:1];
	track3Data = [[thirdPart componentsSeparatedByString:@"\x3F\x1C"] objectAtIndex:0];
	DLOG(@"Track 3 data: %@", [[self convertToNSData:track3Data] autorelease]);
	
	deviceStatus = [deviceStatus substringFromIndex:1];
	if (![deviceStatus isEqualToString:@"\x30"]) {
		DLOG(@"Read error");
		// throw an error
	}
	
	return [NSArray arrayWithObjects:track1Data, track2Data, track3Data, nil];
}

- (void)readCardDelegate:(NSArray *)trackData
{
	[readButton setTitle:@"Read"];
	[readProgressIndicator setHidden:YES];
	[readProgressIndicator stopAnimation:self];
	if ([readOperation isCancelled])
	{
		DLOG(@"Read cancelled");
		return;
	} else if (trackData == nil) {
		DLOG(@"Read error - no data returned");
		// throw an error
		return;
	} else {
		if (track1DataRead)
			[track1DataRead release];
		if (track2DataRead)
			[track2DataRead release];
		if (track3DataRead)
			[track3DataRead release];
		
		track1DataRead = [[trackData objectAtIndex:0] retain];
		track2DataRead = [[trackData objectAtIndex:1] retain];
		track3DataRead = [[trackData objectAtIndex:2] retain];
		[self displayReadData];
		return;
	}
}

- (void)readISOCardOp:(AppController *)mainObject
{
	NSArray *trackData = [mainObject readISOCard];
	//NSArray *trackData = [self readISOCard];
	[mainObject performSelectorOnMainThread:@selector(readCardDelegate:) withObject:trackData waitUntilDone:YES];
}

- (void)writeCardDelegate:(NSNumber *)status
{
	// Handle errors, cleanup UI
	DLOG(@"Status: %i", [status unsignedIntValue]);
	[writeButton setTitle:@"Write"];
	[writeProgressIndicator setHidden:YES];
	[writeProgressIndicator stopAnimation:self];
}

//- (BOOL)writeISOCard:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3 format:(MTDataFormat)format
- (void)writeISOCardOp:(NSArray *)objects
{
	//NSArray *trackData = [mainObject readISOCard];
	AppController *mainObject = [objects objectAtIndex:0];
	NSString *track1 = [objects objectAtIndex:1];
	NSString *track2 = [objects objectAtIndex:2];
	NSString *track3 = [objects objectAtIndex:3];
	NSNumber *formatObject = [objects objectAtIndex:4];
	MTDataFormat format = [formatObject unsignedIntValue];
	
	// Call the main write method
	MTCommandStatus status = [mainObject writeISOCard:track1 track2:track2 track3:track3 format:format];
	
	//NSArray *trackData = [self readISOCard];
	[mainObject performSelectorOnMainThread:@selector(writeCardDelegate:) withObject:[NSNumber numberWithUnsignedInt:status] waitUntilDone:YES];
}

- (void)duplicateCardOp:(AppController *)mainObject
{
	// read data
	[duplicateStatus setStringValue:@"Please swipe the card to be read..."];
	NSArray *trackData = [self readISOCard];
	if ([duplicateOperation isCancelled])
	{
		DLOG(@"Duplicate cancelled");
		return;
	} else if (trackData == nil) {
		DLOG(@"Read error");
		return;
		// throw an error
	}
	
	NSString *track1 = [trackData objectAtIndex:0];
	NSString *track2 = [trackData objectAtIndex:1];
	NSString *track3 = [trackData objectAtIndex:2];
	
	// remove empty tracks
	if ([[track1 uppercaseString] isEqualToString:@"\x1B\x2B"])
		track1 = nil;
	if ([[track2 uppercaseString] isEqualToString:@"\x1B\x2B"])
		track2 = nil;
	if ([[track3 uppercaseString] isEqualToString:@"\x1B\x2B"])
		track3 = nil;
	
	// write data
	[duplicateStatus setStringValue:@"Please swipe the card to be written..."];
	if([self writeISOCard:track1 track2:track2 track3:track3 format:MTASCII] != MTStatusSuccess)
	{
		if ([duplicateOperation isCancelled])
		{
			DLOG(@"Duplicate cancelled");
			return;
		}
		// write failed
		// throw error
		DLOG(@"Some error writing");
		[duplicateStatus setStringValue:@"Write failed."];
	} else {
		DLOG(@"Success writing");
		[duplicateStatus setStringValue:@"Success!"];
	}
	[duplicateButton setTitle:@"Duplicate"];
	[duplicateProgressIndicator stopAnimation:self];
}

- (void)eraseCardOp:(NSArray *)objects
{
	//AppController *mainObject = [objects objectAtIndex:0];
	unichar commandCode[1];
	commandCode[0] = [[objects objectAtIndex:1] characterAtIndex:0];
	
	NSString *command = [NSString stringWithFormat:@"\x1B\x63%c", commandCode[0]];
	DLOG(@"command: %@", [command dataUsingEncoding:NSASCIIStringEncoding]);
	
	[port writeString:command usingEncoding:NSASCIIStringEncoding error:nil];
	
	while(![port bytesAvailable])
	{
		if ([eraseOperation isCancelled])
			return;
		[NSThread sleepForTimeInterval:0.01];
	}
	
	NSString *response = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	if (![response isEqualToString:@"\x1B\x30"])
	{
		// write failed
		DLOG(@"Erase failed (response: %@)", [response dataUsingEncoding:NSASCIIStringEncoding]);
		return;
	}
}

#pragma mark Class overrides

- (void)init
{
#ifdef DEBUG
	CFBundleRef bundle = CFBundleGetBundleWithIdentifier(
			(CFStringRef) @"com.iForgotSystems.MagTool");
	CFStringRef versStr = (CFStringRef) 
			CFBundleGetValueForInfoDictionaryKey(bundle,kCFBundleVersionKey);
	NSString *debugString = [NSString stringWithFormat:@"DEBUG MagTool %s (%s %s)", 
							 CFStringGetCStringPtr(versStr,kCFStringEncodingMacRoman), 
							 __DATE__, __TIME__];
	DLOG(debugString);
#endif
	/* initialize some variables */
	dataBuffer = [[NSMutableData dataWithCapacity:500] retain];
	resetCommand = [[NSString stringWithUTF8String:"\x1B\x61"] retain];	// "[ESC][a][ESC][a]"
	readCommand = [[NSString stringWithUTF8String:"\x1B\x72"] retain];	// "[ESC][r]"
	writeCommand = [[NSString stringWithUTF8String:"\x1B\x77"] retain];	// "[ESC][w]"
	commTestCommand = [[NSString stringWithUTF8String:"\x1B\x65"] retain];	// "[ESC][e]"
	allLEDOnCommand = [[NSString stringWithUTF8String:"\x1B\x82"] retain];
	sensorTestCommand = [[NSString stringWithUTF8String:"\x1B\x86"] retain];
	ramTestCommand = [[NSString stringWithUTF8String:"\x1B\x87"] retain];
	checkLeadingZerosCommand = [[NSString stringWithUTF8String:"\x1B\x6C"] retain];
	eraseCommand = [[NSString stringWithUTF8String:"\x1B\x63"] retain];
	setBPICommand = [[NSString stringWithUTF8String:"\x1B\x62"] retain];
	setBPCCommand = [[NSString stringWithUTF8String:"\x1B\x6F"] retain];
	setHiCoercivityCommand = [[NSString stringWithUTF8String:"\x1B\x78"] retain];
	setLoCoercivityCommand = [[NSString stringWithUTF8String:"\x1B\x79"] retain];
	getDeviceModelCommand = [[NSString stringWithUTF8String:"\x1B\x74"] retain];
	getFirmwareVersionCommand = [[NSString stringWithUTF8String:"\x1B\x76"] retain];
	getCoercivity = [[NSString stringWithUTF8String:"\x1B\x64"] retain];
	
	track1DataRead = @"";
	track2DataRead = @"";
	track3DataRead = @"";
	readTimeOut	= 0.25;
	
	operationQueue = [NSOperationQueue new];
	[super init];
}

- (void)dealloc
{
	[dataBuffer release];
	[resetCommand release];
	[readCommand release];
	[track1DataRead release];
	[track2DataRead release];
	[track3DataRead release];
	[super dealloc];
}

// called when the application initializes
- (void)awakeFromNib
{

#ifdef DEBUG
	/* Show version and build time */
	[versionDisplay setHidden:NO];
	CFBundleRef bundle = CFBundleGetBundleWithIdentifier(
							(CFStringRef) @"com.iForgotSystems.MagTool");
	CFStringRef versStr = (CFStringRef) 
			CFBundleGetValueForInfoDictionaryKey(bundle,kCFBundleVersionKey);
	[versionDisplay setStringValue:
	 [NSString stringWithFormat:@"DEBUG MagTool %s (%s %s)", 
	  CFStringGetCStringPtr(versStr,kCFStringEncodingMacRoman), 
	  __DATE__, __TIME__]];
	[outputTextView insertText:
	 [NSString stringWithFormat:@"DEBUG MagTool %s (%s %s)\n", 
	  CFStringGetCStringPtr(versStr,kCFStringEncodingMacRoman),
	  __DATE__, __TIME__]];
#endif
	
	[inputTextField setStringValue: @"ati"]; // will ask for modem type
	
	/* register for port add/remove notification */
	[[NSNotificationCenter defaultCenter] 
					  addObserver:self 
						 selector:@selector(didAddPorts:) 
							 name:AMSerialPortListDidAddPortsNotification 
						   object:nil];
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(didRemovePorts:) 
		name:AMSerialPortListDidRemovePortsNotification 
		object:nil];
	// initialize port list to arm notifications
	[AMSerialPortList sharedPortList]; 
	
	/* Populate the Popup Button with a list of available devices */
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *aPort;
	while (aPort = [enumerator nextObject]) {
#ifdef DEBUG
		[outputTextView insertText:
			[NSString stringWithFormat:@"Port found: %@, %@, %@\n", 
			 [aPort type], [aPort name], [aPort bsdPath]]];
#endif
		[deviceSelector addItemWithTitle:[aPort bsdPath]];
	}
	
	if ([deviceSelector numberOfItems] > 0) {
		[deviceSelector selectItemAtIndex:0];
		[self initPort];
		[outputTextView insertText:[NSString stringWithFormat:@"%i bytes available in input buffer\n", [port bytesAvailable]]];
	}
	else
		[outputTextView insertText:@"No devices found\r"];
	
	
	/* Setup app mode toolbar buttons */
	//[debugMode 
	[appToolbar setSelectedItemIdentifier:[debugMode itemIdentifier]];
	
	[self initDevice];
}

#pragma mark IBActions

- (IBAction)deviceChanged:(id)sender
{
	NSLog(@"Dev changed");
	[deviceChangedProgress setHidden:NO];
	[deviceChangedProgress startAnimation:self];
	[self initPort];
	[self initDevice];
	[deviceChangedProgress setHidden:YES];
	[deviceChangedProgress stopAnimation:self];
}

- (IBAction)switchAppMode:(id)sender
{
	NSLog(@"SwitchAppMode");
	[outputTextView insertText:@"Switch app mode activated\n"];
}

- (IBAction)sendString:(id)sender
{
	
}

- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:[debugMode itemIdentifier], [readMode itemIdentifier], [writeMode itemIdentifier], [duplicateMode itemIdentifier], nil];	
}

// Tell the device to read a card and display the data once the card is swiped
- (IBAction)readCard:(id)sender
{
	if ([[readButton title] isEqualToString:@"Read"])
	{
		readOperation = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(readISOCardOp:) object:self] autorelease];	// automagically retained when added to operation queue
		if ([[operationQueue operations] count] != 0) {
			DLOG(@"WARN: Operation queue has prior queued operations...");
		}
		[readButton setTitle:@"Cancel"];
		[readProgressIndicator setHidden:NO];
		[readProgressIndicator startAnimation:self];
		[operationQueue addOperation:readOperation];	// retains readOperation
		return;
	} else if ([[readButton title] isEqualToString:@"Cancel"]) {
		[readOperation cancel];
		[self initDevice];
		[readButton setTitle:@"Read"];
		[readProgressIndicator setHidden:YES];
		[readProgressIndicator stopAnimation:self];
	}
}

- (IBAction)writeCard:(id)sender
{	
	if ([[writeButton title] isEqualToString:@"Write"])
	{
		NSString *track1 = [track1Write stringValue];
		NSString *track2 = [track2Write stringValue];
		NSString *track3 = [track3Write stringValue];
		
		// turn off tracks that are not selected/enabled for write
		if ([track1WriteEnable state] == NSOffState)
			track1 = nil;
		if ([track2WriteEnable state] == NSOffState)
			track2 = nil;
		if ([track3WriteEnable state] == NSOffState)
			track3 = nil;
		
		MTDataFormat format = [writeFormat selectedSegment];
		
		switch ([writeFormat selectedSegment]) {
			case 0:
			case 1:
			case 2:
			case 3:
				writeOperation = [[[NSInvocationOperation alloc] 
									initWithTarget:self 
									selector:@selector(writeISOCardOp:) 
									object:[NSArray arrayWithObjects:self, [track1Write stringValue], [track2Write stringValue], [track3Write stringValue], [NSNumber numberWithUnsignedInt:format], nil]] autorelease]; // automagically retained when added to operation queue
				//[self writeISOCard:[track1Write stringValue] track2:[track2Write stringValue] track3:[track3Write stringValue] format:format];
				break;
			case 4:
				// Create writeOperation
				//[self writeRawCard:[track1Write stringValue] track2:[track2Write stringValue] track3:[track3Write stringValue]];
				break;
			default:
				DLOG(@"Cryptic ERROR: writeFormat out of range");
				return;
				break;
		}
		
		[writeButton setTitle:@"Cancel"];
		[writeProgressIndicator setHidden:NO];
		[writeProgressIndicator startAnimation:self];
		
		if ([[operationQueue operations] count] != 0) {
			DLOG(@"WARN: Operation queue has prior queued operations...");
		}
		[operationQueue addOperation:writeOperation];	// retains writeOperation
	} else if ([[writeButton title] isEqualToString:@"Cancel"]) {
		[writeOperation cancel];
		[self initDevice];
		[writeButton setTitle:@"Read"];
		[writeProgressIndicator setHidden:YES];
		[writeProgressIndicator stopAnimation:self];
	}
}

- (IBAction)resetDevice:(id)sender
{
	DLOG(@"Resetting device");
	[self initPort];
	[self initDevice];
}

- (IBAction)readDisplayChanged:(id)sender
{
	[self displayReadData];	
}

- (IBAction)writeFormatChangedCustom:(id)sender
{
	// Select custom format button
	[writeFormat setSelectedSegment:3];
}

- (IBAction)writeFormatTemplateChanged:(id)sender
{
	switch ([writeFormat selectedSegment]) {
		case 0:
			// ISO
			[track1BPC setEnabled:NO];
			[track2BPC setEnabled:NO];
			[track3BPC setEnabled:NO];
			[track1BPI setEnabled:NO];
			[track2BPI setEnabled:NO];
			[track3BPI setEnabled:NO];
			[writeDisplay setEnabled:YES];
			[track1BPC selectItemWithTitle:@"7 bpc"];
			[track2BPC selectItemWithTitle:@"5 bpc"];
			[track3BPC selectItemWithTitle:@"5 bpc"];
			[track1BPI selectItemWithTitle:@"210 bpi"];
			[track2BPI selectItemWithTitle:@"75 bpi"];
			[track3BPI selectItemWithTitle:@"210 bpi"];
			break;
		case 1:
			// AAMVA
			[track1BPC setEnabled:NO];
			[track2BPC setEnabled:NO];
			[track3BPC setEnabled:NO];
			[track1BPI setEnabled:NO];
			[track2BPI setEnabled:NO];
			[track3BPI setEnabled:NO];
			[writeDisplay setEnabled:YES];
			[track1BPC selectItemWithTitle:@"7 bpc"];
			[track2BPC selectItemWithTitle:@"5 bpc"];
			[track3BPC selectItemWithTitle:@"7 bpc"];
			[track1BPI selectItemWithTitle:@"210 bpi"];
			[track2BPI selectItemWithTitle:@"75 bpi"];
			[track3BPI selectItemWithTitle:@"210 bpi"];
			break;
		case 2:
			// CADMV
			[track1BPC setEnabled:NO];
			[track2BPC setEnabled:NO];
			[track3BPC setEnabled:NO];
			[track1BPI setEnabled:NO];
			[track2BPI setEnabled:NO];
			[track3BPI setEnabled:NO];
			[writeDisplay setEnabled:YES];
			[track1BPC selectItemWithTitle:@"6 bpc"];
			[track2BPC selectItemWithTitle:@"5 bpc"];
			[track3BPC selectItemWithTitle:@"7 bpc"];
			[track1BPI selectItemWithTitle:@"210 bpi"];
			[track2BPI selectItemWithTitle:@"75 bpi"];
			[track3BPI selectItemWithTitle:@"210 bpi"];
			break;
		case 3:
			// custom
			[track1BPC setEnabled:YES];
			[track2BPC setEnabled:YES];
			[track3BPC setEnabled:YES];
			[track1BPI setEnabled:YES];
			[track2BPI setEnabled:YES];
			[track3BPI setEnabled:YES];
			[writeDisplay setEnabled:YES];
			break;
		case 4:
			// raw
			[track1BPC setEnabled:NO];
			[track2BPC setEnabled:NO];
			[track3BPC setEnabled:NO];
			[track1BPI setEnabled:NO];
			[track2BPI setEnabled:NO];
			[track3BPI setEnabled:NO];
			[writeDisplay setEnabled:NO];
			[writeDisplay setSelectedSegment:1];	// hex input only
			break;
		default:
			DLOG(@"Cryptic ERROR: out of range");
			break;
	}
}

- (IBAction)readFormatTemplateChanged:(id)sender
{
	switch ([readFormat selectedSegment]) {
		case 0:
			// ISO
			[track1BPCRead setEnabled:NO];
			[track2BPCRead setEnabled:NO];
			[track3BPCRead setEnabled:NO];
			[track1BPIRead setEnabled:NO];
			[track2BPIRead setEnabled:NO];
			[track3BPIRead setEnabled:NO];
			[readDisplay setEnabled:YES];
			[track1BPCRead selectItemWithTitle:@"7 bpc"];
			[track2BPCRead selectItemWithTitle:@"5 bpc"];
			[track3BPCRead selectItemWithTitle:@"5 bpc"];
			[track1BPIRead selectItemWithTitle:@"210 bpi"];
			[track2BPIRead selectItemWithTitle:@"75 bpi"];
			[track3BPIRead selectItemWithTitle:@"210 bpi"];
			break;
		case 1:
			// AAMVA
			[track1BPCRead setEnabled:NO];
			[track2BPCRead setEnabled:NO];
			[track3BPCRead setEnabled:NO];
			[track1BPIRead setEnabled:NO];
			[track2BPIRead setEnabled:NO];
			[track3BPIRead setEnabled:NO];
			[readDisplay setEnabled:YES];
			[track1BPCRead selectItemWithTitle:@"7 bpc"];
			[track2BPCRead selectItemWithTitle:@"5 bpc"];
			[track3BPCRead selectItemWithTitle:@"7 bpc"];
			[track1BPIRead selectItemWithTitle:@"210 bpi"];
			[track2BPIRead selectItemWithTitle:@"75 bpi"];
			[track3BPIRead selectItemWithTitle:@"210 bpi"];
			break;
		case 2:
			// CA DMV
			[track1BPCRead setEnabled:NO];
			[track2BPCRead setEnabled:NO];
			[track3BPCRead setEnabled:NO];
			[track1BPIRead setEnabled:NO];
			[track2BPIRead setEnabled:NO];
			[track3BPIRead setEnabled:NO];
			[readDisplay setEnabled:YES];
			[track1BPCRead selectItemWithTitle:@"6 bpc"];
			[track2BPCRead selectItemWithTitle:@"5 bpc"];
			[track3BPCRead selectItemWithTitle:@"7 bpc"];
			[track1BPIRead selectItemWithTitle:@"210 bpi"];
			[track2BPIRead selectItemWithTitle:@"75 bpi"];
			[track3BPIRead selectItemWithTitle:@"210 bpi"];
			break;
		case 3:
			// custom
			[track1BPCRead setEnabled:YES];
			[track2BPCRead setEnabled:YES];
			[track3BPCRead setEnabled:YES];
			[track1BPIRead setEnabled:YES];
			[track2BPIRead setEnabled:YES];
			[track3BPIRead setEnabled:YES];
			[readDisplay setEnabled:YES];
			break;
		case 4:
			// raw
			[track1BPCRead setEnabled:NO];
			[track2BPCRead setEnabled:NO];
			[track3BPCRead setEnabled:NO];
			[track1BPIRead setEnabled:NO];
			[track2BPIRead setEnabled:NO];
			[track3BPIRead setEnabled:NO];
			[readDisplay setEnabled:NO];
			[readDisplay setSelectedSegment:1];	// hex input only
			break;
		default:
			DLOG(@"Cryptic ERROR: out of range");
			break;
	}
}

- (IBAction)writeTrackEnableChanged:(id)sender
{
	if([track1WriteEnable state] == NSOnState)
		[track1Write setEnabled:YES];
	else 
		[track1Write setEnabled:NO];
	
	if([track2WriteEnable state] == NSOnState)
		[track2Write setEnabled:YES];
	else 
		[track2Write setEnabled:NO];
	
	if([track3WriteEnable state] == NSOnState)
		[track3Write setEnabled:YES];
	else 
		[track3Write setEnabled:NO];
}

- (IBAction)eraseCard:(id)sender
{
	if ([[eraseButton title] isEqualToString:@"Erase"])
	{
		unichar commandCode[1];
		commandCode[0] = [track1EraseEnable state] + 2*[track2EraseEnable state] + 4*[track3EraseEnable state];
		
		NSArray *args = [NSArray arrayWithObjects:self, [NSString stringWithCharacters:commandCode length:1], nil];
		eraseOperation == [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(eraseCardOp:) object:args] autorelease];
		[eraseProgressIndicator startAnimation:self];
		[eraseButton setTitle:@"Cancel"];
	} else if ([[eraseButton title] isEqualToString:@"Cancel"]) {
		[eraseOperation retain];
		[eraseOperation cancel];
		// Wait for op to finish
		while (![eraseOperation isFinished])
			[NSThread sleepForTimeInterval:0.01];
		[eraseOperation release];
		
		[eraseButton setTitle:@"Erase"];
		[self initDevice];
		[eraseProgressIndicator stopAnimation:self];
	}
	/*
	NSString *command = [NSString stringWithFormat:@"\x1B\x63%c", commandCode[0]];
	DLOG(@"command: %@", [command dataUsingEncoding:NSASCIIStringEncoding]);
	
	[port writeString:command usingEncoding:NSASCIIStringEncoding error:nil];
	
	while(![port bytesAvailable])
	{
		[NSThread sleepForTimeInterval:0.01];
	}
	
	NSString *response = [port readBytes:2 usingEncoding:NSASCIIStringEncoding error:nil];
	if (![response isEqualToString:@"\x1B\x30"])
	{
		// write failed
		DLOG(@"Erase failed (response: %@)", [response dataUsingEncoding:NSASCIIStringEncoding]);
		return;
	}
	 */
}

- (IBAction)duplicateCard:(id)sender
{
	if ([[duplicateButton title] isEqualToString:@"Duplicate"])
	{
		duplicateOperation = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(duplicateCardOp:) object:self] autorelease];	
		[duplicateProgressIndicator startAnimation:self];
		[duplicateButton setTitle:@"Cancel"];
		[operationQueue addOperation:duplicateOperation];	// retains readOperation
		return;
	} else if ([[duplicateButton title] isEqualToString:@"Cancel"]) {
		[duplicateOperation retain];
		[duplicateOperation cancel];
		// Wait for op to finish
		while (![duplicateOperation isFinished])
			[NSThread sleepForTimeInterval:0.01];
		[duplicateOperation release];
		
		[duplicateButton setTitle:@"Duplicate"];
		[duplicateStatus setStringValue:@"Idle."];
		[self initDevice];
		[duplicateProgressIndicator stopAnimation:self];
	}
}

#pragma mark Delegates

// delegate called when data was read in the background
// Adds ports to device list
// called by: portsWereAdded (AMSerialPortList.m)
- (void)didAddPorts:(NSNotification *)theNotification
{
#ifdef DEBUG
	[outputTextView insertText:@"didAddPorts:"];
	[outputTextView insertText:@"\r"];
	[outputTextView insertText:[[theNotification userInfo] description]];
	[outputTextView insertText:@"\r"];
	[outputTextView setNeedsDisplay:YES];
#endif
	/* add ports to device list */
	NSMutableArray *addedPorts = [[theNotification userInfo] 
								  objectForKey:AMSerialPortListAddedPorts];
	for (int i=0; i < [addedPorts count]; i++) {
		[deviceSelector addItemWithTitle:[[addedPorts objectAtIndex:i] bsdPath]];
	}
	[self initPort];
	[self initDevice];
}

// Removes ports from device list
// called by: portsWereRemoved (AMSerialPortList.m)
- (void)didRemovePorts:(NSNotification *)theNotification
{
#ifdef DEBUG
	[outputTextView insertText:@"didRemovePorts:"];
	[outputTextView insertText:@"\r"];
	[outputTextView insertText:[[theNotification userInfo] description]];
	[outputTextView insertText:@"\r"];
	[outputTextView insertText:[NSString stringWithFormat:@"%d",
								selectedDevice]];
	[outputTextView insertText:@"\r"];
	[outputTextView setNeedsDisplay:YES];
#endif
	/* remove ports from device list */
	NSMutableArray *removedPorts = [[theNotification userInfo] 
									objectForKey:AMSerialPortListRemovedPorts];
	for (int i=0; i < [removedPorts count]; i++) {
		// ports are automatically closed when removed by the AMSerialPort 
		// framework, so we don't have to check and manually close them
		[deviceSelector removeItemWithTitle:[[removedPorts objectAtIndex:i]
											 bsdPath]];
	}
	[self initPort];
	[self initDevice];
}

- (void)serialPortReadData:(NSDictionary *)dataDictionary
{
	DLOG(@"SerialPortReadData called: %@", dataDictionary);

	// this method is called if data arrives 
	// @"data" is the actual data, @"serialPort" is the sending port
	AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
	NSData *data = [dataDictionary objectForKey:@"data"];
	if ([data length] > 0) {
		[outputTextView insertText:[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]];
		[dataBuffer appendData:data];
		
		unhandledData = YES;
		// continue listening
		[sendPort readDataInBackground];
	} else { // port closed
		[outputTextView insertText:@"port closed\r"];
	}
	[outputTextView setNeedsDisplay:YES];
	[outputTextView displayIfNeeded];
}

- (void)serialPortWriteProgress:(NSDictionary *)dataDictionary
{
	DLOG(@"Write progress received: $@", dataDictionary);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

@end
