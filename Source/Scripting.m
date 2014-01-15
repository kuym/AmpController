#include "Scripting.h"

#include <Cocoa/Cocoa.h>
#include "Model.h"

#include "lua.h"
#include "lualib.h"


@implementation Scripting
{
	AmpControllerModel*		_model;
	
	lua_State*				_luaState;
}

+ (NSArray*)availableScripts;
{
	//list all .lua files in devices/ in the bundle resources
	NSArray* scriptFilePaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"lua" inDirectory:@"devices"];
	NSMutableArray* scriptFiles = [NSMutableArray arrayWithCapacity:[scriptFilePaths count]];
	
	//and transform them from /long/absolute/path/to/bundle/resources/devices/lemon.lua => lemon
	for(NSString* filePath in scriptFilePaths)
	{
		NSArray* pathComponents = [filePath pathComponents];
		NSString* name = [pathComponents objectAtIndex:([pathComponents count] - 1)];
		NSString* extension = [name pathExtension];

		[scriptFiles addObject:[name substringToIndex:([name length] - [extension length] - 1)]];
	}
	
	return(scriptFiles);
}

- (id)initWithModel:(AmpControllerModel*)model
{
	_model = model;
	_luaState = 0;
	
	[self onScriptChanged:nil];
	[_model onChanged:@"deviceModel" call:@selector(onScriptChanged:) on:self];
	
	[_model onChanged:@"input" call:@selector(onInputEvent:) on:self];
	[_model onChanged:@"serialInput" call:@selector(onSerialInput:) on:self];
	
	[_model onChanged:@"event" call:@selector(onGenericEvent:) on:self];
	
	return(self);
}

- (void)onScriptChanged:(NSNotification*)notification
{
	[_model setDeviceStatus:@"(loading script)"];
	
	[self loadLuaScript:[[NSBundle mainBundle] pathForResource:[_model deviceModel] ofType:@"lua" inDirectory:@"devices"]];
}


static void* luaAlloc(void* context, void* p, size_t osize, size_t nsize)
{
	(void)context;
	(void)osize;
	if(nsize == 0)
	{
		free(p);
		return(NULL);
	}
	else
		return(realloc(p, nsize));
}

int		luaPrint(lua_State* L)
{
	int n = lua_gettop(L);
	
	if(n > 0)
		printf("[Lua]* ");
	for(int i = 1; i <= n; i++)
	{
		if(lua_isstring(L, i))
			printf("%s ", lua_tolstring(L, i, 0));
		else if(lua_isfunction(L, i))
			printf("[function %p] ", lua_topointer(L, i));
		else if(lua_istable(L, i))
			printf("[table %p] ", lua_topointer(L, i));
		else if(lua_isnoneornil(L, i))
			printf("[null] ");
		else
			printf("[other %p] ", lua_topointer(L, i));
	}
	if(n > 0)
		printf("\n");
	return(0);
}

int		luaSetStatus(lua_State* L)
{
	int n = lua_gettop(L);
	if((n < 1) || !lua_isstring(L, 1))
	{
		lua_pushstring(L, "setStatus must be called with a string argument");
		return(lua_error(L));	// longjmps, doesn't actually return
	}
	
	size_t len;
	char const* str = lua_tolstring(L, 1, &len);
	
	Scripting* s = (__bridge Scripting*)lua_touserdata(L, lua_upvalueindex(1));
	[s setStatus:[NSString stringWithUTF8String:str]];
	
	return(0);
}

int		luaSetSerialBaud(lua_State* L)
{
	int n = lua_gettop(L);
	if((n < 1) || !lua_isnumber(L, 1))
	{
		lua_pushstring(L, "setStatus must be called with an integer argument");
		return(lua_error(L));	// longjmps, doesn't actually return
	}
	
	int baud = (int)lua_tointeger(L, 1);
	
	Scripting* s = (__bridge Scripting*)lua_touserdata(L, lua_upvalueindex(1));
	[s setBaudRate:baud];
	
	return(0);
}

int		luaSerialWrite(lua_State* L)
{
	int n = lua_gettop(L);
	if((n < 1) || !lua_isstring(L, 1))
	{
		lua_pushstring(L, "serialWrite must be called with a string argument");
		return(lua_error(L));	// longjmps, doesn't actually return
	}
	
	size_t len;
	char const* data = lua_tolstring(L, 1, &len);
	
	Scripting* s = (__bridge Scripting*)lua_touserdata(L, lua_upvalueindex(1));
	[s serialWrite:[NSData dataWithBytes:data length:len]];
	
	return(0);
}


typedef struct ScriptLoadClosure
{
	FILE*	file;
	size_t	bufferSize;
	char	buffer[64];
	
} ScriptLoadClosure;

char const*		readScriptCallback(lua_State* L, void* context, size_t* outSize)
{
	ScriptLoadClosure* closure = (ScriptLoadClosure*)context;
	*outSize = fread(closure->buffer, 1, closure->bufferSize, closure->file);
	
	return(closure->buffer);
}

- (void)unloadScript
{
	if(_luaState != 0)
	{
		lua_close(_luaState);
		_luaState = 0;
	}
}

void	addGlobalMethod(lua_State* L, void* context, char const* name, lua_CFunction fn)
{
	lua_pushlightuserdata(L, context);
	lua_pushcclosure(L, fn, 1);
	lua_setglobal(L, name);
}

- (BOOL)loadLuaScript:(NSString*)scriptPath
{
	if(_luaState != 0)
		[self unloadScript];
	
	
	FILE* file = fopen([scriptPath cStringUsingEncoding:NSUTF8StringEncoding], "r");
	
	if(file == 0)
	{
		[self unloadScript];
		printf("Unable to load script file\n");
		[_model setDeviceStatus:@"(could not load script)"];
		return(NO);
	}
	
	// init lua
	_luaState = lua_newstate(&luaAlloc, 0);
	
	lua_gc(_luaState, LUA_GCSTOP, 0);
	luaL_openlibs(_luaState);	//load default libraries
	lua_gc(_luaState, LUA_GCRESTART, 0);
	
	addGlobalMethod(_luaState, (__bridge void*)self, "print", &luaPrint);
	addGlobalMethod(_luaState, (__bridge void*)self, "setStatus", &luaSetStatus);
	addGlobalMethod(_luaState, (__bridge void*)self, "setSerialBaud", &luaSetSerialBaud);
	addGlobalMethod(_luaState, (__bridge void*)self, "serialWrite", &luaSerialWrite);
	
	ScriptLoadClosure* closure = (ScriptLoadClosure*)malloc(sizeof(ScriptLoadClosure));
	closure->file = file;
	closure->bufferSize = sizeof(closure->buffer);
	
	int result = lua_load(_luaState, &readScriptCallback, closure, [scriptPath cStringUsingEncoding:NSUTF8StringEncoding], 0);
	
	fclose(file);
	free(closure);
	
	if(result != 0)
	{
		char const* reason = "(unknown)";
		switch(result)
		{
		case LUA_ERRSYNTAX:
			reason = "syntax error.";
			break;
		case LUA_ERRMEM:
		case LUA_ERRGCMM:
			reason = "memory management error.";
			break;
		}
		printf("Unable to load the lua script, error: %s\n", reason);
		[_model setDeviceStatus:@"(script syntax/memory error)"];
		[self unloadScript];
		return(NO);
	}
	
	if(lua_pcall(_luaState, 0, 0, 0) != 0)
	{
		if(lua_isstring(_luaState, -1))
		{
			printf("Error: %s \n", lua_tolstring(_luaState, -1, 0));
		}
		else
			printf("Other error.\n");
		
		[_model setDeviceStatus:@"(script runtime error)"];
		[self unloadScript];
	}
	
	return(YES);
}

- (void)onInputEvent:(NSNotification*)notification
{
	if(_luaState != 0)
	{
		NSString* event = [[notification userInfo] objectForKey:@"event"];
		unsigned int value = (unsigned int)[(NSNumber*)[[notification userInfo] objectForKey:@"value"] unsignedIntegerValue];
		
		lua_getglobal(_luaState, "onEvent");
		
		lua_pushstring(_luaState, [event cStringUsingEncoding:NSUTF8StringEncoding]);
		lua_pushunsigned(_luaState, value);
		
		if(lua_pcall(_luaState, 2, 0, 0) != 0)
		{
			if(lua_isstring(_luaState, -1))
				printf("Error: %s \n", lua_tolstring(_luaState, -1, 0));
			else
				printf("Other error.\n");
		}
	}
}

- (void)setStatus:(NSString*)value
{
	[_model setDeviceStatus:value];
}

- (void)setBaudRate:(int)baud
{
	[_model setBaudRate:baud];
}

- (void)serialWrite:(NSData*)data
{
	[_model postSerialOutput:data];
}

- (void)onSerialInput:(NSNotification*)notification
{
	if(_luaState != 0)
	{
		NSData* d = [[notification userInfo] objectForKey:@"data"];
		
		lua_getglobal(_luaState, "onEvent");
		
		lua_pushstring(_luaState, "serial");
		if([d length] == 0)
			lua_pushstring(_luaState, "");
		else
			lua_pushlstring(_luaState, [d bytes], [d length]);
		
		if(lua_pcall(_luaState, 2, 0, 0) != 0)
		{
			if(lua_isstring(_luaState, -1))
				printf("Error: %s \n", lua_tolstring(_luaState, -1, 0));
			else
				printf("Other error.\n");
		}
	}
}

- (void)onGenericEvent:(NSNotification*)notification
{
	if(_luaState != 0)
	{
		NSString* event = [[notification userInfo] objectForKey:@"event"];
		NSString* value = [[notification userInfo] objectForKey:@"value"];
		
		lua_getglobal(_luaState, "onEvent");
		
		lua_pushstring(_luaState, [event cStringUsingEncoding:NSUTF8StringEncoding]);
		lua_pushstring(_luaState, [value cStringUsingEncoding:NSUTF8StringEncoding]);
		
		if(lua_pcall(_luaState, 2, 0, 0) != 0)
		{
			if(lua_isstring(_luaState, -1))
				printf("Error: %s \n", lua_tolstring(_luaState, -1, 0));
			else
				printf("Other error.\n");
		}
	}
}

@end