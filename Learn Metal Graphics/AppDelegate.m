//
//  AppDelegate.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"

@implementation AppDelegate
{
	MainWindowController* mainWindowController;
}

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	MainWindowController* mainWindowController = [[MainWindowController alloc] init];
	[mainWindowController showWindow:self];
	self->mainWindowController = mainWindowController;
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	// Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
	return YES;
}

@end
