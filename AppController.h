//
//  AppController.h
//  MagTool
//
//  Created by Dustin Li on 7/12/09.
//  Copyright 2009 iForgot Systems. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"
#import "SelectableToolbar.h"
#import <BWToolkitFramework/BWToolkitFramework.h>

#ifdef DEBUG
// DLOG takes a NSString and any number of format args
// DLOG(@"Hello! I have %d lives.", 9);
#define DLOG(fmt, ...) NSLog([@"[%@:%s:%d] " stringByAppendingString:fmt], [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __func__, __LINE__, ##__VA_ARGS__)
#else
#define DLOG(...)
#endif

// Main controller for the app. Handles all events from the UI and updates
// the UI as necessary.
@interface AppController : NSObject {
	@private
	// IBOutlets
	IBOutlet NSToolbarItem *debugMode;
	IBOutlet NSToolbarItem *readMode;
	IBOutlet NSToolbarItem *writeMode;
	IBOutlet NSToolbarItem *duplicateMode;
	IBOutlet SelectableToolbar *appToolbar;
	
	// debug panel
	IBOutlet NSTextField *inputTextField;
	IBOutlet NSTextView *outputTextView;
	
	// Setup panel
	IBOutlet NSPopUpButton *deviceSelector;
	IBOutlet NSTextField *versionDisplay;
	IBOutlet NSTextField *deviceFirmware;
	IBOutlet NSTextField *deviceModel;
	IBOutlet NSProgressIndicator *deviceChangedProgress;
	
	// read panel
	IBOutlet NSTextField *track1Read;
	IBOutlet NSTextField *track2Read;
	IBOutlet NSTextField *track3Read;
	//IBOutlet NSMatrix *readFormat;
	//IBOutlet NSMatrix *readDisplay;
	IBOutlet NSButton *readButton;
	IBOutlet NSSegmentedControl *readFormat;
	IBOutlet NSSegmentedControl *readDisplay;
	IBOutlet NSPopUpButton *track1BPCRead;
	IBOutlet NSPopUpButton *track2BPCRead;
	IBOutlet NSPopUpButton *track3BPCRead;
	IBOutlet NSPopUpButton *track1BPIRead;
	IBOutlet NSPopUpButton *track2BPIRead;
	IBOutlet NSPopUpButton *track3BPIRead;
	IBOutlet NSProgressIndicator *readProgressIndicator;
	
	// write panel
	IBOutlet NSTextField *track1Write;
	IBOutlet NSTextField *track2Write;
	IBOutlet NSTextField *track3Write;
	IBOutlet NSButton *writeButton;
	IBOutlet NSButton *track1WriteEnable;
	IBOutlet NSButton *track2WriteEnable;
	IBOutlet NSButton *track3WriteEnable;
	IBOutlet NSSegmentedControl *writeCoercivity;		// hi or lo
	IBOutlet NSSegmentedControl *writeFormat;			// raw or ISO
	IBOutlet NSSegmentedControl *writeDisplay;		// hex or ASCII (for ISO format only)
	IBOutlet NSPopUpButton *track1BPC;
	IBOutlet NSPopUpButton *track2BPC;
	IBOutlet NSPopUpButton *track3BPC;
	IBOutlet NSPopUpButton *track1BPI;
	IBOutlet NSPopUpButton *track2BPI;
	IBOutlet NSPopUpButton *track3BPI;
	IBOutlet NSProgressIndicator *writeProgressIndicator;
	
	// duplicate panel
	IBOutlet NSTextField *duplicateStatus;
	IBOutlet NSButton *duplicateButton;
	IBOutlet NSProgressIndicator *duplicateProgressIndicator;
	
	// erase panel
	IBOutlet NSButton *track1EraseEnable;
	IBOutlet NSButton *track2EraseEnable;
	IBOutlet NSButton *track3EraseEnable;
	IBOutlet NSButton *eraseButton;
	IBOutlet NSProgressIndicator *eraseProgressIndicator;
	
	// The serial port used to communicate with the device
	AMSerialPort *port;
	NSInteger selectedDevice;	// deprecated?
	
	// Commands to control the MSR206
	NSString *stringEsc;
	NSString *resetCommand;
	NSString *readCommand;
	NSString *writeCommand;
	NSString *commTestCommand;
	NSString *allLEDOnCommand;
	NSString *sensorTestCommand;
	NSString *ramTestCommand;
	NSString *checkLeadingZerosCommand;
	NSString *eraseCommand;
	NSString *setBPICommand;
	NSString *setBPCCommand;
	NSString *setHiCoercivityCommand;
	NSString *setLoCoercivityCommand;
	NSString *getDeviceModelCommand;
	NSString *getFirmwareVersionCommand;
	NSString *getCoercivity;
	
	// ASCII format data from each track
	NSString *track1DataRead;
	NSString *track2DataRead;
	NSString *track3DataRead;
	
	NSInteger leadingZerosTracks13;	// tracks 1 and 3 use same # of leading zeros
	NSInteger leadingZerosTrack2;
	
	NSTimeInterval readTimeOut;

	NSOperationQueue *operationQueue;
	NSInvocationOperation *readOperation;
	NSInvocationOperation *writeOperation;
	NSInvocationOperation *duplicateOperation;
	NSInvocationOperation *eraseOperation;
	
	NSMutableData *dataBuffer;
	BOOL unhandledData;
	

}

// Types
typedef int MTDataFormat;
enum MTDataFormat {
	MTASCII = 0,
	MTHex = 1
};

typedef unsigned int MTCommandStatus;
enum MTCommandStatus {
	MTStatusPortBroken = 0,
	MTStatusBPCBroken = 1,
	MTStatusCoercivityBroken = 2,
	MTStatusBadSentinel = 3,
	MTStatusHexUneven = 4,
	MTStatusInvalidHexChars = 5,
	MTStatusBadResponse = 6,
	MTStatusSuccess = 7,
	MTStatusCancelled = 8,
	MTStatusEmptyStrings = 9,
};

// helper methods
- (AMSerialPort *)port;
- (void)clearDataBuffer;
- (void)setPort:(AMSerialPort *)newPort;
- (void)initPort;
- (void)checkLeadingZeros;
- (MTCommandStatus)writeISOCard:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3 format:(MTDataFormat)format;
- (void)writeRawCard:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3;
- (NSArray *)readISOCard;

// IBActions
- (IBAction)sendString:(id)sender;
- (IBAction)deviceChanged:(id)sender;
- (IBAction)switchAppMode:(id)sender;
- (IBAction)readCard:(id)sender;
- (IBAction)writeCard:(id)sender;
- (IBAction)resetDevice:(id)sender;
- (IBAction)readDisplayChanged:(id)sender;
- (IBAction)writeFormatChangedCustom:(id)sender;
- (IBAction)writeFormatTemplateChanged:(id)sender;
- (IBAction)readFormatTemplateChanged:(id)sender;
- (IBAction)writeTrackEnableChanged:(id)sender;
- (IBAction)eraseCard:(id)sender;
- (IBAction)duplicateCard:(id)sender;

// delegates
- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;						// SelectableToolbar // Deprecated
- (void)serialPortReadData:(NSDictionary *)dataDictionary;									// AMSerialPort
- (void)serialPortWriteProgress:(NSDictionary *)dataDictionary;								// AMSerialPort
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication;	// Application

@end
