-- name: Speedrun Splits v3.2
-- description: The Lemon Bros. are BACK!

gGlobalSyncTable.startTimer = 0
gGlobalSyncTable.speedrunTimer = 0
gGlobalSyncTable.diffTime = 0
gGlobalSyncTable.beatGame = true
gGlobalSyncTable.currentSplits = {}
gGlobalSyncTable.lastSplits = {}
gGlobalSyncTable.newPb = false
gGlobalSyncTable.lastSplitsEnabled = false
gGlobalSyncTable.numPbSplits = 0


local startTimer = 4 * 30
local speedrunTimer = 0
local showSpeedrunTimer = true

--- @param m MarioState
function mario_update(m)
    if m.playerIndex ~= 0 then return end

    if (m.controller.buttonPressed & X_BUTTON) ~= 0 and network_is_server() then
        startTimer = 4 * 30
        gGlobalSyncTable.beatGame = false

        warp_to_level(gLevelValues.entryLevel, 1, 0)
    end

    if gGlobalSyncTable.startTimer > 0 then
        m.freeze = true

        m.faceAngle.y = m.intendedYaw
        m.health = 0x880
    end
end

function update()
    if network_is_server() then
        if startTimer > 0 and not gGlobalSyncTable.beatGame then
            startTimer = startTimer - 1
            gGlobalSyncTable.startTimer = startTimer / 30
            gGlobalSyncTable.speedrunTimer = 0
            speedrunTimer = 0
        else
            if not gGlobalSyncTable.beatGame then
                speedrunTimer = speedrunTimer + 1
                gGlobalSyncTable.speedrunTimer = speedrunTimer
            end
        end

        if gGlobalSyncTable.newPb then
            gGlobalSyncTable.newPb = false
            for i = 1, gGlobalSyncTable.numPbSplits, 1
            do
                mod_storage_save(tostring(i), tostring(gGlobalSyncTable.currentSplits[i]))
            end
        end
    end
end

function hud_center_render()
    if gGlobalSyncTable.startTimer <= 0 then
        return
    end

    -- set text
    local text = tostring(math.floor(gGlobalSyncTable.startTimer))

    -- set scale
    local scale = 1

    -- get width of screen and text
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local width = djui_hud_measure_text(text) * scale
    local height = 32 * scale

    local x = (screenWidth - width) / 2.0
    local y = (screenHeight - height) / 2.0

    -- render
    djui_hud_set_color(0, 0, 0, 128)
    djui_hud_render_rect(x - 6 * scale, y, width + 12 * scale, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(text, x, y, scale)
end

function frames_to_time_string(frames)
    local Hours = math.floor(frames / 30 / 60 / 60)
    local Minutes = math.floor(frames / 30 / 60 % 60)
    local Seconds = math.floor(frames / 30) % 60
    local DeciSeconds = math.floor(frames / 3 % 10)

    -- set text

    if Hours > 0 then
        return string.format("%d:%02d:%02d.%d", Hours, Minutes, Seconds, DeciSeconds)
    elseif Minutes > 0 then
        return string.format("%d:%02d.%d", Minutes, Seconds, DeciSeconds)
    else
        return string.format("%d.%d", Seconds, DeciSeconds)
    end
end

function hud_bottom_render()
    if not showSpeedrunTimer then return end

    local starindex = gMarioStates[0].numStars

    local timeStr = frames_to_time_string(gGlobalSyncTable.speedrunTimer)
    local diffStr
    local difftime

    if gGlobalSyncTable.lastSplitsEnabled then
        diffTime = gGlobalSyncTable.speedrunTimer - gGlobalSyncTable.lastSplits[starindex + 1]
    else
        difftime = 0
    end

    if diffTime > 0 then
        diffStr = string.format(" (+%s)", frames_to_time_string(diffTime))
    else
        diffStr = string.format(" (-%s)", frames_to_time_string(diffTime * -1))
    end

    -- set scale
    local scale = 0.50

    -- get width of screen and text
    local screenWidth = djui_hud_get_screen_width()
    local screenHeight = djui_hud_get_screen_height()
    local width = djui_hud_measure_text(timeStr) * scale + djui_hud_measure_text(diffStr) * scale

    local x = (screenWidth - width) / 2.0
    local y = screenHeight - 16

    -- render


    djui_hud_set_color(0, 0, 0, 128)
    djui_hud_render_rect(x - 6, y, width + 12, 16)
    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(timeStr, x, y, scale)

    x = x + (djui_hud_measure_text(timeStr) * scale)

    if diffTime > 0 then
        djui_hud_set_color(255, 82, 82, 255)
    else
        djui_hud_set_color(135, 255, 92, 255)
    end

    djui_hud_print_text(diffStr, x, y, scale)
end

function on_render()
    djui_hud_set_font(FONT_NORMAL)
    djui_hud_set_resolution(RESOLUTION_N64)

    hud_center_render()
    hud_bottom_render()
end

---@param m MarioState
---@param o Object
---@param intee InteractionType
---@param interacted any
function on_interact(m, o, intee, interacted)
    local starcount = m.numStars
    if (intee == INTERACT_STAR_OR_KEY) and
        (get_id_from_behavior(o.behavior) ~= id_bhvBowserKey) and
        (get_id_from_behavior(o.behavior) ~= id_bhvGrandStar) then
        gGlobalSyncTable.currentSplits[starcount] = gGlobalSyncTable.speedrunTimer
    end

    if get_id_from_behavior(o.behavior) == id_bhvGrandStar then
        gGlobalSyncTable.beatGame = true
        gGlobalSyncTable.currentSplits[starcount + 1] = gGlobalSyncTable.speedrunTimer
        if gGlobalSyncTable.lastSplits[starcount + 1] > gGlobalSyncTable.currentSplits[starcount + 1] then
            gGlobalSyncTable.newPb = true
            gGlobalSyncTable.numPbSplits = starcount + 1
        end
    end
end

hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_UPDATE, update)
hook_event(HOOK_ON_HUD_RENDER, on_render)
hook_event(HOOK_ON_INTERACT, on_interact)

hook_chat_command('speedrun-timer', '[on|off]Shows the speedrun timer', function(msg)
    if msg == 'on' then
        showSpeedrunTimer = true
        djui_chat_message_create('The Speedrun Timer is now Enabled')
    elseif msg == 'off' then
        showSpeedrunTimer = false
        djui_chat_message_create('The Speedrun Timer is now Disabled')
    else
        djui_chat_message_create('Please enter a valid input')
    end

    return true
end)

function populate()
    if network_is_server() then
        for i = 1, 121, 1
        do
            gGlobalSyncTable.lastSplits[i] = tonumber(mod_storage_load(tostring(i)))
            gGlobalSyncTable.lastSplitsEnabled = true
        end
    end
end

populate()
