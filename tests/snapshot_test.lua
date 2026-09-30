local fake = require('tests.ashita');
local common = require('lib.core.common');

-- get_bt calls into FFXiMain through an ffi function pointer; the fake's is address 1,
-- a crash no pcall can catch. refresh_game_state samples <bt> movement, so stub it.
require('lib.core.targets').get_bt = function() return nil; end

local function setup()
    fake.reset();
    fake.state.strings['jobs.names_abbr'] = { [3] = 'WHM', [4] = 'BLM', [5] = 'RDM' };
    fake.state.entities[0x400].Movement.LocalPosition = { X = 1, Y = 2, Z = 3 };
    fake.state.party[6] = { name = 'Ally', server_id = 0x500, target_index = 0x410, hp = 800,
        hp_pct = 50, mp = 20, mp_pct = 10, tp = 300, active = true,
        main_job = 5, main_level = 70, sub_job = 3, sub_level = 35 };
end

test('member snapshots carry every party-manager read', function()
    setup();
    common.refresh_game_state();
    local p = common.game_state.player;
    assert_eq({ p.name, p.server_id, p.target_index, p.hp, p.hpp, p.mp, p.mpp, p.tp },
              { 'Tester', 0x100, 0x400, 1000, 100, 500, 100, 0 });
    assert_eq({ p.job, p.job_name, p.sub_job, p.sub_job_name, p.main_level, p.sub_level },
              { 3, 'WHM', 4, 'BLM', 75, 37 });
    assert_eq(p.position, { x = 1, y = 2, z = 3 });
    assert_eq(p.entity_status, 0);

    local a = common.game_state.alliance[2][0];
    assert_eq({ a.name, a.server_id, a.hp, a.hpp, a.mp, a.mpp, a.tp, a.job_name, a.sub_job_name, a.main_level },
              { 'Ally', 0x500, 800, 50, 20, 10, 300, 'RDM', 'WHM', 70 });
    assert_eq(common.game_state.alliance_size, 1);
end);

test('an /anon player row takes job and level from the Player struct', function()
    setup();
    local row = fake.state.party[0];
    row.main_job, row.main_level, row.sub_job, row.sub_level = 0, 0, 0, 0;
    common.refresh_game_state();
    local p = common.game_state.player;
    assert_eq({ p.job, p.job_name, p.sub_job, p.main_level, p.sub_level }, { 3, 'WHM', 4, 75, 37 });
end);
