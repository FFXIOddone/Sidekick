local fake = require('tests.ashita');
local common = require('lib.core.common');

-- buff.execute reads the [A]/ME buttons from the config window; feed them per test.
local real_config = package.loaded['lib.ui.config'];
package.loaded['lib.ui.config'] = {
    get_party_buffs = function() return {}; end,
    get_party_buff_gates = function() return {}; end,
};
local buff = require('lib.actions.buff');

-- The post-recast delay and the Accession stamp read os.clock; freeze it.
local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

local LIGHT_ARTS, ACCESSION, FIRESTORM, PROTECT_IV = 358, 366, 178, 46;

local function scholar()
    package.loaded['lib.jobs.scholar'] = nil;
    local def = require('lib.jobs.scholar');
    for _, list in pairs(def.abilities) do
        for _, a in ipairs(list) do a.is_main_job = true; end
    end
    return def;
end

-- Settings with every non-storm buff row off, so only the storms (and what a test
-- turns back on) can win the tick.
local function storm_settings(extra)
    local s = { buff_enabled = true, selected_storm = 'Firestorm' };
    for _, k in ipairs({ 'group_arts', 'group_addendum', 'Sublimation', 'Klimaform', 'group_protect',
                         'group_shell', 'Stoneskin', 'Blink', 'Aquaveil', 'group_spikes', 'group_reraise' }) do
        s['disabled_' .. k] = true;
    end
    for k, v in pairs(extra or {}) do s[k] = v; end
    return s;
end

-- Scholar 75 in Light Arts with every storm learned; members are { trust = bool } entries.
local function setup(buffs, members)
    fake.reset();
    now = now + 1000;   -- past every earlier ready stamp and Accession stamp
    local p = fake.state.player;
    p.main_job, p.sub_job, p.main_level, p.sub_level = 20, 3, 75, 37;
    p.buffs = buffs;
    for _, id in ipairs({ 99, 113, 114, 115, 116, 117, 118, 119, PROTECT_IV }) do p.spells[id] = true; end
    fake.state.party[0].mp, fake.state.party[0].main_job = 500, 20;
    for i in ipairs(members or {}) do
        local ti = 0x500 + i;
        fake.state.party[i] = { name = 'M' .. i, server_id = 0x1000000 + i, target_index = ti, hp = 1000,
            hp_pct = 100, mp = 100, mp_pct = 100, tp = 0, active = true, zone = 1, main_job = 1, main_level = 75 };
        fake.state.entities[ti] = fake.entity({ ServerId = 0x1000000 + i, Name = 'M' .. i, TargetIndex = ti,
            Movement = { LocalPosition = { X = 3, Y = 0, Z = 0 } } });
    end
    common.refresh_game_state();
    local gs = common.game_state;
    gs.stratagems = 3;
    for i, m in ipairs(members or {}) do
        gs.party[i].is_trust, gs.party[i].buffs, gs.party[i].hpp = m.trust, {}, 100;
    end
    gs.player.buffs = buffs;
end

-- One tick's command. The first pass stamps each spell's post-recast delay.
local function tick(settings, cfg, warm)
    local def = scholar();
    if warm ~= false then buff.execute(settings, def, 75, 37, nil, cfg); now = now + 1; end
    local r = buff.execute(settings, def, 75, 37, nil, cfg);
    return r and r.command;
end

local TRUSTS = { { trust = true }, { trust = true } };

test('[A] + ME on the same storm still casts it area for a Trust party', function()
    setup({ LIGHT_ARTS }, TRUSTS);
    assert_eq(tick(storm_settings(), { storm = { A = true, [0] = true } }), '/ja "Accession" <me>');
end);

test('with nobody else in range the [A] storm goes out on self without Accession', function()
    setup({ LIGHT_ARTS }, {});
    assert_eq(tick(storm_settings(), { storm = { A = true, [0] = true } }), '/ma "Firestorm" 256');
end);

test('an Accession raised for another buff is left to that buff', function()
    local s = storm_settings({ disabled_group_protect = false, selected_protect = 'Protect IV',
        stratagem_settings = { protect = { ['Accession (+AOE)'] = true } } });
    local cfg = { storm = { A = true }, protect = { [0] = true } };
    setup({ LIGHT_ARTS, FIRESTORM }, {});
    assert_eq(tick(s, cfg), '/ja "Accession" <me>', 'Protect raises Accession');
    setup({ LIGHT_ARTS, FIRESTORM, ACCESSION }, {});
    assert_eq(tick(s, cfg), '/ma "Protect IV" 256', 'the follow-up tick casts Protect, not the storm');
end);

test('the area pass spends its own Accession even once nobody is missing the storm', function()
    local cfg = { storm = { A = true } };
    setup({ LIGHT_ARTS }, TRUSTS);
    assert_eq(tick(storm_settings(), cfg), '/ja "Accession" <me>');
    fake.state.player.buffs = { LIGHT_ARTS, ACCESSION, FIRESTORM };
    common.game_state.player.buffs = fake.state.player.buffs;
    now = now + 1;
    assert_eq(tick(storm_settings(), cfg, false), '/ma "Firestorm" 256');
end);

test('with only Trusts to cover, the area storm recasts on its 180 s duration', function()
    local s = storm_settings({ ungrouped_storm = true });
    local cfg = { Firestorm = { A = true }, Thunderstorm = { [0] = true } };   -- self has its own storm
    local function at(buffs, dt)
        fake.state.player.buffs, common.game_state.player.buffs = buffs, buffs;
        now = now + dt;
        return tick(s, cfg, false);
    end
    setup({ LIGHT_ARTS, 182 }, TRUSTS);   -- 182 = Thunderstorm
    assert_eq(tick(s, cfg), '/ja "Accession" <me>', 'never cast: due now');
    assert_eq(at({ LIGHT_ARTS, 182, ACCESSION }, 1), '/ma "Firestorm" 256');
    assert_eq(at({ LIGHT_ARTS, 182 }, 60), nil, 'within the duration: nothing');
    assert_eq(at({ LIGHT_ARTS, 182 }, 120), '/ja "Accession" <me>', 'duration up: recast');
end);

os.clock = real_clock;
package.loaded['lib.ui.config'] = real_config;
