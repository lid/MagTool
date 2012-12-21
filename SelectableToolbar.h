//
//  SelectableToolbar.h
//  MagTool
//
//  Created by Dustin Li on 7/12/09.
//  Copyright 2009 iForgot Systems. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SelectableToolbar : NSToolbar {
	IBOutlet NSToolbarItem *debugMode;
	IBOutlet NSToolbarItem *readMode;
	IBOutlet NSToolbarItem *writeMode;
	IBOutlet NSToolbarItem *duplicateMode;
}
- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;

@end
