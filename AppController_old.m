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
		DLOG(@"Displaying as ASCII");
		[track1Read setStringValue:track1DataRead];
		[track2Read setStringValue:track2DataRead];
		[track3Read setStringValue:track3DataRead];
	} else {
		// Display as hex
		DLOG(@"Displaying as hex");
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
		if ([port bytesAvailable] > 0) {
			// throw an error
			DLOG(@"Could not flush the input buffer.");
		}
	}
}

// Helper function to reset and test the device
// Should be called only after the port is opened
- (void)initDevice
{
	if (!port || ![port isOpen]) {
		DLOG(@"Port is not open!");
		// throw an error
		return;
	}
	
	// Reset the device
	if (![port writeString:resetCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		DLOG(@"Reset error occured!");
	}
	
	[self flushSerialInputBuffer];
	
	// Test communication
	if (![port writeString:commTestCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		DLOG(@"Test comm occured!");
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
	}
	
	// Flash LEDs
	[port writeString:allLEDOnCommand usingEncoding:NSASCIIStringEncoding error:NULL];

	[self checkLeadingZeros];
}

// Query device for # of leading zeros on each track
- (void)checkLeadingZeros
{
	[port writeString:checkLeadingZerosCommand usingEncoding:NSASCIIStringEncoding error:NULL];
	NSData *response = [port readBytes:3 error:nil];
	if (![response length]) {
		DLOG(@"No response to checkLeadingZeros");
		return;
		// throw error
	}
	const unsigned char *data = [response bytes];
	leadingZerosTracks13 = data[1];
	leadingZerosTrack2 = data[2];
	DLOG(@"Track 1 & 3: %d    Track 2: %d", leadingZerosTracks13, leadingZerosTrack2);
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
			
#ifdef DEBUG
			[outputTextView insertText:@"Port opened.\r"];
			[outputTextView setNeedsDisplay:YES];
			[outputTextView displayIfNeeded];
#endif

			// listen for data in a separate thread
			//[port readDataInBackground];
			
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
	ramTestCommand = [[NSString stringWithUTF8String:"\x1B\x87"] retain];

	
	track1DataRead = @"";
	track2DataRead = @"";
	track3DataRead = @"";
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
	[self initPort];
	[self initDevice];
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
	if (!port || ![port isOpen]) {
		DLOG(@"readCard called but no serial port is open!");
		// throw an error
		return;
	}
	
	if (unhandledData) {
		DLOG(@"WARNING: unhandled data when reading card!");
		// throw an error
	}
	
	[self clearDataBuffer];
	[self flushSerialInputBuffer];
	
	if (![port writeString:readCommand usingEncoding:NSASCIIStringEncoding error:NULL])
	{
		// throw an error
	}
	
	// Wait for the user to swipe card before trying to read the data
	while(![port bytesAvailable])
	{
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
	DLOG(@"deviceStatus: %@", deviceStatus);	// display ASCII string
	DLOG(@"deviceStatus: %@", [[self convertToNSData:deviceStatus] autorelease]);						// display as hex
	NSArray *substrings = [unparsedData componentsSeparatedByString:@"\x1B"];
	DLOG(@"Substrings: %@", substrings);
	
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
	
	if (track1DataRead)
		[track1DataRead release];
	if (track2DataRead)
		[track2DataRead release];
	if (track3DataRead)
		[track3DataRead release];
	
	// Find track 1 data between [1B 01] and [1B 02]
	NSString *firstPart = [[unparsedData componentsSeparatedByString:@"\x1B\x01"] objectAtIndex:1];
	track1DataRead = [[[firstPart componentsSeparatedByString:@"\x1B\x02"] objectAtIndex:0] retain];
	DLOG(@"Track 1 data: %@", [[self convertToNSData:track1DataRead] autorelease]);
	
	// Find track 2 data between [1B 02] and [1B 03]
	NSString *secondPart = [[unparsedData componentsSeparatedByString:@"\x1B\x02"] objectAtIndex:1];
	track2DataRead = [[[secondPart componentsSeparatedByString:@"\x1B\x03"] objectAtIndex:0] retain];
	DLOG(@"Track 2 data: %@", [[self convertToNSData:track2DataRead] autorelease]);
	
	// Find track 3 data between [1B 03] and [3F 1C]
	NSString *thirdPart = [[unparsedData componentsSeparatedByString:@"\x1B\x03"] objectAtIndex:1];
	track3DataRead = [[[thirdPart componentsSeparatedByString:@"\x3F\x1C"] objectAtIndex:0] retain];
	DLOG(@"Track 3 data: %@", [[self convertToNSData:track3DataRead] autorelease]);
	
	deviceStatus = [deviceStatus substringFromIndex:1];
	if (![deviceStatus isEqualToString:@"\x30"]) {
		DLOG(@"Read error");
		// throw an error
	}
	
	[self displayReadData];
	/*
	while([port bytesAvailable])
	{
		[NSThread sleepForTimeInterval:0.1];
	}
	 */
}

- (IBAction)writeCard:(id)sender
{
	
}

- (IBAction)resetDevice:(id)sender
{
	DLOG(@"Resetting device");

	[self initDevice];
}

- (IBAction)readDisplayChanged:(id)sender
{
	[self displayReadData];	
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
