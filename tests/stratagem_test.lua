local fake = require('tests.ashita');
local common = require('lib.core.common');
local scholar = require('lib.jobs.scholar');

local LIGHT_ARTS, ADDENDUM_WHITE, DARK_ARTS = 358, 401, 359;
local PERPETUANCE, ACCESSION = 'Perpetuance (+Duration)', 'Accession (+AOE)';

local function buff_named(name)
    for _, a in ipairs(scholar.abilities.buff) do
        if a.name == name then return a; end
    end
    error('no Scholar buff named ' .. name);
end
local protect = buff_named('Protect IV');

-- A Scholar holding four stratagem charges, in the given stance, with the named
-- stratagems assigned to Protect. Returns what check_stratagem does next.
local function next_stratagem(stance, assigned)
    fake.reset();
    fake.state.player.buffs = { stance };
    common.game_state.stratagems = 4;
    local settings = { stratagem_settings = { [protect.group] = {} } };
    for _, name in ipairs(assigned) do settings.stratagem_settings[protect.group][name] = true; end
    local result = common.check_stratagem(scholar, settings, protect.name, protect);
    return result and result.command;
end

test('Perpetuance fires under Light Arts without Addendum: White', function()
    assert_eq(next_stratagem(LIGHT_ARTS, { PERPETUANCE }), '/ja "Perpetuance" <me>');
end);

test('Perpetuance fires under Addendum: White', function()
    assert_eq(next_stratagem(ADDENDUM_WHITE, { PERPETUANCE }), '/ja "Perpetuance" <me>');
end);

test('Accession fires under Light Arts without Addendum: White', function()
    assert_eq(next_stratagem(LIGHT_ARTS, { ACCESSION }), '/ja "Accession" <me>');
end);

test('Perpetuance assigned beside Accession does not stall the pair under Light Arts', function()
    assert_eq(next_stratagem(LIGHT_ARTS, { PERPETUANCE, ACCESSION }), '/ja "Perpetuance" <me>');
end);

test('a Light Arts stratagem does not fire under Dark Arts', function()
    assert_eq(next_stratagem(DARK_ARTS, { PERPETUANCE }), nil);
end);
