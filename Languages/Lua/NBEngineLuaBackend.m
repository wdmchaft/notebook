/*
 * Copyright 2011 Matthew Arsenault. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY MATTHEW ARSENAULT "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL MATTHEW ARSENAULT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NBEngineLuaBackend.h"
#include <assert.h>
#include <string.h>

@implementation NBEngineLuaBackend

- (id) init
{
    self = [super init];

    if (self != nil)
    {
        L = lua_open();
        luaL_openlibs(L);
    }

    return self;
}

- (oneway void) executeSnippet:(NSString*) snippet
{
    NBException* err = nil;
    lua_Debug ar;
    int iniTop, nReturn;

    iniTop = lua_gettop(L);
    if (luaL_dostring(L, [snippet UTF8String]))
    {
        err = [[NBException alloc] init];
        assert(lua_getinfo(L, ">Snl", &ar));

        //err.line = currentline;
        err.message = [NSString stringWithUTF8String:strdup(ar.short_src)];
    }
    else
    {
        nReturn = lua_gettop(L) - iniTop;
    }
}

@end