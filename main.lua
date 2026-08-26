local group = ui.find("Aimbot", "Anti Aim", "Fake Lag")
local fast_switch = group:switch("\aADDA51FFFast Switch", false)

local csgo_weapons = require("neverlose/csgo_weapons")
local refs = { }
local vars = { }

refs.weapon_actions = ui.find("Miscellaneous", "Main", "Other", "Weapon Actions")
refs.fake_duck = ui.find("Aimbot", "Anti Aim", "Misc", "Fake Duck")
vars.switch_tick = 0
vars.weapon_switched = 0
vars.weaponselect = false
vars.air_ticks = 0
vars.shot_tick = 0

function in_air(player)
    if player == nil then return end
    local flags = player.m_fFlags
    if bit.band(flags, 1) == 0 then
        return true
    end
    return false
end

local angle3d_struct = ffi.typeof("struct { float pitch; float yaw; float roll; }")
local vec_struct = ffi.typeof("struct { float x; float y; float z; }")

local cUserCmd =
    ffi.typeof(
    [[
    struct
    {
        uintptr_t vfptr;
        int command_number;
        int tick_count;
        $ viewangles;
        $ aimdirection;
        float forwardmove;
        float sidemove;
        float upmove;
        int buttons;
        uint8_t impulse;
        int weaponselect;
        int weaponsubtype;
        int random_seed;
        short mousedx;
        short mousedy;
        bool hasbeenpredicted;
        $ headangles;
        $ headoffset;
        bool send_packet; 
    }
    ]],
    angle3d_struct,
    vec_struct,
    angle3d_struct,
    vec_struct
)

local client_sig = utils.opcode_scan("client.dll", "B9 ? ? ? ? 8B 40 38 FF D0 84 C0 0F 85") or error("client.dll!:input not found.")
local get_cUserCmd = ffi.typeof("$* (__thiscall*)(uintptr_t ecx, int nSlot, int sequence_number)", cUserCmd)
local input_vtbl = ffi.typeof([[struct{uintptr_t padding[8];$ GetUserCmd;}]],get_cUserCmd)
local input = ffi.typeof([[struct{$* vfptr;}*]], input_vtbl)
local get_input = ffi.cast(input,ffi.cast("uintptr_t**",tonumber(ffi.cast("uintptr_t", client_sig)) + 1)[0])

local function apply_tickbase(cmd, ticks_to_shift)
    local usrcmd = get_input.vfptr.GetUserCmd(ffi.cast("uintptr_t", get_input), 0, cmd.command_number)

    if cmd.choked_commands == 0 then return end

    cmd.no_choke = true
    cmd.send_packet = true
    usrcmd.send_packet = true
    usrcmd.tick_count = globals.tickcount + ticks_to_shift
    return
end

events.aim_fire:set(function()
    vars.shot_tick = globals.tickcount
end)

events.createmove:set(function(cmd)
    local me = entity.get_local_player()

    if me == nil then
        return
    end

    if not fast_switch:get() then
        return
    end

    if (globals.tickcount - vars.switch_tick) < 0 then
        vars.switch_tick = 0
    end

    if (globals.tickcount - vars.air_ticks) < 0 then
        vars.air_ticks = 0
    end

    if in_air(me) then
        vars.air_ticks = globals.tickcount
    end

    if (globals.tickcount - vars.air_ticks) < 5 then
        return
    end

    if refs.fake_duck:get() then
        return
    end

    refs.weapon_actions:override("Auto Pistols")

    local client_delay_ticks = math.floor( utils.net_channel().avg_latency[1] / globals.tickinterval ) + 1
    local disabler = ((globals.tickcount - vars.shot_tick) <= client_delay_ticks)
    local active_weapon = me:get_player_weapon()

    if active_weapon == nil then
        return
    end

    local LastShot = active_weapon.m_fLastShotTime
    local NextAttack = me.m_flNextAttack

    if LastShot == nil or NextAttack == nil then
        return
    end

    local in_attack = globals.curtime - LastShot <= 0.35 
    local in_swap = globals.curtime - NextAttack <= -0.50

    if cmd.weaponselect ~= 0 and (globals.tickcount - vars.switch_tick) > 20 then
        cmd.send_packet = true
        vars.weapon_switched = cmd.weaponselect
        local weapon_idx = active_weapon.m_iItemDefinitionIndex

        if weapon_idx == nil then
            return
        end

        local weapon = csgo_weapons[weapon_idx]

        if weapon == nil then
            return
        end

        if weapon.type == "knife" or weapon.type == "grenade" or weapon.type == "c4" then
            return
        end

        vars.switch_tick = globals.tickcount
        vars.weaponselect = true
    end

    local weapon_idx = active_weapon.m_iItemDefinitionIndex

    if weapon_idx == nil then
        return
    end

    local weapon = csgo_weapons[weapon_idx]

    if weapon == nil then
        return
    end

    if in_swap then
        cmd.force_defensive = globals.tickcount%16 == 1 and true or false
    end

    if disabler then 
        cmd.force_defensive = false
    end

    if weapon.type == "knife" or weapon.type == "grenade" or weapon.type == "c4" then
        vars.switch_tick = 0
        return
    end

    if vars.weaponselect and cmd.send_packet and not in_attack then
        local nextcmdnummber = globals.last_outgoing_command + globals.choked_commands + 1
        apply_tickbase(cmd, nextcmdnummber, true)
        vars.weaponselect = false
    end

    --[[if (globals.tickcount - vars.switch_tick) > 0 and (globals.tickcount - vars.switch_tick) < 25 and active_weapon ~= vars.weapon_switched and not in_attack then
        if weapon.type == "taser" then
            utils.console_exec('slot11')
        elseif weapon.type == "pistol" then
            utils.console_exec('slot2')
        else
            utils.console_exec('slot1')
        end
    end]]
end)

fast_switch:set_callback(function()
    refs.weapon_actions:set(refs.weapon_actions:get())
end)

events.shutdown:set(function()
    refs.weapon_actions:set(refs.weapon_actions:get())
end)
