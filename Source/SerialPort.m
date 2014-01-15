#include "SerialPort.h"

#include <Cocoa/Cocoa.h>
#include <termios.h>

@implementation SerialPort
{
@private
	CFFileDescriptorRef		_fdref;
}

+ (NSArray*)availableSerialPorts
{
	NSString* path = @"/dev/";
	NSArray* devFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
	NSArray* serialPorts = [devFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'tty.'"]];
	NSMutableArray* serialPortPaths = [NSMutableArray arrayWithCapacity:[serialPorts count]];
	
	for(NSString* port in serialPorts)
		[serialPortPaths addObject:[path stringByAppendingString:port]];

	return(serialPortPaths);
}

static void onBytesReady(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void* info)
{
	int fd = CFFileDescriptorGetNativeDescriptor(fdref);
	
	if(callBackTypes & kCFFileDescriptorReadCallBack)
	{
		NSMutableData* data = [NSMutableData data];
		unsigned char buffer[64];
		ssize_t bytesRead;
		while((bytesRead = read(fd, buffer, 64)) > 0)
			[data appendBytes:buffer length:bytesRead];
		
		SerialPort* s = (__bridge SerialPort*)info;
		if(([data length] == 0) && (bytesRead == -1))	//closed
		{
			[s close];
			//post a data event with nil data meaning "closed"
			[[NSNotificationCenter defaultCenter]	postNotificationName:@"data"
													object:s
													userInfo:[NSDictionary dictionaryWithObject:[NSData data] forKey:@"data"]];
			return;
		}
		
		//post a regluar data event
		[[NSNotificationCenter defaultCenter]	postNotificationName:@"data"
												object:s
												userInfo:[NSDictionary dictionaryWithObject:data forKey:@"data"]];
	}
	
	CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
}

- (id)initWithFile:(char const*)ttyName baudRate:(unsigned int)baud
{
	int ttyDescriptor = open(ttyName, O_RDWR | O_NONBLOCK);
	
	if(ttyDescriptor < 0)
		return(self);
	
	struct termios uartTTYSettings = {0};
	uartTTYSettings.c_iflag = 0;
	uartTTYSettings.c_oflag = 0;
	uartTTYSettings.c_cflag = CS8 | CREAD | CLOCAL;	// 8n1
	uartTTYSettings.c_lflag = 0;
	uartTTYSettings.c_cc[VMIN] = 1;
	uartTTYSettings.c_cc[VTIME] = 5;
	
	cfsetospeed(&uartTTYSettings, baud);
	cfsetispeed(&uartTTYSettings, baud);
	
	tcsetattr(ttyDescriptor, TCSANOW, &uartTTYSettings);
	
	CFFileDescriptorContext context = {0};
	
	// use a weak reference; if this instance is not externally maintained, the port will close.
	context.info = (__bridge void*)self;
	
	_fdref = CFFileDescriptorCreate(kCFAllocatorDefault, ttyDescriptor, true, &onBytesReady, &context);
	CFFileDescriptorEnableCallBacks(_fdref, kCFFileDescriptorReadCallBack);
	CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _fdref, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopDefaultMode);
	CFRelease(source);
	
	return(self);
}

- (void)dealloc
{
	[self close];
}

- (void)close
{
	if(_fdref != nil)
	{
		close(CFFileDescriptorGetNativeDescriptor(_fdref));
		CFFileDescriptorInvalidate(_fdref);
		CFRelease(_fdref);
		_fdref = nil;
	}
}

- (void)onData:(SEL)sel target:(id)target
{
	[[NSNotificationCenter defaultCenter] addObserver:target selector:sel name:@"data" object:self];
}
- (void)unbindListener:(id)target
{
	[[NSNotificationCenter defaultCenter] removeObserver:target name:@"data" object:self];
}

- (void)write:(char const*)data length:(size_t)length
{
	if(_fdref != nil)
	{
		int fd = CFFileDescriptorGetNativeDescriptor(_fdref);
		write(fd, data, length);
	}
}
- (void)write:(NSData*)data
{
	if(_fdref != nil)
	{
		int fd = CFFileDescriptorGetNativeDescriptor(_fdref);
		unsigned char buffer[64];
		size_t length = [data length];
		while(length > 0)
		{
			size_t chunkSize = (length > 64)? 64 : length;
			[data getBytes:buffer length:chunkSize];
			write(fd, buffer, chunkSize);
			length -= chunkSize;
		}
	}
}

@end

