#ifndef _APPLEREMOTE_H_
#define _APPLEREMOTE_H_

#include "InputSource.h"

class AppleRemote
{
public:
	static IInputSource*		Create(void);
	
private:
								AppleRemote(void) {}
};

#endif //!defined _APPLEREMOTE_H_
