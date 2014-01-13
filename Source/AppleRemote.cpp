#include "AppleRemote.h"

#include <stdio.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hid/IOHIDUsageTables.h>

#include <CoreFoundation/CoreFoundation.h>

#include "CRC32.h"

struct CookieTuple
{
	IOHIDElementCookie	cookie;
	long				page;
	long				usage;
};

struct CookieJar
{
	CookieTuple*	cookieList;
	size_t			cookieCount;
};

class AppleRemoteDriver: public IInputSource
{
public:
							AppleRemoteDriver(void):
								hidDeviceInterface(0),
								jar(0),
								queue(0),
								_callback(0),
								_callbackContext(0)
	{
		CFMutableDictionaryRef	hidMatchDictionary = NULL;
		io_service_t			hidService = 0;
		io_object_t				hidDevice = 0;
		IOReturn				ioReturnValue = kIOReturnSuccess;
		
		hidMatchDictionary = IOServiceNameMatching("AppleIRController");
		hidService = IOServiceGetMatchingService(kIOMasterPortDefault, hidMatchDictionary);

		if(hidService == 0)
		{
			fprintf(stderr, "[AppleRemoteDriver] Apple Infrared Remote not found.\n");
			return;
		}

		hidDevice = (io_object_t)hidService;

		createHIDDeviceInterface(hidDevice, &hidDeviceInterface);
		getHIDCookies((IOHIDDeviceInterface122 **)hidDeviceInterface);
		ioReturnValue = IOObjectRelease(hidDevice);
		if(ioReturnValue != kIOReturnSuccess)	printf("[AppleRemoteDriver] Failed to release HID.\n");

		if(hidDeviceInterface == 0)
		{
			printf("[AppleRemoteDriver] No HID available.\n");
			return;
		}
		
		ioReturnValue = (*hidDeviceInterface)->open(hidDeviceInterface, kIOHIDOptionsTypeSeizeDevice);	//exclusive mode!
		
		queue = (*hidDeviceInterface)->allocQueue(hidDeviceInterface);
		if(!queue)
		{
			printf("[AppleRemoteDriver] Failed to allocate event queue.\n");
			return;
		}

		(void)(*queue)->create(queue, 0, 8);	//8???
		
		for(int i = 0; i < jar->cookieCount; i++)
		{
			(void)(*queue)->addElement(queue, jar->cookieList[i].cookie, 0);
		}
		
		addQueueCallbacks(queue, jar);
		
		if((*queue)->start(queue) != 0)
		{
			printf("[AppleRemoteDriver] Failed to start the queue.\n");
		}
	}

	virtual					~AppleRemoteDriver(void)
	{
		IOReturn result = (*queue)->stop(queue);
		IOReturn ioReturnValue = kIOReturnSuccess;
		
		result = (*queue)->dispose(queue);
		
		(*queue)->Release(queue);
		
		if(hidDeviceInterface != 0)
		{
			ioReturnValue = (*hidDeviceInterface)->close(hidDeviceInterface);
			(*hidDeviceInterface)->Release(hidDeviceInterface);
		}
	}
	
	virtual void	SetCallback(InputCallback callback, void* context)
	{
		_callback = callback;
		_callbackContext = context;
	}
	
private:
	void					createHIDDeviceInterface(io_object_t hidDevice, IOHIDDeviceInterface*** hdi)
	{
		io_name_t				className;
		IOCFPlugInInterface**	plugInInterface = NULL;
		HRESULT					plugInResult = S_OK;
		SInt32					score = 0;
		IOReturn				ioReturnValue = kIOReturnSuccess;
		
		ioReturnValue = IOObjectGetClass(hidDevice, className);
		
		if(ioReturnValue != kIOReturnSuccess)	printf("[AppleRemoteDriver] Failed to get class name.\n");
		
		ioReturnValue = IOCreatePlugInInterfaceForService(		hidDevice,
																kIOHIDDeviceUserClientTypeID,
																kIOCFPlugInInterfaceID,
																&plugInInterface,
																&score
															);
		
		if(ioReturnValue != kIOReturnSuccess)
			return;
		
		plugInResult = (*plugInInterface)->QueryInterface(		plugInInterface,
																CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID),
																(void**)hdi
															);
		if(plugInResult != S_OK)	printf("[AppleRemoteDriver] Failed to create device interface.\n");
		
		(*plugInInterface)->Release(plugInInterface);
	}
	
	void		getHIDCookies(IOHIDDeviceInterface122 **handle)
	{
		IOHIDElementCookie	cookie;
		CFTypeRef			object;
		long				number;
		long				usage;
		long				usagePage;
		CFArrayRef			elements;
		CFDictionaryRef		element;
		IOReturn			result;

		jar = new CookieJar();
		jar->cookieList = 0;
		jar->cookieCount = 0;
		
		if(!handle || !(*handle))
			return;

		result = (*handle)->copyMatchingElements(handle, NULL, &elements);

		if(result != kIOReturnSuccess)
		{
			fprintf(stderr, "[AppleRemoteDriver] Failed to copy cookies.\n");
		}

		CFIndex i;
		jar->cookieCount = CFArrayGetCount(elements);
		jar->cookieList = new CookieTuple[jar->cookieCount];
		
		for(i = 0; i < CFArrayGetCount(elements); i++)
		{
			element = (CFDictionaryRef)CFArrayGetValueAtIndex(elements, i);
			object = (CFDictionaryGetValue(element, CFSTR(kIOHIDElementCookieKey)));
			
			if(object == 0 || CFGetTypeID(object) != CFNumberGetTypeID())				continue;
			if(!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number))		continue;
			
			cookie = (IOHIDElementCookie)number;
			object = CFDictionaryGetValue(element, CFSTR(kIOHIDElementUsageKey));
			if(object == 0 || CFGetTypeID(object) != CFNumberGetTypeID())				continue;
			if(!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number))		continue;
			usage = number;
			object = CFDictionaryGetValue(element,CFSTR(kIOHIDElementUsagePageKey));
			if(object == 0 || CFGetTypeID(object) != CFNumberGetTypeID())				continue;
			if(!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number))		continue;
			usagePage = number;
			
			printf("[AppleRemoteDriver] found potential cookie %p for usage %li, page %li\n", (void*)(size_t)cookie, usage, usagePage);
			jar->cookieList[i].page = usagePage;
			jar->cookieList[i].usage = usage;
			jar->cookieList[i].cookie = cookie;
		}
	}
	
	static void		queueCallbackFunction(void *target, IOReturn result, void *refcon, void *sender)
	{
		AppleRemoteDriver* self = (AppleRemoteDriver*)target;
		
		AbsoluteTime			zeroTime = {0,0};
		IOHIDQueueInterface**	hqi = (IOHIDQueueInterface **)sender;
		IOHIDEventStruct		event;

		unsigned int signature = 0;
		while(true)
		{
			if((*hqi)->getNextEvent(hqi, &event, zeroTime, 0) == 0)
			{
				unsigned int hash = (unsigned int)event.elementCookie | (event.value << 16);
				CRC32HashIncremental(signature, (unsigned char*)&hash, sizeof(event.elementCookie));
			}
			else break;
		}
		
		unsigned int action = 0;
		switch(signature)
		{
		case 0x21f2ee29:
		case 0x3e2c6f3f:
			action = IInputSource::UserInputAction_VolumeUp;
			break;
		case 0x3a9bcfaf:
		case 0xb1298afa:
			action = IInputSource::UserInputAction_VolumeDown;
			break;
		}
		
		if(self->_callback != 0)
			self->_callback(self->_callbackContext, self, action);
	}

	bool addQueueCallbacks(IOHIDQueueInterface** hqi, CookieJar* jar)
	{
		IOReturn				ret;
		CFRunLoopSourceRef		eventSource;
		IOHIDQueueInterface***	privateData;
		
		privateData = new IOHIDQueueInterface**[1];
		*privateData = hqi;
		
		ret = (*hqi)->createAsyncEventSource(hqi, &eventSource);
		if (ret != kIOReturnSuccess)
			return false;
		
		ret = (*hqi)->setEventCallout(hqi, &queueCallbackFunction, this, &privateData);
		if (ret != kIOReturnSuccess)
			return false;
		
		CFRunLoopAddSource(CFRunLoopGetCurrent(), eventSource, kCFRunLoopDefaultMode);
		return true;
	}
	
	IOHIDDeviceInterface**		hidDeviceInterface;
	CookieJar*					jar;
	
	IOHIDQueueInterface**		queue;
	
	InputCallback				_callback;
	void*						_callbackContext;
};

//static
IInputSource*		AppleRemote::Create(void)
{
	return(new AppleRemoteDriver());
}
