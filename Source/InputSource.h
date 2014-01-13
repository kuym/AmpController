#ifndef _INPUTSOURCE_H_
#define _INPUTSOURCE_H_

class IInputSource
{
public:

	typedef enum
	{
		UserInputAction_VolumeUp	= 10,
		UserInputAction_VolumeDown	= 11,
		UserInputAction_VolumeMute	= 12,
		
	} UserInputAction;
	
	typedef void		(*InputCallback)(void* context, IInputSource* inputSource, unsigned int inputEvent);
	
	virtual				~IInputSource(void) {};
	
	virtual void		SetCallback(InputCallback callback, void* context) = 0;
	
protected:
						IInputSource(void) {};
};

#endif //!defined _INPUTSOURCE_H_
