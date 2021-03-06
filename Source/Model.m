#include "Model.h"

#include <Cocoa/Cocoa.h>

@implementation AmpControllerModel
{
@private
	NSString*		_deviceStatus;
	float			_deviceVolume;
	int				_deviceMuted;
	int				_baud;
}

- (id)init
{
	_deviceStatus = @"(no model selected)";
	_baud = 9600;
	_deviceVolume = 0.f;
	_deviceMuted = 0;
	
	return(self);
}


- (void)onChanged:(NSString*)propertyName call:(SEL)method on:(id)target
{
	[[NSNotificationCenter defaultCenter] addObserver:target selector:method name:propertyName object:self];
}

- (void)unbindChange:(NSString*)propertyName on:(id)target
{
	[[NSNotificationCenter defaultCenter] removeObserver:target name:propertyName object:self];
}

- (void)change:(NSString*)propertyName on:(id)target
{
	[[NSNotificationCenter defaultCenter] postNotificationName:propertyName object:target];
}

- (void)change:(NSString*)propertyName on:(id)target withInfo:(NSDictionary*)userInfo
{
	[[NSNotificationCenter defaultCenter] postNotificationName:propertyName object:target userInfo:userInfo];
}

- (void)postGenericEvent:(NSString*)event value:(NSString*)value;
{
	[self change:@"event" on:self withInfo:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", value, @"value", nil]];
}

- (void)postGenericEvent:(NSString*)event floatValue:(float)value;
{
	[self change:@"event" on:self withInfo:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", [NSNumber numberWithFloat:value], @"value", nil]];
}

- (void)postGenericEvent:(NSString*)event intValue:(unsigned int)value
{
	[self change:@"event" on:self withInfo:[NSDictionary dictionaryWithObjectsAndKeys:event, @"event", [NSNumber numberWithUnsignedInt:value], @"value", nil]];
}

- (void)postSerialInput:(NSData*)data
{
	[self change:@"serialInput" on:self withInfo:[NSDictionary dictionaryWithObject:data forKey:@"data"]];
}

- (void)postSerialOutput:(NSData*)data
{
	[self change:@"serialOutput" on:self withInfo:[NSDictionary dictionaryWithObject:data forKey:@"data"]];
}


- (BOOL)autostart
{
	return([[NSUserDefaults standardUserDefaults] boolForKey:@"autostart"]);
}

- (void)setAutostart:(BOOL)autostart
{
	[[NSUserDefaults standardUserDefaults] setBool:autostart forKey:@"autostart"];
	
	[self change:@"autostart" on:self];
}

- (NSString*)serialPort
{
	return([[NSUserDefaults standardUserDefaults] stringForKey:@"serialport"]);
}

- (void)setSerialPort:(NSString*)value
{
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"serialport"];
	
	[self change:@"serialPort" on:self];
}

- (int)baudRate
{
	return(_baud);
}

- (void)setBaudRate:(int)baud
{
	_baud = baud;
	
	[self change:@"baudRate" on:self];
}

- (NSString*)deviceModel
{
	return([[NSUserDefaults standardUserDefaults] stringForKey:@"devicemodel"]);
}

- (void)setDeviceModel:(NSString*)value
{
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"devicemodel"];
	
	[self change:@"deviceModel" on:self];
}

- (NSString*)deviceStatus
{
	return(_deviceStatus);
}

- (void)setDeviceStatus:(NSString*)value
{
	_deviceStatus = value;
	
	[self change:@"deviceStatus" on:self];
}

- (float)deviceVolume
{
	return(_deviceVolume);
}

- (void)setDeviceVolume:(float)value
{
	_deviceVolume = value;
	
	[self change:@"deviceVolume" on:self];
}

- (int)deviceMuted
{
	return(_deviceMuted);
}

- (void)setDeviceMuted:(int)value
{
	_deviceMuted = value;
	
	[self change:@"deviceMuted" on:self];
}

@end


