local fake = require('tests.ashita');
local common = require('lib.core.common');

-- The count cache reads os.clock; freeze it so a test controls elapsed time.
local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

local PET_FOOD = { { id = 4372, name = 'Pet Food Zeta' }, { id = 4371, name = 'Pet Food Epsilon' } };
local TOOLS = { { id = 1161, name = 'Shihei' } };

local function reset()
    fake.reset();
    now = now + 1000;   -- far past any earlier count
    fake.state.inventory[0] = { { Id = 4372, Count = 12 }, { Id = 1161, Count = 99 } };
end

test('a consumable count is not re-read from the inventory within 0.5s', function()
    reset();
    assert_eq(common.count_equippable_items(PET_FOOD), 12);
    local reads = fake.state.inventory_reads;
    fake.state.inventory[0][1].Count = 11;
    now = now + 0.4;
    assert_eq({ common.count_equippable_items(PET_FOOD), fake.state.inventory_reads }, { 12, reads });
    now = now + 0.2;
    assert_eq(common.count_equippable_items(PET_FOOD), 11);
end);

test('two consumables keep separate counts', function()
    reset();
    assert_eq({ common.count_equippable_items(PET_FOOD), common.count_equippable_items(TOOLS) }, { 12, 99 });
end);

os.clock = real_clock;
