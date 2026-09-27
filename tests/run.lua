-- Minimal test runner, run from the repo root:
--   luajit tests/run.lua              every tests/*_test.lua
--   luajit tests/run.lua jobs_test    one file (with or without .lua)
-- tests/ashita.lua is loaded first so the real lib/ modules resolve their Ashita
-- dependencies (T{}, AshitaCore, chat, settings, ...) against a fake client.
local windows = package.config:sub(1, 1) == '\\';
package.path = './?.lua;' .. package.path;

local pass, fail = 0, 0;
local current;

local function dump(v)
    if type(v) ~= 'table' then return tostring(v); end
    local parts = {};
    for k, x in pairs(v) do table.insert(parts, tostring(k) .. '=' .. dump(x)); end
    table.sort(parts);
    return '{' .. table.concat(parts, ', ') .. '}';
end

local function deep_eq(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b; end
    for k, v in pairs(a) do if not deep_eq(v, b[k]) then return false; end end
    for k in pairs(b) do if a[k] == nil then return false; end end
    return true;
end

function assert_eq(actual, expected, msg)
    if not deep_eq(actual, expected) then
        error(('%s\n  expected: %s\n  actual:   %s'):format(msg or 'assert_eq', dump(expected), dump(actual)), 2);
    end
end

function test(name, fn)
    local ok, err = pcall(fn);
    if ok then pass = pass + 1;
    else fail = fail + 1; print(('FAIL %s :: %s\n  %s'):format(current, name, tostring(err))); end
end

local function list_tests()
    local cmd = windows and 'dir /b "tests" 2>nul' or 'ls "tests" 2>/dev/null';
    local handle, out = io.popen(cmd), {};
    for entry in handle:lines() do
        if entry:match('_test%.lua$') then table.insert(out, entry); end
    end
    handle:close();
    table.sort(out);
    return out;
end

require('tests.ashita');

local files = list_tests();
if arg[1] ~= nil then
    files = { (arg[1]:gsub('^tests[/\\]', ''):gsub('%.lua$', '') .. '.lua') };
end
if #files == 0 then
    io.stderr:write('no tests/*_test.lua files found; run from the repo root\n');
    os.exit(2);
end
for _, file in ipairs(files) do
    current = file;
    local ok, err = pcall(dofile, 'tests/' .. file);
    if not ok then fail = fail + 1; print(('FAIL %s :: could not load\n  %s'):format(file, tostring(err))); end
end
print(('total: %d passed, %d failed'):format(pass, fail));
os.exit(fail == 0 and 0 or 1);
