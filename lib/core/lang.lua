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

-- Language code -> Name[] slot of an Ashita resource (Default, Japanese, English).
lang.NAME_INDEX = { ja = 2 }

local ENGLISH = 2  -- Ashita langId for English (0 Default, 1 Japanese, 2 English)

-- Command verb -> resource manager lookup for its quoted name.
local LOOKUP = {
    ma = 'GetSpellByName',
    ja = 'GetAbilityByName', pet = 'GetAbilityByName',
    item = 'GetItemByName', equip = 'GetItemByName',
}

-- Native name of English `name` in language `code`, looked up with resource
-- manager `method`. Returns nil when unknown or empty.
local function lookup(method, name, code)
    -- Ashita resources carry only English and Japanese names.
    local index = lang.NAME_INDEX[code]
    if not index then return nil end
    local ok, res = pcall(function()
        local rm = AshitaCore:GetResourceManager()
        return rm[method](rm, name, ENGLISH)
    end)
    local native = ok and res and res.Name and res.Name[index]
    if native and native ~= '' then return native end
    return nil
end

-- Translate the first quoted name in a command into language `code`.
-- Args: command (string) - '/ma "Cure" <p1>', '/equip ammo "X" 0', ...
--       code (string|nil) - settings.command_language ('en', 'ja')
-- Returns: string - the translated command, or the original when there is nothing
--          to translate or no native name is known (unknown/custom name, language
--          without a resource slot).
function lang.translate(command, code)
    if not code or code == 'en' then return command end

    local method = LOOKUP[command:match('^/(%a+)') or '']
    local open = command:find('"', 1, true)
    local close = open and command:find('"', open + 1, true)
    if not method or not close then return command end

    local name = command:sub(open + 1, close - 1)
    local native = lookup(method, name, code)
    if not native then
        common.debugf('[LANG] No %s name for "%s"; sending English', code, name)
        return command
    end
    return command:sub(1, open) .. native .. command:sub(close)
end

-- Translate a bare spell or ability name, with no command verb to pick the table:
-- tries spells, then abilities. For chat lines (the Hold AOE gather alert).
-- Returns: string - the native name, or `name` unchanged when none is known.
function lang.name(name, code)
    if not code or code == 'en' then return name end
    return lookup('GetSpellByName', name, code) or lookup('GetAbilityByName', name, code) or name
end

-- Hold AOE gather alert phrase per language. Written as Shift-JIS bytes, the
-- game's chat encoding (the resource names above already come back in it).
local GATHER = {
    en = 'Gather together.',
    ja = '\x8f\x57\x82\xdc\x82\xc1\x82\xc4\x82\xad\x82\xbe\x82\xb3\x82\xa2\x81\x42', -- 集まってください。
}

-- Party chat text for the Hold AOE gather alert: phrase plus ability name, both
-- in language `code`; English when the language has no phrase.
function lang.gather(ability_name, code)
    return (GATHER[code] or GATHER.en) .. '  ' .. lang.name(ability_name, code)
end

return lang
