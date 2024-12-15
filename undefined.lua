require("undf"); local events = bettercall:new(); cvars.sv_cheats:set_int(1)



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
            dragsystem.on_config_load()
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
            dragsystem.on_config_load()
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
    ["Defensive"] = groups["Indicators"]:color_picker(inter["Defensive"], "Indicator accent", refs.accentcol:get()),
    ["Velocity"] = groups["Indicators"]:color_picker(inter["Velocity"], "Indicator accent", refs.accentcol:get()),

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

