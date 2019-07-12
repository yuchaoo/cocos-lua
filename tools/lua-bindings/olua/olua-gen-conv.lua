local olua = require "olua.core"

local format = olua.format

local function gen_conv_header(module)
    local HEADER = string.upper(module.NAME)
    local DECL_FUNCS = {}

    for _, cv in ipairs(module.CONVS) do
        DECL_FUNCS[#DECL_FUNCS + 1] = "// " .. cv.CPPCLS
        local CPPCLS = cv.CPPCLS
        local CPPCLS_PATH = olua.topath(cv)
        if cv.FUNC.PUSH then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                int auto_olua_push_${CPPCLS_PATH}(lua_State *L, const ${CPPCLS} *value);
            ]])
        end
        if cv.FUNC.CHECK then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                void auto_olua_check_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value);
            ]])
        end
        if cv.FUNC.OPT then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                void auto_olua_opt_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value, const ${CPPCLS} &def);
            ]])
        end
        if cv.FUNC.PACK then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                void auto_olua_pack_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value);
            ]])
        end
        if cv.FUNC.UNPACK then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                int auto_olua_unpack_${CPPCLS_PATH}(lua_State *L, const ${CPPCLS} *value);
            ]])
        end
        if cv.FUNC.IS then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                bool auto_olua_is_${CPPCLS_PATH}(lua_State *L, int idx);
            ]])
        end
        if cv.FUNC.ISPACK then
            DECL_FUNCS[#DECL_FUNCS + 1] = format([[
                bool auto_olua_ispack_${CPPCLS_PATH}(lua_State *L, int idx);
            ]])
        end
        DECL_FUNCS[#DECL_FUNCS + 1] = ""
    end

    DECL_FUNCS = table.concat(DECL_FUNCS, "\n")

    local HEADER_INCLUDES = module.HEADER_INCLUDES
    olua.write(module.HEADER_PATH, format([[
        //
        // generated by olua
        //
        #ifndef __AUTO_GEN_LUA_${HEADER}_H__
        #define __AUTO_GEN_LUA_${HEADER}_H__

        ${HEADER_INCLUDES}

        ${DECL_FUNCS}

        #endif
    ]]))
end

local function gen_push_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local NUM_ARGS = #cv.PROPS
    local ARGS_CHUNK = {}

    for _, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        local VARNAME = pi.VARNAME
        local PUSH_FUNC
        local isbase = true
        local DECL_TYPE = ""
        if pi.TYPE.DECL_TYPE == 'lua_Number' then
            PUSH_FUNC = 'olua_setfieldnumber'
        elseif pi.TYPE.DECL_TYPE == 'lua_Integer'
            or pi.TYPE.DECL_TYPE == 'lua_Unsigned' then
            PUSH_FUNC = 'olua_setfieldinteger'
            DECL_TYPE = '(' .. pi.TYPE.DECL_TYPE .. ')'
        elseif pi.TYPE.CPPCLS == 'std::string' then
            PUSH_FUNC = 'olua_setfieldstring'
            VARNAME = VARNAME .. '.c_str()'
        elseif pi.TYPE.CPPCLS == 'bool' then
            PUSH_FUNC = 'olua_setfieldboolean'
        elseif pi.TYPE.CPPCLS == 'const char *' then
            PUSH_FUNC = 'olua_setfieldstring'
        else
            isbase = false
            PUSH_FUNC = pi.TYPE.FUNC_PUSH_VALUE
            -- error(string.format("%s %s %s", cv.VARNAME, cv.LUANAME, cv.TYPE.CPPCLS))
        end
        if isbase then
            ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                ${PUSH_FUNC}(L, -1, "${LUANAME}", ${DECL_TYPE}value->${VARNAME});
            ]])
        else
            ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                ${PUSH_FUNC}(L, &value->${VARNAME});
                lua_setfield(L, -2, "${LUANAME}");
            ]])
        end
    end

    ARGS_CHUNK = table.concat(ARGS_CHUNK, "\n")
    write(format([[
        int auto_olua_push_${CPPCLS_PATH}(lua_State *L, const ${CPPCLS} *value)
        {
            if (value) {
                lua_createtable(L, 0, ${NUM_ARGS});
                ${ARGS_CHUNK}
            } else {
                lua_pushnil(L);
            }
            
            return 1;
        }
    ]]))
    write('')
end

local function gen_check_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local NUM_ARGS = #cv.PROPS
    local ARGS_CHUNK = {}

    for _, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        local VARNAME = pi.VARNAME
        local CPPCLS = pi.TYPE.CPPCLS
        local CHECK_FUNC
        local isbase = true
        local INIT_VALUE = pi.TYPE.INIT_VALUE
        if pi.TYPE.DECL_TYPE == 'lua_Number' then
            CHECK_FUNC = 'olua_checkfieldnumber'
        elseif pi.TYPE.DECL_TYPE == 'lua_Integer'
            or pi.TYPE.DECL_TYPE == 'lua_Unsigned' then
            CHECK_FUNC = 'olua_checkfieldinteger'
        elseif pi.TYPE.CPPCLS == 'std::string' then
            CHECK_FUNC = 'olua_checkfieldstring'
        elseif pi.TYPE.CPPCLS == 'bool' then
            CHECK_FUNC = 'olua_checkfieldboolean'
        elseif pi.TYPE.CPPCLS == 'const char *' then
            CHECK_FUNC = 'olua_checkfieldstring'
        else
            CHECK_FUNC = pi.TYPE.FUNC_CHECK_VALUE
            isbase = false
            -- error(string.format("%s %s %s", cv.VARNAME, cv.LUANAME, cv.TYPE.CPPCLS))
        end
        if pi.DEFAULT then
            local DEFAULT = pi.DEFAULT
            CHECK_FUNC = string.gsub(CHECK_FUNC, '_check', '_opt')
            if isbase then
                ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                    value->${VARNAME} = (${CPPCLS})${CHECK_FUNC}(L, idx, "${LUANAME}", ${DEFAULT});
                ]])
            else
                ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                    lua_getfield(L, -1, "${LUANAME}");
                    ${CHECK_FUNC}(L, idx, &value->${VARNAME});
                    lua_pop(L, 1);
                ]])
            end
        else
            if isbase then
                ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                    value->${VARNAME} = (${CPPCLS})${CHECK_FUNC}(L, idx, "${LUANAME}");
                ]])
            else
                ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                    lua_getfield(L, -1, "${LUANAME}");
                    ${CHECK_FUNC}(L, idx, &value->${VARNAME});
                    lua_pop(L, 1);
                ]])
            end
        end
    end

    ARGS_CHUNK = table.concat(ARGS_CHUNK, "\n")
    write(format([[
        void auto_olua_check_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value)
        {
            if (!value) {
                luaL_error(L, "value is NULL");
            }
            idx = lua_absindex(L, idx);
            luaL_checktype(L, idx, LUA_TTABLE);
            ${ARGS_CHUNK}
        }
    ]]))
    write('')
end

local function gen_opt_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local NUM_ARGS = #cv.PROPS
    local ARGS_CHUNK = {}

    for _, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        local VARNAME = pi.VARNAME
        local CPPCLS = pi.TYPE.CPPCLS
        local CHECK_FUNC
        local isbase = true
        local INIT_VALUE = pi.TYPE.INIT_VALUE
        if pi.TYPE.DECL_TYPE == 'lua_Number' then
            CHECK_FUNC = 'olua_optfieldnumber'
        elseif pi.TYPE.DECL_TYPE == 'lua_Integer'
            or pi.TYPE.DECL_TYPE == 'lua_Unsigned' then
            CHECK_FUNC = 'olua_optfieldinteger'
        elseif pi.TYPE.CPPCLS == 'std::string' then
            CHECK_FUNC = 'olua_optfieldstring'
            INIT_VALUE = '""'
        elseif pi.TYPE.CPPCLS == 'bool' then
            CHECK_FUNC = 'olua_optfieldboolean'
        elseif pi.TYPE.CPPCLS == 'const char *' then
            CHECK_FUNC = 'olua_optfieldstring'
        else
            CHECK_FUNC = pi.TYPE.FUNC_CHECK_VALUE
            isbase = false
            -- error(string.format("%s %s %s", cv.VARNAME, cv.LUANAME, cv.TYPE.CPPCLS))
        end
        if isbase then
            ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                value->${VARNAME} = (${CPPCLS})${CHECK_FUNC}(L, idx, "${LUANAME}", ${INIT_VALUE});
            ]])
        else
            ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
                lua_getfield(L, -1, "${LUANAME}");
                ${CHECK_FUNC}(L, idx, &value->${VARNAME});
                lua_pop(L, 1);
            ]])
        end
    end

    ARGS_CHUNK = table.concat(ARGS_CHUNK, "\n")
    write(format([[
        void auto_olua_opt_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value, const ${CPPCLS} &def)
        {
            if (!value) {
                luaL_error(L, "value is NULL");
            }
            if (olua_isnil(L, idx)) {
                *value = def;
            } else {
                idx = lua_absindex(L, idx);
                luaL_checktype(L, idx, LUA_TTABLE);
                ${ARGS_CHUNK}
            }
        }
    ]]))
    write('')
end

local function gen_pack_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local NUM_ARGS = #cv.PROPS
    local ARGS_CHUNK = {}

    for i, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        local VARNAME = pi.VARNAME
        local CPPCLS = pi.TYPE.CPPCLS
        local ARG_N = i - 1
        local CHECK_FUNC
        if pi.TYPE.DECL_TYPE == 'lua_Number' then
            CHECK_FUNC = 'olua_checknumber'
        elseif pi.TYPE.DECL_TYPE == 'lua_Integer'
            or pi.TYPE.DECL_TYPE == 'lua_Unsigned' then
            CHECK_FUNC = 'olua_checkinteger'
        elseif pi.TYPE.CPPCLS == 'std::string' then
            CHECK_FUNC = 'olua_checkstring'
        elseif pi.TYPE.CPPCLS == 'bool' then
            CHECK_FUNC = 'olua_checktoboolean'
        elseif pi.TYPE.CPPCLS == 'const char *' then
            CHECK_FUNC = 'olua_checkstring'
        else
            error(string.format("%s %s %s", cv.VARNAME, cv.LUANAME, cv.TYPE.CPPCLS))
        end
        ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
            value->${VARNAME} = (${CPPCLS})${CHECK_FUNC}(L, idx + ${ARG_N});
        ]])
    end

    ARGS_CHUNK = table.concat(ARGS_CHUNK, "\n")
    write(format([[
        void auto_olua_pack_${CPPCLS_PATH}(lua_State *L, int idx, ${CPPCLS} *value)
        {
            if (!value) {
                luaL_error(L, "value is NULL");
            }
            idx = lua_absindex(L, idx);
            ${ARGS_CHUNK}
        }
    ]]))
    write('')
end

local function gen_unpack_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local NUM_ARGS = #cv.PROPS
    local ARGS_CHUNK = {}

    for i, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        local VARNAME = pi.VARNAME
        local CPPCLS = pi.TYPE.CPPCLS
        local ARG_N = i - 1
        local PUSH_FUNC
        if pi.TYPE.DECL_TYPE == 'lua_Number' then
            PUSH_FUNC = 'lua_pushnumber'
        elseif pi.TYPE.DECL_TYPE == 'lua_Integer'
            or pi.TYPE.DECL_TYPE == 'lua_Unsigned' then
            PUSH_FUNC = 'lua_pushinteger'
        elseif pi.TYPE.CPPCLS == 'std::string' then
            PUSH_FUNC = 'lua_pushstring'
            VARNAME = VARNAME .. '.c_str()'
        elseif pi.TYPE.CPPCLS == 'bool' then
            PUSH_FUNC = 'lua_pushboolean'
        elseif pi.TYPE.CPPCLS == 'const char *' then
            PUSH_FUNC = 'lua_pushstring'
        else
            error(string.format("%s %s %s", cv.VARNAME, cv.LUANAME, cv.TYPE.CPPCLS))
        end
        ARGS_CHUNK[#ARGS_CHUNK + 1] = format([[
            ${PUSH_FUNC}(L, value->${VARNAME});
        ]])
    end

    ARGS_CHUNK = table.concat(ARGS_CHUNK, "\n")
    write(format([[
        int auto_olua_unpack_${CPPCLS_PATH}(lua_State *L, const ${CPPCLS} *value)
        {
            if (value) {
                ${ARGS_CHUNK}
            } else {
                for (int i = 0; i < ${NUM_ARGS}; i++) {
                    lua_pushnil(L);
                }
            }
            
            return ${NUM_ARGS};
        }
    ]]))
    write('')
end

local function gen_is_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local TEST_HAS = {'olua_istable(L, idx)'}
    for i, pi in ipairs(cv.PROPS) do
        local LUANAME = pi.LUANAME
        table.insert(TEST_HAS, 2, format([[
            olua_hasfield(L, idx, "${LUANAME}")
        ]]))
    end
    TEST_HAS = table.concat(TEST_HAS, " && ")
    write(format([[
        bool auto_olua_is_${CPPCLS_PATH}(lua_State *L, int idx)
        {
            return ${TEST_HAS};
        }
    ]]))
    write('')
end

local function gen_ispack_func(cv, write)
    local CPPCLS = cv.CPPCLS
    local CPPCLS_PATH = olua.topath(cv)
    local TEST_TYPE = {}
    for i, pi in ipairs(cv.PROPS) do
        local FUNC_IS_VALUE = pi.TYPE.FUNC_IS_VALUE
        local VIDX = i - 1
        TEST_TYPE[#TEST_TYPE + 1] = format([[
            ${FUNC_IS_VALUE}(L, idx + ${VIDX})
        ]])
    end
    TEST_TYPE = table.concat(TEST_TYPE, " && ")
    write(format([[
        bool auto_olua_ispack_${CPPCLS_PATH}(lua_State *L, int idx)
        {
            return ${TEST_TYPE};
        }
    ]]))
    write('')
end

local function gen_funcs(cv, write)
    if cv.FUNC.PUSH then
        gen_push_func(cv, write)
    end
    if cv.FUNC.CHECK then
        gen_check_func(cv, write)
    end
    if cv.FUNC.OPT then
        gen_opt_func(cv, write)
    end
    if cv.FUNC.PACK then
        gen_pack_func(cv, write)
    end
    if cv.FUNC.UNPACK then
        gen_unpack_func(cv, write)
    end
    if cv.FUNC.IS then
        gen_is_func(cv, write)
    end
    if cv.FUNC.ISPACK then
        gen_ispack_func(cv, write)
    end
end

local function gen_conv_source(module)
    local arr = {}
    local function append(value)
        arr[#arr + 1] = value
    end

    local HEADER = string.upper(module.NAME)
    local INCLUDES = module.INCLUDES
    append(format([[
        //
        // generated by olua
        //
        ${INCLUDES}
    ]]))
    append('')

    for _, cv in ipairs(module.CONVS) do
        gen_funcs(cv, append)
    end

    olua.write(module.SOURCE_PATH, table.concat(arr, "\n"))
end

function gen_conv(module, write)
    if write then
        for _, cv in ipairs(module.CONVS) do
            gen_funcs(cv, write)
        end
    else
        gen_conv_header(module)
        gen_conv_source(module)
    end
end