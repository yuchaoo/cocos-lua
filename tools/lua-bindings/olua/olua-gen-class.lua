local olua = require "olua.core"

local format = olua.format
local class_map = {}

local function check_gen_class_func(cls, fi, write, func_filter)
    local meta = assert(class_map[cls.LUACLS], cls.LUACLS)
    if meta and getmetatable(meta) then
        local supermeta = getmetatable(meta).__index
        for _, f in ipairs(fi) do
            if f.PROTOTYPE and rawget(meta, f.PROTOTYPE) and supermeta[f.PROTOTYPE] then
                print(string.format("super class already export the func: %s %s", cls.CPPCLS, f.PROTOTYPE))
            end
        end
    end
    gen_class_func(cls, fi, write, func_filter)
end

local function gen_class_funcs(cls, write)
    local clsmeta = cls.PROTOTYPES

    if cls.SUPERCLS then
        assert(class_map[cls.SUPERCLS], 'super class ' .. cls.SUPERCLS .. ' must exported befor ' .. cls.CPPCLS)
        clsmeta = setmetatable(clsmeta, {__index = class_map[cls.SUPERCLS]})
    end
    class_map[cls.LUACLS] = clsmeta
    class_map[cls.CPPCLS] = clsmeta

    local func_filter = {}
    table.sort(cls.FUNCS, function (a, b)
        return a[1].LUAFUNC < b[1].LUAFUNC
    end)
    for i, fi in ipairs(cls.FUNCS) do
        check_gen_class_func(cls, fi, write, func_filter)
    end

    table.sort(cls.PROPS, function (a, b)
        return a.PROP_NAME < b.PROP_NAME
    end)
    for i, pi in ipairs(cls.PROPS) do
        if pi.GET then
            check_gen_class_func(cls, {pi.GET}, write, func_filter)
        end
        if pi.SET then
            check_gen_class_func(cls, {pi.SET}, write, func_filter)
        end
    end

    table.sort(cls.VARS, function (a, b)
        return a.VARNAME < b.VARNAME
    end)
    for i, ai in ipairs(cls.VARS) do
        check_gen_class_func(cls, {ai.GET}, write, func_filter)
        if ai.SET then
            check_gen_class_func(cls, {ai.SET}, write, func_filter)
        end
    end
end

local function gen_class_open(cls, write)
    local LUACLS = cls.LUACLS
    local CPPCLS = cls.CPPCLS
    local CPPCLS_PATH = olua.topath(cls)
    local SUPRECLS = "nullptr"
    if cls.SUPERCLS then
        local ti = test_typename(cls.SUPERCLS .. ' *') or test_typename(cls.SUPERCLS)
        assert(ti, cls.SUPERCLS)
        SUPRECLS = olua.stringfy(ti.LUACLS)
    end
    local FUNCS = {}
    local REG_LUATYPE = ''

    for i, fis in ipairs(cls.FUNCS) do
        local CPPFUNC = fis[1].CPPFUNC
        local LUAFUNC = fis[1].LUAFUNC
        FUNCS[#FUNCS + 1] = format([[
            oluacls_func(L, "${LUAFUNC}", _${CPPCLS_PATH}_${CPPFUNC});
        ]])
    end

    for i, pi in ipairs(cls.PROPS) do
        local PROP_NAME = pi.PROP_NAME
        local FUNC_GET = "nullptr"
        local FUNC_SET = "nullptr"
        if pi.GET then
            FUNC_GET = string.format("_%s_%s", CPPCLS_PATH, pi.GET.CPPFUNC)
        end
        if pi.SET then
            FUNC_SET = string.format("_%s_%s", CPPCLS_PATH, pi.SET.CPPFUNC)
        end
        FUNCS[#FUNCS + 1] = format([[
            oluacls_prop(L, "${PROP_NAME}", ${FUNC_GET}, ${FUNC_SET});
        ]])
    end

    for i, vi in ipairs(cls.VARS) do
        local VARNAME = vi.VARNAME
        local FUNC_GET = string.format("_%s_%s", CPPCLS_PATH, vi.GET.CPPFUNC)
        local FUNC_SET = "nullptr"
        if vi.SET and vi.SET.CPPFUNC then
           FUNC_SET = string.format("_%s_%s", CPPCLS_PATH, vi.SET.CPPFUNC)
        end
        FUNCS[#FUNCS + 1] = format([[
            oluacls_prop(L, "${VARNAME}", ${FUNC_GET}, ${FUNC_SET});
        ]])
    end

    table.sort(cls.CONSTS, function (a, b)
        return a.CONST_NAME < b.CONST_NAME
    end)
    for i, ci in ipairs(cls.CONSTS) do
        local CONST_FUNC
        local CONST_VALUE = ci.CONST_VALUE
        local CONST_NAME = ci.CONST_NAME
        if ci.TYPE == "boolean" then
            CONST_FUNC = "oluacls_const_bool"
        elseif ci.TYPE == "integer" then
            CONST_FUNC = "oluacls_const_integer"
        elseif ci.TYPE == "float" then
            CONST_FUNC = "oluacls_const_number"
        elseif ci.TYPE == "string" then
            CONST_FUNC = "oluacls_const_string"
            CONST_VALUE = olua.stringfy(CONST_VALUE)
        end
        FUNCS[#FUNCS + 1] = format([[
            ${CONST_FUNC}(L, "${CONST_NAME}", ${CONST_VALUE});
        ]])
    end

    table.sort(cls.CONSTS, function (a, b)
        return a.ENUM_NAME < b.ENUM_NAME
    end)
    for i, ei in ipairs(cls.ENUMS) do
        local ENUM_NAME = ei.ENUM_NAME
        local ENUM_VALUE = assert(ei.ENUM_VALUE, cls.CPPCLS)
        FUNCS[#FUNCS + 1] = format([[
            oluacls_const_integer(L, "${ENUM_NAME}", (lua_Integer)${ENUM_VALUE});
        ]])
    end

    FUNCS = table.concat(FUNCS, "\n")

    if cls.REG_LUATYPE then
        REG_LUATYPE = format([[
            olua_registerluatype<${CPPCLS}>(L, "${LUACLS}");
        ]])
    end

    write(format([[
        static int luaopen_${CPPCLS_PATH}(lua_State *L)
        {
            oluacls_class(L, "${LUACLS}", ${SUPRECLS});
            ${FUNCS}

            ${REG_LUATYPE}
            oluacls_createclassproxy(L);
            
            return 1;
        }
    ]]))
end

local function gen_class_decl_val(cls, write)
    if cls.CHUNK then
        write(format(cls.CHUNK))
        write('')
    end
end

function gen_class(module, cls, write)
    assert(not string.find(cls.LUACLS, '[: ]'), cls.LUACLS)
    gen_class_decl_val(cls, write)
    gen_class_funcs(cls, write)
    gen_class_open(cls, write)
end