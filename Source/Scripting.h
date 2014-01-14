#ifndef _SCRIPTING_H_
#define _SCRIPTING_H_

#include <Cocoa/Cocoa.h>

@class AmpControllerModel;
@interface Scripting: NSObject

+ (NSArray*)availableScripts;

- (id)initWithModel:(AmpControllerModel*)model;

@end

#endif //!defined _SCRIPTING_H_
