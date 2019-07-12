local olua = require "olua.core"

local format = olua.format

local function gen_include(module, write)
    local INCLUDES = module.INCLUDES
    local CHUNK= module.CHUNK
    write(format([[
        //
        // generated by olua
        //
        ${INCLUDES}
    ]]))
    write('')
    if CHUNK then
        write(format(CHUNK))
        write('')
    end

    if module.CONVS then
        gen_conv(module, write)
    end
end

local function gen_classes(module, write)
    local function do_gen_class(cls)
        local ti = test_typename(cls.CPPCLS .. ' *') or test_typename(cls.CPPCLS)
        assert(ti, cls.CPPCLS)
        cls.LUACLS = assert(ti.LUACLS, cls.CPPCLS)
        if cls.DEFIF then
            write(cls.DEFIF)
        end
        gen_class(module, cls, write)
        if cls.DEFIF then
            write('#endif')
        end
        write('')
    end

    for i, cls in ipairs(module.CLASSES) do
        if #cls > 0 then
            for _, v in ipairs(cls) do
                do_gen_class(v)
            end
        else
            do_gen_class(cls)
        end
    end
end

local function gen_luaopen(module, write)
    local MODULE_NAME = module.NAME
    local REQUIRES = {}

    local function do_gen_open(cls)
        local LUACLS = cls.LUACLS
        local CPPCLS_PATH = olua.topath(cls)
        if cls.DEFIF then
            REQUIRES[#REQUIRES + 1] = cls.DEFIF
        end
        REQUIRES[#REQUIRES + 1] = format([[
            olua_require(L, "${LUACLS}", luaopen_${CPPCLS_PATH});
        ]])
        if cls.DEFIF then
            REQUIRES[#REQUIRES + 1] = '#endif'
        end
    end

    for i, cls in ipairs(module.CLASSES) do
        if #cls > 0 then
            for _, v in ipairs(cls) do
                do_gen_open(v)
            end
        else
            do_gen_open(cls)
        end
    end

    REQUIRES = table.concat(REQUIRES, "\n")
    write(format([[
        int luaopen_${MODULE_NAME}(lua_State *L)
        {
            ${REQUIRES}
            return 0;
        }
    ]]))
    write('')
end

function gen_source(module)
    local arr = {}
    local function append(value)
        value = string.gsub(value, ' *#if', '#if')
        value = string.gsub(value, ' *#endif', '#endif')
        arr[#arr + 1] = value
    end

    gen_include(module, append)
    gen_classes(module, append)
    gen_luaopen(module, append)
    olua.write(module.SOURCE_PATH, table.concat(arr, "\n"))
end