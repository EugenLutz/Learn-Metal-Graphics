//
//  MainWindowController.m
//  Learn Metal Graphics
//
//  Created by Евгений Лютц on 06.08.20.
//  Copyright © 2020 Eugene Lutz. All rights reserved.
//

#import "MainWindowController.h"
@import MetalKit;
#import "SceneRenderer.h"

@implementation MainWindowController
{
	id<MTLDevice> _metalDevice;
	SceneRenderer* _sceneRenderer;
}

- (NSNibName)windowNibName
{
	return @"MainWindowController";
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
	NSView* contentView = self.window.contentView;
	assert([contentView isKindOfClass:MTKView.class]);
	MTKView* metalView = (MTKView*)contentView;
	
	_metalDevice = MTLCreateSystemDefaultDevice();
	assert(_metalDevice);
	
	metalView.device = _metalDevice;
	metalView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
	metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
	metalView.framebufferOnly = YES;
	metalView.sampleCount = 1;
	
	_sceneRenderer = [[SceneRenderer alloc] initWithMetalKitView:metalView];
	assert(_sceneRenderer);
	metalView.delegate = _sceneRenderer;
}

- (void)mouseDragged:(NSEvent*)event
{
	//NSLog(@"mouseDragged");
}

- (void)rightMouseDragged:(NSEvent*)event
{
	//NSLog(@"rightMouseDragged");
}

- (void)keyDown:(NSEvent*)event
{
	NSLog(@"keyDown");
}

- (void)keyUp:(NSEvent*)event
{
	NSLog(@"keyUp");
}

@end
