#ifndef _KEYBOARD_H_
#define _KEYBOARD_H_

#include "InputSource.h"

class Keyboard
{
public:
	static IInputSource*		Create(void);
	
private:
								Keyboard(void) {}
};

#endif //!defined _KEYBOARD_H_
