local STREAKS = {
    [1] = { name = 'First Blood',  sound_path = 'streaks/first_blood.wav' },
    [2] = { name = 'Double Kill',  sound_path = 'streaks/double_kill.wav' },
    [3] = { name = 'Triple Kill',  sound_path = 'streaks/triple_kill.wav' },
    [4] = { name = 'Quadra Kill',  sound_path = 'streaks/quadra_kill.wav' },
    [5] = { name = 'Penta Kill',   sound_path = 'streaks/penta_kill.wav'  },
}

local MAX_STREAK = 5

local menu     = ui.create('Kill Streaks')
local mi_on    = menu:switch('Включить стрики', true)
local mi_team  = menu:switch('Учитывать тиммейтов', false)
local mi_vol   = menu:slider('Громкость', 0, 200, 50, 1, '%')
local mi_rs_on = menu:switch('Авто-ресет КД', false)

local kills = 0

local function play_streak(streak)
    local idx  = math.min(streak, MAX_STREAK)
    local data = STREAKS[idx]
    if not data then return end

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

events.shutdown:set(function()
    kills = 0
end)
