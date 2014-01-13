#include "VolumeKeys.h"

#include <Cocoa/Cocoa.h>
#include <IOKit/hidsystem/ev_keymap.h>

//#define NX_KEYTYPE_SOUND_UP		0
//#define NX_KEYTYPE_SOUND_DOWN		1
//#define	NX_KEYTYPE_MUTE			7

// API patch
#define NX_KEYSTATE_UP      0x0A
#define NX_KEYSTATE_DOWN    0x0B

class KeyboardDriver: public IInputSource
{
public:
							KeyboardDriver(void):
								_callback(0),
								_callbackContext(0)
	{
		_eventPort = CGEventTapCreate(		kCGSessionEventTap,
											kCGHeadInsertEventTap,
											kCGEventTapOptionDefault,
											CGEventMaskBit(NX_SYSDEFINED),
											tapEventCallback,
											this
										);
		
		if(_eventPort == 0)
		{
			printf("Fatal Error: Event Tap could not be created\n");
			return;
		}

		_runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, _eventPort, 0);

		if(_runLoopSource == 0)
		{
			printf("Fatal Error: Run Loop Source could not be created\n");
			return;
		}

		CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
	}

	virtual					~KeyboardDriver(void)
	{
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
		CFRunLoopSourceInvalidate(_runLoopSource);
	}
	
	virtual void	SetCallback(InputCallback callback, void* context)
	{
		_callback = callback;
		_callbackContext = context;
	}
	
private:
	static CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* context)
	{
		KeyboardDriver* s = (KeyboardDriver*)context;
		
		if(type == kCGEventTapDisabledByTimeout)
			CGEventTapEnable(s->_eventPort, TRUE);
		
		if(type != NX_SYSDEFINED)
			return(event);
		
		NSEvent* nsEvent = [NSEvent eventWithCGEvent:event];
		
		if([nsEvent subtype] != 8) 
			return(event);
		
		NSInteger data = [nsEvent data1];
		int keyCode = (data & 0xFFFF0000) >> 16;
		int keyFlags = (data & 0xFFFF);
		int keyState = (keyFlags & 0xFF00) >> 8;
		BOOL keyIsRepeat = (keyFlags & 0x1) > 0;
		
		if(keyIsRepeat)
			return(event);
		
		switch(keyCode)
		{
		case NX_KEYTYPE_SOUND_UP:
			if(keyState == NX_KEYSTATE_DOWN)
				s->_callback(s->_callbackContext, s, IInputSource::UserInputAction_VolumeUp);
			if((keyState == NX_KEYSTATE_UP) || (keyState == NX_KEYSTATE_DOWN))
				return(NULL);
			break;
		case NX_KEYTYPE_SOUND_DOWN:
			if(keyState == NX_KEYSTATE_DOWN)
				s->_callback(s->_callbackContext, s, IInputSource::UserInputAction_VolumeDown);
			if((keyState == NX_KEYSTATE_UP) || (keyState == NX_KEYSTATE_DOWN))
				return(NULL);
			break;
		case NX_KEYTYPE_MUTE:
			if(keyState == NX_KEYSTATE_DOWN)
				s->_callback(s->_callbackContext, s, IInputSource::UserInputAction_VolumeMute);
			if((keyState == NX_KEYSTATE_UP) || (keyState == NX_KEYSTATE_DOWN))
				return(NULL);
			break;
		}
		return(event);
	}
	
	CFMachPortRef				_eventPort;
	CFRunLoopSourceRef			_runLoopSource;
	
	InputCallback				_callback;
	void*						_callbackContext;
};

//static
IInputSource*		Keyboard::Create(void)
{
	return(new KeyboardDriver());
}



















/*
#include <stdio.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hid/IOHIDUsageTables.h>

#include <CoreFoundation/CoreFoundation.h>


#include <Carbon/Carbon.h>
#import <IOKit/hidsystem/ev_keymap.h>

//#include "CRC32.h"

typedef enum
{
	KeyCookie_VolumeUp,
	KeyCookie_VolumeDown,
	KeyCookie_VolumeMute
	
} KeyCookie;

class KeyboardDriver: public IInputSource
{
public:
							KeyboardDriver(void):
								_callback(0),
								_callbackContext(0)
	{
		EventTypeSpec const hotKeyEvents[] =
		{
			{kEventClassKeyboard, kEventHotKeyPressed},
			{kEventClassKeyboard, kEventHotKeyReleased}
		};
		InstallApplicationEventHandler( NewEventHandlerUPP(&onHotkeyPressed), GetEventTypeCount(hotKeyEvents), hotKeyEvents, 0, NULL);
		
		EventHotKeyRef keyRef = 0;
		
		unsigned int keyCode = 0x1234, keyModifiers = 0x0;
		
		EventTargetRef targetRef = 0;
		
		EventHotKeyID keyID;
		keyID.id = KeyCookie_VolumeUp;
		
		RegisterEventHotKey(	keyCode, keyModifiers,
								keyID,
								targetRef,
								0,
								&keyRef
							);
							
		NX_KEYTYPE_PLAY
		
	}
	
	virtual					~KeyboardDriver(void)
	{
	}
	
	virtual void	SetCallback(InputCallback callback, void* context)
	{
		_callback = callback;
		_callbackContext = context;
	}

private:
	
	static	OSStatus	onHotkeyPressed(EventHandlerCallRef inCallRef, EventRef inEvent, void* inUserData)
	{
		EventHotKeyID hotKeyID;
		OSStatus err = eventNotHandledErr;
		UInt32 eventClass = GetEventClass(inEvent);
		UInt32 eventKind = GetEventKind(inEvent);
		
		switch(eventClass)
		{
		case kEventClassKeyboard:
			if(eventKind == kEventHotKeyPressed)
			{
				GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(EventHotKeyID), NULL, &hotKeyID);
				if(hotKeyID.signature == 'Arow')
				{
					switch(hotKeyID.id)
					{
					default:
						break;
					}
				}
			}
			break;
		}

		return(err);
	}
	
	InputCallback				_callback;
	void*						_callbackContext;
};

//static
IInputSource*		Keyboard::Create(void)
{
	return(new KeyboardDriver());
}
*/
