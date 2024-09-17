-- name: Speedrun Splits [Lemon Bros. 2024 Edition]
-- description: Speedrun timer with built-in splits.

-- Sync Globals --

gGlobalSyncTable.runInProgress = false
gGlobalSyncTable.splitCategory = {}
gGlobalSyncTable.currentSplits = {}
gGlobalSyncTable.pbSplits = {}
gGlobalSyncTable.pbSplitsPresent = false
gGlobalSyncTable.speedrunTimer = 0
gGlobalSyncTable.startTimer = 0
gGlobalSyncTable.newPb = false


for i = 0, (MAX_PLAYERS - 1) do
    gPlayerSyncTable[i].resetPosition = false
end

-- Globals --

local showSpeedrunTimer = true
local speedrunTimer = 0
local startTimer = 0
local starCountCategory = 5

-- Constants --

local KEY_DELIMETER = "_"
local VALUE_DELIMETER = "_"
local PACK_SIZE = 32

local VANILLA_EXIT_LEVEL = "Vanilla"
local NON_STOP = "Non-Stop"

local PLAYER_COUNT_1P = "1P"
local PLAYER_COUNT_2P = "2P"
local PLAYER_COUNT_3P = "3P"
local PLAYER_COUNT_4P = "4P"
local PLAYER_COUNT_5P_9P = "5P-9P"
local PLAYER_COUNT_10P_16P = "10P-16P"

local COUNT_TO_CATEGORY = {
    PLAYER_COUNT_1P,
    PLAYER_COUNT_2P,
    PLAYER_COUNT_3P,
    PLAYER_COUNT_4P,
    PLAYER_COUNT_5P_9P,
    PLAYER_COUNT_5P_9P,
    PLAYER_COUNT_5P_9P,
    PLAYER_COUNT_5P_9P,
    PLAYER_COUNT_5P_9P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
    PLAYER_COUNT_10P_16P,
}

local STARCOUNTS = {
    0,
    1,
    16,
    70,
    120
}

-- Functions --

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

function change_star_category(inc)
    if (inc) then
        if (starCountCategory ~= #STARCOUNTS) then
            starCountCategory = starCountCategory + 1
        else
            starCountCategory = 1
        end
    else
        if starCountCategory ~= 1 then
            starCountCategory = starCountCategory - 1
        else
            starCountCategory = #STARCOUNTS
        end
    end
end

function update_splits_category()
    if gServerSettings.stayInLevelAfterStar == 0 then
        gGlobalSyncTable.splitCategory.nonStop = VANILLA_EXIT_LEVEL
    elseif gServerSettings.stayInLevelAfterStar == 2 then
        gGlobalSyncTable.splitCategory.nonStop = NON_STOP
    else
        gGlobalSyncTable.splitCategory.valid = false
        return
    end

    local playerCount = 0
    for i = 0, (MAX_PLAYERS - 1) do
        if gNetworkPlayers[i].connected then
            playerCount = playerCount + 1
        end
    end

    local countCategory = COUNT_TO_CATEGORY[playerCount]
    if countCategory then
        gGlobalSyncTable.splitCategory.playerCount = countCategory
    else
        gGlobalSyncTable.splitCategory.valid = false
        return
    end

    gGlobalSyncTable.splitCategory.starCount = STARCOUNTS[starCountCategory]
    gGlobalSyncTable.splitCategory.valid = true

    -- Now that the split category is set and configured, load the appropriate splits, if present.
    local saveSplits = load_splits()
    if saveSplits then
        for i = 1, gGlobalSyncTable.splitCategory.starCount + 1 do
            gGlobalSyncTable.pbSplits[i] = saveSplits[i]
        end

        gGlobalSyncTable.pbSplitsPresent = true
    else
        gGlobalSyncTable.pbSplitsPresent = false
    end
end

function get_category_string()
    return gGlobalSyncTable.splitCategory.playerCount ..
        gGlobalSyncTable.splitCategory.nonStop ..
        gGlobalSyncTable.splitCategory.starCount
end

function pack_splits(splits)
    local packed_splits = {}
    local isplits = {}

    local count = 0
    for i, _ in ipairs(splits) do
        isplits[i] = math.floor(splits[i])
        count = count + 1
    end

    for i = 1, count, PACK_SIZE do
        local last = min(i + PACK_SIZE - 1, count)
        table.insert(packed_splits, table.concat(isplits, VALUE_DELIMETER, i, last))
    end

    return packed_splits
end

function unpack_splits(packed_splits)
    local splits = {}
    for i, _ in ipairs(packed_splits) do
        for split in string.gmatch(packed_splits[i], "%d+") do
            table.insert(splits, tonumber(split))
        end
    end

    return splits
end

function load_splits()
    local category = get_category_string()
    local numSplits = gGlobalSyncTable.splitCategory.starCount + 1

    local packedSplits = {}
    local numEntries = math.ceil(numSplits / PACK_SIZE)

    for i = 1, numEntries do
        local packKey = category .. KEY_DELIMETER .. i
        local pack = mod_storage_load(packKey)
        if not pack then
            return nil
        end

        table.insert(packedSplits, pack)
    end

    local splits = unpack_splits(packedSplits)

    -- verify the correct number of splits are here.
    if #splits ~= numSplits then
        print("Invalid number of splits present (" ..
            #splits .. " != " .. numSplits .. ")")

        return nil
    end

    return splits
end

function save_splits(splits)
    local category = get_category_string()
    local numSplits = gGlobalSyncTable.splitCategory.starCount + 1
    local numEntries = math.ceil(numSplits / PACK_SIZE)

    if not splits[numSplits] then
        return false
    end

    -- Update any missing splits.
    local lastSplit = splits[numSplits]
    for i = numSplits, 1, -1 do
        if not splits[i] then
            print("Split for star # " .. i .. "is not present. Using previous split")
            splits[i] = lastSplit
        end

        lastSplit = splits[i]
    end

    local packedSplits = pack_splits(splits)

    -- verify the correct number of packed splits are here.
    if #packedSplits ~= numEntries then
        print("Invalid number of entries present (" ..
            #packedSplits .. " != " .. numEntries .. ")")
        return false;
    end

    for i = 1, numEntries do
        local packKey = category .. KEY_DELIMETER .. i
        if not mod_storage_save(packKey, packedSplits[i]) then
            print("Failed to store value. Failure from executable, not script")
            print("Key = " .. packKey)
            print("Splits = " .. packedSplits[i])
        end
    end

    return true
end

function hud_top_render()
    if gGlobalSyncTable.runInProgress then
        return
    end

    local text
    local subtext
    local hasPB = false
    if gGlobalSyncTable.splitCategory.valid then
        text = "< Speedrun Category:" ..
            " " .. gGlobalSyncTable.splitCategory.playerCount ..
            " " .. gGlobalSyncTable.splitCategory.nonStop ..
            " " .. gGlobalSyncTable.splitCategory.starCount ..
            " Star >"

        if gGlobalSyncTable.pbSplitsPresent then
            subtext = "Current PB = " ..
                frames_to_time_string(gGlobalSyncTable.pbSplits[gGlobalSyncTable.splitCategory.starCount + 1])

            hasPB = true
        else
            subtext = "No PB Recorded"
        end
    else
        text = "Invalid Speedrun Category"
        subtext = nil
    end

    -- Print Text at Top of Screen

    local scale = 0.5

    local width = djui_hud_measure_text(text) * scale;
    local height = 32 * scale;

    local x = (djui_hud_get_screen_width() - width) / 2
    local y = 0

    djui_hud_set_color(0, 0, 0, 128)
    djui_hud_render_rect(x, y, width, height)

    djui_hud_set_color(255, 255, 255, 255)
    djui_hud_print_text(text, x, y, scale)

    if (subtext) then
        width = djui_hud_measure_text(subtext) * scale;
        x = (djui_hud_get_screen_width() - width) / 2
        y = y + height

        if hasPB then
            djui_hud_set_color(0, 128, 0, 128)
        else
            djui_hud_set_color(0, 0, 128, 128)
        end

        djui_hud_render_rect(x, y, width, height)

        djui_hud_set_color(255, 255, 255, 255)
        djui_hud_print_text(subtext, x, y, scale)
    end
end

function hud_center_render()
    if gGlobalSyncTable.startTimer <= 0 then
        return
    end

    -- TODO: Need to add countdown render and settings render.
    print(gGlobalSyncTable.splitCategory.playerCount .. " " .. 
          gGlobalSyncTable.splitCategory.nonStop .. " " .. 
          gGlobalSyncTable.splitCategory.starCount)

    print("Player Interaction: " .. gServerSettings.playerInteractions) -- Needs to be Solid
    print("Knockback Strength: " .. gServerSettings.playerKnockbackStrength) -- Needs to be Normal
    print("Bouncy Level Bounds: " .. gServerSettings.bouncyLevelBounds) -- Needs to be Off
    print("Skip Intro Cutscene: " .. gServerSettings.skipIntro) -- can be Off or On
    print("Pause Anywhere: " .. gServerSettings.pauseAnywhere) -- can be Off or On
    print("Bubble on death: " .. gServerSettings.bubbleDeath) -- can be Off or On 
    print("Nametags: " .. gServerSettings.nametags) -- can be Off or On

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

function hud_bottom_render()
    if not showSpeedrunTimer then return end

    local starindex = gMarioStates[0].numStars

    local timeStr = frames_to_time_string(gGlobalSyncTable.speedrunTimer)
    local diffStr
    local difftime

    if gGlobalSyncTable.pbSplitsPresent then
        diffTime = gGlobalSyncTable.speedrunTimer - gGlobalSyncTable.pbSplits[starindex + 1]
        if diffTime > 0 then
            diffStr = string.format(" (+%s)", frames_to_time_string(diffTime))
        else
            diffStr = string.format(" (-%s)", frames_to_time_string(diffTime * -1))
        end
    else
        diffTime = 0
        diffStr = ""
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

    hud_top_render()
    hud_center_render()
    hud_bottom_render()
end

--- @param m MarioState?
function on_player_connect_disconnect(m)
    if network_is_server() and not gGlobalSyncTable.runInProgress then
        update_splits_category()
    end
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

    if get_id_from_behavior(o.behavior) == id_bhvGrandStar and
        starcount == gGlobalSyncTable.splitCategory.starCount then
        gGlobalSyncTable.currentSplits[starcount + 1] = gGlobalSyncTable.speedrunTimer
        gGlobalSyncTable.runInProgress = false

        if not gGlobalSyncTable.pbSplitsPresent or
            gGlobalSyncTable.pbSplits[starcount + 1] > gGlobalSyncTable.currentSplits[starcount + 1] then
            gGlobalSyncTable.newPb = true
        end
    end
end

function update()
    if network_is_server() then
        if gGlobalSyncTable.runInProgress then
            if startTimer > 0 then
                startTimer = startTimer - 1
                gGlobalSyncTable.startTimer = startTimer / 30
                gGlobalSyncTable.speedrunTimer = 0
                speedrunTimer = 0
            else
                speedrunTimer = speedrunTimer + 1
                gGlobalSyncTable.speedrunTimer = speedrunTimer
            end
        end

        if gGlobalSyncTable.newPb then
            gGlobalSyncTable.newPb = false
            local result = save_splits(gGlobalSyncTable.currentSplits)
            if not result then
                error("Save file not populated")
            end

            update_splits_category()
        end
    end
end

--- @param m MarioState
function mario_update(m)
    if m.playerIndex ~= 0 then return end

    if network_is_server() then
        if (m.controller.buttonPressed & X_BUTTON) ~= 0 then
            -- Start Run --

            gGlobalSyncTable.runInProgress = true

            startTimer = 4 * 30
            speedrunTimer = 0

            for i, _ in ipairs(gGlobalSyncTable.currentSplits) do
                gGlobalSyncTable.currentSplits[i] = nil
            end

            for i = 0, (MAX_PLAYERS - 1) do
                gPlayerSyncTable[i].resetPosition = true
            end
        end

        if not gGlobalSyncTable.runInProgress then
            if (m.controller.buttonPressed & R_JPAD) ~= 0 then
                change_star_category(true)
                update_splits_category()
            elseif (m.controller.buttonPressed & L_JPAD) ~= 0 then
                change_star_category(false)
                update_splits_category()
            end
        end
    end

    if gPlayerSyncTable[0].resetPosition then
        gPlayerSyncTable[0].resetPosition = false
        warp_to_level(gLevelValues.entryLevel, 1, 0)
        save_file_erase_current_backup_save()
        save_file_erase(get_current_save_file_num() - 1)
        update_all_mario_stars()
    end

    if gGlobalSyncTable.startTimer > 0 then
        m.freeze = true
        m.faceAngle.y = m.intendedYaw
        m.health = 0x880
        m.numLives = 4
    end
end

-- Hooks --

hook_event(HOOK_ON_HUD_RENDER, on_render)
hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connect_disconnect)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_connect_disconnect)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_UPDATE, update)
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

hook_chat_command('print-splits', '[current|pb|currentpkd|pbpkd] Prints the current or pb splits', function(msg)
    local category = get_category_string()

    local splits

    if msg == 'current' then
        splits = unpack_splits(pack_splits(gGlobalSyncTable.currentSplits))
    elseif msg == 'pb' then
        splits = unpack_splits(pack_splits(gGlobalSyncTable.pbSplits))
    elseif msg == 'currentpkd' then
        splits = pack_splits(gGlobalSyncTable.currentSplits)
    elseif msg == 'pbpkd' then
        splits = pack_splits(gGlobalSyncTable.pbSplits)
    else
        djui_chat_message_create('Please enter a valid input')
        return true
    end

    local present = false

    for i, _ in ipairs(splits) do
        local key = category .. KEY_DELIMETER .. i
        local line = key .. '=' .. splits[i]
        djui_chat_message_create(line)
        print(line)
        present = true
    end

    if not present then
        djui_chat_message_create("No splits available")
        print("No splits available")
    end

    return true
end)

-- Init --
on_player_connect_disconnect(nil)
