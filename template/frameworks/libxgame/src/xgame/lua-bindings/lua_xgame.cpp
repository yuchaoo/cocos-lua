//
// generated by tolua
//
#include "xgame/lua-bindings/lua_xgame.h"
#include "xgame/xfilesystem.h"
#include "xgame/xlua.h"
#include "xgame/xlua-conv.h"
#include "xgame/xpreferences.h"
#include "xgame/xruntime.h"
#include "xgame/xtimer.h"

static int _kernel_runtime_clearStorage(lua_State *L)
{
    lua_settop(L, 0);
    
    xgame::runtime::clearStorage();
    
    return 0;
}

static int _kernel_runtime_launch(lua_State *L)
{
    lua_settop(L, 1);
    const std::string & arg1 = (std::string)xluacv_to_std_string(L, 1);
    bool ret = (bool)xgame::runtime::launch(arg1);
    xluacv_push_bool(L, ret);
    return 1;
}

static int _kernel_runtime_restart(lua_State *L)
{
    lua_settop(L, 0);
    
    bool ret = (bool)xgame::runtime::restart();
    xluacv_push_bool(L, ret);
    return 1;
}

static int _kernel_runtime_isRestarting(lua_State *L)
{
    lua_settop(L, 0);
    
    bool ret = (bool)xgame::runtime::isRestarting();
    xluacv_push_bool(L, ret);
    return 1;
}

static int _kernel_runtime_setAntialias(lua_State *L)
{
    lua_settop(L, 2);
    bool arg1 = (bool)xluacv_to_bool(L, 1);
    unsigned int arg2 = (unsigned int)xluacv_to_uint(L, 2);
    xgame::runtime::setAntialias(arg1, arg2);
    
    return 0;
}

static int _kernel_runtime_isAntialias(lua_State *L)
{
    lua_settop(L, 0);
    
    bool ret = (bool)xgame::runtime::isAntialias();
    xluacv_push_bool(L, ret);
    return 1;
}

static int _kernel_runtime_getNumSamples(lua_State *L)
{
    lua_settop(L, 0);
    
    unsigned int ret = (unsigned int)xgame::runtime::getNumSamples();
    xluacv_push_uint(L, ret);
    return 1;
}

static int _kernel_runtime_getPackageName(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getPackageName();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int _kernel_runtime_getVersion(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getVersion();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int _kernel_runtime_getVersionBuild(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getVersionBuild();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int _kernel_runtime_getChannel(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getChannel();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int _kernel_runtime_getOS(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getOS();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int _kernel_runtime_getDeviceInfo(lua_State *L)
{
    lua_settop(L, 0);
    
    const std::string ret = (std::string)xgame::runtime::getDeviceInfo();
    xluacv_push_std_string(L, ret);
    return 1;
}

static int luaopen_kernel_runtime(lua_State *L)
{
    xluacls_class(L, "kernel.runtime", nullptr);
    xluacls_setfunc(L, "clearStorage", _kernel_runtime_clearStorage);
    xluacls_setfunc(L, "launch", _kernel_runtime_launch);
    xluacls_setfunc(L, "restart", _kernel_runtime_restart);
    xluacls_setfunc(L, "isRestarting", _kernel_runtime_isRestarting);
    xluacls_setfunc(L, "setAntialias", _kernel_runtime_setAntialias);
    xluacls_setfunc(L, "isAntialias", _kernel_runtime_isAntialias);
    xluacls_setfunc(L, "getNumSamples", _kernel_runtime_getNumSamples);
    xluacls_property(L, "packageName", _kernel_runtime_getPackageName, nullptr);
    xluacls_property(L, "version", _kernel_runtime_getVersion, nullptr);
    xluacls_property(L, "versionBuild", _kernel_runtime_getVersionBuild, nullptr);
    xluacls_property(L, "channel", _kernel_runtime_getChannel, nullptr);
    xluacls_property(L, "os", _kernel_runtime_getOS, nullptr);
    xluacls_property(L, "deviceInfo", _kernel_runtime_getDeviceInfo, nullptr);
    
    lua_newtable(L);
    luaL_setmetatable(L, "kernel.runtime");
    
    return 1;
}
static int luaopen_kernel_filesytem(lua_State *L)
{
    xluacls_class(L, "kernel.filesytem", nullptr);
    
    
    lua_newtable(L);
    luaL_setmetatable(L, "kernel.filesytem");
    
    return 1;
}
int luaopen_xgame(lua_State *L)
{
    xlua_require(L, "kernel.runtime", luaopen_kernel_runtime);
    xlua_require(L, "kernel.filesytem", luaopen_kernel_filesytem);
    return 0;
}