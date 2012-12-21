//
//  SelectableToolbar.m
//  MagTool
//
//  Created by Dustin Li on 7/12/09.
//  Copyright 2009 iForgot Systems. All rights reserved.
//

#import "SelectableToolbar.h"


@implementation SelectableToolbar

- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
	NSLog(@"set selectable item id's");
	return [NSArray arrayWithObjects:[debugMode itemIdentifier], [readMode itemIdentifier], [writeMode itemIdentifier], [duplicateMode itemIdentifier], nil];	
}

@end
