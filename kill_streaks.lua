local STREAKS = {
    [1] = { name = 'First Blood',  sound_path = 'streaks/first_blood.wav', image_path = 'streaks/first_blood.png', duration = 1.489 },
    [2] = { name = 'Double Kill',  sound_path = 'streaks/double_kill.wav', image_path = 'streaks/double_kill.png', duration = 1.698 },
    [3] = { name = 'Triple Kill',  sound_path = 'streaks/triple_kill.wav', image_path = 'streaks/triple_kill.png', duration = 1.672 },
    [4] = { name = 'Quadra Kill',  sound_path = 'streaks/quadra_kill.wav', image_path = 'streaks/dominating.png',  duration = 1.724 },
    [5] = { name = 'Penta Kill',   sound_path = 'streaks/penta_kill.wav',  image_path = 'streaks/rampage.png',     duration = 1.620 },
}

local MAX_STREAK = 5

-- Картинки грузим один раз с этим размером (определяет соотношение сторон).
-- 1280x512 = 2.5:1, совпадает с банерами First Blood / Rampage и т.д.
local IMG_LOAD_SIZE = vector(1280, 512)
local IMG_ASPECT    = 1280 / 512

local FADE_IN   = 0.15
local FADE_OUT  = 0.30
local POP_TIME  = 0.20
local POP_START = 1.10

local menu     = ui.create('Kill Streaks')
local mi_on    = menu:switch('Включить стрики', true)
local mi_team  = menu:switch('Учитывать тиммейтов', false)
local mi_vol      = menu:slider('Громкость', 0, 200, 50, 1, '%')
local mi_img_on   = menu:switch('Картинки стриков', true)
local mi_img_size = menu:slider('Размер картинок', 50, 200, 100, 1, '%')
local mi_rs_on    = menu:switch('Авто-ресет КД', false)

local kills = 0

local img_cache = {}
local function get_image(idx)
    local data = STREAKS[idx]
    if not data or not data.image_path then return nil end
    local cached = img_cache[idx]
    if cached == false then return nil end
    if cached then return cached end
    local ok, img = pcall(render.load_image_from_file, data.image_path, IMG_LOAD_SIZE)
    if ok and img then
        img_cache[idx] = img
        return img
    end
    img_cache[idx] = false
    return nil
end

local cur_img = { idx = 0, start = 0, dur = 0 }

local function play_streak(streak)
    local idx  = math.min(streak, MAX_STREAK)
    local data = STREAKS[idx]
    if not data then return end

    if mi_img_on:get() then
        cur_img.idx   = idx
        cur_img.start = globals.realtime
        cur_img.dur   = data.duration or 1.5
    end

    local vol = mi_vol:get() / 50
    if vol <= 0 then return end
    if vol > 4 then vol = 4 end

    local path = data.sound_path
    local full = math.floor(vol)
    local rest = vol - full
    for _ = 1, full do
        utils.console_exec(('playvol %s 1'):format(path))
    end
    if rest > 0.001 then
        utils.console_exec(('playvol %s %.3f'):format(path, rest))
    end
end

local last_rs_at = 0
local rs_pending = false
local function check_auto_rs()
    if not mi_rs_on:get() or rs_pending then return end
    local now = common.get_timestamp() / 1000
    if now - last_rs_at < 3 then return end
    rs_pending = true
    utils.execute_after(0.3, function()
        rs_pending = false
        local me = entity.get_local_player()
        if not me then return end
        local pr  = entity.get_player_resource()
        local idx = me:get_index()
        local k = (pr and pr.m_iKills  and pr.m_iKills[idx])  or me.m_iFrags  or 0
        local d = (pr and pr.m_iDeaths and pr.m_iDeaths[idx]) or me.m_iDeaths or 0
        common.add_event(('[rs] K=%d D=%d'):format(k, d))
        if d > k then
            last_rs_at = common.get_timestamp() / 1000
            utils.console_exec('say !rs')
            common.add_event('[rs] sent: say !rs')
        end
    end)
end

events.player_death:set(function(e)
    local me = entity.get_local_player()
    if not me then return end

    local attacker = entity.get(e.attacker, true)
    local victim   = entity.get(e.userid, true)
    if not attacker or not victim then return end

    if victim == me then
        check_auto_rs()
    end

    if attacker ~= me then return end
    if e.userid == e.attacker then return end
    if not mi_team:get() and not victim:is_enemy() then return end

    if mi_on:get() then
        kills = kills + 1
        play_streak(kills)
    end
end)

events.round_prestart:set(function()
    kills = 0
end)

events.round_start:set(function()
    kills = 0
end)

events.render:set(function()
    if cur_img.idx == 0 then return end
    if not mi_img_on:get() then
        cur_img.idx = 0
        return
    end

    local age = globals.realtime - cur_img.start
    local dur = cur_img.dur
    if age < 0 or age >= dur then
        cur_img.idx = 0
        return
    end

    local img = get_image(cur_img.idx)
    if not img then
        cur_img.idx = 0
        return
    end

    local screen = render.screen_size()
    local sw, sh = screen.x, screen.y

    -- Масштаб от высоты экрана: на 1080p ~194px, на 1440p ~259px, на 2160p ~389px.
    -- На ультравайде (5120x1440) ширина банера ~648px — не растягивается на весь экран.
    local size_mult = mi_img_size:get() / 100
    local h = sh * 0.18 * size_mult
    local w = h * IMG_ASPECT

    local alpha = 1.0
    if age < FADE_IN then
        alpha = age / FADE_IN
    elseif age > dur - FADE_OUT then
        alpha = (dur - age) / FADE_OUT
    end
    if alpha < 0 then alpha = 0 end
    if alpha > 1 then alpha = 1 end

    if age < POP_TIME then
        local t = age / POP_TIME
        local scale = POP_START - (POP_START - 1) * t
        h = h * scale
        w = w * scale
    end

    local x = (sw - w) * 0.5
    local y = (sh - h) * 0.5
    render.texture(img, vector(x, y), vector(w, h), color(255, 255, 255, math.floor(255 * alpha)))
end)

events.shutdown:set(function()
    kills = 0
    cur_img.idx = 0
end)
