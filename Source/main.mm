#include <Cocoa/Cocoa.h>
#include <CoreGraphics/CoreGraphics.h>

#include "Model.h"

#include "AppleRemote.h"
#include "VolumeKeys.h"

#include "SerialPort.h"
#include "Scripting.h"

////////////////////////////////////////////////////////////////


@class MenubarController;

@class UserInputController;

@interface AmpControllerApp: NSObject <NSApplicationDelegate>
{
@private
	MenubarController*		_menubarController;
	
	UserInputController*	_userInput;
	
	AmpControllerModel*		_model;
	
	Scripting*				_scripting;
	
	SerialPort*				_serialPort;
}

@end


////////////////////////////////////////////////////////////////


@interface UserInputController: NSObject
{
@private
	AmpControllerModel*		_model;
	
	IInputSource*			_keyboard;
	IInputSource*			_appleRemote;
}

- (id)initWithModel:(AmpControllerModel*)model;

@end


////////////////////////////////////////////////////////////////


@class MenubarView;
@class SettingsWindowController;

@interface MenubarController: NSObject
{
@private
	MenubarView*				_menubarView;
	NSMenuItem*					_detailItem;
	
	AmpControllerModel*			_model;
	
	SettingsWindowController*	_settingsWindow;
}

- (id)initWithModel:(AmpControllerModel*)model;

@property (nonatomic, strong, readonly) MenubarView* statusItemView;


@end


////////////////////////////////////////////////////////////////


@interface SettingsWindowController: NSWindowController
{
@private
	AmpControllerModel*		_model;
}

@property IBOutlet NSWindow*			portChooserWindow;
@property IBOutlet NSTextField*			portChooserPath;

@property IBOutlet NSPopUpButton*		serialPortChooser;
@property IBOutlet NSPopUpButton*		deviceModelChooser;
@property IBOutlet NSTextField*			deviceStatus;
@property IBOutlet NSButton*			autoStartButton;

- (id)initWithModel:(AmpControllerModel*)model;

- (void)showWindow:(id)sender;

@end

////////////////////////////////////////////////////////////////

typedef enum
{
	MenubarViewImageSlot_normal = 0,
	MenubarViewImageSlot_highlight = 1,
	
	MenubarViewImageSlot__pastEnd
} MenubarViewImageSlot;

@interface MenubarView: NSView <NSMenuDelegate>
{
@private
	NSImage*		_image[MenubarViewImageSlot__pastEnd];
	NSStatusItem*	_statusItem;
	BOOL			_isHighlighted;
}

- (id)initWithStatusItem:(NSStatusItem*)statusItem;

- (void)setImage:(NSImage*)newImage forSlot:(MenubarViewImageSlot)slot;
- (void)setMenu:(NSMenu*)menu;
- (void)setHighlighted:(BOOL)newFlag;

@property (nonatomic, strong, readonly) NSStatusItem* statusItem;
@property (nonatomic, setter = setHighlighted:) BOOL isHighlighted;

@end


////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

@implementation AmpControllerApp

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
	_model = [[AmpControllerModel alloc] init];
	
	_userInput = [[UserInputController alloc] initWithModel:_model];
	
	_menubarController = [[MenubarController alloc] initWithModel:_model];
	
	[_model onChanged:@"autostart" call:@selector(onUpdateAutoStart:) on:self];
	
	[_model onChanged:@"serialPort" call:@selector(onSerialPortChanged:) on:self];
	[_model onChanged:@"serialOutput" call:@selector(onSerialOutput:) on:self];
	[self openSerialPort:[_model serialPort] baudRate:9600];	//@@script controlled baud

	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(onSystemWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(onSystemDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
	
	_scripting = [[Scripting alloc] initWithModel:_model];
}

- (void)onUpdateAutoStart:(NSNotification*)notification
{
	LSSharedFileListRef loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil);
	
	// take a snapshot of the existing login items
	unsigned int ignore;
	NSArray* loginItemsArray = (__bridge NSArray*)LSSharedFileListCopySnapshot(loginItems, &ignore);

	// this is our path - we need to see if it exists in the login items
	NSString* applicationPath = [[NSBundle mainBundle] bundlePath];
	LSSharedFileListItemRef foundItem = nil;
	
	// try to find a login item for us
	for(id item in loginItemsArray)
	{
		LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)item;
		CFURLRef itemPath = nil;
		if(LSSharedFileListItemResolve(itemRef, kLSSharedFileListDoNotMountVolumes, (CFURLRef*)&itemPath, nil) == noErr)
		{
			if(itemPath == nil)
				continue;
			
			NSString* itemPathStr = [(__bridge NSURL*)itemPath path];
			if([itemPathStr hasPrefix:applicationPath])
			{
				foundItem = itemRef;
				break;
			}
		}
	}
	
	if([_model autostart])
	{
		if(foundItem == nil)
		{
			// add only if there's not already an item for us
			CFURLRef launchPath = CFBundleCopyBundleURL(CFBundleGetMainBundle());
			foundItem = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, nil, nil, launchPath, nil, nil);
			CFRelease(launchPath);
		}
	}
	else if(foundItem != nil)
	{
		//remove only if we're in the list
		LSSharedFileListItemRemove(loginItems, foundItem);
	}

	if(foundItem != nil)
		CFRelease(foundItem);
}

- (void)openSerialPort:(NSString*)devicePath baudRate:(unsigned int)baud
{
	_serialPort = [[SerialPort alloc] initWithFile:[devicePath cStringUsingEncoding:NSUTF8StringEncoding] baudRate:baud];	// @@make script-controlled
	[_serialPort onData:@selector(onSerialInput:) target:self];
}

- (void)onSystemWillSleep:(NSNotification*)notification
{
	[_model postGenericEvent:@"power" value:@"sleep"];
}

- (void)onSystemDidWake:(NSNotification*)notification
{
	[_model postGenericEvent:@"power" value:@"wake"];
}

- (void)onSerialPortChanged:(NSNotification*)notification
{
	if(_serialPort != nil)
	{
		[_serialPort close];
		[_serialPort unbindListener:self];
	}
	
	[self openSerialPort:[_model serialPort] baudRate:9600];	//@@script controlled baud
}

- (void)onSerialInput:(NSNotification*)notification
{
	[_model postSerialInput:[[notification userInfo] objectForKey:@"data"]];
}

- (void)onSerialOutput:(NSNotification*)notification
{
	[_serialPort write:[[notification userInfo] objectForKey:@"data"]];
}

@end


////////////////////////////////////////////////////////////////


@implementation UserInputController

- (id)initWithModel:(AmpControllerModel*)model
{
	_model = model;
	
	_appleRemote = AppleRemote::Create();
	_appleRemote->SetCallback(&onRemoteInputEvent, (void*)CFBridgingRetain(self));
	
	_keyboard = Keyboard::Create();
	_keyboard->SetCallback(&onKeyboardInputEvent, (void*)CFBridgingRetain(self));
	
	return(self);
}

- (void)onKeyboardInputEvent:(int)inputEvent
{
	[_model postInputEvent:@"key" value:inputEvent];
}

void onKeyboardInputEvent(void* context, IInputSource* inputSource, unsigned int inputEvent)
{
	UserInputController* s = (__bridge UserInputController*)context;	//note: _appleRemote owns the reference
	
	[s onKeyboardInputEvent:inputEvent];
}

- (void)onRemoteInputEvent:(int)inputEvent
{
	[_model postInputEvent:@"remote" value:inputEvent];
}

void onRemoteInputEvent(void* context, IInputSource* inputSource, unsigned int inputEvent)
{
	UserInputController* s = (__bridge UserInputController*)context;	//note: _appleRemote owns the reference
	
	[s onRemoteInputEvent:inputEvent];
}

@end


////////////////////////////////////////////////////////////////


@implementation MenubarController

- (id)initWithModel:(AmpControllerModel*)model
{
	_model = model;
	
	NSStatusItem* statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	
	[statusItem setHighlightMode:YES];
	
	_menubarView = [[MenubarView alloc] initWithStatusItem:statusItem];
	
	[_menubarView setImage:[NSImage imageNamed:@"menubarIcon"] forSlot:MenubarViewImageSlot_normal];
	[_menubarView setImage:[NSImage imageNamed:@"menubarIconHighlighted"] forSlot:MenubarViewImageSlot_highlight];
	
	//build a menu
	NSMenu* menu = [[NSMenu alloc] initWithTitle:@"AmpController"];
	int index = 0;
	_detailItem = [menu insertItemWithTitle:@"Disconnected" action:nil keyEquivalent:@"" atIndex:index++];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	[[menu insertItemWithTitle:@"Settings..." action:@selector(showSettings:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	[[menu insertItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@"" atIndex:index++] setTarget:self];
	
	[_menubarView setMenu:menu];
	
	_settingsWindow = [[SettingsWindowController alloc] initWithModel:_model];
	
	[_model onChanged:@"deviceStatus" call:@selector(onDeviceStatusChange:) on:self];
	
	return(self);
}

- (void)dealloc
{
	[[NSStatusBar systemStatusBar] removeStatusItem:[_menubarView statusItem]];
}

- (IBAction)showSettings:(id)sender
{
	//printf("Showing settings...\n");
	
	[_settingsWindow showWindow:self];
}

- (IBAction)quit:(id)sender
{
	[NSApp terminate:self];
}

- (void)onDeviceStatusChange:(NSNotification*)notification
{
	[_detailItem setTitle:[_model deviceStatus]];
}

@end


////////////////////////////////////////////////////////////////


@implementation SettingsWindowController


- (id)initWithModel:(AmpControllerModel*)model
{
	self = [super initWithWindowNibName:@"SettingsWindow"];
	
	_model = model;
	
	[_model onChanged:@"deviceStatus" call:@selector(onDeviceStatusChange:) on:self];

	return(self);
}

- (void)showWindow:(id)sender
{
	[super showWindow:sender];
}

- (void)awakeFromNib
{
	// set initial dropdown/popup state
	[self generateSerialPortMenu];
	
	// set initial device model state
	[self generateDeviceModelMenu];
	
	// set initial status state
	[[self deviceStatus] setStringValue:[_model deviceStatus]];
	
	// set initial autostart state
	[[self autoStartButton] setIntegerValue:[_model autostart]];
	
	// show the window
	[[super window] setLevel:NSFloatingWindowLevel];
	[NSApp activateIgnoringOtherApps:YES];
	[[super window] makeKeyAndOrderFront:self];
}

NSString* presentDeviceModel(NSString* model)
{
	//NSArray* pathComponents = [model pathComponents];
	//return([pathComponents objectAtIndex:([pathComponents count] - 1)]);
	return(model);
}

- (IBAction)onSerialPortChanged:(id)sender
{
	NSString* chosenPort = [sender representedObject];
	
	if(chosenPort == nil)
	{
		[self showExplicitPortChooser];
	}
	else
		[_model setSerialPort:chosenPort];
}

- (IBAction)onDeviceModelChanged:(id)sender
{
	NSString* deviceModel = [sender representedObject];
	
	if(deviceModel == nil)
	{
		NSOpenPanel* panel = [NSOpenPanel openPanel];
		[panel setCanChooseFiles:YES];
		/*[NSApp beginSheet:	panel
							modalForWindow: [self window]
							modalDelegate: self
							didEndSelector: @selector(finishedDeviceChooser:returnCode:contextInfo:)
							contextInfo: nil
		];*/
		
		[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result)
		{
			[_model setDeviceModel:[[panel URL] path]];
			[self generateDeviceModelMenu];
		}];
	}
	else
		[_model setDeviceModel:deviceModel];
}
/*- (void)finishedDeviceChooser:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
	NSOpenPanel* panel = (NSOpenPanel*)sheet;
	[_model setDeviceModel:[[panel URL] path]];
	[self generateDeviceModelMenu];
	
	[sheet orderOut:self];
}*/


- (IBAction)onAutoStartChanged:(id)sender
{
	[_model setAutostart:[[self autoStartButton] integerValue]];
}

- (void)generateDeviceModelMenu
{
	[self generateOptionsForButton:[self deviceModelChooser]
			fromOptions:[Scripting availableScripts]
			current:[_model deviceModel]
			changeMethod:@selector(onDeviceModelChanged:)
			presentMethod:&presentDeviceModel
		];
}

- (void)generateSerialPortMenu
{
	[self generateOptionsForButton:[self serialPortChooser]
			fromOptions:[SerialPort availableSerialPorts]
			current:[_model serialPort]
			changeMethod:@selector(onSerialPortChanged:)
			presentMethod:&presentSerialPort
		];
	
	/*// populate serial ports list
	NSArray* ports = [SerialPort availableSerialPorts];
	
	NSString* currentPort = [_model serialPort];
	
	NSMenu* serialPortMenu = [[NSMenu alloc] init];
	int index = 0, activeOption = -1;
	
	// add a "none selected" option that is selected when the model shows no selected port
	if((currentPort == nil) || [currentPort isEqualToString:@""])
		activeOption = 0;
	[[serialPortMenu insertItemWithTitle:@"(none)" action:@selector(onSerialPortChanged:) keyEquivalent:@"" atIndex:index++]
			setRepresentedObject:@""];
	
	[serialPortMenu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	
	for(int i = 0; i < [ports count]; i++)
	{
		NSString* portPath = [ports objectAtIndex:i];
		NSString* displayedTitle = [portPath substringFromIndex:9]; // cheaply trim "/dev/tty.usbserial-1234" to "usbserial-1234"
		[[serialPortMenu insertItemWithTitle:displayedTitle action:@selector(onSerialPortChanged:) keyEquivalent:@"" atIndex:index++]
			setRepresentedObject:portPath];
			
		if([portPath isEqualToString:currentPort])
			activeOption = index;
	}
	
	[serialPortMenu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	
	// if the model's current serial port isn't in the list, add a menu item specifically for it, and select that option
	if(activeOption == -1)
	{
		activeOption = index;
		[[serialPortMenu insertItemWithTitle:currentPort action:@selector(onSerialPortChanged:) keyEquivalent:@"" atIndex:index++]
				setRepresentedObject:currentPort];
	}
	
	// the "Other" option allows an explicit path. It has no representedObject.
	[serialPortMenu insertItemWithTitle:@"Other..." action:@selector(onSerialPortChanged:) keyEquivalent:@"" atIndex:index++];
	
	[[self serialPortChooser] setMenu:serialPortMenu];
	
	//set one as highlighted
	[[self serialPortChooser] selectItemAtIndex:activeOption];
	*/
}

NSString* presentSerialPort(NSString* portPath)
{
	return([portPath substringFromIndex:9]); // cheaply trim "/dev/tty.usbserial-1234" to "usbserial-1234"
}

- (void)generateOptionsForButton:(NSPopUpButton*)button fromOptions:(NSArray*)options current:(NSString*)current changeMethod:(SEL)method presentMethod:(NSString* (*)(NSString*))present
{
	NSMenu* menu = [[NSMenu alloc] init];
	int index = 0, activeOption = -1;
	
	// add a "none selected" option that is selected when the model shows no selected option
	if((current == nil) || [current isEqualToString:@""])
		activeOption = 0;
	[[menu insertItemWithTitle:@"(none)" action:method keyEquivalent:@"" atIndex:index++]
			setRepresentedObject:@""];
	
	[menu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	
	for(int i = 0; i < [options count]; i++)
	{
		NSString* value = [options objectAtIndex:i];
		NSString* displayedTitle = present(value);
		if([value isEqualToString:current])
			activeOption = index;
		[[menu insertItemWithTitle:displayedTitle action:method keyEquivalent:@"" atIndex:index++]
			setRepresentedObject:value];
	}
	
	[menu insertItem:[NSMenuItem separatorItem] atIndex:index++];
	
	// if the model's current serial port isn't in the list, add a menu item specifically for it, and select that option
	if(activeOption == -1)
	{
		activeOption = index;
		[[menu insertItemWithTitle:current action:method keyEquivalent:@"" atIndex:index++]
				setRepresentedObject:current];
	}
	
	// the "Other" option allows an explicit path. It has no representedObject.
	[menu insertItemWithTitle:@"Other..." action:method keyEquivalent:@"" atIndex:index++];
	
	[button setMenu:menu];
	
	//set one as highlighted
	[button selectItemAtIndex:activeOption];
}

- (void)showExplicitPortChooser
{
	[NSApp beginSheet:	[self portChooserWindow]
						modalForWindow: [self window]
						modalDelegate: self
						didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
						contextInfo: nil
	];
}

- (IBAction)closeExplicitPortChooser:(id)sender
{
	NSString* portPath = [[self portChooserPath] stringValue];
	
	//@@validation?
	
	[_model setSerialPort:portPath];
	[self generateSerialPortMenu];
	
	[NSApp endSheet:[self portChooserWindow]];
}

- (void)didEndSheet:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
	[sheet orderOut:self];
}

- (void)onDeviceStatusChange:(NSNotification*)notification
{
	[[self deviceStatus] setStringValue:[_model deviceStatus]];
}


@end


@implementation MenubarView

@synthesize statusItem = _statusItem;

- (id)initWithStatusItem:(NSStatusItem*)statusItem
{
	CGFloat itemWidth = [statusItem length];
	CGFloat itemHeight = [[NSStatusBar systemStatusBar] thickness];
	NSRect itemRect = NSMakeRect(0.0, 0.0, itemWidth, itemHeight);
	self = [super initWithFrame:itemRect];
	
	if(self != nil)
	{
		_statusItem = statusItem;
		_statusItem.view = self;
	}
	return(self);
}

- (void)drawRect:(NSRect)dirtyRect
{
	[self.statusItem drawStatusBarBackgroundInRect:dirtyRect withHighlight:_isHighlighted];
	
	/*
	CGAffineTransform mtx = CGAffineTransformMake(24.f, 0.f, 0.f, 24.f, 0.f, 0.f);
	CGContextConcatCTM(context, mtx);
	
	CGContextSetLineWidth(context, 0.04166f);
	CGColorRef color = CGColorGetConstantColor(kCGColorBlack);
	CGContextSetStrokeColorWithColor(context, color);
	
	CGContextMoveToPoint(context, 0.f, 0.618f);
	CGContextAddLineToPoint(context, 1.f, 1.f);
	CGContextStrokePath(context);
	*/

	NSImage* icon = _isHighlighted ? _image[MenubarViewImageSlot_highlight] : _image[MenubarViewImageSlot_normal];
	
	if(icon)
	{
		NSSize iconSize = [icon size];
		NSRect bounds = self.bounds;
		CGFloat iconX = roundf((NSWidth(bounds) - iconSize.width) / 2);
		CGFloat iconY = roundf((NSHeight(bounds) - iconSize.height) / 2);
		NSPoint iconPoint = NSMakePoint(iconX, iconY);

		//CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
		[icon drawAtPoint:iconPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}

- (void)mouseDown:(NSEvent*)theEvent
{
	NSMenu* menu = [_statusItem menu];
	[_statusItem popUpStatusItemMenu:menu];
	[self setHighlighted:NO];
	[self setNeedsDisplay:YES];
}

- (void)menuWillOpen:(NSMenu*)menu
{
	[self setHighlighted:YES];
	[self setNeedsDisplay:YES];
}

- (void)menuDidClose:(NSMenu*)menu
{
	[self setHighlighted:NO];
	[self setNeedsDisplay:YES];
}

- (void)setMenu:(NSMenu*)menu
{
	[menu setDelegate:self];
	[_statusItem setMenu:menu];
}

- (void)setHighlighted:(BOOL)newFlag
{
	if(_isHighlighted != newFlag)
	{
		_isHighlighted = newFlag;
		[self setNeedsDisplay:YES];
	}
}

- (void)setImage:(NSImage*)newImage forSlot:(MenubarViewImageSlot)slot
{
	if(slot >= MenubarViewImageSlot__pastEnd)
		return;
	if(_image[slot] != newImage)
	{
		_image[slot] = newImage;
		[self setNeedsDisplay:YES];
	}
}

- (NSRect)globalRect
{
	NSRect frame = [self frame];
	frame.origin = [self.window convertBaseToScreen:frame.origin];
	return frame;
}

@end


////////////////////////////////////////////////////////////////


int main(int argc, const char*  argv[])
{
	AmpControllerApp* application = [[AmpControllerApp alloc] init];

	[[NSApplication sharedApplication] setDelegate:application];
	[[NSApplication sharedApplication] run];

	return(0);
}
