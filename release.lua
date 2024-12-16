ffi = require ("ffi")
bit = require ("bit")


ffi.cdef [[
    // 3d vector struct
    typedef struct
    {
        float x;
        float y;
        float z;
    } Vector_3;

    // animstate structs; used to override animations
    typedef struct
    {
        char    pad0[0x60]; // 0x00
        void* pEntity; // 0x60
        void* pActiveWeapon; // 0x64
        void* pLastActiveWeapon; // 0x68
        float        flLastUpdateTime; // 0x6C
        int            iLastUpdateFrame; // 0x70
        float        flLastUpdateIncrement; // 0x74
        float        flEyeYaw; // 0x78
        float        flEyePitch; // 0x7C
        float        flGoalFeetYaw; // 0x80
        float        flLastFeetYaw; // 0x84
        float        flMoveYaw; // 0x88
        float        flLastMoveYaw; // 0x8C // changes when moving/jumping/hitting ground
        float        flLeanAmount; // 0x90
        char    pad1[0x4]; // 0x94
        float        flFeetCycle; // 0x98 0 to 1
        float        flMoveWeight; // 0x9C 0 to 1
        float        flMoveWeightSmoothed; // 0xA0
        float        flDuckAmount; // 0xA4
        float        flHitGroundCycle; // 0xA8
        float        flRecrouchWeight; // 0xAC
        Vector_3        vecOrigin; // 0xB0
        Vector_3        vecLastOrigin;// 0xBC
        Vector_3        vecVelocity; // 0xC8
        Vector_3        vecVelocityNormalized; // 0xD4
        Vector_3        vecVelocityNormalizedNonZero; // 0xE0
        float        flVelocityLenght2D; // 0xEC
        float        flJumpFallVelocity; // 0xF0
        float        flSpeedNormalized; // 0xF4 // clamped velocity from 0 to 1
        float m_flFeetSpeedForwardsOrSideWays; //0xF8
        float m_flFeetSpeedUnknownForwardOrSideways; //0xFC
        float        flRunningSpeed; // 0xF8
        float        flDuckingSpeed; // 0xFC
        float        flDurationMoving; // 0x100
        float        flDurationStill; // 0x104
        bool        bOnGround; // 0x108
        bool        bHitGroundAnimation; // 0x109
        char    pad2[0x2]; // 0x10A
        float        flNextLowerBodyYawUpdateTime; // 0x10C
        float        flDurationInAir; // 0x110
        float        flLeftGroundHeight; // 0x114
        float m_flStopToFullRunningFraction; //0x116
        float        flHitGroundWeight; // 0x118 // from 0 to 1, is 1 when standing
        float        flWalkToRunTransition; // 0x11C // from 0 to 1, doesnt change when walking or crouching, only running
        char    pad3[0x4]; // 0x120
        float        flAffectedFraction; // 0x124 // affected while jumping and running, or when just jumping, 0 to 1
        char    pad4[0x208]; // 0x128
        float        flMinBodyYaw; // 0x330
        float        flMaxBodyYaw; // 0x334
        float        flMinPitch; //0x338
        float        flMaxPitch; // 0x33C
        int            iAnimsetVersion; // 0x340
    } CPlayer_Animation_State;


    typedef void*(__thiscall* get_client_entity_t)(void*, int);
    typedef uintptr_t (__thiscall* GetClientEntityHandle_4242425_t)(void*, uintptr_t);
]]

math.clamp = function(v, min, max)
    if min > max then
        min, max = max, min
    end
    if v > max then
        return max
    end
    if v < min then
        return v
    end
    return v
end

math.vec_length2d = function(vec)
    root = 0.0
    sqst = vec.x * vec.x + vec.y * vec.y
    root = math.sqrt(sqst)
    return root
end

math.angle_diff = function(dest, src)
    local delta = 0.0

    delta = math.fmod(dest - src, 360.0)

    if dest > src then
        if delta >= 180 then
            delta = delta - 360
        end
    else
        if delta <= -180 then
            delta = delta + 360
        end
    end

    return delta
end

math.angle_normalize = function(angle)
    local ang = 0.0
    ang = math.fmod(angle, 360.0)

    if ang < 0.0 then
        ang = ang + 360
    end

    return ang
end

math.anglemod = function(a)
    local num = (360 / 65536) * bit.band(math.floor(a * (65536 / 360.0), 65535))
    return num
end

math.approach_angle = function(target, value, speed)
    target = math.anglemod(target)
    value = math.anglemod(value)

    local delta = target - value

    if speed < 0 then
        speed = -speed
    end

    if delta < -180 then
        delta = delta + 360
    elseif delta > 180 then
        delta = delta - 360
    end

    if delta > speed then
        value = value + speed
    elseif delta < -speed then
        value = value - speed
    else
        value = target
    end

    return value
end

math.yaw_to_player = function(player, forward)
    local LocalPlayer = entity_list.get_local_player()
    if not LocalPlayer or not player then
        return 0
    end

    local lOrigin = LocalPlayer:get_render_origin()
    local ViewAngles = engine.get_view_angles()
    local pOrigin = player:get_render_origin()
    local Yaw = (-math.atan2(pOrigin.x - lOrigin.x, pOrigin.y - lOrigin.y) / 3.14 * 180 + 180) - (forward and 90 or -90) -- - ViewAngles.y +(forward and 0 or -180)
    if Yaw >= 180 then
        Yaw = 360 - Yaw
        Yaw = -Yaw
    end
    return Yaw
end

eui = (function()
    local ui = {}
    ui.__type = {
        group = -1,
        button = 0,
        keybind = 1,
        text_input = 2,
        text = 3,
        separator = 4,
        list = 5,
        checkbox = 6,
        color_picker = 7,
        multi_selection = 8,
        selection = 9,
        slider = 10
    }
    ui.__metasave = true
    ui.__data = {}
    ui.create = function(_group, _column)
        local data = {
            group = _group,
            column = _column,
            id = ui.__type.group
        }
        menu.set_group_column(_group, _column)
        ui.__index = ui
        return setmetatable(data, ui)
    end
    function ui:create_element(_id, _name, _options)
        local ref = nil
        if _id == ui.__type.button then
            ref = menu.add_button(self.group, _name, _options.fn)
        elseif _id == ui.__type.checkbox then
            ref = menu.add_checkbox(self.group, _name, _options.default_value)
        elseif _id == ui.__type.color_picker then
            ref = _options.parent.ref:add_color_picker(_name, _options.default_value, _options.alpha)
        elseif _id == ui.__type.keybind then
            ref = _options.parent.ref:add_keybind(_name, _options.default_value)
        elseif _id == ui.__type.list then
            ref = menu.add_list(self.group, _name, _options.items, _options.visible_count)
        elseif _id == ui.__type.multi_selection then
            ref = menu.add_multi_selection(self.group, _name, _options.items, _options.visible_count)
        elseif _id == ui.__type.selection then
            ref = menu.add_selection(self.group, _name, _options.items, _options.visible_count)
        elseif _id == ui.__type.slider then
            ref = menu.add_slider(self.group, _name, _options.min, _options.max, _options.step, _options.precision, _options.suffix)
        elseif _id == ui.__type.text_input then
            ref = menu.add_text_input(self.group, _name)
        elseif _id == ui.__type.text then
            ref = menu.add_text(self.group, _name)
        elseif _id == ui.__type.separator then
            ref = menu.add_separator(self.group)
        end
        local data = {
            name = _name,
            id = _id,
            ref = ref,
            group = self.group,
            get = function(self, _item)
                if self.id == ui.__type.multi_selection then
                    return self.ref:get(_item)
                else
                    return self.ref:get()
                end
            end
        }
        if not ui.__data[self.group] then
            ui.__data[self.group] = {}
        end
        ui.__data[self.group][_name] = data
        if ui.__metasave then
            if not ui[self.group] then
                ui[self.group] = {}
            end
            ui[self.group][_name] = data
            self[_name] = data
        end
        return setmetatable(data, ui)
    end
    function ui:button(_name, _fn)
        _fn = _fn or function()
        end
        return self:create_element(ui.__type.button, _name, {
            fn = _fn
        })
    end
    function ui:checkbox(_name, _default_value)
        return self:create_element(ui.__type.checkbox, _name, {
            default_value = _default_value
        })
    end
    function ui:color_picker(_parent, _name, _default_value, _alpha)
        return self:create_element(ui.__type.color_picker, _name, {
            parent = _parent,
            default_value = _default_value,
            alpha = _alpha
        })
    end
    function ui:keybind(_parent, _name, _default_value)
        return self:create_element(ui.__type.keybind, _name, {
            parent = _parent,
            default_value = _default_value
        })
    end
    function ui:list(_name, _items, _visible_count)
        return self:create_element(ui.__type.list, _name, {
            items = _items,
            visible_count = _visible_count
        })
    end
    function ui:multi_selection(_name, _items, _visible_count)
        return self:create_element(ui.__type.multi_selection, _name, {
            items = _items,
            visible_count = _visible_count
        })
    end
    function ui:selection(_name, _items, _visible_count)
        return self:create_element(ui.__type.selection, _name, {
            items = _items,
            visible_count = _visible_count
        })
    end
    function ui:slider(_name, _min, _max, _step, _precision, _suffix)
        return self:create_element(ui.__type.slider, _name, {
            min = _min,
            max = _max,
            step = _step,
            precision = _precision,
            suffix = _suffix
        })
    end
    function ui:text_input(_name)
        return self:create_element(ui.__type.text_input, _name)
    end
    function ui:text(_name, _options)
        return self:create_element(ui.__type.text, _name, _options)
    end
    function ui:separator()
        return self:create_element(ui.__type.separator, "separator")
    end
    ui.export = function()
        local d = {}
        for i, v in pairs(ui.__data) do
            d[i] = {}
            for i0, v0 in pairs(v) do
                if not (v0.id < ui.__type.checkbox) then
                    if v0.id == ui.__type.multi_selection then
                        local s = {}
                        for i1, v1 in pairs(v0.ref:get_items()) do
                            table.insert(s, {v1, v0.ref:get(v1)})
                        end
                        table.insert(d[i], {v0.name, s})
                    elseif v0.id == ui.__type.color_picker then
                        local clr = v0.ref:get()
                        table.insert(d[i], {v0.name, clr.r, clr.g, clr.b, clr.a})
                    else
                        table.insert(d[i], {v0.name, v0.ref:get()})
                    end
                end
            end
        end
        return json.encode(d)
    end
    ui.import = function(data)
        local db = json.parse(data)
        for i, v in pairs(db) do
            for i0, v0 in pairs(v) do
                if not (ui.__data[i] == nil or ui.__data[i][v0[1]] == nil) then
                    if ui.__data[i][v0[1]].id == ui.__type.multi_selection then
                        for i1, v1 in pairs(v0[2]) do
                            ui.__data[i][v0[1]].ref:set(v1[1], v1[2])
                        end
                    elseif ui.__data[i][v0[1]].id == ui.__type.color_picker then
                        ui.__data[i][v0[1]].ref:set(color_t(v0[2], v0[3], v0[4], v0[5]))
                    else
                        ui.__data[i][v0[1]].ref:set(v0[2])
                    end
                end
            end
        end
    end
    function ui:depend(...)
        local args = {...}
        local result = nil
        for i, v in pairs(args) do
            local con = nil
            if type(v[1]) == "boolean" then
                con = v[1]
            else
                con = v[1].ref:get() == v[2]
            end
            if result ~= nil then
                result = (result and con)
            else
                result = con
            end
        end
        if self.id == -1 then
            menu.set_group_visibility(self.group, result)
        else
            self.ref:set_visible(result)
        end
    end
    return ui
end)()


base64 = (function()
    local base64 = {}
    local b, c, d = bit.lshift, bit.rshift, bit.band;
    local e, f, g, h, i, j, tostring, error, pairs = string.char, string.byte, string.gsub, string.sub, string.format, table.concat, tostring, error, pairs;
    local k = function(l, m, n)
        return d(c(l, m), b(1, n) - 1)
    end;
    local function o(p)
        local q, r = {}, {}
        for s = 1, 65 do
            local t = f(h(p, s, s)) or 32;
            if r[t] ~= nil then
                error("invalid alphabet: duplicate character " .. tostring(t), 3)
            end
            q[s - 1] = t;
            r[t] = s - 1
        end
        return q, r
    end
    local u, v = {}, {}
    u["base64"], v["base64"] = o("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
    u["base64url"], v["base64url"] = o("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    local w = {
        __index = function(x, y)
            if type(y) == "string" and y:len() == 64 or y:len() == 65 then
                u[y], v[y] = o(y)
                return x[y]
            end
        end
    }
    setmetatable(u, w)
    setmetatable(v, w)
    function base64.encode(z, q)
        q = u[q or "base64"] or error("invalid alphabet specified", 2)
        z = tostring(z)
        local A, B, C = {}, 1, #z;
        local D = C % 3;
        local E = {}
        for s = 1, C - D, 3 do
            local F, G, H = f(z, s, s + 2)
            local l = F * 0x10000 + G * 0x100 + H;
            local I = E[l]
            if not I then
                I = e(q[k(l, 18, 6)], q[k(l, 12, 6)], q[k(l, 6, 6)], q[k(l, 0, 6)])
                E[l] = I
            end
            A[B] = I;
            B = B + 1
        end
        if D == 2 then
            local F, G = f(z, C - 1, C)
            local l = F * 0x10000 + G * 0x100;
            A[B] = e(q[k(l, 18, 6)], q[k(l, 12, 6)], q[k(l, 6, 6)], q[64])
        elseif D == 1 then
            local l = f(z, C) * 0x10000;
            A[B] = e(q[k(l, 18, 6)], q[k(l, 12, 6)], q[64], q[64])
        end
        return j(A)
    end
    function base64.decode(J, r)
        r = v[r or "base64"] or error("invalid alphabet specified", 2)
        local K = "[^%w%+%/%=]"
        if r then
            local L, M;
            for N, O in pairs(r) do
                if O == 62 then
                    L = N
                elseif O == 63 then
                    M = N
                end
            end
            K = i("[^%%w%%%s%%%s%%=]", e(L), e(M))
        end
        J = g(tostring(J), K, '')
        local E = {}
        local A, B = {}, 1;
        local C = #J;
        local P = h(J, -2) == "==" and 2 or h(J, -1) == "=" and 1 or 0;
        for s = 1, P > 0 and C - 4 or C, 4 do
            local F, G, H, Q = f(J, s, s + 3)
            local R = F * 0x1000000 + G * 0x10000 + H * 0x100 + Q;
            local I = E[R]
            if not I then
                local l = r[F] * 0x40000 + r[G] * 0x1000 + r[H] * 0x40 + r[Q]
                I = e(k(l, 16, 8), k(l, 8, 8), k(l, 0, 8))
                E[R] = I
            end
            A[B] = I;
            B = B + 1
        end
        if P == 1 then
            local F, G, H = f(J, C - 3, C - 1)
            local l = r[F] * 0x40000 + r[G] * 0x1000 + r[H] * 0x40;
            A[B] = e(k(l, 16, 8), k(l, 8, 8))
        elseif P == 2 then
            local F, G = f(J, C - 3, C - 2)
            local l = r[F] * 0x40000 + r[G] * 0x1000;
            A[B] = e(k(l, 16, 8))
        end
        return j(A)
    end
    return base64;
end)()

json = (function()
    local json = {
        _version = "0.1.2"
    }
    local encode
    local escape_char_map = {
        ["\\"] = "\\",
        ["\""] = "\"",
        ["\b"] = "b",
        ["\f"] = "f",
        ["\n"] = "n",
        ["\r"] = "r",
        ["\t"] = "t"
    }
    local escape_char_map_inv = {
        ["/"] = "/"
    }
    for k, v in pairs(escape_char_map) do
        escape_char_map_inv[v] = k
    end
    local function escape_char(c)
        return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
    end
    local function encode_nil(val)
        return "null"
    end
    local function encode_table(val, stack)
        local res = {}
        stack = stack or {}
        if stack[val] then
            error("circular reference")
        end
        stack[val] = true
        if rawget(val, 1) ~= nil or next(val) == nil then
            local n = 0
            for k in pairs(val) do
                if type(k) ~= "number" then
                    error("invalid table: mixed or invalid key types")
                end
                n = n + 1
            end
            if n ~= #val then
                error("invalid table: sparse array")
            end
            for i, v in ipairs(val) do
                table.insert(res, encode(v, stack))
            end
            stack[val] = nil
            return "[" .. table.concat(res, ",") .. "]"
        else
            for k, v in pairs(val) do
                if type(k) ~= "string" then
                    error("invalid table: mixed or invalid key types")
                end
                table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
            end
            stack[val] = nil
            return "{" .. table.concat(res, ",") .. "}"
        end
    end
    local function encode_string(val)
        return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end
    local function encode_number(val)
        if val ~= val or val <= -math.huge or val >= math.huge then
            error("unexpected number value '" .. tostring(val) .. "'")
        end
        return string.format("%.14g", val)
    end
    local type_func_map = {
        ["nil"] = encode_nil,
        ["table"] = encode_table,
        ["string"] = encode_string,
        ["number"] = encode_number,
        ["boolean"] = tostring
    }
    encode = function(val, stack)
        local t = type(val)
        local f = type_func_map[t]
        if f then
            return f(val, stack)
        end
        error("unexpected type '" .. t .. "'")
    end
    function json.encode(val)
        return (encode(val))
    end
    local parse
    local function create_set(...)
        local res = {}
        for i = 1, select("#", ...) do
            res[select(i, ...)] = true
        end
        return res
    end
    local space_chars = create_set(" ", "\t", "\r", "\n")
    local delim_chars = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
    local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
    local literals = create_set("true", "false", "null")
    local literal_map = {
        ["true"] = true,
        ["false"] = false,
        ["null"] = nil
    }
    local function next_char(str, idx, set, negate)
        for i = idx, #str do
            if set[str:sub(i, i)] ~= negate then
                return i
            end
        end
        return #str + 1
    end
    local function decode_error(str, idx, msg)
        local line_count = 1
        local col_count = 1
        for i = 1, idx - 1 do
            col_count = col_count + 1
            if str:sub(i, i) == "\n" then
                line_count = line_count + 1
                col_count = 1
            end
        end
        error(string.format("%s at line %d col %d", msg, line_count, col_count))
    end
    local function codepoint_to_utf8(n)
        local f = math.floor
        if n <= 0x7f then
            return string.char(n)
        elseif n <= 0x7ff then
            return string.char(f(n / 64) + 192, n % 64 + 128)
        elseif n <= 0xffff then
            return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
        elseif n <= 0x10ffff then
            return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128, f(n % 4096 / 64) + 128, n % 64 + 128)
        end
        error(string.format("invalid unicode codepoint '%x'", n))
    end
    local function parse_unicode_escape(s)
        local n1 = tonumber(s:sub(1, 4), 16)
        local n2 = tonumber(s:sub(7, 10), 16)
        if n2 then
            return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
        else
            return codepoint_to_utf8(n1)
        end
    end
    local function parse_string(str, i)
        local res = ""
        local j = i + 1
        local k = j
        while j <= #str do
            local x = str:byte(j)
            if x < 32 then
                decode_error(str, j, "control character in string")
            elseif x == 92 then
                res = res .. str:sub(k, j - 1)
                j = j + 1
                local c = str:sub(j, j)
                if c == "u" then
                    local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1) or str:match("^%x%x%x%x", j + 1) or decode_error(str, j - 1, "invalid unicode escape in string")
                    res = res .. parse_unicode_escape(hex)
                    j = j + #hex
                else
                    if not escape_chars[c] then
                        decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                    end
                    res = res .. escape_char_map_inv[c]
                end
                k = j + 1
            elseif x == 34 then
                res = res .. str:sub(k, j - 1)
                return res, j + 1
            end
            j = j + 1
        end
        decode_error(str, i, "expected closing quote for string")
    end
    local function parse_number(str, i)
        local x = next_char(str, i, delim_chars)
        local s = str:sub(i, x - 1)
        local n = tonumber(s)
        if not n then
            decode_error(str, i, "invalid number '" .. s .. "'")
        end
        return n, x
    end
    local function parse_literal(str, i)
        local x = next_char(str, i, delim_chars)
        local word = str:sub(i, x - 1)
        if not literals[word] then
            decode_error(str, i, "invalid literal '" .. word .. "'")
        end
        return literal_map[word], x
    end
    local function parse_array(str, i)
        local res = {}
        local n = 1
        i = i + 1
        while 1 do
            local x
            i = next_char(str, i, space_chars, true)
            if str:sub(i, i) == "]" then
                i = i + 1
                break
            end
            x, i = parse(str, i)
            res[n] = x
            n = n + 1
            i = next_char(str, i, space_chars, true)
            local chr = str:sub(i, i)
            i = i + 1
            if chr == "]" then
                break
            end
            if chr ~= "," then
                decode_error(str, i, "expected ']' or ','")
            end
        end
        return res, i
    end
    local function parse_object(str, i)
        local res = {}
        i = i + 1
        while 1 do
            local key, val
            i = next_char(str, i, space_chars, true)
            if str:sub(i, i) == "}" then
                i = i + 1
                break
            end
            if str:sub(i, i) ~= '"' then
                decode_error(str, i, "expected string for key")
            end
            key, i = parse(str, i)
            i = next_char(str, i, space_chars, true)
            if str:sub(i, i) ~= ":" then
                decode_error(str, i, "expected ':' after key")
            end
            i = next_char(str, i + 1, space_chars, true)
            val, i = parse(str, i)
            res[key] = val
            i = next_char(str, i, space_chars, true)
            local chr = str:sub(i, i)
            i = i + 1
            if chr == "}" then
                break
            end
            if chr ~= "," then
                decode_error(str, i, "expected '}' or ','")
            end
        end
        return res, i
    end
    local char_func_map = {
        ['"'] = parse_string,
        ["0"] = parse_number,
        ["1"] = parse_number,
        ["2"] = parse_number,
        ["3"] = parse_number,
        ["4"] = parse_number,
        ["5"] = parse_number,
        ["6"] = parse_number,
        ["7"] = parse_number,
        ["8"] = parse_number,
        ["9"] = parse_number,
        ["-"] = parse_number,
        ["t"] = parse_literal,
        ["f"] = parse_literal,
        ["n"] = parse_literal,
        ["["] = parse_array,
        ["{"] = parse_object
    }
    parse = function(str, idx)
        local chr = str:sub(idx, idx)
        local f = char_func_map[chr]
        if f then
            return f(str, idx)
        end
        decode_error(str, idx, "unexpected character '" .. chr .. "'")
    end
    function json.parse(str)
        if type(str) ~= "string" then
            error("expected argument of type string, got " .. type(str))
        end
        local res, idx = parse(str, next_char(str, 1, space_chars, true))
        idx = next_char(str, idx, space_chars, true)
        if idx <= #str then
            decode_error(str, idx, "trailing garbage")
        end
        return res
    end
    return json
end)()

dragsystem = (function()
    local is_menu_visible = false
    local check_menu_events = function()
        is_menu_visible = menu.is_open()
    end
    callbacks.add(e_callbacks.PAINT, check_menu_events)
    local system = {}
    local screen_size = render.get_screen_size()
    system.list = {}
    system.windows = {}
    system.__index = system
    system.register = function(position, size, global_name, ins_function)
        local data = {
            size = size,
            position = vec2_t(position[1]:get(), position[2]:get()),
            is_dragging = false,
            drag_position = {
                x = 0,
                y = 0
            },
            global_name = global_name,
            ins_function = ins_function,
            ui_callbacks = {
                x = position[1],
                y = position[2]
            }
        }
        table.insert(system.windows, data)
        return setmetatable(data, system)
    end
    function system:limit_positions()
        if self.position.x <= 0 then
            self.position.x = 0
        end
        if self.position.x + self.size.x >= screen_size.x - 1 then
            self.position.x = screen_size.x - self.size.x - 1
        end
        if self.position.y <= 0 then
            self.position.y = 0
        end
        if self.position.y + self.size.y >= screen_size.y - 1 then
            self.position.y = screen_size.y - self.size.y - 1
        end
    end
    function system:is_in_area(mouse_position)
        return mouse_position.x >= self.position.x and mouse_position.x <= self.position.x + self.size.x and mouse_position.y >= self.position.y and mouse_position.y <= self.position.y + self.size.y
    end
    function system:update(...)
        if is_menu_visible then
            local mouse_position = input.get_mouse_pos()
            local is_in_area = self:is_in_area(mouse_position)
            local list = system.list
            local is_key_pressed = input.is_key_held(e_keys.MOUSE_LEFT)
            if (is_in_area or self.is_dragging) and is_key_pressed and (list.target == "" or list.target == self.global_name) then
                list.target = self.global_name
                if not self.is_dragging then
                    self.is_dragging = true
                    self.drag_position = mouse_position - self.position
                else
                    self.position = mouse_position - self.drag_position
                    self:limit_positions()
                    self.ui_callbacks.x.ref:set(math.floor(self.position.x))
                    self.ui_callbacks.y.ref:set(math.floor(self.position.y))
                end
            elseif not is_key_pressed then
                list.target = ""
                self.is_dragging = false
                self.drag_position = {
                    x = 0,
                    y = 0
                }
            end
        end
        self.ins_function(self, ...)
    end
    system.on_config_load = function()
        for _, point in pairs(system.windows) do
            point.position = vec2_t(point.ui_callbacks.x:get(), point.ui_callbacks.y:get())
        end
    end
    return system
end)()

bettercall = (function ()
    local cb = {}
    cb.__global_callbacks = {}

    function cb:ensure_global_event_registered(event_name)
        if not self.__global_callbacks[event_name] then
            self.__global_callbacks[event_name] = {}
            callbacks.add(event_name, function(...)
                local callbacks_to_run = self.__global_callbacks[event_name]
                for _, cb_data in ipairs(callbacks_to_run) do
                    if cb_data.state() then
                        cb_data.callback(...)
                    end
                end
            end)
        end
    end

    function cb:new()
        local instance = {
            bettercall_callbacks = {}
        }
        setmetatable(instance, { __index = self })
        return instance
    end

    function cb:add(event_name, callback, state)
        self:ensure_global_event_registered(event_name)

        local cb_data = {
            callback = callback,
            state = state or function() return true end
        }

        if not self.bettercall_callbacks[event_name] then
            self.bettercall_callbacks[event_name] = {}
        end
        table.insert(self.bettercall_callbacks[event_name], cb_data)

        if not self.__global_callbacks[event_name] then
            self.__global_callbacks[event_name] = {}
        end
        table.insert(self.__global_callbacks[event_name], cb_data)

        return cb_data
    end

    function cb:set_state(cb_data, new_state)
        if cb_data then
            cb_data.state = new_state
        end
    end

    function cb:remove(event_name, callback_to_remove)
        local callbacks = self.bettercall_callbacks[event_name]
        if callbacks then
            for i = #callbacks, 1, -1 do
                if callbacks[i].callback == callback_to_remove then
                    table.remove(callbacks, i)
                    break
                end
            end
        end
    end

    function cb:clear(event_name)
        self.bettercall_callbacks[event_name] = nil
    end

    function cb:clear_all()
        self.bettercall_callbacks = {}
    end

    return cb
end)()

animation = (function ()
    local animation_data = {}

    local lerp = function (start, end_pos, time)
        if type(start) == "userdata" then
            local color_data = {0, 0, 0, 0}
            for i, component in ipairs({"r", "g", "b", "a"}) do
                color_data[i] = lerp(start[component], end_pos[component], time)
            end
            return color_t(unpack(color_data))
        end

        return start + (end_pos - start) * time
    end

    local new = function (name, value, time)
        if animation_data[name] == nil then
            animation_data[name] = 0
        end

        animation_data[name] = lerp(animation_data[name], value, global_vars.frame_time() * time)

        return animation_data[name]
    end

    local get = function (name)
        return animation_data[name]
    end
    
    return {
        new = new,
        get = get
    }
end)()

clipboard = (function ()
    local vgui_sys = 'VGUI_System010'
    local vgui2 = 'vgui2.dll'
    local VTableBind = function (mod, face, n, type)
        local iface = memory.create_interface(mod, face) or error(face .. ": invalid interface")
        local instance = memory.get_vfunc(iface, n) or error(index .. ": invalid index")
        local success, typeof = pcall(ffi.typeof, type)
        if not success then
            error(typeof, 2)
        end
        local fnptr = ffi.cast(typeof, instance) or error(type .. ": invalid typecast")
        return function(...)
            return fnptr(tonumber(ffi.cast("void***", iface)), ...)
        end
    end
    local native_GetClipboardTextCount = VTableBind(vgui2, vgui_sys, 7, "int(__thiscall*)(void*)")
    local native_SetClipboardText = VTableBind(vgui2, vgui_sys, 9, "void(__thiscall*)(void*, const char*, int)")
    local native_GetClipboardText = VTableBind(vgui2, vgui_sys, 11, "int(__thiscall*)(void*, int, const char*, int)")
    return {
        get = function()
            local len = native_GetClipboardTextCount()
            if (len > 0) then
                local char_arr = ffi.typeof("char[?]")(len)
                native_GetClipboardText(0, char_arr, len)
                return ffi.string(char_arr, len - 1)
            end
        end,
        set = function(text)
            text = tostring(text)
            native_SetClipboardText(text, string.len(text))
        end
    }
end)()

fonts = (function()
    local self = {}
    self.fonts = {}

    self.register = function(indx, font, size, weight, ...)
        if not self.fonts[indx] then
            -- Pasamos las flags como argumentos individuales
            self.fonts[indx] = render.create_font(font, size or 12, weight or 400, ...)
        end
        return self.fonts[indx]
    end

    self.default = function()
        return render.get_default_font()
    end

    self.get = function(indx)
        return self.fonts[indx]
    end

    self.get_or_register = function(indx, font, size, weight, ...)
        return self.register(indx, font, size, weight, ...)
    end

    return self
end)()


filesystem = (function()
    local tbl = {}
    tbl.__index = {}

    -- Obtener interfaces
    tbl.class = ffi.cast(
        ffi.typeof("void***"),
        memory.create_interface("filesystem_stdio.dll", "VBaseFileSystem011")
    )
    tbl.v_table = tbl.class[0]
    tbl.full_class = ffi.cast(
        "void***",
        memory.create_interface("filesystem_stdio.dll", "VFileSystem017")
    )
    tbl.v_fltable = tbl.full_class[0]

    -- Definir métodos usando casting
    tbl.casts = {
        read_file = ffi.cast("int (__thiscall*)(void*, void*, int, void*)", tbl.v_table[0]),
        write_file = ffi.cast("int (__thiscall*)(void*, void const*, int, void*)", tbl.v_table[1]),
        open_file = ffi.cast("void* (__thiscall*)(void*, const char*, const char*, const char*)", tbl.v_table[2]),
        close_file = ffi.cast("void (__thiscall*)(void*, void*)", tbl.v_table[3]),
        file_size = ffi.cast("unsigned int (__thiscall*)(void*, void*)", tbl.v_table[7]),
        file_exists = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", tbl.v_table[10]),
        delete_file = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", tbl.v_fltable[20]),
        rename_file = ffi.cast("bool (__thiscall*)(void*, const char*, const char*, const char*)", tbl.v_fltable[21]),
        create_dir = ffi.cast("void (__thiscall*)(void*, const char*, const char*)", tbl.v_fltable[22]),
        is_dir = ffi.cast("bool (__thiscall*)(void*, const char*, const char*)", tbl.v_fltable[23])
    }

    -- Métodos adicionales
    local filesystem = memory.create_interface("filesystem_stdio.dll", "VFileSystem017")
    local call = ffi.cast(ffi.typeof("void***"), filesystem)

    ffi.cdef([[
        typedef void (__thiscall* AddSearchPath)(void*, const char*, const char*);
        typedef void (__thiscall* RemoveSearchPaths)(void*, const char*);
        typedef const char* (__thiscall* FindNext)(void*, int);
        typedef bool (__thiscall* FindIsDirectory)(void*, int);
        typedef void (__thiscall* FindClose)(void*, int);
        typedef const char* (__thiscall* FindFirstEx)(void*, const char*, const char*, int*);
        typedef long (__thiscall* GetFileTime)(void*, const char*, const char*);
    ]])

    local add_search_path = ffi.cast("AddSearchPath", call[0][11])
    local remove_search_paths = ffi.cast("RemoveSearchPaths", call[0][14])
    local find_next = ffi.cast("FindNext", call[0][33])
    local find_is_dir = ffi.cast("FindIsDirectory", call[0][34])
    local find_close = ffi.cast("FindClose", call[0][35])
    local find_first_ex = ffi.cast("FindFirstEx", call[0][36])

    -- Modos de apertura de archivos
    tbl.modes = {
        ["r"] = "r", ["w"] = "w", ["a"] = "a",
        ["r+"] = "r+", ["w+"] = "w+", ["a+"] = "a+",
        ["rb"] = "rb", ["wb"] = "wb", ["ab"] = "ab",
        ["rb+"] = "rb+", ["wb+"] = "wb+", ["ab+"] = "ab+"
    }

    -- Funciones
    tbl.open = function(file, mode, id)
        if not tbl.modes[mode] then
            error("File mode error!")
        end
        return setmetatable({
            file = file,
            mode = mode,
            path_id = id,
            handle = tbl.casts.open_file(tbl.class, file, mode, id)
        }, tbl)
    end

    tbl.close = function(fs)
        tbl.casts.close_file(tbl.class, fs.handle)
    end

    tbl.exists = function(file, id)
        return tbl.casts.file_exists(tbl.class, file, id)
    end

    tbl.get_size = function(fs)
        return tbl.casts.file_size(tbl.class, fs.handle)
    end

    tbl.write_binary = function(path, buffer)
        local fs = tbl.open(path, "wb", "MOD")
        tbl.casts.write_file(tbl.class, buffer, #buffer, fs.handle)
        tbl.close(fs)
    end

    tbl.read_binary = function(path)
        local fs = tbl.open(path, "rb", "MOD")
        local size = tbl.get_size(fs)
        local output = ffi.new("char[?]", size)
        tbl.casts.read_file(tbl.class, output, size, fs.handle)
        tbl.close(fs)
        return ffi.string(output, size)
    end

    tbl.write = function(path, buffer)
        local fs = tbl.open(path, "w", "MOD")
        tbl.casts.write_file(tbl.class, buffer, #buffer, fs.handle)
        tbl.close(fs)
    end

    tbl.append = function(path, buffer)
        local fs = tbl.open(path, "a", "MOD")
        tbl.casts.write_file(tbl.class, buffer, #buffer, fs.handle)
        tbl.close(fs)
    end

    tbl.read = function(path)
        local fs = tbl.open(path, "r", "MOD")
        local size = tbl.get_size(fs)
        local output = ffi.new("char[?]", size + 1)
        tbl.casts.read_file(tbl.class, output, size, fs.handle)
        tbl.close(fs)
        return ffi.string(output)
    end

    tbl.rename = function(old_path, new_path, id)
        return tbl.casts.rename_file(tbl.full_class, old_path, new_path, id)
    end

    tbl.delete = function(file, id)
        tbl.casts.delete_file(tbl.full_class, file, id)
    end

    tbl.create_directory = function(path, id)
        tbl.casts.create_dir(tbl.full_class, path, id)
    end

    tbl.is_directory = function(path, id)
        return tbl.casts.is_dir(tbl.full_class, path, id)
    end

    return tbl
end)()

panorama = (function()
    local _INFO, ffi, cast, typeof, new, string, metatype, find_pattern, create_interface, add_shutdown_callback, safe_mode, ffiCEnabled, shutdown, _error, exception, exceptionCb, rawgetImpl, rawsetImpl, __thiscall, table_copy, vtable_bind, interface_ptr, vtable_entry, vtable_thunk, proc_bind, follow_call, v8js_args, v8js_function, is_array, nullptr, intbuf, panorama, vtable, DllImport, UIEngine, nativeIsValidPanelPointer, nativeGetLastDispatchedEventTargetPanel, nativeCompileRunScript, nativeRunScript, nativeGetV8GlobalContext, nativeGetIsolate, nativeHandleException, nativeGetParent, nativeGetID, nativeFindChildTraverse, nativeGetJavaScriptContextParent, nativeGetPanelContext, jsContexts, getJavaScriptContextParent, v8_dll, pIsolate, persistentTbl, Message, Local, MaybeLocal, PersistentProxy_mt, Persistent, Value, Object, Array, Function, ObjectTemplate, FunctionTemplate, FunctionCallbackInfo, Primitive, Null, Undefined, Boolean, Number, Integer, String, Isolate, Context, HandleScope, TryCatch, Script, PanelInfo_t, CUtlVector_Constructor_t, panelList, panelArrayOffset, panelArray _INFO = { _VERSION = 1.7 } setmetatable(_INFO, { __call = function(self) return self._VERSION end, __tostring = function(self) return self._VERSION end }) ffi = require('ffi') do local _obj_0 = ffi cast, typeof, new, string, metatype = _obj_0.cast, _obj_0.typeof, _obj_0.new, _obj_0.string, _obj_0.metatype end find_pattern = function() return error('Unsupported provider') end create_interface = function() return error('Unsupported provider') end add_shutdown_callback = function() return print('WARNING: Cleanup before shutdown disabled') end local api while true do if _G == nil then if quick_maths == nil then if info.fatality == nil then api = 'ev0lve' break end api = 'fa7ality' break end api = 'rifk7' break end if MatSystem ~= nil then api = 'spirthack' break end if file ~= nil then api = 'legendware' break end if GameEventManager ~= nil then api = 'memesense' break end if penetration ~= nil then api = 'pandora' break end if math_utils ~= nil then api = 'legion' break end if plist ~= nil then api = 'gamesense' break end if network ~= nil then api = 'neverlose' break end if renderer ~= nil and renderer.setup_texture ~= nil then api = 'nixware' break end api = 'primordial' break end local _exp_0 = api if 'ev0lve' == _exp_0 then find_pattern = utils.find_pattern create_interface = utils.find_interface add_shutdown_callback = function() end elseif 'fa7ality' == _exp_0 then find_pattern = utils.find_pattern create_interface = utils.find_interface add_shutdown_callback = function() end elseif 'primordial' == _exp_0 then find_pattern = memory.find_pattern create_interface = memory.create_interface add_shutdown_callback = function(fn) return callbacks.add(e_callbacks.SHUTDOWN, fn) end elseif 'memesense' == _exp_0 then find_pattern = Utils.PatternScan create_interface = Utils.CreateInterface add_shutdown_callback = function(fn) return Cheat.RegisterCallback('destroy', fn) end elseif 'legendware' == _exp_0 then find_pattern = utils.find_signature create_interface = utils.create_interface add_shutdown_callback = function(fn) return client.add_callback('unload', fn) end elseif 'pandora' == _exp_0 then find_pattern = client.find_sig create_interface = client.create_interface elseif 'legion' == _exp_0 then find_pattern = memory.find_pattern create_interface = memory.create_interface add_shutdown_callback = function(fn) return client.add_callback('on_unload', fn) end elseif 'gamesense' == _exp_0 then find_pattern = function(moduleName, pattern) local gsPattern = '' for token in pattern:gmatch('%S+') do gsPattern = gsPattern .. (token == '?' and '\xCC' or _G.string.char(tonumber(token, 16))) end return client.find_signature(moduleName, gsPattern) end create_interface = client.create_interface add_shutdown_callback = function(fn) return client.set_event_callback('shutdown', fn) end elseif 'nixware' == _exp_0 then find_pattern = client.find_pattern create_interface = se.create_interface add_shutdown_callback = function(fn) return client.register_callback("unload", fn) end elseif 'neverlose' == _exp_0 then find_pattern = utils.opcode_scan create_interface = utils.create_interface add_shutdown_callback = function() end elseif 'rifk7' == _exp_0 then find_pattern = function(module_name, pattern) local stupid = cast("uint32_t*", engine.signature(module_name, pattern)) assert(tonumber(stupid) ~= 0) return stupid[0] end create_interface = function(module_name, interface_name) interface_name = string.gsub(interface_name, "%d+", "") return general.create_interface(module_name, interface_name) end print = function(text) return general.log_to_console_colored("[lua] " .. tostring(text), 255, 141, 161, 255) end elseif 'spirthack' == _exp_0 then find_pattern = Utils.PatternScan create_interface = Utils.CreateInterface end safe_mode = (xpcall and pcall) and true or false ffiCEnabled = ffi.C and api ~= 'gamesense' shutdown = function() for _, v in pairs(persistentTbl) do Persistent(v):disposeGlobal() end end _error = error if error then error = function(msg) shutdown() return _error(msg) end end exception = function(msg) return print('Caught lua exception in V8 HandleScope: ', tostring(msg)) end exceptionCb = function(msg) return print('Caught lua exception in V8 Function Callback: ', tostring(msg)) end rawgetImpl = function(tbl, key) local mtb = getmetatable(tbl) setmetatable(tbl, nil) local res = tbl[key] setmetatable(tbl, mtb) return res end rawsetImpl = function(tbl, key, value) local mtb = getmetatable(tbl) setmetatable(tbl, nil) tbl[key] = value return setmetatable(tbl, mtb) end if not rawget then rawget = rawgetImpl end if not rawset then rawset = rawsetImpl end __thiscall = function(func, this) return function(...) return func(this, ...) end end table_copy = function(t) local _tbl_0 = { } for k, v in pairs(t) do _tbl_0[k] = v end return _tbl_0 end vtable_bind = function(module, interface, index, typedef) local addr = cast('void***', create_interface(module, interface)) or error(interface .. ' is nil.') return __thiscall(cast(typedef, addr[0][index]), addr) end interface_ptr = typeof('void***') vtable_entry = function(instance, i, ct) return cast(ct, cast(interface_ptr, instance)[0][i]) end vtable_thunk = function(i, ct) local t = typeof(ct) return function(instance, ...) return vtable_entry(instance, i, t)(instance, ...) end end proc_bind = (function() local fnGetProcAddress fnGetProcAddress = function() return error('Failed to load GetProcAddress') end local fnGetModuleHandle fnGetModuleHandle = function() return error('Failed to load GetModuleHandleA') end if ffiCEnabled then ffi.cdef([[ uint32_t GetProcAddress(uint32_t, const char*); uint32_t GetModuleHandleA(const char*); ]]) fnGetProcAddress = ffi.C.GetProcAddress fnGetModuleHandle = ffi.C.GetModuleHandleA else fnGetProcAddress = cast('uint32_t(__stdcall*)(uint32_t, const char*)', cast('uint32_t**', cast('uint32_t', find_pattern('engine.dll', 'FF 15 ? ? ? ? A3 ? ? ? ? EB 05')) + 2)[0][0]) fnGetModuleHandle = cast('uint32_t(__stdcall*)(const char*)', cast('uint32_t**', cast('uint32_t', find_pattern('engine.dll', 'FF 15 ? ? ? ? 85 C0 74 0B')) + 2)[0][0]) end if api == 'gamesense' then local proxyAddr = find_pattern('engine.dll', '51 C3') local fnGetProcAddressAddr = cast('void*', fnGetProcAddress) fnGetProcAddress = function(moduleHandle, functionName) local fnGetProcAddressProxy = cast('uint32_t(__thiscall*)(void*, uint32_t, const char*)', proxyAddr) return fnGetProcAddressProxy(fnGetProcAddressAddr, moduleHandle, functionName) end local fnGetModuleHandleAddr = cast('void*', fnGetModuleHandle) fnGetModuleHandle = function(moduleName) local fnGetModuleHandleProxy = cast('uint32_t(__thiscall*)(void*, const char*)', proxyAddr) return fnGetModuleHandleProxy(fnGetModuleHandleAddr, moduleName) end end return function(module_name, function_name, typedef) return cast(typeof(typedef), fnGetProcAddress(fnGetModuleHandle(module_name), function_name)) end end)() follow_call = function(ptr) local insn = cast('uint8_t*', ptr) local _exp_1 = insn[0] if (0xE8 or 0xE9) == _exp_1 then return cast('uint32_t', insn + cast('int32_t*', insn + 1)[0] + 5) elseif 0xFF == _exp_1 then if insn[1] == 0x15 then return cast('uint32_t**', cast('const char*', ptr) + 2)[0][0] end else return ptr end end v8js_args = function(...) local argTbl = { ... } local iArgc = #argTbl local pArgv = new(('void*[%.f]'):format(iArgc)) for i = 1, iArgc do pArgv[i - 1] = Value:fromLua(argTbl[i]):getInternal() end return iArgc, pArgv end v8js_function = function(callbackFunction) return function(callbackInfo) callbackInfo = FunctionCallbackInfo(callbackInfo) local argTbl = { } local length = callbackInfo:length() if length > 0 then for i = 0, length - 1 do table.insert(argTbl, callbackInfo:get(i)) end end local val = nil if safe_mode then local status, ret = xpcall((function() return callbackFunction(unpack(argTbl)) end), exceptionCb) if status then val = ret end else val = callbackFunction(unpack(argTbl)) end return callbackInfo:setReturnValue(Value:fromLua(val):getInternal()) end end is_array = function(val) local i = 1 for _ in pairs(val) do if val[i] ~= nil then i = i + 1 else return false end end return i ~= 1 end nullptr = new('void*') intbuf = new('int[1]') panorama = { panelIDs = { } } do local _class_0 local _base_0 = { get = function(self, index, t) return __thiscall(cast(t, self.this[0][index]), self.this) end, getInstance = function(self) return self.this end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, ptr) self.this = cast('void***', ptr) end, __base = _base_0, __name = "vtable" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 vtable = _class_0 end do local _class_0 local _base_0 = { cache = { }, get = function(self, method, typedef) if not (self.cache[method]) then self.cache[method] = proc_bind(self.file, method, typedef) end return self.cache[method] end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, filename) self.file = filename end, __base = _base_0, __name = "DllImport" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 DllImport = _class_0 end UIEngine = vtable(vtable_bind('panorama.dll', 'PanoramaUIEngine001', 11, 'void*(__thiscall*)(void*)')()) nativeIsValidPanelPointer = UIEngine:get(36, 'bool(__thiscall*)(void*,void const*)') nativeGetLastDispatchedEventTargetPanel = UIEngine:get(56, 'void*(__thiscall*)(void*)') nativeCompileRunScript = UIEngine:get(113, 'void****(__thiscall*)(void*,void*,char const*,char const*,int,int,bool)') nativeRunScript = __thiscall(cast(typeof('void*(__thiscall*)(void*,void*,void*,void*,int,bool)'), follow_call(find_pattern('panorama.dll', 'E8 ? ? ? ? 8B 4C 24 10 FF 15'))), UIEngine:getInstance()) nativeGetV8GlobalContext = UIEngine:get(123, 'void*(__thiscall*)(void*)') nativeGetIsolate = UIEngine:get(129, 'void*(__thiscall*)(void*)') nativeHandleException = UIEngine:get(121, 'void(__thiscall*)(void*, void*, void*)') nativeGetParent = vtable_thunk(25, 'void*(__thiscall*)(void*)') nativeGetID = vtable_thunk(9, 'const char*(__thiscall*)(void*)') nativeFindChildTraverse = vtable_thunk(40, 'void*(__thiscall*)(void*,const char*)') nativeGetJavaScriptContextParent = vtable_thunk(218, 'void*(__thiscall*)(void*)') nativeGetPanelContext = __thiscall(cast('void***(__thiscall*)(void*,void*)', follow_call(find_pattern('panorama.dll', 'E8 ? ? ? ? 8B 00 85 C0 75 1B'))), UIEngine:getInstance()) jsContexts = { } getJavaScriptContextParent = function(panel) if jsContexts[panel] ~= nil then return jsContexts[panel] end jsContexts[panel] = nativeGetJavaScriptContextParent(panel) return jsContexts[panel] end v8_dll = DllImport('v8.dll') pIsolate = nativeGetIsolate() persistentTbl = { } do local _class_0 local _base_0 = { } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = cast('void*', val) end, __base = _base_0, __name = "Message" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Message = _class_0 end do local _class_0 local _base_0 = { getInternal = function(self) return self.this end, isValid = function(self) return self.this[0] ~= nullptr end, getMessage = function(self) return Message(self.this[0]) end, globalize = function(self) local pPersistent = v8_dll:get('?GlobalizeReference@V8@v8@@CAPAPAVObject@internal@2@PAVIsolate@42@PAPAV342@@Z', 'void*(__cdecl*)(void*,void*)')(pIsolate, self.this[0]) local persistent = Persistent(pPersistent) persistentTbl[persistent:getIdentityHash()] = pPersistent return persistent end, __call = function(self) return Value(self.this[0]) end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = cast('void**', val) end, __base = _base_0, __name = "Local" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Local = _class_0 end do local _class_0 local _base_0 = { getInternal = function(self) return self.this end, toLocalChecked = function(self) if not (self.this[0] == nullptr) then return Local(self.this) end end, toValueChecked = function(self) if not (self.this[0] == nullptr) then return Value(self.this[0]) end end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = cast('void**', val) end, __base = _base_0, __name = "MaybeLocal" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 MaybeLocal = _class_0 end PersistentProxy_mt = { __index = function(self, key) local this = rawget(self, 'this') local ret = HandleScope()(function() return this:getAsValue():toObject():get(Value:fromLua(key):getInternal()):toValueChecked():toLua() end) if type(ret) == 'table' then rawset(ret, 'parent', this) end return ret end, __newindex = function(self, key, value) local this = rawget(self, 'this') return HandleScope()(function() return this:getAsValue():toObject():set(Value:fromLua(key):getInternal(), Value:fromLua(value):getInternal()):toValueChecked():toLua() end) end, __len = function(self) local this = rawget(self, 'this') local ret = 0 if this.baseType == 'Array' then ret = HandleScope()(function() return this:getAsValue():toArray():length() end) elseif this.baseType == 'Object' then ret = HandleScope()(function() return this:getAsValue():toObject():getPropertyNames():toValueChecked():toArray():length() end) end return ret end, __pairs = function(self) local this = rawget(self, 'this') local ret ret = function() return nil end if this.baseType == 'Object' then HandleScope()(function() local keys = Array(this:getAsValue():toObject():getPropertyNames():toValueChecked()) local current, size = 0, keys:length() ret = function() current = current + 1 local key = keys[current - 1] if current <= size then return key, self[key] end end end) end return ret end, __ipairs = function(self) local this = rawget(self, 'this') local ret ret = function() return nil end if this.baseType == 'Array' then HandleScope()(function() local current, size = 0, this:getAsValue():toArray():length() ret = function() current = current + 1 if current <= size then return current, self[current - 1] end end end) end return ret end, __call = function(self, ...) local this = rawget(self, 'this') local args = { ... } if this.baseType ~= 'Function' then error('Attempted to call a non-function value: ' .. this.baseType) end local terminateExecution = false local ret = HandleScope()(function() local tryCatch = TryCatch() tryCatch:enter() local rawReturn = this:getAsValue():toFunction():setParent(rawget(self, 'parent'))(unpack(args)):toLocalChecked() if tryCatch:hasCaught() then nativeHandleException(tryCatch:getInternal(), panorama.getPanel("CSGOJsRegistration")) if safe_mode then terminateExecution = true end end tryCatch:exit() if rawReturn == nil then return nil else return rawReturn():toLua() end end) if terminateExecution then error("\n\nFailed to call the given javascript function, please check the error message above ^ \n\n(definitely not because I was too lazy to implement my own exception handler)\n") end return ret end, __tostring = function(self) local this = rawget(self, 'this') return HandleScope()(function() return this:getAsValue():stringValue() end) end, __gc = function(self) local this = rawget(self, 'this') return this:disposeGlobal() end } do local _class_0 local _base_0 = { setType = function(self, val) self.baseType = val return self end, getInternal = function(self) return self.this end, disposeGlobal = function(self) return v8_dll:get('?DisposeGlobal@V8@v8@@CAXPAPAVObject@internal@2@@Z', 'void(__cdecl*)(void*)')(self.this) end, get = function(self) return MaybeLocal(HandleScope:createHandle(self.this)) end, getAsValue = function(self) return Value(HandleScope:createHandle(self.this)[0]) end, toLua = function(self) return self:get():toValueChecked():toLua() end, getIdentityHash = function(self) return v8_dll:get('?GetIdentityHash@Object@v8@@QAEHXZ', 'int(__thiscall*)(void*)')(self.this) end, __call = function(self) return setmetatable({ this = self, parent = nil }, PersistentProxy_mt) end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val, baseType) if baseType == nil then baseType = 'Value' end self.this = val self.baseType = baseType end, __base = _base_0, __name = "Persistent" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Persistent = _class_0 end do local _class_0 local _base_0 = { fromLua = function(self, val) if val == nil then return Null(pIsolate):getValue() end local valType = type(val) local _exp_1 = valType if 'boolean' == _exp_1 then return Boolean(pIsolate, val):getValue() elseif 'number' == _exp_1 then return Number(pIsolate, val):getInstance() elseif 'string' == _exp_1 then return String(pIsolate, val):getInstance() elseif 'table' == _exp_1 then if is_array(val) then return Array:fromLua(pIsolate, val) else return Object:fromLua(pIsolate, val) end elseif 'function' == _exp_1 then return FunctionTemplate(v8js_function(val)):getFunction()() else return error('Failed to convert from lua to v8js: Unknown type') end end, isUndefined = function(self) return v8_dll:get('?IsUndefined@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isNull = function(self) return v8_dll:get('?IsNull@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isBoolean = function(self) return v8_dll:get('?IsBoolean@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isBooleanObject = function(self) return v8_dll:get('?IsBooleanObject@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isNumber = function(self) return v8_dll:get('?IsNumber@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isNumberObject = function(self) return v8_dll:get('?IsNumberObject@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isString = function(self) return v8_dll:get('?IsString@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isStringObject = function(self) return v8_dll:get('?IsStringObject@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isObject = function(self) return v8_dll:get('?IsObject@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isArray = function(self) return v8_dll:get('?IsArray@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, isFunction = function(self) return v8_dll:get('?IsFunction@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, booleanValue = function(self) return v8_dll:get('?BooleanValue@Value@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, numberValue = function(self) return v8_dll:get('?NumberValue@Value@v8@@QBENXZ', 'double(__thiscall*)(void*)')(self.this) end, stringValue = function(self) local strBuf = new('char*[2]') local val = v8_dll:get('??0Utf8Value@String@v8@@QAE@V?$Local@VValue@v8@@@2@@Z', 'struct{char* str; int length;}*(__thiscall*)(void*,void*)')(strBuf, self.this) local s = string(val.str, val.length) v8_dll:get('??1Utf8Value@String@v8@@QAE@XZ', 'void(__thiscall*)(void*)')(strBuf) return s end, toObject = function(self) return Object(MaybeLocal(v8_dll:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ', 'void*(__thiscall*)(void*,void*)')(self.this, intbuf)):toValueChecked():getInternal()) end, toArray = function(self) return Array(MaybeLocal(v8_dll:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ', 'void*(__thiscall*)(void*,void*)')(self.this, intbuf)):toValueChecked():getInternal()) end, toFunction = function(self) return Function(MaybeLocal(v8_dll:get('?ToObject@Value@v8@@QBE?AV?$Local@VObject@v8@@@2@XZ', 'void*(__thiscall*)(void*,void*)')(self.this, intbuf)):toValueChecked():getInternal()) end, toLocal = function(self) return Local(new('void*[1]', self.this)) end, toLua = function(self) if self:isUndefined() or self:isNull() then return nil end if self:isBoolean() or self:isBooleanObject() then return self:booleanValue() end if self:isNumber() or self:isNumberObject() then return self:numberValue() end if self:isString() or self:isStringObject() then return self:stringValue() end if self:isObject() then if self:isArray() then return self:toArray():toLocal():globalize():setType('Array')() end if self:isFunction() then return self:toFunction():toLocal():globalize():setType('Function')() end return self:toObject():toLocal():globalize():setType('Object')() end return error('Failed to convert from v8js to lua: Unknown type') end, getInternal = function(self) return self.this end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = cast('void*', val) end, __base = _base_0, __name = "Value" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Value = _class_0 end do local _class_0 local _parent_0 = Value local _base_0 = { fromLua = function(self, isolate, val) local obj = Object(MaybeLocal(v8_dll:get('?New@Object@v8@@SA?AV?$Local@VObject@v8@@@2@PAVIsolate@2@@Z', 'void*(__cdecl*)(void*,void*)')(intbuf, isolate)):toValueChecked():getInternal()) for i, v in pairs(val) do obj:set(Value:fromLua(i):getInternal(), Value:fromLua(v):getInternal()) end return obj end, get = function(self, key) return MaybeLocal(v8_dll:get('?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@V32@@Z', 'void*(__thiscall*)(void*,void*,void*)')(self.this, intbuf, key)) end, set = function(self, key, value) return v8_dll:get('?Set@Object@v8@@QAE_NV?$Local@VValue@v8@@@2@0@Z', 'bool(__thiscall*)(void*,void*,void*)')(self.this, key, value) end, getPropertyNames = function(self) return MaybeLocal(v8_dll:get('?GetPropertyNames@Object@v8@@QAE?AV?$Local@VArray@v8@@@2@XZ', 'void*(__thiscall*)(void*,void*)')(self.this, intbuf)) end, callAsFunction = function(self, recv, argc, argv) return MaybeLocal(v8_dll:get('?CallAsFunction@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@V32@HQAV32@@Z', 'void*(__thiscall*)(void*,void*,void*,int,void*)')(self.this, intbuf, recv, argc, argv)) end, getIdentityHash = function(self) return v8_dll:get('?GetIdentityHash@Object@v8@@QAEHXZ', 'int(__thiscall*)(void*)')(self.this) end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, val) self.this = val end, __base = _base_0, __name = "Object", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Object = _class_0 end do local _class_0 local _parent_0 = Object local _base_0 = { fromLua = function(self, isolate, val) local arr = Array(MaybeLocal(v8_dll:get('?New@Array@v8@@SA?AV?$Local@VArray@v8@@@2@PAVIsolate@2@H@Z', 'void*(__cdecl*)(void*,void*,int)')(intbuf, isolate, #val)):toValueChecked():getInternal()) for i = 1, #val do arr:set(i - 1, Value:fromLua(val[i]):getInternal()) end return arr end, get = function(self, key) return MaybeLocal(v8_dll:get('?Get@Object@v8@@QAE?AV?$Local@VValue@v8@@@2@I@Z', 'void*(__thiscall*)(void*,void*,unsigned int)')(self.this, intbuf, key)) end, set = function(self, key, value) return v8_dll:get('?Set@Object@v8@@QAE_NIV?$Local@VValue@v8@@@2@@Z', 'bool(__thiscall*)(void*,unsigned int,void*)')(self.this, key, value) end, length = function(self) return v8_dll:get('?Length@Array@v8@@QBEIXZ', 'uint32_t(__thiscall*)(void*)')(self.this) end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, val) self.this = val end, __base = _base_0, __name = "Array", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Array = _class_0 end do local _class_0 local _parent_0 = Object local _base_0 = { setParent = function(self, val) self.parent = val return self end, __call = function(self, ...) if self.parent == nil then return self:callAsFunction(Context(Isolate():getCurrentContext()):global():toValueChecked():getInternal(), v8js_args(...)) else return self:callAsFunction(self.parent:getAsValue():getInternal(), v8js_args(...)) end end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, val, parent) self.this = val self.parent = parent end, __base = _base_0, __name = "Function", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Function = _class_0 end do local _class_0 local _base_0 = { } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self) self.this = MaybeLocal(v8_dll:get('?New@ObjectTemplate@v8@@SA?AV?$Local@VObjectTemplate@v8@@@2@XZ', 'void*(__cdecl*)(void*)')(intbuf)):toLocalChecked() end, __base = _base_0, __name = "ObjectTemplate" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 ObjectTemplate = _class_0 end do local _class_0 local _base_0 = { getFunction = function(self) return MaybeLocal(v8_dll:get('?GetFunction@FunctionTemplate@v8@@QAE?AV?$Local@VFunction@v8@@@2@XZ', 'void*(__thiscall*)(void*, void*)')(self:this():getInternal(), intbuf)):toLocalChecked() end, getInstance = function(self) return self:this() end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, callback) self.this = MaybeLocal(v8_dll:get('?New@FunctionTemplate@v8@@SA?AV?$Local@VFunctionTemplate@v8@@@2@PAVIsolate@2@P6AXABV?$FunctionCallbackInfo@VValue@v8@@@2@@ZV?$Local@VValue@v8@@@2@V?$Local@VSignature@v8@@@2@HW4ConstructorBehavior@2@@Z', 'void*(__cdecl*)(void*,void*,void*,void*,void*,int,int)')(intbuf, pIsolate, cast('void(__cdecl*)(void******)', callback), new('int[1]'), new('int[1]'), 0, 0)):toLocalChecked() end, __base = _base_0, __name = "FunctionTemplate" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 FunctionTemplate = _class_0 end do local _class_0 local _base_0 = { kHolderIndex = 0, kIsolateIndex = 1, kReturnValueDefaultValueIndex = 2, kReturnValueIndex = 3, kDataIndex = 4, kCalleeIndex = 5, kContextSaveIndex = 6, kNewTargetIndex = 7, getHolder = function(self) return MaybeLocal(self:getImplicitArgs_()[self.kHolderIndex]):toLocalChecked() end, getIsolate = function(self) return Isolate(self:getImplicitArgs_()[self.kIsolateIndex][0]) end, getReturnValueDefaultValue = function(self) return Value(new('void*[1]', self:getImplicitArgs_()[self.kReturnValueDefaultValueIndex])) end, getReturnValue = function(self) return Value(new('void*[1]', self:getImplicitArgs_()[self.kReturnValueIndex])) end, setReturnValue = function(self, value) self:getImplicitArgs_()[self.kReturnValueIndex] = cast('void**', value)[0] end, getData = function(self) return MaybeLocal(self:getImplicitArgs_()[self.kDataIndex]):toLocalChecked() end, getCallee = function(self) return MaybeLocal(self:getImplicitArgs_()[self.kCalleeIndex]):toLocalChecked() end, getContextSave = function(self) return MaybeLocal(self:getImplicitArgs_()[self.kContextSaveIndex]):toLocalChecked() end, getNewTarget = function(self) return MaybeLocal(self:getImplicitArgs_()[self.kNewTargetIndex]):toLocalChecked() end, getImplicitArgs_ = function(self) return self.this[0] end, getValues_ = function(self) return self.this[1] end, getLength_ = function(self) return self.this[2] end, length = function(self) return tonumber(cast('int', self:getLength_())) end, get = function(self, i) if self:length() > i then return Value(self:getValues_() - i):toLua() else return end end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = cast('void****', val) end, __base = _base_0, __name = "FunctionCallbackInfo" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 FunctionCallbackInfo = _class_0 end do local _class_0 local _parent_0 = Value local _base_0 = { getValue = function(self) return self.this end, toString = function(self) return self.this:getValue():stringValue() end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, val) self.this = val end, __base = _base_0, __name = "Primitive", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Primitive = _class_0 end do local _class_0 local _parent_0 = Primitive local _base_0 = { } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate) self.this = Value(cast('uintptr_t', isolate) + 0x48) end, __base = _base_0, __name = "Null", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Null = _class_0 end do local _class_0 local _parent_0 = Primitive local _base_0 = { } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate) self.this = Value(cast('uintptr_t', isolate) + 0x56) end, __base = _base_0, __name = "Undefined", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Undefined = _class_0 end do local _class_0 local _parent_0 = Primitive local _base_0 = { } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate, bool) self.this = Value(cast('uintptr_t', isolate) + ((function() if bool then return 0x4C else return 0x50 end end)())) end, __base = _base_0, __name = "Boolean", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Boolean = _class_0 end do local _class_0 local _parent_0 = Value local _base_0 = { getLocal = function(self) return self.this end, getValue = function(self) return self:getInstance():numberValue() end, getInstance = function(self) return self:this() end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate, val) self.this = MaybeLocal(v8_dll:get('?New@Number@v8@@SA?AV?$Local@VNumber@v8@@@2@PAVIsolate@2@N@Z', 'void*(__cdecl*)(void*,void*,double)')(intbuf, isolate, tonumber(val))):toLocalChecked() end, __base = _base_0, __name = "Number", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Number = _class_0 end do local _class_0 local _parent_0 = Number local _base_0 = { } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate, val) self.this = MaybeLocal(v8_dll:get('?NewFromUnsigned@Integer@v8@@SA?AV?$Local@VInteger@v8@@@2@PAVIsolate@2@I@Z', 'void*(__cdecl*)(void*,void*,uint32_t)')(intbuf, isolate, tonumber(val))):toLocalChecked() end, __base = _base_0, __name = "Integer", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end Integer = _class_0 end do local _class_0 local _parent_0 = Value local _base_0 = { getLocal = function(self) return self.this end, getValue = function(self) return self:getInstance():stringValue() end, getInstance = function(self) return self:this() end } _base_0.__index = _base_0 setmetatable(_base_0, _parent_0.__base) _class_0 = setmetatable({ __init = function(self, isolate, val) self.this = MaybeLocal(v8_dll:get('?NewFromUtf8@String@v8@@SA?AV?$MaybeLocal@VString@v8@@@2@PAVIsolate@2@PBDW4NewStringType@2@H@Z', 'void*(__cdecl*)(void*,void*,const char*,int,int)')(intbuf, isolate, val, 0, #val)):toLocalChecked() end, __base = _base_0, __name = "String", __parent = _parent_0 }, { __index = function(cls, name) local val = rawget(_base_0, name) if val == nil then local parent = rawget(cls, "__parent") if parent then return parent[name] end else return val end end, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 if _parent_0.__inherited then _parent_0.__inherited(_parent_0, _class_0) end String = _class_0 end do local _class_0 local _base_0 = { enter = function(self) return v8_dll:get('?Enter@Isolate@v8@@QAEXXZ', 'void(__thiscall*)(void*)')(self.this) end, exit = function(self) return v8_dll:get('?Exit@Isolate@v8@@QAEXXZ', 'void(__thiscall*)(void*)')(self.this) end, getCurrentContext = function(self) return MaybeLocal(v8_dll:get('?GetCurrentContext@Isolate@v8@@QAE?AV?$Local@VContext@v8@@@2@XZ', 'void**(__thiscall*)(void*,void*)')(self.this, intbuf)):toValueChecked():getInternal() end, getInternal = function(self) return self.this end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) if val == nil then val = pIsolate end self.this = val end, __base = _base_0, __name = "Isolate" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Isolate = _class_0 end do local _class_0 local _base_0 = { enter = function(self) return v8_dll:get('?Enter@Context@v8@@QAEXXZ', 'void(__thiscall*)(void*)')(self.this) end, exit = function(self) return v8_dll:get('?Exit@Context@v8@@QAEXXZ', 'void(__thiscall*)(void*)')(self.this) end, global = function(self) return MaybeLocal(v8_dll:get('?Global@Context@v8@@QAE?AV?$Local@VObject@v8@@@2@XZ', 'void*(__thiscall*)(void*,void*)')(self.this, intbuf)) end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self, val) self.this = val end, __base = _base_0, __name = "Context" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Context = _class_0 end do local _class_0 local _base_0 = { enter = function(self) return v8_dll:get('??0HandleScope@v8@@QAE@PAVIsolate@1@@Z', 'void(__thiscall*)(void*,void*)')(self.this, pIsolate) end, exit = function(self) return v8_dll:get('??1HandleScope@v8@@QAE@XZ', 'void(__thiscall*)(void*)')(self.this) end, createHandle = function(self, val) return v8_dll:get('?CreateHandle@HandleScope@v8@@KAPAPAVObject@internal@2@PAVIsolate@42@PAV342@@Z', 'void**(__cdecl*)(void*,void*)')(pIsolate, val) end, __call = function(self, func, panel) if panel == nil then panel = panorama.GetPanel('CSGOJsRegistration') end local isolate = Isolate() isolate:enter() self:enter() local ctx if panel then ctx = nativeGetPanelContext(getJavaScriptContextParent(panel))[0] else ctx = Context(isolate:getCurrentContext()):global():getInternal() end ctx = Context((function() if ctx ~= nullptr then return self:createHandle(ctx[0]) else return 0 end end)()) ctx:enter() local val = nil if safe_mode then local status, ret = xpcall(func, exception) if status then val = ret end else val = func() end ctx:exit() self:exit() isolate:exit() return val end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self) self.this = new('char[0xC]') end, __base = _base_0, __name = "HandleScope" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 HandleScope = _class_0 end do local _class_0 local _base_0 = { enter = function(self) return v8_dll:get('??0TryCatch@v8@@QAE@PAVIsolate@1@@Z', 'void(__thiscall*)(void*, void*)')(self.this, pIsolate) end, exit = function(self) return v8_dll:get('??1TryCatch@v8@@QAE@XZ', 'void(__thiscall*)(void*)')(self.this) end, canContinue = function(self) return v8_dll:get('?CanContinue@TryCatch@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, hasTerminated = function(self) return v8_dll:get('?HasTerminated@TryCatch@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, hasCaught = function(self) return v8_dll:get('?HasCaught@TryCatch@v8@@QBE_NXZ', 'bool(__thiscall*)(void*)')(self.this) end, message = function(self) return Local(v8_dll:get('?Message@TryCatch@v8@@QBE?AV?$Local@VMessage@v8@@@2@XZ', 'void*(__thiscall*)(void*, void*)')(self.this, intbuf)) end, getInternal = function(self) return self.this end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function(self) self.this = new('char[0x19]') end, __base = _base_0, __name = "TryCatch" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 TryCatch = _class_0 end do local _class_0 local _base_0 = { compile = function(self, panel, source, layout) if layout == nil then layout = '' end return __thiscall(cast('void**(__thiscall*)(void*,void*,const char*,const char*)', api == 'memesense' and find_pattern('panorama.dll', 'E8 ? ? ? ? 8B 4C 24 10 FF 15') - 2816 or find_pattern('panorama.dll', '55 8B EC 83 E4 F8 83 EC 64 53 8B D9')), UIEngine:getInstance())(panel, source, layout) end, loadstring = function(self, str, panel) local compiled = MaybeLocal(self:compile(panel, str)):toLocalChecked() if compiled == nullptr then if safe_mode then error("\nFailed to compile the given javascript string, please check the error message above ^\n") else print("\nFailed to compile the given javascript string, please check the error message above ^\n") return function() return print('WARNING: Attempted to call nullptr (script compilation failed)') end end end local isolate = Isolate() local handleScope = HandleScope() isolate:enter() handleScope:enter() local ctx if panel then ctx = nativeGetPanelContext(getJavaScriptContextParent(panel))[0] else ctx = Context(isolate:getCurrentContext()):global():getInternal() end ctx = Context((function() if ctx ~= nullptr then return handleScope:createHandle(ctx[0]) else return 0 end end)()) ctx:enter() local ret = MaybeLocal(nativeRunScript(intbuf, panel, compiled():getInternal(), 0, false)):toValueChecked() if ret == nullptr then if safe_mode then error("\nFailed to evaluate the given javascript string, please check the error message above ^\n") else print("\nFailed to evaluate the given javascript string, please check the error message above ^\n") ret = function() return print('WARNING: Attempted to call nullptr (script execution failed)') end end else ret = ret:toLua() end ctx:exit() handleScope:exit() isolate:exit() return ret end } _base_0.__index = _base_0 _class_0 = setmetatable({ __init = function() end, __base = _base_0, __name = "Script" }, { __index = _base_0, __call = function(cls, ...) local _self_0 = setmetatable({}, _base_0) cls.__init(_self_0, ...) return _self_0 end }) _base_0.__class = _class_0 Script = _class_0 end PanelInfo_t = typeof([[ struct { char* pad1[0x4]; void* m_pPanel; void* unk1; } ]]) CUtlVector_Constructor_t = typeof([[ struct { struct { $ *m_pMemory; int m_nAllocationCount; int m_nGrowSize; } m_Memory; int m_Size; $ *m_pElements; } ]], PanelInfo_t, PanelInfo_t) metatype(CUtlVector_Constructor_t, { __index = { Count = function(self) return self.m_Memory.m_nAllocationCount end, Element = function(self, i) return cast(typeof('$&', PanelInfo_t), self.m_Memory.m_pMemory[i]) end, RemoveAll = function(self) self = nil self = typeof('$[?]', CUtlVector_Constructor_t)(1)[0] self.m_Size = 0 end }, __ipairs = function(self) local current, size = 0, self:Count() return function() current = current + 1 local pPanel = self:Element(current - 1).m_pPanel if current <= size and nativeIsValidPanelPointer(pPanel) then return current, pPanel end end end }) panelList = typeof('$[?]', CUtlVector_Constructor_t)(1)[0] panelArrayOffset = cast('unsigned int*', cast('uintptr_t**', UIEngine:getInstance())[0][36] + 21)[0] panelArray = cast(panelList, cast('uintptr_t', UIEngine:getInstance()) + panelArrayOffset) panorama.hasPanel = function(panelName) for i, v in ipairs(panelArray) do local curPanelName = string(nativeGetID(v)) if curPanelName == panelName then return true end end return false end panorama.getPanel = function(panelName, fallback) local cachedPanel = panorama.panelIDs[panelName] if cachedPanel ~= nil and nativeIsValidPanelPointer(cachedPanel) and string(nativeGetID(cachedPanel)) == panelName then return cachedPanel end panorama.panelIDs = { } local pPanel = nullptr for i, v in ipairs(panelArray) do local curPanelName = string(nativeGetID(v)) if curPanelName ~= '' then panorama.panelIDs[curPanelName] = v if curPanelName == panelName then pPanel = v break end end end if pPanel == nullptr then if fallback ~= nil then pPanel = panorama.getPanel(fallback) else error(('Failed to get target panel %s (EAX == 0)'):format(tostring(panelName))) end end return pPanel end panorama.getIsolate = function() return Isolate(nativeGetIsolate()) end panorama.runScript = function(jsCode, panel, pathToXMLContext) if panel == nil then panel = panorama.getPanel('CSGOJsRegistration') end if pathToXMLContext == nil then pathToXMLContext = 'panorama/layout/base.xml' end if not nativeIsValidPanelPointer(panel) then error('Invalid panel pointer (EAX == 0)') end return nativeCompileRunScript(panel, jsCode, pathToXMLContext, 8, 10, false) end panorama.loadstring = function(jsCode, panel) if panel == nil then panel = 'CSGOJsRegistration' end local fallback = 'CSGOJsRegistration' if panel == 'CSGOMainMenu' then fallback = 'CSGOHud' end if panel == 'CSGOHud' then fallback = 'CSGOMainMenu' end return Script:loadstring(('(()=>{%s})'):format(jsCode), panorama.getPanel(panel, fallback)) end panorama.open = function(panel) if panel == nil then panel = 'CSGOJsRegistration' end local fallback = 'CSGOJsRegistration' if panel == 'CSGOMainMenu' then fallback = 'CSGOHud' end if panel == 'CSGOHud' then fallback = 'CSGOMainMenu' end return HandleScope()((function() return Context(Isolate():getCurrentContext()):global():toValueChecked():toLua() end), panorama.GetPanel(panel, fallback)) end panorama.GetPanel = panorama.getPanel panorama.GetIsolate = panorama.getIsolate panorama.RunScript = panorama.runScript panorama.panelArray = panelArray panorama.info = _INFO panorama.flush = shutdown setmetatable(panorama, { __tostring = function(self) return ('luv8 panorama library v%.1f'):format(_INFO._VERSION) end, __index = function(self, key) if panorama.hasPanel(key) then return panorama.open(key) end return panorama.open()[key] end }) return panorama
end)()

http = (function()
    local steam_http_raw = ffi.cast("uint32_t**", ffi.cast("char**", ffi.cast("char*", memory.find_pattern("client.dll", "B9 ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 0F 84")) + 1)[0] + 48)[0] or error("steam_http error")
    local steam_http_ptr = ffi.cast("void***", steam_http_raw) or error("steam_http_ptr error")
    local steam_http = steam_http_ptr[0] or error("steam_http_ptr was null")

    -- #region helper functions
    local function __thiscall(func, this)
        return function(...)
            return func(this, ...)
        end
    end
    -- #endregion

    -- #region native casts
    local createHTTPRequest_native = __thiscall(ffi.cast(ffi.typeof("uint32_t(__thiscall*)(void*, uint32_t, const char*)"), steam_http[0]), steam_http_raw)
    local sendHTTPRequest_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint64_t)"), steam_http[5]), steam_http_raw)
    local getHTTPResponseHeaderSize_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, uint32_t*)"), steam_http[9]), steam_http_raw)
    local getHTTPResponseHeaderValue_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, char*, uint32_t)"), steam_http[10]), steam_http_raw)
    local getHTTPResponseBodySize_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, uint32_t*)"), steam_http[11]), steam_http_raw)
    local getHTTPBodyData_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, char*, uint32_t)"), steam_http[12]), steam_http_raw)
    local setHTTPHeaderValue_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"), steam_http[3]), steam_http_raw)
    local setHTTPRequestParam_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*, const char*)"), steam_http[4]), steam_http_raw)
    local setHTTPUserAgent_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t, const char*)"), steam_http[21]), steam_http_raw)
    local setHTTPRequestRaw_native = __thiscall(ffi.cast("bool(__thiscall*)(void*, uint32_t, const char*, const char*, uint32_t)", steam_http[16]), steam_http_raw)
    local releaseHTTPRequest_native = __thiscall(ffi.cast(ffi.typeof("bool(__thiscall*)(void*, uint32_t)"), steam_http[14]), steam_http_raw)
    -- #endregion

    local requests = {}
    callbacks.add(e_callbacks.PAINT, function ()
        for _, instance in ipairs(requests) do
            if global_vars.cur_time() - instance.ls > instance.task_interval then
                instance:_process_tasks()
                instance.ls = global_vars.cur_time()
            end
        end
    end)

    -- #region Models
    local request = {}
    local request_mt = {__index = request}
    function request.new(requestHandle, requestAddress, callbackFunction)
        return setmetatable({handle = requestHandle, url = requestAddress, callback = callbackFunction, ticks = 0}, request_mt)
    end
    local data = {}
    local data_mt = {__index = data}
    function data.new(state, body, headers)
        return setmetatable({status = state, body = body, headers = headers}, data_mt)
    end
    function data:success()
        return self.status == 200
    end
    -- #endregion

    -- #region Main
    local http = {state = {ok = 200, no_response = 204, timed_out = 408, unknown = 0}}
    local http_mt = {__index = http}
    function http.new(task)
        task = task or {}
        local instance = setmetatable({requests = {}, task_interval = task.task_interval or 0.3, enable_debug = task.debug or false, timeout = task.timeout or 10, ls = global_vars.cur_time()}, http_mt)
        table.insert(requests, instance)
        return instance
    end
    local method_t = {['get'] = 1, ['head'] = 2, ['post'] = 3, ['put'] = 4, ['delete'] = 5, ['options'] = 6, ['patch'] = 7}
    function http:request(method, url, options, callback)
        -- prepare
        if type(options) == "function" and callback == nil then
            callback = options
            options = {}
        end
        options = options or {}
        local method_num = method_t[tostring(method):lower()]
        local reqHandle = createHTTPRequest_native(method_num, url)
        -- header
        local content_type = "application/text"
        if type(options.headers) == "table" then
            for name, value in pairs(options.headers) do
                name = tostring(name)
                value = tostring(value)
                if name:lower() == "content-type" then
                    content_type = value
                end
                setHTTPHeaderValue_native(reqHandle, name, value)
            end
        end
        -- raw
        if type(options.body) == "string" then
            local len = options.body:len()
            setHTTPRequestRaw_native(reqHandle, content_type, ffi.cast("unsigned char*", options.body), len)
        end
        -- params
        if type(options.params) == "table" then
            for k, v in pairs(options.params) do
                setHTTPRequestParam_native(reqHandle, k, v)
            end
        end
        -- useragent
        if type(options.user_agent_info) == "string" then
            setHTTPUserAgent_native(reqHandle, options.user_agent_info)
        end
        -- send
        if not sendHTTPRequest_native(reqHandle, 0) then
            return
        end
        local reqInstance = request.new(reqHandle, url, callback)
        self:_debug("[HTTP] New %s request to: %s", method:upper(), url)
        table.insert(self.requests, reqInstance)
    end
    function http:get(url, callback)
        local reqHandle = createHTTPRequest_native(1, url)
        if not sendHTTPRequest_native(reqHandle, 0) then
            return
        end
        local reqInstance = request.new(reqHandle, url, callback)
        self:_debug("[HTTP] New GET request to: %s", url)
        table.insert(self.requests, reqInstance)
    end
    function http:post(url, params, callback)
        local reqHandle = createHTTPRequest_native(3, url)
        for k, v in pairs(params) do
            setHTTPRequestParam_native(reqHandle, k, v)
        end
        if not sendHTTPRequest_native(reqHandle, 0) then
            return
        end
        local reqInstance = request.new(reqHandle, url, callback)
        self:_debug("[HTTP] New POST request to: %s", url)
        table.insert(self.requests, reqInstance)
    end
    function http:download_image(url, save_path, callback)
        self:get(url, function(response)
            if response:success() then
                local file_data = response.body

                local dir = save_path:match("^(.-)/[^/]*$") -- Extrae el directorio de la ruta



                filesystem.write_binary(save_path, file_data)


                if callback then
                    callback(true, "Sucess")
                end
            else
                -- Llamar al callback con error si la solicitud no fue exitosa
                if callback then
                    callback(false, "Failed to download image " .. (response.status or "Unknown"))
                end
            end
        end)
    end


    function http:_process_tasks()
        for k, v in ipairs(self.requests) do
            local data_ptr = ffi.new("uint32_t[1]")
            self:_debug("[HTTP] Processing request #%s", k)
            if getHTTPResponseBodySize_native(v.handle, data_ptr) then
                local reqData = data_ptr[0]
                if reqData > 0 then
                    local strBuffer = ffi.new("char[?]", reqData)
                    if getHTTPBodyData_native(v.handle, strBuffer, reqData) then
                        self:_debug("[HTTP] Request #%s finished. Invoking callback.", k)
                        v.callback(data.new(http.state.ok, ffi.string(strBuffer, reqData), setmetatable({}, {__index = function(tbl, val) return http._get_header(v, val) end})))
                        table.remove(self.requests, k)
                        releaseHTTPRequest_native(v.handle)
                    end
                else
                    v.callback(data.new(http.state.no_response, "", {}))
                end
            end
        end
    end

    function http:_debug(fmt, ...)
        if self.enable_debug then
            print(string.format(fmt, ...))
        end
    end
    -- #endregion

    return http
end)()


icons = {

    [0] = render.load_image_buffer( [[<svg width="40" height="35" viewBox="0 0 45 40" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M23 37C32.3888 37 40 29.3888 40 20C40 10.6112 32.3888 3 23 3C13.6112 3 6 10.6112 6 20C6 29.3888 13.6112 37 23 37ZM23 33C30.1797 33 36 27.1797 36 20C36 12.8203 30.1797 7 23 7C15.8203 7 10 12.8203 10 20C10 27.1797 15.8203 33 23 33Z" fill="white"/>
    <rect x="4" y="18" width="8" height="4" fill="white"/>
    <rect x="34" y="18" width="8" height="4" fill="white"/>
    <rect x="21" y="9" width="8" height="4" transform="rotate(-90 21 9)" fill="white"/>
    <rect x="21" y="39" width="8" height="4" transform="rotate(-90 21 39)" fill="white"/>
    <circle cx="23" cy="20" r="4" fill="white"/>
    </svg>
    ]] ),

    [1] = render.load_image_buffer( [[<svg width="40" height="35" viewBox="0 0 45 40" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_4_38)">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M22.5 19C27.7467 19 32 14.9706 32 10C32 5.02944 27.7467 1 22.5 1C17.2533 1 13 5.02944 13 10C13 14.9706 17.2533 19 22.5 19ZM22.5 14C24.9853 14 27 12.2091 27 10C27 7.79086 24.9853 6 22.5 6C20.0147 6 18 7.79086 18 10C18 12.2091 20.0147 14 22.5 14Z" fill="white"/>
    <rect x="9" y="35" width="26" height="5" fill="white"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M16 23C10.4772 23 6 27.4772 6 33V49C6 54.5228 10.4772 59 16 59H29C34.5228 59 39 54.5228 39 49V33C39 27.4772 34.5228 23 29 23H16ZM15 28C12.7909 28 11 29.7909 11 32V50C11 52.2091 12.7909 54 15 54H30C32.2091 54 34 52.2091 34 50V32C34 29.7909 32.2091 28 30 28H15Z" fill="white"/>
    </g>
    <defs>
    <clipPath id="clip0_4_38">
    <rect width="45" height="40" fill="white"/>
    </clipPath>
    </defs>
    </svg>

    ]] ),

    [2] = render.load_image_buffer( [[<svg width="40" height="35" viewBox="0 0 45 40" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M24 27C23.1286 23.6205 21.8867 22.4517 18.5 21.5C18.5 21.5 36.5 4.5 37 4C37.5 3.49999 40 1.5 42 3.5C44 5.5 42.5 8 42.5 8L24 27Z" fill="white"/>
    <path d="M12 25C16.6419 22.7786 18.4899 23.2804 21 26C22.5194 29.3047 22.2871 31.0434 20.5 34C16.8626 36.9698 14.5526 37.5795 10 37C6.07061 36.114 4.78508 34.9486 3 32.5C5.36184 32.3382 6.46191 31.8082 8 30C9.22854 27.3933 10.1385 26.3667 12 25Z" fill="white"/>
    <path d="M24 27C23.1286 23.6205 21.8867 22.4517 18.5 21.5C18.5 21.5 36.5 4.5 37 4C37.5 3.49999 40 1.5 42 3.5C44 5.5 42.5 8 42.5 8L24 27Z" stroke="white"/>
    <path d="M12 25C16.6419 22.7786 18.4899 23.2804 21 26C22.5194 29.3047 22.2871 31.0434 20.5 34C16.8626 36.9698 14.5526 37.5795 10 37C6.07061 36.114 4.78508 34.9486 3 32.5C5.36184 32.3382 6.46191 31.8082 8 30C9.22854 27.3933 10.1385 26.3667 12 25Z" stroke="white"/>
    </svg>

    ]] ),

    [3] = render.load_image_buffer( [[<svg width="40" height="35" viewBox="0 0 45 40" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_4_77)">
    <path fill-rule="evenodd" clip-rule="evenodd" d="M19.424 30.9756C21.653 36.2309 27.7203 38.6841 32.9756 36.4551C38.2309 34.226 40.6842 28.1587 38.4551 22.9034C36.226 17.6481 30.1587 15.1949 24.9034 17.4239C19.6481 19.653 17.1949 25.7203 19.424 30.9756ZM24.1818 28.9575C25.2963 31.5851 28.3299 32.8117 30.9576 31.6972C33.5852 30.5827 34.8119 27.549 33.6973 24.9214C32.5828 22.2937 29.5491 21.0671 26.9215 22.1816C24.2938 23.2962 23.0672 26.3298 24.1818 28.9575Z" fill="white"/>
    <rect x="34.85" y="34.2566" width="3.87606" height="5.16807" transform="rotate(67.0155 34.85 34.2566)" fill="white"/>
    <rect x="39.825" y="19.5155" width="5.16807" height="3.87606" transform="rotate(67.0155 39.825 19.5155)" fill="white"/>
    <rect x="26.2733" y="14.036" width="3.87606" height="5.16807" transform="rotate(67.0155 26.2733 14.036)" fill="white"/>
    <rect x="29.3842" y="18.9465" width="5" height="5" transform="rotate(-67.9845 29.3842 18.9465)" fill="white"/>
    <rect x="22.0676" y="37.0417" width="5" height="5" transform="rotate(-67.9845 22.0676 37.0417)" fill="white"/>
    <rect x="37.4454" y="27.542" width="5" height="5" transform="rotate(22.0155 37.4454 27.542)" fill="white"/>
    <rect x="18.812" y="20.0078" width="5" height="5" transform="rotate(22.0155 18.812 20.0078)" fill="white"/>
    <rect x="19.6044" y="28.0922" width="5.16807" height="3.87606" transform="rotate(67.0155 19.6044 28.0922)" fill="white"/>
    <path fill-rule="evenodd" clip-rule="evenodd" d="M14 20C18.4183 20 22 16.4183 22 12C22 7.58172 18.4183 4 14 4C9.58172 4 6 7.58172 6 12C6 16.4183 9.58172 20 14 20ZM14 16C16.2091 16 18 14.2091 18 12C18 9.79086 16.2091 8 14 8C11.7909 8 10 9.79086 10 12C10 14.2091 11.7909 16 14 16Z" fill="white"/>
    <rect x="21" y="10" width="3" height="4" fill="white"/>
    <rect x="12" y="2" width="4" height="3" fill="white"/>
    <rect x="4" y="10" width="3" height="4" fill="white"/>
    <rect x="8.12134" y="8.94974" width="3" height="4" transform="rotate(-135 8.12134 8.94974)" fill="white"/>
    <rect x="19.1213" y="19.9497" width="3" height="4" transform="rotate(-135 19.1213 19.9497)" fill="white"/>
    <rect x="17" y="6.12131" width="3" height="4" transform="rotate(-45 17 6.12131)" fill="white"/>
    <rect x="6" y="17.1213" width="3" height="4" transform="rotate(-45 6 17.1213)" fill="white"/>
    <rect x="12" y="19" width="4" height="3" fill="white"/>
    </g>
    <defs>
    <clipPath id="clip0_4_77">
    <rect width="45" height="40" fill="white"/>
    </clipPath>
    </defs>
    </svg>
    ]] ),


}

if not filesystem.is_directory(".undf/") then 
    filesystem.create_directory(".undf/")
end

http_instance = http:new()

http_instance:download_image("https://raw.githubusercontent.com/vleav/shit/refs/heads/main/user.jpg", ".undf/user.jpg", function(success, message)
    if success then
        icons["User"] = render.load_image("./csgo/.undf/user.jpg")
    end
end)

damage = (function () 
    self = {}
    self.scale = {
        stomach = 1.25,
        chest = 1,
        head = 4
    }
    self.calculate = function(self, player, hitbox)
        local lplr = entity_list.get_local_player()
        if not lplr then
            return 0
        end
        local weaponidk = lplr:get_active_weapon()
        if not weaponidk then
            return 0
        end
        local weapon = lplr:get_active_weapon():get_weapon_data()
        if not weapon then
            return 0
        end
        local local_origin = lplr:get_prop("m_vecAbsOrigin")
        local distance = local_origin:dist(player:get_prop("m_vecAbsOrigin"))
        local weapon_adjust = weapon.damage
        local dmg_after_range = (weapon_adjust * math.pow(weapon.range_modifier, (distance * 0.002)))
        local armor = player:get_prop("m_ArmorValue")
        local newdmg = dmg_after_range * (weapon.armor_ratio * 0.5)
        if dmg_after_range - (dmg_after_range * (weapon.armor_ratio * 0.5)) * 0.5 > armor then
            newdmg = dmg_after_range - (armor / 0.5)
        end
        local enemy_health = player:get_prop("m_iHealth")
        -- local newdmg_indi = newdmg * 1.25

        return newdmg * self.scale[hitbox]
    end

    return self
end)()


use = (function () 
    self = {}
    self.dump = function(self, o)
        if type(o) == 'table' then
            local s = '{ '
            for k, v in pairs(o) do
                if type(k) ~= 'number' then
                    k = '"' .. k .. '"'
                end
                s = s .. '[' .. k .. '] = ' .. self:dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end

    self.weapon = function()
        return ({"auto", "scout", "awp", "deagle", "revolver", "pistols"})[ragebot.get_active_cfg() + 1] or "other"
    end

    self.damage = function(self)
        local dmg_ovr = menu.find("aimbot", self.weapon(), "target overrides", "min. damage")[1]
        local dmg_ovr_key = menu.find("aimbot", self.weapon(), "target overrides", "min. damage")[2]
        local norm_dmg = menu.find("aimbot", self.weapon(), "targeting", "min. damage")

        return dmg_ovr_key:get() and dmg_ovr:get() or norm_dmg:get()
    end

    self.render_glow = function(pos, size, round, color, glow_size)
        for radius = 4, math.floor(glow_size) do
            local radius_glow = radius / 2
            render.rect(vec2_t(pos.x - radius_glow, pos.y - radius_glow), vec2_t(size.x + radius_glow * 2, size.y + radius_glow * 2), color_t(color.r, color.g, color.b, math.floor(color.a / glow_size * (glow_size - radius))), round)
        end
    end

    self.animated_text = function(font, text, color2, color3, position, speed)
        local data, totalWidth = {}, 0
        local len, two_pi = #text, math.pi * 1.5
        local textOffset = position
        local clr1 = speed == 0 and color_t(255, 255, 255, 255) or color3 

        for idx = 1, len do
            local modifier = two_pi / len * idx
            local char = text:sub(idx, idx)
            local charWidth = render.get_text_size(font, char).x
            data[idx] = {totalWidth, char, modifier}
            totalWidth = totalWidth + charWidth
        end

        totalWidth = totalWidth * 0.5

        return function()
            local time = -globals.cur_time() * math.pi * speed
            local headerOffset = textOffset - vec2_t(totalWidth, 0)

            for _, char in pairs(data) do
                local charPosition = headerOffset + vec2_t(char[1], 0)
                local fadeValue = math.sin(time + char[3]) * 0.5 + 0.5
                local color = clr1:fade(color2, fadeValue)
                render.text(font, char[2], charPosition, color)
            end
        end
    end

    return self
end)()

screen = (function ()
    local self = {}
    local screen_size = render.get_screen_size() -- Obtén los valores de la pantalla una vez
    self.x, self.y = screen_size.x, screen_size.y

    return {
        x = self.x,
        y = self.y
    }
end)()


local events = bettercall:new(); cvars.sv_cheats:set_int(1)

local resolver = {memory = {}, states = {"stand", "lowvel", "move", "duck", "duckM", "air", "airC"}, last = {}, update = {}}

local refs = {
    hideshots = menu.find("aimbot", "general", "exploits", "hideshots", "enable")[2],
    doubletap = menu.find("aimbot", "general", "exploits", "doubletap", "enable")[2],
    dontusecharge = menu.find('aimbot', 'general', 'exploits', 'doubletap', 'dont use charge')[2],
    dormant = menu.find("aimbot", "general", "dormant aimbot", "enable")[2],
    ping = menu.find("aimbot", "general", "fake ping", "enable")[2],
    resolve = menu.find("aimbot", "general", "aimbot", "resolve antiaim"),
    autopeek = menu.find("aimbot", "general", "misc", "autopeek")[2],
    ax = menu.find("aimbot", "general", "exploits", "force prediction"),
    rollres = menu.find("aimbot", "general", "aimbot", "body lean resolver", "enable")[2],

    slowmotion = menu.find("misc", "main", "movement", "slow walk", "enable")[2],
    fakeduck = menu.find("antiaim", "main", "general", "fakeduck")[2],

    antiprediction = menu.find("aimbot", "general", "exploits", "doubletap", "Anti-Prediction On peek"),

    pitch = menu.find("antiaim", "main", "angles", "pitch"),
    yawbase = menu.find("antiaim", "main", "angles", "yaw base"),
    yawadd = menu.find("antiaim", "main", "angles", "yaw add"),
    rotate = menu.find("antiaim", "main", "angles", "rotate"),
    rotaterange = menu.find("antiaim", "main", "angles", "rotate range"),
    rotatespeed = menu.find("antiaim", "main", "angles", "rotate speed"),
    jittermode = menu.find("antiaim", "main", "angles", "jitter mode"),
    jittertype = menu.find("antiaim", "main", "angles", "jitter type"),
    jitterrange = menu.find("antiaim", "main", "angles", "jitter add"),

    ladderaa = menu.find("antiaim", "main", "general", "ladder antiaim"),
    fastladder = menu.find("antiaim", "main", "general", "fast ladder move"),
    antibackstab = menu.find("antiaim", "main", "general", "anti knife"),
    legslide = menu.find("antiaim", "main", "general", "leg slide"),

    overridemove = menu.find("antiaim", "main", "desync", "override stand#move"),
    overridemovesw = menu.find("antiaim", "main", "desync", "override stand#slow walk"),
    desyncside = menu.find("antiaim", "main", "desync", "stand", "side"),
    desyncdefside = menu.find("antiaim", "main", "desync", "stand", "default side"),
    leftamount = menu.find("antiaim", "main", "desync", "left amount"),
    rightamount = menu.find("antiaim", "main", "desync", "right amount"),
    antibruteforce = menu.find("antiaim", "main", "desync", "anti bruteforce"),
    desynconshot = menu.find("antiaim", "main", "desync", "on shot"),
    fake_lag_value = menu.find("antiaim", "main", "fakelag", "amount"),

    bodylean = menu.find("antiaim", "main", "angles", "body lean"),
    bodyleanval = menu.find("antiaim", "main", "angles", "body lean value"),
    movebodylean = menu.find("antiaim", "main", "angles", "moving body lean"),

    enableroll = menu.find("antiaim", "main", "extended angles", "enable")[2],
    moveroll = menu.find("antiaim", "main", "extended angles", "enable while moving"),
    rollpitch = menu.find("antiaim", "main", "extended angles", "pitch"),
    rolltype = menu.find("antiaim", "main", "extended angles", "type"),
    rolloffset = menu.find("antiaim", "main", "extended angles", "offset"),

    invert = menu.find("antiaim", "main", "manual", "invert desync")[2],
    left = menu.find("antiaim", "main", "manual", "left")[2],
    right = menu.find("antiaim", "main", "manual", "right")[2],
    back = menu.find("antiaim", "main", "manual", "back")[2],
    freestand = menu.find("antiaim", "main", "auto direction", "enable")[2],
    fsstate = menu.find("antiaim", "main", "auto direction", "states"),

    nadehelper = menu.find("misc", "nade helper", "general", "autothrow")[2],

    transparency = menu.find("visuals", "view", "thirdperson", "transparency when scoped"),
    health = menu.find("visuals", "esp", "players", "health#enemy")[1],
    localchams = menu.find("visuals", "esp", "models", "enable#local"),
    localstyle = menu.find("visuals", "esp", "models", "style#local"),
    localcolor = menu.find("visuals", "esp", "models", "color#local")[2],

    accentcol = menu.find("misc", "main", "personalization", "accent color")[2],

    keybinds = menu.find("misc", "main", "indicators", "keybinds#keybinds"),
    always = menu.find("misc", "main", "indicators", "show always-on keybinds#keybinds")
}

local groups = {
    ["Invisible"] = eui.create("Invisible", 1),
    ["Window"] = eui.create("Window", 2),
    ["World"] = eui.create("World", 1),
    ["Thirdperson"] = eui.create("Thirperson", 1),
    ["Indicators"] = eui.create("Indicators", 2),
    ["Misc"] = eui.create("Miscellaneous", 1),
    ["Settings"] = eui.create("Settings", 2),
    ["Sharing"] = eui.create("Sharing", 2),
    ["Improvements"] = eui.create("Enhancements", 1),
    ["Resolver"] = eui.create("Resolver system", 2),
    ["Conditional"] = eui.create("Conditional preset", 1),
    ["Anims"] = eui.create("Anim breakers", 1),
}
local builder = {
    ["General"] = {},
    ["Defensive"] = {},
    ["Enable"] = groups["Conditional"]:checkbox("Antiaim system"),
    ["Selectable"] = groups["Conditional"]:list("Condition", {"Share","Stand", "Walk", "Slow", "Duck", "Air", "Air+", "Break"}, 4),
    conditions = {"Share","Stand", "Walk", "Slow", "Duck", "Air", "Air+", "Break"},
    delay = 0,
    delayinvert = false,
    desyncdelay = 0,
    desyncdelayinvert = false,
    chocked = 0,
    chockedinvert = false,
    exploit = 0,
    defensive = 0,
    defensiveactive = false,
    switch = 0,
    switchactive = false,
    speen = 0,

}

local defensive = {
    db = {},
    active = function(self)
        local player = entity_list.get_local_player()
        local idx = player:get_index()
        local tickcount = globals.tick_count()
        local sim_time = client.time_to_ticks(player:get_prop("m_flSimulationTime"))

        self.db[idx] = self.db[idx] and self.db[idx] or {
            last_sim_time = 0,
            defensive_until = 0
        }

        if self.db[idx].last_sim_time == 0 then
            self.db[idx].last_sim_time = sim_time
            return false
        end

        local sim_diff = sim_time - self.db[idx].last_sim_time

        if sim_diff < 0 then

            self.db[idx].defensive_until = tickcount + math.abs(sim_diff)

            if engine.get_choked_commands() == 1 then
                self.db[idx].defensive_until = self.db[idx].defensive_until - client.time_to_ticks(engine.get_latency())
            end
        end

        self.db[idx].last_sim_time = sim_time

        return self.db[idx].defensive_until > tickcount
    end,
    trigger = function()
        if (refs.hideshots:get() or refs.doubletap:get()) and (exploits.get_charge() == exploits.get_max_charge()) then
            exploits.force_anti_exploit_shift()
        end
    end
}

for i=1, #builder.conditions do 

    groups["General_angles" .. i] = eui.create("[" .. builder.conditions[i] .. "] Angles", 1)
    groups["General_modifier" .. i] = eui.create("[" .. builder.conditions[i] .. "] Modifier", 2)
    groups["General_defensive" .. i] = eui.create("[" .. builder.conditions[i] .. "] Defensive", 3)

    builder["General"][i] = {
        ["Enable"] = groups["General_angles" .. i]:checkbox("Enable condition"),

        ["Pitch"] = groups["General_angles" .. i]:selection("Pitch", {"None", "Down", "Up", "Zero", "Jitter", "Random"}),
        ["Yaw"] = groups["General_angles" .. i]:selection("Yaw base", {"None", "Viewangle", "Crosshair", "Distance", "Velocity"}),

        ["Yaw_mode"] = groups["General_modifier" .. i]:selection("Yaw mode", {"Disabled", "Left + Right", "Tickbased", "Smart based"}),
        ["Yaw_left"] = groups["General_modifier" .. i]:slider("Yaw left", -180, 180, 1, 0),
        ["Yaw_right"] = groups["General_modifier" .. i]:slider("Yaw right", -180, 180, 1, 0),
        ["Tick"] = groups["General_modifier" .. i]:slider("Tick", 2, 16, 1, 0),
        ["Fluctuate"] = groups["General_modifier" .. i]:slider("Fluctuate", 0, 6, 1, 0),

        ["Modifier"] = groups["General_modifier" .. i]:selection("Yaw modifier", {"Disabled", "Offset", "Center", "3-Way", "5-Way", "Exploit"}),
        --["Separator"] = groups["General_angles_modifier" .. i]:separator("a"),
        ["Modifier_value"] = groups["General_modifier" .. i]:slider("Modifier value", -180, 180, 1, 0),

        ["Desync"] = groups["General_modifier" .. i]:selection("Desync", {"None", "Tick", "Jitter", "Breaker"}),
        ["Desync_text"] = groups["General_modifier" .. i]:text("( ! )  Disable invert desync keybind"),
        ["Desync_left"] = groups["General_modifier" .. i]:slider("Desync left", 0, 100, 1, 0, "%"),
        ["Desync_right"] = groups["General_modifier" .. i]:slider("Desync right", 0, 100, 1, 0, "%"),
        ["Desync_tick"] = groups["General_modifier" .. i]:slider("Tick delay", 2, 16, 1, 0),
        ["Desync_fluctuate"] = groups["General_modifier" .. i]:slider("Fluctuate delay", 0, 6, 1, 0),
    }

    builder["Defensive"][i] = {
        ["Defensive"] = groups["General_angles" .. i]:selection("Defensive mode", {"Disabled", "Default", "Ping", "Random"}),

        ["Pitch"] = groups["General_defensive" .. i]:selection("Pitch", {"Disabled", "Down", "Up", "Zero", "Jitter", "Random", "Switch"}),
        ["Pitch_value_l"] = groups["General_defensive" .. i]:slider("Pitch value 1", -89, 89, 1, 0),
        ["Pitch_value_r"] = groups["General_defensive" .. i]:slider("Pitch value 2", -89, 89, 1, 0),
        ["Yaw"] = groups["General_defensive" .. i]:selection("Yaw", {"Disabled", "Switch", "Spin", "Random", "Override"}),
        ["Yaw_value"] = groups["General_defensive" .. i]:slider("Amount", -180, 180, 1, 0),
        
    }
end

local inter = {

    ["Selectable"] = groups["Conditional"]:selection("undf", {"1","2","3","4"}),


    ["Multipoint"] = groups["Improvements"]:checkbox("Auto multipoint"),
    ["Unlockping"] = groups["Improvements"]:checkbox("Unlock fake ping"),
    ["Interpolation"] = groups["Improvements"]:checkbox("Disable interpolation"),

    ["Resolver"] = groups["Resolver"]:checkbox("Custom resolver"),
    ["Dump_memory"] = groups["Resolver"]:button("Dump memory", function ()
        print(use:dump(resolver.memory))
        engine.execute_cmd("showconsole")    
    end),
    ["Clear_memory"] = groups["Resolver"]:button("Clear memory", function ()
        print("Memory has been reset")
        resolver.memory = {}
        engine.execute_cmd("showconsole")    
    end),

    ["Watermark"] = groups["Window"]:checkbox("Brand mark"),
    --["Logs"] = groups["Window"]:checkbox("Aimbot logs"),
    
    ["Hitmarker"] = groups["World"]:checkbox("Hitmarker"), 
    ["Skeet_fonts"] = groups["World"]:checkbox("Gamesense ESP"), 

    ["Check_thirdperson"] = groups["Thirdperson"]:checkbox("Thirdperson"),
    ["Thirdperson"] = groups["Thirdperson"]:slider("Distance", 0, 200, 1, 0),

    ["Indicators"] = groups["Indicators"]:checkbox("Side"),
    ["Defensive"] = groups["Indicators"]:checkbox("Defensive"),
    ["Velocity"] = groups["Indicators"]:checkbox("Velocity"),

    ["Toss"] = groups["Misc"]:selection("Toss", {"Disable", "Intelligent", "Semi mode", "Full mode"}),
    ["Antiafk"] = groups["Misc"]:checkbox("Anti AFK"),
    ["Clantag"] = groups["Misc"]:checkbox("Clantag"),
    ["Trashtalk"] = groups["Misc"]:checkbox("Trashktalk"),

    ["Ground"] = groups["Anims"]:selection("Ground", {"Disabled", "Follow legs", "Walk legs", "Broke legs"}),
    ["Air"] = groups["Anims"]:selection("Air", {"Disabled", "Static legs", "Walk legs", "Broke legs"}),
    ["Extra"] = groups["Anims"]:multi_selection("Extra", {"Lean"}),
    ["Lean"] = groups["Anims"]:slider("Lean", 0, 100, 1, 0),

    --["Configs"] = groups["Settings"]:text("Undf is working in this option but there is a problem importing/exporting that brokes some variables that dont exports correctly", 0, 100, 1, 0),

    
    ["Load_config"] = groups["Settings"]:button("Load config", function ()

        local data = filesystem.read(".undf/settings.undf", "")
        local success, result = pcall(base64.decode, data)
        if not success then
            client.log_screen("Invalid config (did u copy it correctly?)")
        else
            data = base64.decode(data)
        end
        local success, result = pcall(eui.import, data)
        if not success then
            client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Invalid config: " .. result)
        else
            
            client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Loaded config")
        end

    end),
    ["Save_config"] = groups["Settings"]:button("Save config", function ()
        filesystem.write(".undf/settings.undf", base64.encode(eui.export()))
        client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Saved config")

    end),

    ["Import_config"] = groups["Sharing"]:button("Import config", function ()
        local data = clipboard.get()
        local success, result = pcall(base64.decode, data)
        if not success then
            client.log_screen("Invalid config (did u copy it correctly?)")
        else
            data = base64.decode(data)
        end
        local success, result = pcall(eui.import, data)
        if not success then
            client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Invalid config: " .. result)
        else
            client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Loaded config")
        end
    end),

    ["Export_config"] = groups["Sharing"]:button("Export config", function ()
        clipboard.set(base64.encode(eui.export()))    
        client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Exported config")
    end),
}

local colors = {
    ["Watermark"] = groups["Window"]:color_picker(inter["Watermark"], "Brand mark accent", color_t(255,255,255,125)),
    ["Hitmarker"] = groups["World"]:color_picker(inter["Hitmarker"], "Hitmarker accent", color_t(255,255,255)),
    ["Indicators"] = groups["Indicators"]:color_picker(inter["Indicators"], "Indicator accent", refs.accentcol:get()),
    ["Defensive"] = groups["Indicators"]:color_picker(inter["Defensive"], "Defensive accent", refs.accentcol:get()),
    ["Velocity"] = groups["Indicators"]:color_picker(inter["Velocity"], "Velocity  accent", refs.accentcol:get()),

}

local drag = {
    ["Velocity_x"] = groups["Indicators"]:slider("Velocity x", 0, screen.x, 1, 0),
    ["Velocity_y"] = groups["Indicators"]:slider("Velocity y", 0, screen.y, 1, 0),
    ["Defensive_x"] = groups["Indicators"]:slider("Defensive x", 0, screen.x, 1, 0),
    ["Defensive_y"] = groups["Indicators"]:slider("Defensive y", 0, screen.y, 1, 0),
}
local keys = {
    ["Thirdperson"] = groups["Thirdperson"]:keybind(inter["Check_thirdperson"], "Thirperson key")
}

--Menu visible stuff
events:add(e_callbacks.PAINT, function () 
    inter["Selectable"]:depend({(false)})

    builder["Enable"]:depend({inter["Selectable"], 2})
    builder["Selectable"]:depend({builder["Enable"], true}, {inter["Selectable"], 2})

    for i=1, #builder.conditions do 

        builder["General"][i]["Enable"]:depend({builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})

        builder["General"][i]["Pitch"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Yaw"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})

        builder["General"][i]["Yaw_mode"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Yaw_left"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["General"][i]["Yaw_mode"]:get() > 1)})
        builder["General"][i]["Yaw_right"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["General"][i]["Yaw_mode"]:get() > 1)})
        builder["General"][i]["Tick"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {builder["General"][i]["Yaw_mode"],3})
        builder["General"][i]["Fluctuate"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {builder["General"][i]["Yaw_mode"],3})

        builder["General"][i]["Modifier"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Modifier_value"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["General"][i]["Modifier"]:get() > 1)})


        builder["Defensive"][i]["Defensive"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})

        builder["Defensive"][i]["Pitch"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["Defensive"][i]["Defensive"]:get() > 1)})
        builder["Defensive"][i]["Pitch_value_l"]:depend({builder["General"][i]["Enable"], true}, {builder["Defensive"][i]["Pitch"], 7}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["Defensive"][i]["Defensive"]:get() > 1)})
        builder["Defensive"][i]["Pitch_value_r"]:depend({builder["General"][i]["Enable"], true}, {builder["Defensive"][i]["Pitch"], 7}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["Defensive"][i]["Defensive"]:get() > 1)})
        builder["Defensive"][i]["Yaw"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["Defensive"][i]["Defensive"]:get() > 1)})
        builder["Defensive"][i]["Yaw_value"]:depend({builder["General"][i]["Enable"], true}, {(builder["Defensive"][i]["Yaw"]:get() ~= 1 and builder["Defensive"][i]["Yaw"]:get() ~= 4 )}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i}, {(builder["Defensive"][i]["Defensive"]:get() > 1)})

        builder["General"][i]["Desync"]:depend({builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Desync_text"]:depend({refs.invert:get(), false}, {(builder["General"][i]["Desync"]:get() > 1)}, {builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Desync_left"]:depend({(builder["General"][i]["Desync"]:get() > 1)}, {builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Desync_right"]:depend({(builder["General"][i]["Desync"]:get() > 1)}, {builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Desync_tick"]:depend({builder["General"][i]["Desync"], 2}, {(builder["General"][i]["Desync"]:get() > 1)}, {builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})
        builder["General"][i]["Desync_fluctuate"]:depend({builder["General"][i]["Desync"], 2}, {(builder["General"][i]["Desync"]:get() > 1)}, {builder["General"][i]["Enable"], true}, {builder["Enable"], true}, {inter["Selectable"], 2}, {builder["Selectable"], i})

    end

    inter["Multipoint"]:depend({inter["Selectable"], 1})
    inter["Unlockping"]:depend({inter["Selectable"], 1})
    inter["Interpolation"]:depend({inter["Selectable"], 1})
    inter["Resolver"]:depend({inter["Selectable"], 1})
    inter["Dump_memory"]:depend({inter["Selectable"], 1})
    inter["Clear_memory"]:depend({inter["Selectable"], 1})


    inter["Watermark"]:depend({inter["Selectable"], 3})
    colors["Watermark"]:depend({inter["Watermark"], true}, {inter["Selectable"], 3})

    --inter["Logs"]:depend({inter["Selectable"], 3})

    inter["Hitmarker"]:depend({inter["Selectable"], 3})
    colors["Hitmarker"]:depend({inter["Hitmarker"], true},{inter["Selectable"], 3})
    inter["Skeet_fonts"]:depend({inter["Selectable"], 3})

    inter["Check_thirdperson"]:depend({inter["Selectable"], 3})
    inter["Thirdperson"]:depend({inter["Selectable"], 3}, {inter["Check_thirdperson"], true})
    keys["Thirdperson"]:depend({inter["Selectable"], 3}, {inter["Check_thirdperson"], true})

    inter["Indicators"]:depend({inter["Selectable"], 3})
    colors["Indicators"]:depend({inter["Indicators"], true}, {inter["Selectable"], 3})

    inter["Defensive"]:depend({inter["Selectable"], 3})
    colors["Defensive"]:depend({inter["Defensive"], true}, {inter["Selectable"], 3})
    drag["Defensive_x"]:depend({(false)})
    drag["Defensive_y"]:depend({(false)})


    inter["Velocity"]:depend({inter["Selectable"], 3})
    colors["Velocity"]:depend({inter["Velocity"], true}, {inter["Selectable"], 3})
    drag["Velocity_x"]:depend({(false)})
    drag["Velocity_y"]:depend({(false)})

    inter["Toss"]:depend({inter["Selectable"], 4})
    inter["Clantag"]:depend({inter["Selectable"], 4})
    inter["Antiafk"]:depend({inter["Selectable"], 4})
    inter["Trashtalk"]:depend({inter["Selectable"], 4})

    inter["Ground"]:depend({inter["Selectable"], 4})
    inter["Air"]:depend({inter["Selectable"], 4})
    inter["Extra"]:depend({inter["Selectable"], 4})
    inter["Lean"]:depend({inter["Extra"]:get(1), true}, {inter["Selectable"], 4})

    inter["Load_config"]:depend({inter["Selectable"], 4})
    inter["Save_config"]:depend({inter["Selectable"], 4})

    inter["Import_config"]:depend({inter["Selectable"], 4})
    inter["Export_config"]:depend({inter["Selectable"], 4})


end, function () 
    return menu.is_open()
end)

events:add(e_callbacks.PAINT, function ()
    local menu_size = menu.get_size()
    local menu_pos = menu.get_pos()
    local font = fonts.get_or_register("Undf", "Arial",  17, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC)
    local pos = vec2_t(menu_pos.x + menu_size.x + 10, -menu_size.y - 50 + (50 + menu_size.y + menu_pos.y)*animation.get("menu_tabs_animation"))

    render.rect_filled(pos, vec2_t(150, menu_size.y), color_t(30, 30, 30),4)


    --HEADER 1
    render.rect_filled(pos, vec2_t(150, 50), color_t(41, 41, 41),4)
    render.rect_filled(pos + vec2_t(0, 45), vec2_t(150, 10), color_t(41, 41, 41),0)
    render.line(pos + vec2_t(0, 54), pos +vec2_t(150, 54), refs.accentcol:get(),0)

    render.text(font, "undefined", pos + vec2_t(150/2 - render.get_text_size(font, "undefined").x/2, 55/2 - render.get_text_size(font, "undefined").y/2), refs.accentcol:get())
    --ENDHEADER 1

    --HEADER 2
    render.rect_filled(pos + vec2_t(0, menu_size.y - 70), vec2_t(150, 10), color_t(41, 41, 41),0)
    render.rect_filled(pos + vec2_t(0, menu_size.y - 60), vec2_t(150, 60), color_t(41, 41, 41),4)
    render.line(pos + vec2_t(0, menu_size.y - 71), pos + vec2_t(150, menu_size.y - 71), refs.accentcol:get(),0)
    
    if icons["User"] ~= nil then 
        render.texture(icons["User"].id, pos + vec2_t(10, menu_size.y - 70/2 - 20), vec2_t(40, 40))
        local circle_center = pos + vec2_t(10 + 20, menu_size.y - 70/2)
        local radius = 20 
        local step = 1
        local max_radius = 29
        local color = color_t.new(41, 41, 41) 
        
        local offset = vec2_t(1, 1)
        local offset2 = vec2_t(1, 1) 

        for r = radius, max_radius, step do
            render.circle(circle_center, r, color)

            render.circle(circle_center + offset, r, color)  
            render.circle(circle_center - offset, r, color)  
            render.circle(circle_center + vec2_t(-offset.x, offset.y), r, color)  
            render.circle(circle_center + vec2_t(offset.x, -offset.y), r, color)  

            render.circle(circle_center + offset2, r, color)  
            render.circle(circle_center - offset2, r, color) 
            render.circle(circle_center + vec2_t(-offset2.x, offset2.y), r, color)  
            render.circle(circle_center + vec2_t(offset2.x, -offset2.y), r, color) 
        end
        if render.get_text_size(fonts.default(), user.name).x > 85 then 
            render.text(fonts.default(), "free user", pos + vec2_t(55, menu_size.y - 70/2 - render.get_text_size(fonts.default(), user.name).y/2), color_t(180,180,180))
        else 
            render.text(fonts.default(), user.name, pos + vec2_t(55, menu_size.y - 70/2 - render.get_text_size(fonts.default(), user.name).y/2), color_t(180,180,180))
        end
    end
    --ENDHEADER 2




    for i=0, 3 do 
        local icon = icons[i]

        if i ~= inter["Selectable"].ref:get() - 1 then
            render.texture(icon.id, pos + vec2_t(150/2 - icon.size.x/2, 55 + (icon.size.y*i) + 50*(i+1)), icon.size)
            render.rect_filled(pos + vec2_t(150/2 - icon.size.x/2, 55 + (icon.size.y*i) + 50*(i+1)),icon.size, color_t(30,30,30,120))
        end

        
        if input.is_key_pressed(e_keys.MOUSE_LEFT) then
    
            if input.is_mouse_in_bounds(pos + vec2_t(0, 40 + (icon.size.y*i) + 50*(i+1)),vec2_t(150, icon.size.y + 30)) then
                inter["Selectable"].ref:set(i+1)            
            end
        end
    end

    local currenticon = icons[inter["Selectable"].ref:get() - 1]
    local anim = animation.new("menu_tabs_animation2", inter["Selectable"].ref:get(), 5)

    render.texture(currenticon.id, pos + vec2_t(150/2 - currenticon.size.x/2, 55 + (currenticon.size.y*(anim-1)) + 50*(anim)), currenticon.size)
    render.rect_filled(pos + vec2_t(2, 55 + (currenticon.size.y*(anim-1)) + 50*(anim)), vec2_t(2, currenticon.size.y), refs.accentcol:get())




    render.rect(pos, vec2_t(150, menu_size.y), color_t(0, 0, 0),4)

    --render.rect(pos, vec2_t(220, 80), color_t(0,0,0), 4)


end, function () 
    local anim = animation.new("menu_tabs_animation", menu.is_open() and 1 or 0, 12)
    return anim >= 0.01
end)

--builder system 
builder.current = function () 
    local lp = entity_list.get_local_player()
    if not lp then
        return 1
    end 
    local m_vecVelocity = lp:get_prop('m_vecVelocity')
    local velocity = math.vec_length2d(m_vecVelocity)
    local flags = lp:get_prop('m_fFlags')
    local ducking = bit.lshift(1, 1)
    local ground = bit.lshift(1, 0)

    if exploits.get_charge() == 0 and builder["General"][8]["Enable"]:get() then 
        return 8
    end
    if bit.band(flags, ground) == 1 and velocity > 80 and bit.band(flags, ducking) == 0 then
        return builder["General"][3]["Enable"]:get() and 3 or 1 --Walk
    end
    if bit.band(flags, ground) == 0 and bit.band(flags, ducking) == 0 then
        return builder["General"][6]["Enable"]:get() and 6 or 1 --Air
    end
    if bit.band(flags, ground) == 0 and bit.band(flags, ducking) > 0.9 then
        return builder["General"][7]["Enable"]:get() and 7 or 1 --Air+
    end
    if bit.band(flags, ground) == 1 and velocity < 3 and bit.band(flags, ducking) == 0 then
        return builder["General"][2]["Enable"]:get() and 2 or 1 --Stand
    else
        if bit.band(flags, ground) == 1 and refs.slowmotion:get() and bit.band(flags, ducking) == 0 then
            return builder["General"][4]["Enable"]:get() and 4 or 1 --Slow
        end
    end
    if bit.band(flags, ground) == 1 and bit.band(flags, ducking) > 0.9 then
        return builder["General"][5]["Enable"]:get() and 5 or 1 --Duck
    end
    return builder["General"][8]["Enable"]:get() and 8 or 1
end

events:add(e_callbacks.ANTIAIM, function(ctx, cmd)
    local i = builder.current()
    if builder["General"][i]["Pitch"]:get() ~= 6 then 
        refs.pitch:set(builder["General"][i]["Pitch"]:get())
    else
        ctx:set_pitch(math.random(-89,89))
    end

    refs.yawbase:set(builder["General"][i]["Yaw"]:get())
    
    --YAW BASE
    if builder["General"][i]["Yaw_mode"]:get() == 1 then 
        refs.yawadd:set(0)
    elseif builder["General"][i]["Yaw_mode"]:get() == 2 then 
        if builder["General"][i]["Desync"]:get() == 2 then 
            refs.yawadd:set(builder.desyncdelayinvert and builder["General"][i]["Yaw_left"]:get() or builder["General"][i]["Yaw_right"]:get())
        else
            if antiaim.get_desync_side() == 1 then --Left
                refs.yawadd:set(builder["General"][i]["Yaw_left"]:get())
            elseif antiaim.get_desync_side() == 2 then --Right 
                refs.yawadd:set(builder["General"][i]["Yaw_right"]:get())
            else --No side
                refs.yawadd:set(0)
            end
        end

    elseif builder["General"][i]["Yaw_mode"]:get() == 3 then 
        if engine.get_choked_commands() == 0 then
            if globals.tick_count() > builder.delay then
                builder.delay = globals.tick_count() + builder["General"][i]["Tick"]:get() + math.random(-builder["General"][i]["Fluctuate"]:get(), builder["General"][i]["Fluctuate"]:get())
                builder.delayinvert = not builder.delayinvert
            end
        end
        refs.yawadd:set(builder.delayinvert and builder["General"][i]["Yaw_left"]:get() or builder["General"][i]["Yaw_right"]:get())

    elseif builder["General"][i]["Yaw_mode"]:get() == 4 then 
        builder.chocked = builder.chocked + engine.get_choked_commands()%14
        if builder.chocked > 14  then 
            builder.chockedinvert = not builder.chockedinvert
            builder.chocked = 0
        end
        
        refs.yawadd:set(builder.chockedinvert and builder["General"][i]["Yaw_left"]:get() or builder["General"][i]["Yaw_right"]:get())
    end

    --YAW MODIFIER 
    if builder["General"][i]["Modifier"]:get() == 1 then
        refs.jittermode:set(1)
    else
        refs.jittermode:set(2)
        if builder["General"][i]["Modifier"]:get() ~= 6 then 
            refs.jittertype:set(builder["General"][i]["Modifier"]:get()-1)
            refs.jitterrange:set(builder["General"][i]["Modifier_value"]:get())
        else 

            if engine.get_choked_commands() == 0 then
                if globals.tick_count() > builder.exploit then
                    builder.exploit = globals.tick_count() + 64
                    refs.jittertype:set(1)
                    refs.jitterrange:set(math.random(0,1) == 1 and 90 or -90)
                else
                    refs.jittertype:set(2)
                    refs.jitterrange:set(builder["General"][i]["Modifier_value"]:get())
                end
            end


        end
    end

    --DESYNC BASE
    if builder["General"][i]["Desync"]:get() > 1 then   
        refs.overridemove:set(false)
        refs.overridemovesw:set(false)

        refs.leftamount:set(builder["General"][i]["Desync_left"]:get())
        refs.rightamount:set(builder["General"][i]["Desync_right"]:get())
        if builder["General"][i]["Desync"]:get() == 2 then 
            if engine.get_choked_commands() == 0 then
                if globals.tick_count() > builder.desyncdelay then
                    builder.desyncdelay = globals.tick_count() + builder["General"][i]["Desync_tick"]:get() + math.random(-builder["General"][i]["Desync_fluctuate"]:get(), builder["General"][i]["Desync_fluctuate"]:get())
                    builder.desyncdelayinvert = not builder.desyncdelayinvert
                end 
            end
       
            refs.desyncside:set(builder.desyncdelayinvert and 2 or 3)
        end

        if builder["General"][i]["Desync"]:get() == 3 then 
            refs.desyncside:set(4)
        end

        if builder["General"][i]["Desync"]:get() == 4 then 
            local value = math.random(2, 7)

            refs.desyncside:set(value)
            refs.desyncdefside:set(math.random(1,2))

        end

    else 
        refs.desyncside:set(1)
    end

end, function () 
    return builder["Enable"]:get() and builder["General"][builder.current()]["Enable"]:get() and not builder.defensiveactive
end)

events:add(e_callbacks.ANTIAIM, function(ctx, cmd)
    local i = builder.current()
    if engine.get_choked_commands() == 0 then
        if globals.tick_count() > builder.switch then
            builder.switch = globals.tick_count() + 2
            builder.switchactive = not builder.switchactive 
        end
    end
    if builder["Defensive"][i]["Pitch"]:get() < 6 then 
        refs.pitch:set(builder["Defensive"][i]["Pitch"]:get())
    else
        
        if builder["Defensive"][i]["Pitch"]:get() == 7 then 

            ctx:set_pitch(builder.switchactive and builder["Defensive"][i]["Pitch_value_l"]:get() or builder["Defensive"][i]["Pitch_value_r"]:get())

        elseif builder["Defensive"][i]["Pitch"]:get() == 6 then 
            ctx:set_pitch(math.random(-89,89))
        end
    end

    if builder["Defensive"][i]["Yaw"]:get() == 2 then 
        refs.jitterrange:set(builder.switchactive and builder["General"][i]["Modifier_value"]:get() + builder["Defensive"][i]["Yaw_value"]:get() or builder["General"][i]["Modifier_value"]:get() - builder["Defensive"][i]["Yaw_value"]:get())
    end

    if builder["Defensive"][i]["Yaw"]:get() == 3 then
        local spin = function(speed)
            builder.speen = builder.speen + speed / 2
            if builder.speen < -180 then
                builder.speen = builder.speen + 360
            elseif builder.speen > 180 then
                builder.speen = builder.speen - 360
            end
            return builder.speen

        end 

        refs.yawadd:set(spin(builder["Defensive"][i]["Yaw_value"]:get()))
    end
    
    if builder["Defensive"][i]["Yaw"]:get() == 4 then 
        refs.jittermode:set(3)
        refs.jittertype:set(math.random(1,4))
        refs.jitterrange:set(math.random(-180, 180))
    end

    if builder["Defensive"][i]["Yaw"]:get() == 5 then 

        refs.jittermode:set(1)

        refs.yawadd:set(builder["Defensive"][i]["Yaw_value"]:get())

    end


end, function () 
    if builder["Enable"]:get() and builder["General"][builder.current()]["Enable"]:get() then 
        if builder["Defensive"][builder.current()]["Defensive"]:get() == 1 then 
            builder.defensiveactive = false
        elseif builder["Defensive"][builder.current()]["Defensive"]:get() == 2 then 
            if (refs.hideshots:get() or refs.doubletap:get()) and (exploits.get_charge() == exploits.get_max_charge()) and not refs.fakeduck:get() then 
                defensive:trigger()
            end
            builder.defensiveactive = defensive:active()
        elseif builder["Defensive"][builder.current()]["Defensive"]:get() == 3 then
            builder.defensive = builder.defensive + engine.get_latency(e_latency_flows.INCOMING)
            if builder.defensive > engine.get_latency(e_latency_flows.INCOMING)*10 then 
                builder.defensiveactive = not builder.defensiveactive
                if builder.defensiveactive then 
                    builder.defensive = -engine.get_latency(e_latency_flows.INCOMING)*10
                else
                    builder.defensive = -engine.get_latency(e_latency_flows.INCOMING)*50

                end
            end


        elseif builder["Defensive"][builder.current()]["Defensive"]:get() == 4 then 

            builder.defensiveactive = math.random(0,engine.get_choked_commands()) == 1 and true or false
        end
    else 
        builder.defensiveactive = false
    end
    return builder.defensiveactive
end)


events:add(e_callbacks.EVENT, function (e)
    if e.name == "round_start" then 
        builder.delay = 0
        builder.delayinvert = false
        builder.desyncdelay = 0
        builder.desyncdelayinvert = false
        builder.chocked = 0
        builder.chockedinvert = false
        builder.exploit = 0
        builder.defensive = 0
        builder.defensiveactive = false
        builder.switch = 0
        builder.switchactive = false
        builder.speen = 0
        client.log_screen(refs.accentcol:get(), "undf", color_t(255,255,255), "Antiaim base has been reset")
    end

    

end, function () 
    return builder["Enable"]:get() 
end)

events:add(e_callbacks.ANTIAIM, function(ctx, cmd)
    if not engine.is_connected() or not engine.is_in_game() then
        return
    end
    local lp = entity_list.get_local_player()
    if not lp then
        return
    end
    local m_vecVelocity = lp:get_prop('m_vecVelocity')
    local velocity = math.vec_length2d(m_vecVelocity)
    local flags = lp:get_prop("m_fFlags")
    local airborne = bit.band(flags, bit.lshift(1, 0)) == 0

    if not airborne then
        if inter["Ground"]:get() == 2 and velocity > 3 then
            refs.legslide:set(3)
            ctx:set_render_pose(e_poses.RUN, 0)
            
        elseif inter["Ground"]:get() == 3 and velocity > 3 then
            refs.legslide:set(2)
            ctx:set_render_pose(e_poses.MOVE_YAW, 0)
            ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 1)
        elseif inter["Ground"]:get() == 4 and velocity > 3 then
                local value = math.random(0, 1) == 1
                refs.legslide:set(value and 3 or 2)
                if value then 
                    ctx:set_render_pose(e_poses.RUN, 0)
                    ctx:set_render_pose(e_poses.MOVE_YAW, 1)
                    ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 0)

                else
                    ctx:set_render_pose(e_poses.RUN, 1)
                    ctx:set_render_pose(e_poses.MOVE_YAW, 1)
                    ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 1)
                end
        end
    else
        if inter["Air"]:get() == 2 then
            ctx:set_render_pose(e_poses.JUMP_FALL, 1)
        elseif inter["Air"]:get() == 3 then
            refs.legslide:set(2)
            ctx:set_render_pose(e_poses.MOVE_YAW, 0)
            ctx:set_render_pose(e_poses.JUMP_FALL, 1)
            ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, 1)
        elseif inter["Air"]:get() == 4 then
            ctx:set_render_pose(e_poses.JUMP_FALL, client.random_float(0, 1))
            ctx:set_render_pose(e_poses.MOVE_YAW, client.random_float(0, 1))
            ctx:set_render_animlayer(e_animlayers.MOVEMENT_MOVE, client.random_float(0, 1))
            ctx:set_render_pose(e_poses.SPEED, client.random_float(0, 1))

        end
    end

    if inter["Extra"]:get(1) then
        ctx:set_render_animlayer(e_animlayers.LEAN, inter["Lean"]:get() / 100)
    end
    

end, function () 
    return true
end)




--Resolver
local iresolver = function () 
    utilitize = {
        this_call = function(call_function, parameters)
            return function(...)
                return call_function(parameters, ...)
            end
        end,
    
        entity_list_003 = ffi.cast(ffi.typeof("uintptr_t**"), memory.create_interface("client.dll", "VClientEntityList003"))
    }
    get_entity_address = utilitize.this_call(ffi.cast("get_client_entity_t", utilitize.entity_list_003[0][3]), utilitize.entity_list_003);
    resolver.detectState = function(ent)
        local m_vecVelocity = ent:get_prop('m_vecVelocity')
        local velocity = math.vec_length2d(m_vecVelocity)
        local flags = ent:get_prop('m_fFlags')
    
        local on_ground = bit.band(flags, 1) == 1
        local is_ducking = bit.band(flags, 2) == 2
    
        local state = ""
        local statenum = 0
    
        if on_ground then
            if velocity > 80 and not is_ducking then
                state, statenum = "move", 4
            elseif velocity < 3 and not is_ducking then
                state, statenum = "stand", 2
            elseif velocity <= 80 and not is_ducking then
                state, statenum = "slow motion", 3
            elseif is_ducking then
                if velocity > 10 then
                    state, statenum = "duck move", 6
                else
                    state, statenum = "duck", 5
                end
            end
        else
            if not is_ducking then
                state, statenum = "air", 7
            else
                state, statenum = "air duck", 8
            end
        end
    
        return state, statenum - 1
    end
    resolver.m_flMaxDelta = function(ent)
        local player_index = ent:get_index()
        local player_ptr = get_entity_address(player_index)
    
        local anim_state = ffi.cast("CPlayer_Animation_State**", ffi.cast("uintptr_t", player_ptr) + 0x9960)[0]
    
        -- Obtener propiedades del estado de animación
        local feet_speed = math.clamp(anim_state.m_flFeetSpeedForwardsOrSideWays, 0, 1)
        local stop_to_run_fraction = anim_state.m_flStopToFullRunningFraction
        local duck_amount = anim_state.flDuckAmount
    
        local avg_speed_factor = ((stop_to_run_fraction * -0.3 - 0.2) * feet_speed) + 1
    
        if duck_amount > 0 then
            local duck_speed = duck_amount * feet_speed
            avg_speed_factor = avg_speed_factor + (duck_speed * (0.5 - avg_speed_factor))
        end
    
        -- Limitar el valor final entre 0 y 1
        return math.clamp(avg_speed_factor, 0, 1)
    end
    resolver.walk_to_run_transition = function(m_flWalkToRunTransition, m_bWalkToRunTransitionState, m_flLastUpdateIncrement, m_flVelocityLengthXY)
        -- Constantes de transición y velocidad
        local ANIM_TRANSITION_WALK_TO_RUN = false
        local ANIM_TRANSITION_RUN_TO_WALK = true
        local ANIM_TRANSITION_SPEED = 2.0
        local PLAYER_SPEED_RUN = 260.0
        local SPEED_WALK_THRESHOLD = PLAYER_SPEED_RUN * 0.52 -- Walk modifier
        local SPEED_RUN_THRESHOLD = PLAYER_SPEED_RUN * 0.34 -- Duck modifier
    
        -- Actualizar transición basada en el estado actual
        if m_flWalkToRunTransition > 0 and m_flWalkToRunTransition < 1 then
            local increment = m_flLastUpdateIncrement * ANIM_TRANSITION_SPEED
            if m_bWalkToRunTransitionState == ANIM_TRANSITION_WALK_TO_RUN then
                m_flWalkToRunTransition = m_flWalkToRunTransition + increment
            else
                m_flWalkToRunTransition = m_flWalkToRunTransition - increment
            end
            m_flWalkToRunTransition = math.clamp(m_flWalkToRunTransition, 0, 1)
        end
    
        -- Determinar nuevo estado de transición
        if m_flVelocityLengthXY > SPEED_WALK_THRESHOLD and m_bWalkToRunTransitionState == ANIM_TRANSITION_RUN_TO_WALK then
            m_bWalkToRunTransitionState = ANIM_TRANSITION_WALK_TO_RUN
            m_flWalkToRunTransition = math.max(0.01, m_flWalkToRunTransition)
        elseif m_flVelocityLengthXY < SPEED_WALK_THRESHOLD and m_bWalkToRunTransitionState == ANIM_TRANSITION_WALK_TO_RUN then
            m_bWalkToRunTransitionState = ANIM_TRANSITION_RUN_TO_WALK
            m_flWalkToRunTransition = math.min(0.99, m_flWalkToRunTransition)
        end
    
        return m_flWalkToRunTransition, m_bWalkToRunTransitionState
    end
    resolver.calculate_predicted_foot_yaw = function(m_flFootYawLast, m_flEyeYaw, m_flLowerBodyYawTarget, m_flWalkToRunTransition, m_vecVelocity, m_flMinBodyYaw, m_flMaxBodyYaw)
        -- Constantes y cálculos iniciales
        local MAX_VELOCITY = 260.0
        local VELOCITY_THRESHOLD = 0.1
        local VELOCITY_Z_THRESHOLD = 100.0
        local VELOCITY_MULTIPLIER = 30.0
        local TRANSITION_MULTIPLIER = 20.0
        local STATIC_ADJUSTMENT = 100.0
    
        local m_flVelocityLengthXY = math.min(math.vec_length2d(m_vecVelocity), MAX_VELOCITY)
        local m_flFootYaw = math.clamp(m_flFootYawLast, -360, 360)
        local flEyeFootDelta = math.angle_diff(m_flEyeYaw, m_flFootYaw)
    
        -- Ajustar yaw basado en diferencias de ángulo
        if flEyeFootDelta > m_flMaxBodyYaw then
            m_flFootYaw = m_flEyeYaw - math.abs(m_flMaxBodyYaw)
        elseif flEyeFootDelta < m_flMinBodyYaw then
            m_flFootYaw = m_flEyeYaw + math.abs(m_flMinBodyYaw)
        end
    
        m_flFootYaw = math.angle_normalize(m_flFootYaw)
    
        -- Incremento de actualización por tick
        local m_flLastUpdateIncrement = globals.interval_per_tick()
    
        -- Ajustar yaw basado en velocidad
        if m_flVelocityLengthXY > VELOCITY_THRESHOLD or m_vecVelocity.z > VELOCITY_Z_THRESHOLD then
            local adjustment = m_flLastUpdateIncrement * (VELOCITY_MULTIPLIER + TRANSITION_MULTIPLIER * m_flWalkToRunTransition)
            m_flFootYaw = math.approach_angle(m_flEyeYaw, m_flFootYaw, adjustment)
        else
            local adjustment = m_flLastUpdateIncrement * STATIC_ADJUSTMENT
            m_flFootYaw = math.approach_angle(m_flLowerBodyYawTarget, m_flFootYaw, adjustment)
        end
    
        return m_flFootYaw
    end
    resolver.resolve = function(ctx)
        local idx = ctx.player:get_index()
        local ent = ctx.player
        local lp = entity_list.get_local_player()
    
        if not lp or not lp:is_valid() or not lp:is_player() or not lp:is_alive() then
            return
        end
    
        if not resolver.last[idx] then
            resolver.last[idx] = {}
        end
    
        if not ent:is_valid() or not ent:is_alive() or not idx then
            return
        end
    
        -- Obtener propiedades y direcciones necesarias
        local player_ptr = get_entity_address(idx)
        local animstate = ffi.cast("CPlayer_Animation_State**", ffi.cast("uintptr_t", player_ptr) + 0x9960)[0]
        if not animstate then return end
    
        local m_vecVelocity = ent:get_prop('m_vecVelocity')
        local m_flVelocityLengthXY = math.vec_length2d(m_vecVelocity)
        local m_flEyeYaw = animstate.flEyeYaw
        local m_flGoalFeetYaw = animstate.flGoalFeetYaw
        local m_flLowerBodyYawTarget = ent:get_prop('m_flLowerBodyYawTarget')
        local m_flAngleDiff = math.angle_diff(m_flEyeYaw, m_flGoalFeetYaw)
    
        -- Verificar si las propiedades necesarias son válidas antes de usarlas
        if m_flEyeYaw == nil or m_flGoalFeetYaw == nil or m_flLowerBodyYawTarget == nil then
            return
        end
    
        -- Desincronización y cálculos de ángulos
        local m_flMaxDesyncDelta = resolver.m_flMaxDelta(ent)
        if m_flMaxDesyncDelta == nil then return end -- Verificar si el valor de desincronización es válido
    
        local m_flDesync = m_flMaxDesyncDelta * 57.295779513082 -- 57 es el valor máximo de desincronización (Max)
        local m_flAbsAngleDiff = math.abs(m_flAngleDiff)
    
        -- Inicialización de m_flAbsPreviousDiff si es nil
        if resolver.last[idx].m_flAbsPreviousDiff == nil then
            resolver.last[idx].m_flAbsPreviousDiff = 0  -- Asignar un valor por defecto si es nil
        end
    
        -- Calcular la diferencia entre los ángulos
        local m_flAbsPreviousDiff = resolver.last[idx].m_flAbsPreviousDiff
    
        -- Determinar el lado del ángulo
        local side = 0
        if m_flAngleDiff < 0 then
            side = 1
        elseif m_flAngleDiff > 0 then
            side = -1
        end
    
        -- Ajuste dinámico de la desincronización
        if m_flAbsAngleDiff < m_flAbsPreviousDiff then
            if m_flVelocityLengthXY > (resolver.last[idx].m_flVelocityLengthXY or 0) then
                if m_flAbsAngleDiff <= 10 then
                    m_flDesync = m_flAbsAngleDiff
                elseif m_flAbsAngleDiff <= 35 then
                    m_flDesync = math.max(29.0, m_flAbsAngleDiff)
                else
                    m_flDesync = math.clamp(m_flAbsAngleDiff, 29.0, 57.0)
                end
            end
        end
    
        -- Guardar estado de desincronización
        resolver.last[idx].m_flDesync = math.clamp(m_flDesync * side, -60, 60)
        resolver.last[idx].m_flSide = side
        resolver.last[idx].forced = false
        resolver.last[idx].m_flState, resolver.last[idx].m_flStateNum = resolver.detectState(ent)
        resolver.last[idx].Desync = -math.min(57, math.max(ent:get_prop("m_flPoseParameter", 11) * 120 - 57))
    
        -- Actualizar transición de caminar a correr
        resolver.last[idx].m_flWalkToRunTransition, resolver.last[idx].m_bWalkToRunTransitionState = resolver.walk_to_run_transition(
            resolver.last[idx].m_flWalkToRunTransition or 0, 
            resolver.last[idx].m_bWalkToRunTransitionState or false,
            globals.interval_per_tick(), 
            m_flVelocityLengthXY
        )
    
        -- Resolver usando memoria guardada si está disponible
        if resolver.memory[idx] then
            for state, sides in pairs(resolver.memory[idx]) do
                if state == resolver.last[idx].m_flState then
                    for side_key, desync_value in pairs(sides) do
                        if side_key == side then
                            resolver.last[idx].m_flDesync = desync_value
                            resolver.last[idx].forced = true
                            if idx == resolver.last.target then
                                resolver.last.Desync = resolver.last[idx].Desync
                                resolver.last.forced = resolver.last[idx].forced
                            end
                        end
                    end
                end
            end
        end
    
        -- Actualizar animaciones si hay arma activa
        local player_weapon = ent:get_active_weapon()
        if not player_weapon then return end
    
        -- Calcular el nuevo yaw de los pies basado en los ajustes
        animstate.flGoalFeetYaw = resolver.calculate_predicted_foot_yaw(
            m_flGoalFeetYaw, 
            m_flEyeYaw + resolver.last[idx].m_flDesync, 
            m_flLowerBodyYawTarget, 
            resolver.last[idx].m_flWalkToRunTransition, 
            m_vecVelocity, 
            -57, 
            57
        )
    
        -- Actualizar el valor de m_flAbsPreviousDiff para la siguiente iteración
        resolver.last[idx].m_flAbsPreviousDiff = m_flAbsAngleDiff
    end
    events:add(e_callbacks.HITSCAN, function (ctx)
        resolver.last.target = ctx.player:get_index()
    end, function () 
        return inter["Resolver"]:get()
    end)
    events:add(e_callbacks.NET_UPDATE, function (ctx)
        local players = entity_list.get_players(true)
        if not players then
            return
        end
        for _, enemy in ipairs(players) do
            if not enemy:is_dormant() then
                if enemy:is_alive() then
                    local ctx = {
                        player = enemy
                    }
                    resolver.resolve(ctx)
                end
            end
        end
    end, function () 
        return inter["Resolver"]:get()
    end)
    events:add(e_callbacks.EVENT, function (e)
        if e.name == "round_prestart" then
            if game_rules.get_prop("m_totalRoundsPlayed") == 0 then
                print("wiping resolver memory")
                resolver.memory = {}
            end
        end
        if e.name == "player_connect_full" then
            if entity_list.get_player_from_userid(e.userid) == entity_list.get_local_player() then
                resolver.memory = {}
            end
        end
    end, function () 
        return inter["Resolver"]:get()
    end)
    resolver.update.state = nil 
    resolver.update.side = nil 
    resolver.update.shot = function(self, shot)
        local lp = entity_list.get_local_player()
        if not lp then
            return
        end
        local idx = shot.player:get_index()
        self.desync = (resolver.last[idx] and resolver.last[idx].m_flDesync) and math.floor(resolver.last[idx].m_flDesync)
        self.side = resolver.last[idx] and resolver.last[idx].m_flSide or "?"
        self.state = resolver.last[idx] and resolver.last[idx].m_flState or "?"
        self.statenum = resolver.last[idx] and resolver.last[idx].m_flStateNum or "?"
        if resolver.last[idx] then
            self.forced = resolver.last[idx].forced
        else
            self.forced = false
        end
    end
    resolver.update.hit = function(self, hit)
    
        if resolver.last.target == hit.player:get_index() then
            if not resolver.memory[hit.player:get_index()] then
                resolver.memory[hit.player:get_index()] = {}
            end
            if self.state ~= nil then
                if not resolver.memory[hit.player:get_index()][self.state] then
                    resolver.memory[hit.player:get_index()][self.state] = {}
                end
                if hit.aim_hitgroup == hit.hitgroup then
                    resolver.memory[hit.player:get_index()][self.state][self.side] = self.desync
                    if self.forced then
                        print("resolved past instance for " .. hit.player:get_name() .. " as " .. hit.player:get_index() .. "." .. self.state .. " | " .. self.desync)
                    else
                        print("logged shot for " .. hit.player:get_name() .. " as " .. hit.player:get_index() .. "." .. self.state .. " | " .. self.desync)
                    end
                    
                end
            end
        end
    end
    resolver.update.miss = function(self, miss)
        if not (miss.reason_string == "resolver") then
            return
        end
    
        if resolver.last.target == miss.player:get_index() then
            if not resolver.memory[miss.player:get_index()] then
                return
            end
            if self.state ~= nil then
                if not resolver.memory[miss.player:get_index()][self.state] then
                    return
                end
                if not resolver.memory[miss.player:get_index()][self.state][self.side] then
                    return
                end
                resolver.memory[miss.player:get_index()][self.state][self.side] = nil
                print("removing memory instance due to miss: " .. self.state .. " | " .. self.side)
                
            end
        end
    end
    events:add(e_callbacks.AIMBOT_SHOOT, function (shot)
        resolver.update:shot(shot)
    end, function () 
        return inter["Resolver"]:get()
    end)
    events:add(e_callbacks.AIMBOT_HIT, function (hit)
        resolver.update:hit(hit)
    end, function () 
        return inter["Resolver"]:get()
    end)
    events:add(e_callbacks.AIMBOT_MISS, function (miss)
        resolver.update:miss(miss)
    end, function () 
        return inter["Resolver"]:get()
    end)
end; iresolver()

--Auto multipoint
events:add(e_callbacks.HITSCAN, function (ctx)
    local lp = entity_list.get_local_player()
    local enemy = ctx.player
    if not lp then
        return
    end

    local localorigin = lp:get_eye_position()
    local enemypos = {
        head = enemy:get_hitbox_pos(e_hitboxes.HEAD),
        chest = enemy:get_hitbox_pos(e_hitboxes.CHEST),
        stomach = enemy:get_hitbox_pos(e_hitboxes.PELVIS)
    }
    local enemydamage = {
        head = damage:calculate(enemy, "head"),
        chest = damage:calculate(enemy, "chest"),
        stomach = damage:calculate(enemy, "stomach")
    }

    for k, v in pairs(enemydamage) do
        if v > enemy:get_prop("m_iHealth") or v > use:damage() then
            local bullet = trace.bullet(localorigin, enemypos[k], lp, enemy)
            if bullet.valid and (client.get_hitgroup_name(bullet.hitgroup) == k) then
                local hitgroup = e_hitscan_groups[string.upper(k)]
                ctx:set_hitscan_group_state(hitgroup, true, false)
                break
            end
        end
    end
end, function () 
    return inter["Multipoint"]:get()
end)

--Interpolation & ping
events:add(e_callbacks.EVENT, function ()
    cvars.cl_interpolate:set_int(inter["Interpolation"].ref:get() and 0 or 1)    
    cvars.sv_maxunlag:set_float(inter["Unlockping"].ref:get() and .4 or .2)
end)

--Side indicators
events:add(e_callbacks.PAINT, function ()
    local font = fonts.get_or_register("Indicators", "Calibri Bold", 24, 670, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC)
    local active_weapon = use.weapon()

    local referencies = {
        [0] = {name = "SAFER", ref = menu.find("aimbot", active_weapon, "target overrides", "safepoint")[2]},
        [1] = {name = "PING", ref = refs.ping},
        [2] = {name = "SLOW", ref = refs.slowmotion},
        [3] = {name = "DUCK", ref = refs.fakeduck},
        [4] = {name = "MD", ref = menu.find("aimbot", active_weapon, "target overrides", "min. damage")[2]},
        [5] = {name = "OS", ref = refs.hideshots},
        [6] = {name = "DT", ref = refs.doubletap},
        [7] = {name = "FS", ref = refs.freestand},

    }; 
    local items = {}


    for i=0, #referencies do 
        local current = referencies[i]

        local current_anim_x = animation.new("xindicators_"..current.name, current.ref:get() and 1 or 0, 12)
        local current_anim_y = animation.new("yindicators_"..current.name, #items, 12)

        if current_anim_x >= 0.5 then 
            table.insert(items, {})
        end
        
        local pos = vec2_t(-50 + 80*current_anim_x, screen.y/1.45 - (current_anim_y)*30)


        local is_special_indicator = (current.name == "DT" or current.name == "OS")
        local charge_condition = (is_special_indicator and exploits.get_charge() > 0 and current_anim_x >= 0.9) or (not is_special_indicator and current_anim_x >= 0.9)
        local current_anim_xx = animation.new("xxindicators_" .. current.name, charge_condition and 1 or 0, 6)
        
        local col = colors["Indicators"].ref:get()

        render.push_alpha_modifier(current_anim_x)
        if is_special_indicator or current.name == "PING" then 
            render.text(font, current.name, pos, (exploits.get_charge() > 0 or current.name == "PING") and color_t(col.r,col.g,col.b) or color_t(255,140,140))
        else 
            render.text(font, current.name, pos, color_t(240,240,240))
        end
        render.pop_alpha_modifier()

        render.push_alpha_modifier(current_anim_xx*current_anim_x)
        render.rect_fade(pos - vec2_t(5, 1), vec2_t((35 + render.get_text_size(font, current.name).x)*current_anim_xx, render.get_text_size(font, current.name).y), color_t(col.r,col.g,col.b,25), color_t(col.r,col.g,col.b,0), true)
        render.pop_alpha_modifier()
    end


end, function () 
    local lp = entity_list.get_local_player()
    
    -- Verificar si el jugador local es válido
    if not lp or not lp:is_valid() or not lp:is_player() or not lp:is_alive() then
        return
    end

    return inter["Indicators"].ref:get()
end)

--Watermark
events:add(e_callbacks.PAINT, function ()
    local font = fonts.get_or_register("Undf", "Arial",  17, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC)

    render.text(font, "undefined", vec2_t(screen.x/2 - render.get_text_size(font, "undefined").x/2, screen.y - 30), colors["Watermark"].ref:get())

end, function () 
    return inter["Watermark"].ref:get()
end)


--Velocity
local velocity = dragsystem.register({drag["Velocity_x"], drag["Velocity_y"]}, render.get_text_size(fonts.get_or_register("Indicators warning", "Arial",  15, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC), "Velocity %100"), "Velocity", function(self)

    local lp = entity_list.get_local_player()
    local font = fonts.get_or_register("Indicators warning", "Arial",  15, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC)
    local value = math.abs(lp:get_prop("m_flVelocityModifier") * 100 + 100 * -1)
    local anim = animation.new("Velocity_indicatros_rect", (value == 0 and menu.is_open()) and 100 or value, 5)
    local rect = (anim > 99.5) and 100 or anim
    local text = string.format("Velocity %i%s", rect, "%")
    local alpha = animation.new("Velocity_indicatros", (value > 0 or menu.is_open()) and 1 or 0, 5)
    local col = colors["Velocity"].ref:get()

        
    self.position.x = (self.position.x ~= drag["Velocity_x"]:get()) and drag["Velocity_x"]:get() or self.position.x
    self.position.y = (self.position.y ~= drag["Velocity_y"]:get()) and drag["Velocity_y"]:get() or self.position.y

    render.push_alpha_modifier(alpha)
    --render.rect_fade(vec2_t(screen.x/2 - render.get_text_size(font, text).x/2*(rect/100), screen.y/4 +render.get_text_size(font, text).y + 3), vec2_t(render.get_text_size(font, text).x*(rect/100), 7), color_t(col.r,col.g,col.b,25), color_t(col.r,col.g,col.b,0), false)
    render.text(font, text, vec2_t(self.position.x, self.position.y), color_t(255,255,255))
    render.rect_filled(vec2_t(self.position.x, self.position.y + render.get_text_size(font, text).y + 3), vec2_t(render.get_text_size(font, text).x*(rect/100), 2), col)
    render.pop_alpha_modifier()
end)
events:add(e_callbacks.PAINT, function () 
    velocity:update()
end, function () 
    local lp = entity_list.get_local_player()
    
    if not lp or not lp:is_valid() or not lp:is_player() or not lp:is_alive() then
        return
    end

    return inter["Velocity"].ref:get()
end)

--Defensive

local defensive = dragsystem.register({drag["Defensive_x"], drag["Defensive_y"]}, render.get_text_size(fonts.get_or_register("Indicators warning", "Arial",  15, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC), "Defensive %100"), "Defensive", function(self)

    local lp = entity_list.get_local_player()
    local font = fonts.get_or_register("Indicators warning", "Arial",  15, 750, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW, e_font_flags.ITALIC)
    local alpha = animation.new("Defensive_indicatros", (builder.defensiveactive or menu.is_open()) and 1 or 0, 5)
    local rect = (alpha*100 > 99.5) and 100 or alpha*100
    local text = string.format("Defensive %i%s", rect, "%")
    local col = colors["Defensive"].ref:get()

    self.position.x = (self.position.x ~= drag["Defensive_x"]:get()) and drag["Defensive_x"]:get() or self.position.x
    self.position.y = (self.position.y ~= drag["Defensive_y"]:get()) and drag["Defensive_y"]:get() or self.position.y

    render.push_alpha_modifier(alpha)
    render.text(font, text, vec2_t(self.position.x, self.position.y), color_t(255,255,255))
    render.rect_filled(vec2_t(self.position.x, self.position.y +render.get_text_size(font, text).y + 3), vec2_t(render.get_text_size(font, text).x*(rect/100), 2), col)
    render.pop_alpha_modifier()
end)
events:add(e_callbacks.PAINT, function ()
    defensive:update()
end, function () 
    local lp = entity_list.get_local_player()
    
    if not lp or not lp:is_valid() or not lp:is_player() or not lp:is_alive() then
        return
    end

    return inter["Defensive"].ref:get()
end)


--Thirdperson fix
events:add(e_callbacks.PAINT, function ()
    cvars.cam_command:set_int(keys["Thirdperson"].ref:get() and 1 or 0)
    cvars.c_mindistance:set_int(inter["Thirdperson"].ref:get())
    cvars.c_maxdistance:set_int(inter["Thirdperson"].ref:get())
    cvars.cam_idealdist:set_int(inter["Thirdperson"].ref:get())

end, function () 
    return inter["Check_thirdperson"].ref:get()
end)

--Thirdperson sv_cheats
events:add(e_callbacks.EVENT, function ()
    cvars.sv_cheats:set_int(1)
    
end, function ()
    return inter["Check_thirdperson"].ref:get()
end)

--Hitmarker
events:add(e_callbacks.WORLD_HITMARKER, function (screen_pos, world_pos, alpha_factor, damage, is_lethal, is_headshot)
    render.push_alpha_modifier(alpha_factor)

    render.rect_filled(vec2_t(screen_pos.x - 5, screen_pos.y - 1), vec2_t(10, 2), colors["Hitmarker"].ref:get())
    render.rect_filled(vec2_t(screen_pos.x - 1, screen_pos.y - 5), vec2_t(2, 10), colors["Hitmarker"].ref:get())

    render.pop_alpha_modifier()
end, function () 
    return inter["Hitmarker"].ref:get()
end)

--Esp fonts
events:add(e_callbacks.PLAYER_ESP, function(ctx)
    ctx:set_font(fonts.get_or_register("Gamesense", "Tahoma", 11, 500, e_font_flags.ANTIALIAS, e_font_flags.DROPSHADOW))
end, function () 
    return inter["Skeet_fonts"].ref:get()
end)

--Toss
events:add(e_callbacks.SETUP_COMMAND, function(cmd)
    local toss = {
        ang_vec = function(ang)
            return vec3_t(math.cos(ang.x * math.pi / 180) * math.cos(ang.y * math.pi / 180), math.cos(ang.x * math.pi / 180) * math.sin(ang.y * math.pi / 180), -math.sin(ang.x * math.pi / 180))
        end,
        target_angles = vec3_t(0, 0, 0)
    }
    
    if refs.nadehelper:get() then
        return
    end

    local lp = entity_list.get_local_player()
    if not lp or not lp:is_player() or not lp:is_alive() then
        return
    end
    if (lp:get_prop("m_MoveType") == 9) then
        return
    end

    local weapon = lp:get_active_weapon()
    if not weapon then
        return
    end

    local data = weapon:get_weapon_data()
    if not data then
        return
    end
    toss.lastangles = engine.get_view_angles()

    if not weapon:get_prop("m_flThrowStrength") then
        return
    end

    local ang_throw = vec3_t(cmd.viewangles.x, toss.lastangles.y, 0)
    ang_throw.x = ang_throw.x - (90 - math.abs(ang_throw.x)) * 10 / 90
    ang_throw = toss.ang_vec(ang_throw)


    local throw_strength = math.clamp(weapon:get_prop("m_flThrowStrength"), 0, 1)
    local fl_velocity = math.clamp(data.throw_velocity * 0.9, 15, 750)
    fl_velocity = fl_velocity * (throw_strength * 0.7 + 0.3)
    fl_velocity = vec3_t(fl_velocity, fl_velocity, fl_velocity)


    local localplayer_velocity = lp:get_prop('m_vecVelocity')
    local vec_throw = (ang_throw * fl_velocity + localplayer_velocity * vec3_t(1.45, 1.45, 1.45))
    vec_throw = vec_throw:to_angle()
    local yaw_difference = toss.lastangles.y - vec_throw.y
    while yaw_difference > 180 do
        yaw_difference = yaw_difference - 360
    end
    while yaw_difference < -180 do
        yaw_difference = yaw_difference + 360
    end
    local pitch_difference = toss.lastangles.x - vec_throw.x - 10
    while pitch_difference > 90 do
        pitch_difference = pitch_difference - 45
    end
    while pitch_difference < -90 do
        pitch_difference = pitch_difference + 45
    end

    toss.target_angles.y = toss.lastangles.y + yaw_difference
    toss.target_angles.x = math.clamp(toss.lastangles.x + pitch_difference, -89, 89)

    cmd.viewangles.y = toss.target_angles.y
    if inter["Toss"].ref:get() == 3 then
        local flags = lp:get_prop("m_fFlags")
        local airborne = bit.band(flags, bit.lshift(1, 0)) == 0
        if airborne then
            cmd.viewangles.x = toss.target_angles.x
        end
    elseif inter["Toss"].ref:get() == 4 then
        cmd.viewangles.x = toss.target_angles.x

    end
end, function () 
    return inter["Toss"].ref:get() ~= 1
end)

--Antiafk
local roundstart = {
    afkdirection = 1,
    afk_valid = false,
    afk = 0,
}
events:add(e_callbacks.SETUP_COMMAND, function(cmd)
    if roundstart.afk_valid == true then
        roundstart.afk = roundstart.afk + 1
        if roundstart.afk > 128 then
            roundstart.afk = 0
            roundstart.afkdirection = not roundstart.afkdirection
        end
        -- client.log_screen(builder.afk)
    end

    if cmd:has_button(e_cmd_buttons.MOVELEFT) then
        roundstart.afk_valid = false
    end
    if cmd:has_button(e_cmd_buttons.MOVERIGHT) then
        roundstart.afk_valid = false
    end
    if cmd:has_button(e_cmd_buttons.FORWARD) then
        roundstart.afk_valid = false
    end
    if cmd:has_button(e_cmd_buttons.BACK) then
        roundstart.afk_valid = false
    end

    if roundstart.afk < 8 and roundstart.afk_valid then
        -- client.log_screen("moving")
        cmd.move.x = 450 * (roundstart.afkdirection and 1 or -1)
    end
end, function () 
    return inter["Antiafk"].ref:get()
end)
events:add(e_callbacks.EVENT, function(event)
    if event.name == "round_start" then
        roundstart.afk_valid = true
    end
end, function () 
    return inter["Antiafk"].ref:get()
end)

--Clantag 
local last_tick = 0
events:add(e_callbacks.PAINT, function()
    local tag = {"", "", "u", "u", "un", "un", "und", "und", "unde", "unde", "undef", "undef", "undefi", "undefi", "undefin", "undefin", "undefine", "undefine", "undefined", "undefined", "undefined","undefined", "undefined", "undefined", "undefined","undefined", "undefine", "undefine", "undefin", "undefin", "undefi", "undefi", "undef", "undef", "unde", "unde", "und", "und", "un", "un", "u", "u"}

    if globals.real_time() - last_tick >= 0.15 then
        local server_time = math.floor(globals.cur_time() / 0.296875 + 6.60925 - 0.07 - engine.get_latency(e_latency_flows.OUTGOING) - engine.get_latency(e_latency_flows.INCOMING))
        client.set_clantag(tag[server_time % #tag+1] .. "                                   ")
        last_tick = globals.real_time()
    end
end, function() 
    if globals.real_time() - last_tick >= 2 then
        client.set_clantag("")
        last_tick = globals.real_time()
    end
    return inter["Clantag"]:get()
end)

--Trashtalk
events:add(e_callbacks.EVENT, function(event)
    local phrases = {
        "undf говорит 1",
        "Ты забыл включить undf, бот, или ты такой тупой по жизни?", -- ¿Olvidaste activar undf o eres así de estúpido siempre?
        "undf даже не маскирует вонь твоей мамаши.", -- undf ni siquiera puede cubrir el hedor de tu madre.
        "Верни свои жалкие деньги, undf на таких бедняков, как ты, не рассчитан.", -- Devuelve tu miserable dinero, undf no es para pobres como tú.
        "С твоими навыками даже undf не вытащит тебя из помойки.", -- Con tus habilidades, ni siquiera undf puede sacarte del basurero.
        "undf не спасает тупых, таких как ты.", -- undf no salva a idiotas como tú.
        "Легко? С undf было бы унизительно просто.", -- ¿Fácil? Con undf sería insultantemente fácil.
        "Ты продал этот хедшот? Наверное, undf тебе не одобрил.", -- ¿Vendiste ese headshot? Seguramente undf te lo negó.
        "Продли undf, а не свою никчёмность.", -- Renueva undf, no tu inutilidad.
        "undf даже твою мамашу не спасёт, но она умоляет о нём каждую ночь.", -- undf ni siquiera salvaría a tu madre, pero lo ruega cada noche.
        "Единственное, что ниже твоего k/d, это твоё жалкое понимание undf.", -- Lo único más bajo que tu k/d es tu patético entendimiento de undf.
        "Твоя меткость хуже, чем шанс undf спасти твою никчёмность.", -- Tu puntería es peor que las posibilidades de que undf salve tu inutilidad.
        "Поиграй с undf, хотя бы библиотечный Wi-Fi перестанет лагать.", -- Juega con undf, al menos el Wi-Fi de la biblioteca dejará de laggear.
        "Единственное, что менее надёжно, чем ты, это undf, если он у тебя был.", -- Lo único menos confiable que tú es undf, si es que lo tuviste.
        "undf считает тебя настолько тупым, что удалился из твоей системы.", -- undf piensa que eres tan estúpido que se desinstaló solo.
        "С undf ты хотя бы смог бы умирать красиво, а не позорно.", -- Con undf al menos podrías morir con estilo y no con vergüenza.
        "Я бы прыгнул с твоего эго на твоё понимание undf, но сдохну от стыда в полёте.", -- Saltaría de tu ego a tu entendimiento de undf, pero moriría de vergüenza en el aire.
        "Ты бы хоть раз прочитал, как использовать undf, тупица.", -- Al menos una vez lee cómo usar undf, imbécil.
        "Отдай undf своему стулу, у него больше шансов на победу.", -- Dale undf a tu silla, tiene más posibilidades de ganar que tú.
        "37 триллионов клеток в твоём теле и ни одна не знает, как пользоваться undf.", -- 37 trillones de células en tu cuerpo y ninguna sabe usar undf.
        "Я бы назвал тебя инструментом, но undf даже в руках идиота полезнее.", -- Te llamaría herramienta, pero undf es más útil incluso en manos de un idiota.
    }

    if event.name == 'player_death' then
        local lp = entity_list.get_local_player()
        if lp then
            local attacker = entity_list.get_player_from_userid(event.attacker)
            if attacker then
                if attacker == lp then

                    client.delay_call(function()
                        engine.execute_cmd("say " .. phrases[math.random(1, #phrases)])
                    end, 1)


                end
            end
        end
        
        end
end, function () 
    return inter["Trashtalk"].ref:get()
end)

--filesystem.create_directory("./undf", "")

