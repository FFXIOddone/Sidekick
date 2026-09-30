local fake = require('tests.ashita');
local automation = require('lib.core.automation');

-- The throttle reads os.clock; freeze it so a test controls elapsed time.
local now = 100;
local real_clock = os.clock;
os.clock = function() return now; end

local function reset()
    fake.reset();
    now = now + 1000;   -- far past any earlier command
end

test('is_ready turns true 0.1s before the throttle lets a command out', function()
    reset();
    assert_eq(automation.execute_command('/echo a'), true);
    now = now + 0.9;
    assert_eq(automation.is_ready(), false);
    now = now + 0.15;   -- 1.05s: inside the lead
    assert_eq({ automation.is_ready(), automation.execute_command('/echo b') }, { true, false });
    now = now + 0.1;    -- 1.15s: throttle open
    assert_eq(automation.execute_command('/echo c'), true);
end);

test('a spell finish holds is_ready off for the longer lockout', function()
    reset();
    automation.notify_action_finished(true);
    now = now + 2.9;
    assert_eq(automation.is_ready(), false);
    now = now + 0.15;
    assert_eq(automation.is_ready(), true);
end);

os.clock = real_clock;
