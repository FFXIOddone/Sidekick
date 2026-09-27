local fake = require('tests.ashita');
local action_core = require('lib.core.action_core');

local job = { resource_type = 'mp' };
local cure = { name = 'Cure', cost = 8, spell_id = 1, command = function(t) return '/ma "Cure" ' .. t; end };
local provoke = { name = 'Provoke', cost = 0, recast_id = 5, command = '/ja "Provoke" <t>' };

-- The post-recast delay reads os.clock; freeze it so a test controls elapsed time.
local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

local function reset()
    fake.reset();
    now = now + 1000;   -- far enough that every earlier ready stamp has expired
end

test('a spell with enough MP and no recast is usable', function()
    reset();
    action_core.clear_ready_stamp(cure);
    assert_eq(action_core.is_usable(cure, job), false, 'first read stamps the recast as just ready');
    now = now + 0.5;
    assert_eq(action_core.is_usable(cure, job), true);
end);

test('a spell costing more than the current MP is refused', function()
    reset();
    fake.state.party[0].mp = 7;
    local ok, reason = action_core.is_usable(cure, job);
    assert_eq({ ok, reason }, { false, 'insufficient mp' });
end);

test('a spell on recast reports the seconds left', function()
    reset();
    fake.state.spell_recasts[1] = 300;   -- 5 s in 1/60 s ticks
    local ok, reason = action_core.is_usable(cure, job);
    assert_eq({ ok, reason }, { false, 'spell cooldown (5.0s)' });
end);

test('a job ability never used reads as ready without any recast slot', function()
    reset();
    action_core.clear_ready_stamp(provoke);
    assert_eq(action_core.is_usable(provoke, job), true);
end);

test('a job ability on recast is refused', function()
    reset();
    fake.state.ability_recasts[5] = 120;
    local ok, reason = action_core.is_usable(provoke, job);
    assert_eq({ ok, reason }, { false, 'ability cooldown' });
end);

test('a job ability is usable half a second after its recast ends', function()
    reset();
    fake.state.ability_recasts[5] = 0;
    action_core.clear_ready_stamp(provoke);
    assert_eq(action_core.is_usable(provoke, job), false, 'first zero read only stamps it');
    now = now + 0.49;
    assert_eq(action_core.is_usable(provoke, job), false, 'still inside the post-recast delay');
    now = now + 0.01;
    assert_eq(action_core.is_usable(provoke, job), true);
end);

test('silence blocks magic but not job abilities', function()
    reset();
    fake.state.player.buffs = { 6 };
    local ok, reason = action_core.is_usable(cure, job);
    assert_eq({ ok, reason }, { false, 'blocked by Silence' });
    fake.state.ability_recasts[5] = 0;
    action_core.clear_ready_stamp(provoke);
    action_core.is_usable(provoke, job);
    now = now + 0.5;
    assert_eq(action_core.is_usable(provoke, job), true);
end);

test('first_missing_stack asks for the second copy of a buff listed twice', function()
    local rune = { name = 'Ignis', buff_id = 523 };
    local desired = { rune, rune, { name = 'Gelus', buff_id = 524 } };
    assert_eq(action_core.first_missing_stack(desired, {}).name, 'Ignis');
    assert_eq(action_core.first_missing_stack(desired, { 523 }), rune, 'one Ignis up, still one short');
    assert_eq(action_core.first_missing_stack(desired, { 523, 523 }).name, 'Gelus');
    assert_eq(action_core.first_missing_stack(desired, { 523, 523, 524 }), nil);
end);

test('has_any_buff accepts a single id or a list', function()
    assert_eq(action_core.has_any_buff({ 40, 41 }, 41), true);
    assert_eq(action_core.has_any_buff({ 40, 41 }, { 43, 41 }), true);
    assert_eq(action_core.has_any_buff({ 40, 41 }, { 43 }), false);
    assert_eq(action_core.needs_buff({ 40 }, nil), true, 'untracked buffs are always needed');
end);

os.clock = real_clock;
