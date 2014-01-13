#ifndef _SERIALPORT_H_
#define _SERIALPORT_H_

#include <Cocoa/Cocoa.h>

@interface SerialPort: NSObject

+ (NSArray*)availableSerialPorts;

- (id)initWithFile:(char const*)ttyName baudRate:(unsigned int)baud;

- (void)onData:(SEL)sel target:(id)target;
- (void)unbindListener:(id)target;
- (void)write:(char const*)data length:(size_t)size;
- (void)write:(NSData*)data;
- (void)close;

@end

#endif //!defined _SERIALPORT_H_
