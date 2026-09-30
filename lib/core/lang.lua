--[[
    Command language
    Rewrites the spell/ability/item name inside a game command into the client's
    language, so a Japanese client runs /ja "Troubadour" <me> as
    /ja "トルバドゥール" <me>. Names come from Ashita's resource manager (the client
    DATs), already in the game's own encoding, so no name tables are kept here.
    Job files keep writing English commands; automation.execute_command translates
    right before QueueCommand.
]]--

local common = require('lib.core.common')

local lang = {}

-- Ashita numbers its languages two ways. The langId argument of Get*ByName is
-- 0 Default, 1 Japanese, 2 English; a resource's Lua Name[] slots are 0 Default,
-- 1 English, 2 Japanese. Resources carry only these two languages, so Japanese
-- is the only one a command can be translated into.
local ENGLISH = 2   -- langId
local JAPANESE = 2  -- Name[] slot

-- Japanese client? The boot config's ashita.language/playonline names the
-- PlayOnline install the game runs from: 1 is the Japanese one, while 0 (Default)
-- and 2 both open the US install (plugins/sdk/Registry.h). Read once at load:
-- it can't change without a relaunch.
local ok, playonline = pcall(function()
    return AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2)
end)
lang.japanese = ok and playonline == 1

-- Command verb -> resource manager lookup for its quoted name.
local LOOKUP = {
    ma = 'GetSpellByName',
    ja = 'GetAbilityByName', pet = 'GetAbilityByName',
    item = 'GetItemByName', equip = 'GetItemByName',
}

-- Names with no Japanese name, each warned about once a session.
local warned = {}

-- Japanese name of English `name`, looked up with resource manager `method`.
-- Returns nil when unknown or empty.
local function lookup(method, name)
    local found, res = pcall(function()
        local rm = AshitaCore:GetResourceManager()
        return rm[method](rm, name, ENGLISH)
    end)
    local native = found and res and res.Name and res.Name[JAPANESE]
    if native and native ~= '' then return native end
    return nil
end

-- Translate the first quoted name in a command into the client's language.
-- Args: command (string) - '/ma "Cure" <p1>', '/equip ammo "X" 0', ...
-- Returns: string - the translated command, or the original on an English client,
--          when there is nothing to translate, or when no Japanese name is known
--          (unknown/custom name; warned once, since the client will reject it).
function lang.translate(command)
    if not lang.japanese then return command end
    local method = LOOKUP[command:match('^/(%a+)') or '']
    if not method then return command end

    -- gsub keeps the match when the function returns nil.
    return (command:gsub('"([^"]*)"', function(name)
        local native = lookup(method, name)
        if native then return '"' .. native .. '"' end
        if not warned[name] then
            warned[name] = true
            common.warnf('No Japanese name for "%s"; sending it in English', name)
        end
        return nil
    end, 1))
end

-- Hold AOE gather alert phrase in Japanese. Written as Shift-JIS bytes, the
-- game's chat encoding (the resource names above already come back in it).
local JA_GATHER = '\x8f\x57\x82\xdc\x82\xc1\x82\xc4\x82\xad\x82\xbe\x82\xb3\x82\xa2\x81\x42' -- 集まってください。

-- Party chat text for the Hold AOE gather alert, in the client's language. A bare
-- name has no verb to pick the table, so Japanese tries spells, then abilities,
-- and keeps the English name when neither knows it.
function lang.gather(ability_name)
    if not lang.japanese then return 'Gather together for ' .. ability_name end
    local native = lookup('GetSpellByName', ability_name) or lookup('GetAbilityByName', ability_name)
    return JA_GATHER .. '  ' .. (native or ability_name)
end

return lang
