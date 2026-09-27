-- Data-table checks over every lib/jobs/*.lua, against the CatsEyeXI server tables in
-- tests/data/ (regenerate with tools/gen_resources.lua). Each test collects every
-- problem it finds and asserts the list is empty, so one run reports them all.
local spells = require('tests.data.spells');
local abilities = require('tests.data.abilities');
local effects = require('tests.data.status_effects');

local windows = package.config:sub(1, 1) == '\\';

local function read(path)
    local f = assert(io.open(path, 'r'));
    local text = f:read('*a');
    f:close();
    return text;
end

local function job_files()
    local cmd = windows and 'dir /b "lib\\jobs" 2>nul' or 'ls "lib/jobs" 2>/dev/null';
    local handle, out = io.popen(cmd), {};
    for entry in handle:lines() do
        local name = entry:match('^(%a[%w_]*)%.lua$');
        if name then table.insert(out, name); end
    end
    handle:close();
    table.sort(out);
    return out;
end

local jobs = {};
for _, name in ipairs(job_files()) do
    jobs[name] = require('lib.jobs.' .. name);
    jobs[name].__file = name;
end

-- Every ability of every job, with where it came from for the failure message.
local function each_ability(fn)
    for job_name, job in pairs(jobs) do
        for category, list in pairs(job.abilities or {}) do
            for i, ability in ipairs(list) do
                fn(ability, ('%s.%s[%d] %s'):format(job_name, category, i, tostring(ability.name)), job);
            end
        end
    end
end

-- The command string an ability sends, with a placeholder target for the closures.
local function command_of(ability)
    if type(ability.command) == 'function' then return ability.command('<t>'); end
    return ability.command;
end

-- Server SQL names are lower case with apostrophes dropped, spaces and colons as
-- underscores and hyphens kept: "Knight's Minne" is knights_minne, "Addendum: White" is
-- addendum_white, "Geo-Regen" is geo-regen.
local function sql_name(display)
    return (display:lower():gsub("'", ''):gsub('[^%w%-]+', '_'):gsub('^_', ''):gsub('_$', ''));
end

-- Where the quoted name in the command lands in a server table.
local function command_parts(ability)
    local cmd = command_of(ability);
    if type(cmd) ~= 'string' then return nil; end
    local kind, quoted = cmd:match('^/(%a+) "([^"]+)"');
    return kind, quoted and sql_name(quoted);
end

local function ids_of(v)
    if type(v) == 'table' then return v; end
    return { v };
end

local function sorted(problems)
    table.sort(problems);
    return problems;
end

test('every job file is registered under its own id in Sidekick.lua', function()
    local registered = {};
    local block = read('Sidekick.lua'):match('local job_map = {(.-)}');
    for id, name in block:gmatch("%[(%d+)%]%s*=%s*'([%w_]+)'") do
        registered[name] = tonumber(id);
    end
    local problems = {};
    for name, job in pairs(jobs) do
        if registered[name] ~= job.job_id then
            table.insert(problems, ('%s: job_id %s but job_map has %s'):format(name, tostring(job.job_id), tostring(registered[name])));
        end
    end
    for name in pairs(registered) do
        if jobs[name] == nil then table.insert(problems, name .. ': in job_map but no lib/jobs file'); end
    end
    assert_eq(sorted(problems), {});
end);

test('every job has a name, resource type, abilities, defaults and a priority order', function()
    local problems = {};
    for name, job in pairs(jobs) do
        if type(job.job_name) ~= 'string' then table.insert(problems, name .. ': no job_name'); end
        if job.resource_type ~= 'mp' and job.resource_type ~= 'tp' then
            table.insert(problems, name .. ': resource_type must be mp or tp');
        end
        if type(job.abilities) ~= 'table' then table.insert(problems, name .. ': no abilities'); end
        if type(job.default_settings) ~= 'table' then table.insert(problems, name .. ': no default_settings'); end
        if type(job.priority_order) ~= 'table' then table.insert(problems, name .. ': no priority_order'); end
    end
    assert_eq(sorted(problems), {});
end);

test('every ability carries a name, a level, a cost and a command', function()
    local problems = {};
    each_ability(function(a, where)
        if type(a.name) ~= 'string' then table.insert(problems, where .. ': no name'); end
        if type(a.level) ~= 'number' or a.level < 1 or a.level > 99 then
            table.insert(problems, where .. ': level ' .. tostring(a.level));
        end
        if type(a.cost) ~= 'number' then table.insert(problems, where .. ': no cost'); end
        local cmd = command_of(a);
        if type(cmd) ~= 'string' or not cmd:match('^/%a+ "[^"]+"') then
            table.insert(problems, where .. ': command ' .. tostring(cmd));
        end
    end);
    assert_eq(sorted(problems), {});
end);

test('an ability carries one cooldown id, and the field matches the command type', function()
    local problems = {};
    each_ability(function(a, where)
        local kind = command_parts(a);
        if a.spell_id and a.recast_id then
            table.insert(problems, where .. ': both spell_id and recast_id');
        elseif kind == 'ma' and not a.spell_id then
            table.insert(problems, where .. ': /ma without spell_id');
        elseif kind ~= 'ma' and a.spell_id then
            table.insert(problems, where .. ': spell_id on a /' .. tostring(kind) .. ' command');
        elseif (kind == 'ja' or kind == 'pet') and not a.recast_id
            and not a.requires_stratagem_charge and not a.requires_ready_charge then
            -- Stratagems and Ready moves draw on a charge pool instead of a plain recast.
            table.insert(problems, where .. ': /' .. kind .. ' without recast_id');
        end
    end);
    assert_eq(sorted(problems), {});
end);

-- Spells the job file keeps on purpose although the server has no row for them yet;
-- each job file's header note says why. Remove the entry here once the server adds it.
local missing_on_server = {
    ['blue_mage'] = { ['Carcharian Verve'] = true },
};

test('spell_id is the spell_list row for the spell the command casts', function()
    local problems = {};
    each_ability(function(a, where, job)
        local kind, name = command_parts(a);
        local kept = missing_on_server[job.__file] and missing_on_server[job.__file][a.name];
        if kind == 'ma' and a.spell_id and not kept then
            local row = spells[a.spell_id];
            if row == nil then
                table.insert(problems, ('%s: spell_id %d is not in spell_list'):format(where, a.spell_id));
            elseif row.name ~= name then
                table.insert(problems, ('%s: spell_id %d is %s, command casts %s'):format(where, a.spell_id, row.name, name));
            end
        end
    end);
    assert_eq(sorted(problems), {});
end);

test('cost matches the spell_list MP cost', function()
    local problems = {};
    each_ability(function(a, where)
        local row = a.spell_id and spells[a.spell_id];
        if row and a.cost ~= row.mp then
            table.insert(problems, ('%s: cost %d, spell_list says %d'):format(where, a.cost, row.mp));
        end
    end);
    assert_eq(sorted(problems), {});
end);

test('recast_id is the abilities.sql recastId of the ability the command uses', function()
    local by_name = {};
    for _, row in pairs(abilities) do by_name[row.name] = row; end
    local problems = {};
    each_ability(function(a, where)
        local kind, name = command_parts(a);
        if (kind == 'ja' or kind == 'pet') and a.recast_id then
            local row = by_name[name];
            if row == nil then
                table.insert(problems, ('%s: %s is not in abilities.sql'):format(where, name));
            elseif row.recast ~= a.recast_id then
                table.insert(problems, ('%s: recast_id %d, abilities.sql says %d'):format(where, a.recast_id, row.recast));
            end
        end
    end);
    assert_eq(sorted(problems), {});
end);

test('ability_id is the abilities.sql abilityId of the ability the command uses', function()
    local problems = {};
    each_ability(function(a, where)
        local _, name = command_parts(a);
        if a.ability_id then
            local row = abilities[a.ability_id];
            if row == nil then
                table.insert(problems, ('%s: ability_id %d is not in abilities.sql'):format(where, a.ability_id));
            elseif row.name ~= name then
                table.insert(problems, ('%s: ability_id %d is %s, command uses %s'):format(where, a.ability_id, row.name, name));
            end
        end
    end);
    assert_eq(sorted(problems), {});
end);

test('every buff, debuff, requires_buff and blocked_by id is a status_effects row', function()
    local problems = {};
    each_ability(function(a, where)
        for _, field in ipairs({ 'buff_id', 'debuff_id', 'requires_buff', 'blocked_by' }) do
            for _, id in ipairs(ids_of(a[field])) do
                if effects[id] == nil then
                    table.insert(problems, ('%s: %s %s is not in status_effects'):format(where, field, tostring(id)));
                end
            end
        end
    end);
    assert_eq(sorted(problems), {});
end);

-- The engine reads settings by literal key (settings.heal_enabled), by a key it builds
-- from a prefix (settings['disabled_' .. name], 'rune_' .. slot .. '_enabled'), or through
-- a key an ability field names (settings[ability.rune_field]). A default nothing reads is
-- dead, and a default under the wrong name means the feature silently uses nil.
test('every default setting of a job is a key the engine reads', function()
    local engine = read('Sidekick.lua');
    for _, dir in ipairs({ 'lib/core', 'lib/actions' }) do
        local cmd = windows and ('dir /b "%s" 2>nul'):format(dir:gsub('/', '\\')) or ('ls "%s" 2>/dev/null'):format(dir);
        local handle = io.popen(cmd);
        for entry in handle:lines() do
            if entry:match('%.lua$') then engine = engine .. read(dir .. '/' .. entry); end
        end
        handle:close();
    end
    -- Key shapes the engine assembles at runtime, as anchored patterns.
    local built = {};
    for prefix in engine:gmatch("settings%['([%w_]+)' *%.%.") do
        table.insert(built, '^' .. prefix);
    end
    for prefix, suffix in engine:gmatch("'([%w_]+)' *%.%. *[%w_.]+ *%.%. *'([%w_]+)'") do
        table.insert(built, '^' .. prefix .. '[%w_]+' .. suffix .. '$');
    end
    local function is_built(key)
        for _, pattern in ipairs(built) do
            if key:match(pattern) then return true; end
        end
        return false;
    end
    local problems = {};
    for name, job in pairs(jobs) do
        local source = read('lib/jobs/' .. name .. '.lua');
        for key in pairs(job.default_settings) do
            local pattern = '%f[%w_]' .. key .. '%f[^%w_]';
            local _, in_job = source:gsub(pattern, '');
            if not engine:find(pattern) and not is_built(key) and in_job < 2 then
                table.insert(problems, ('%s: %s'):format(name, key));
            end
        end
    end
    assert_eq(sorted(problems), {});
end);

test('priority_order only names actions the master order in Sidekick.lua knows', function()
    local known = {};
    local block = read('Sidekick.lua'):match('local master_priority = {(.-)}');
    for action in block:gmatch("'([%w_]+)'") do known[action] = true; end
    local problems = {};
    for name, job in pairs(jobs) do
        for _, action in ipairs(job.priority_order) do
            if not known[action] then table.insert(problems, name .. ': ' .. action); end
        end
    end
    assert_eq(sorted(problems), {});
end);
