--[[---------------------------------------------------------------------------------
  Clique by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------------]]

Clique = {Locals = {}}

assert(DongleStub, string.format("Clique requires DongleStub."))
DongleStub("Dongle-1.2"):New("Clique", Clique)
Clique.version = GetAddOnMetadata("Clique", "Version")
if Clique.version then Clique.version = strtrim(Clique.version) end
if Clique.version == "wowi:revision" then Clique.version = "SVN" end

local L = Clique.Locals

local pairs = pairs
local ipairs = ipairs

local isEnabled;
function Clique:Enable()
    -- Only allow initialization ONCE per game session!
    if isEnabled then return; end
    isEnabled = true;

    -- Grab the localisation table.
    L = Clique.Locals

    -- Set up database.
    self.defaults = {
        -- Profile: Values which are shared by all characters that use a specific profile.
        profile = {
            clicksets = {
                [L.CLICKSET_DEFAULT] = {},
                [L.CLICKSET_HARMFUL] = {},
                [L.CLICKSET_HELPFUL] = {},
                [L.CLICKSET_OOC] = {},
            },
            blacklist = {
            },
        },
        -- Char: Values which are independently stored per-character, regardless of which profile each character uses.
        char = {
            downClick = false,
            autoBindMaxRank = true,
            unitTooltips = false,
            easterEgg = false,
        },
    }

    self.db = self:InitializeDB("CliqueDB", self.defaults)
    self:LinkProfileData()

    -- Dynamically built to hold all actions that will be registered while out of combat.
    self.ooc_clickset = {}

    -- We MUST build the ooc_clickset here, to ensure it gets applied to all subsequent frame registrations.
    self:RebuildOOCSet()

    -- Queue of frame registrations/unregistrations that happened during combat lockdown.
    self.incombat_registrations = {}

    -- "ClickCastFrames" is global to allow easy access by other addons (for adding their own custom unit frames). Therefore,
    -- we'll import that table (if it already exists) and use its existing contents as the basis of our real, internal frame-table.
    -- NOTE: For safety, we re-use the EXACT SAME table, since other addons MAY have stored a local reference to the global table,
    -- and we'll want to ensure that any further additions/modifications by them to their table reference are detected by us.
    self.ccframes = _G.ClickCastFrames or {}

    -- This metatable function will be used on both the global "ClickCastFrames" table AND the real, internal "ccframes" table.
    -- It automatically registers or unregisters frames when someone tries to directly set a NON-EXISTENT key to a truthy/falsy value.
    -- NOTE: Since we never save the key to the fresh-and-empty "ClickCastFrames" (created further below), this function is ALWAYS
    -- executed when assigning/modifying values on ANY key on the new GLOBAL table. However, if someone has stored a LOCAL reference
    -- to the OLD global table (aka "ccframes") and they modify some EXISTING key, then we CAN'T react since "new index" isn't called.
    local newindex = function(t,k,v)
        if not v then
            Clique:UnregisterFrame(k)
            -- If they're trying to set an entry to nil it means they're actually trying to DELETE the frame info entirely (not merely
            -- set it to true (enabled) or false (disabled). In that case, remove it, and refresh the "frame editor"-window.
            if v == nil then
                rawset(self.ccframes, k, nil)
                if CliqueTextListFrame and self.textlist == "FRAMES" and CliqueTextListFrame:IsVisible() then
                    Clique:TextListScrollUpdate()
                end
            end
        else
            Clique:RegisterFrame(k)
        end
    end

    -- This step is ONLY necessary if someone has stored a local reference; then they'll be pointing directly at "ccframes" and we'll
    -- want to properly react (and register) new frames if they attempt to ADD a value to their own local table reference.
    -- NOTE: This WON'T react (update registration) if they are MODIFYING *any* existing value. There's NOTHING we can do about that!
    setmetatable(self.ccframes, { __newindex = newindex })

    -- Lastly, create a brand new, empty global "ClickCastFrames" table, which will NEVER write any entries to itself. Thus ensuring
    -- that EVERY attempt to set/modify a value on this global table will call the "new index" function, and properly (un-)register...
    _G.ClickCastFrames = setmetatable({}, {
        __newindex = newindex,
        __index = function(t,k)
            -- If a caller attempts to look up (read) an index, return the same index from the real, internal table.
            return self.ccframes[k]
        end
    })

    -- Generate the options GUI.
    Clique:OptionsOnLoad()

    -- Register any frames that were added to the global table by other addons before Clique was loaded.
    for frame in pairs(self.ccframes) do
        self:RegisterFrame(frame)
    end

    -- Register all default Blizzard unitframes.
    Clique:EnableFrames()

    -- Register for dongle events.
    self:RegisterMessage("DONGLE_PROFILE_CHANGED")
    self:RegisterMessage("DONGLE_PROFILE_COPIED")
    self:RegisterMessage("DONGLE_PROFILE_DELETED")
    self:RegisterMessage("DONGLE_PROFILE_RESET")

    -- Register for Blizzard events.
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("LEARNED_SPELL_IN_TAB")

    -- Securehook CreateFrame to catch any new raid frames
    local raidFunc = function(type, name, parent, template)
        if template == "RaidPulloutButtonTemplate" then
            local btn = _G[name.."ClearButton"]
            if btn then
                self:RegisterFrame(btn)
            end
        end
    end

    local oldotsu = GameTooltip:GetScript("OnTooltipSetUnit")
    if oldotsu then
        GameTooltip:SetScript("OnTooltipSetUnit", function(...)
            Clique:AddTooltipLines()
            return oldotsu(...)
        end)
    else
        GameTooltip:SetScript("OnTooltipSetUnit", function(...)
            Clique:AddTooltipLines()
        end)
    end

    hooksecurefunc("CreateFrame", raidFunc)

    -- Create our slash command
    self.cmd = self:InitializeSlashCommand("Clique commands", "CLIQUE", "clique")
    self.cmd:RegisterSlashHandler("debug - Enables extra messages for debugging purposes", "debug", "ShowAttributes")
    self.cmd:InjectDBCommands(self.db, "copy", "delete", "list", "reset", "set")
    self.cmd:RegisterSlashHandler("tooltip - Enables binding lists in tooltips.", "tooltip", "ToggleTooltip")
    self.cmd:RegisterSlashHandler("showbindings - Shows a window that contains the current bindings", "showbindings", "ShowBindings")

    -- Place the Clique tab
    self:LEARNED_SPELL_IN_TAB()
end

function Clique:EnableFrames()
    local tbl = {
        PlayerFrame,
        PetFrame,
        PartyMemberFrame1,
        PartyMemberFrame2,
        PartyMemberFrame3,
        PartyMemberFrame4,
        PartyMemberFrame1PetFrame,
        PartyMemberFrame2PetFrame,
        PartyMemberFrame3PetFrame,
        PartyMemberFrame4PetFrame,
        TargetFrame,
        TargetofTargetFrame,
    }

    for i,frame in pairs(tbl) do
        self:RegisterFrame(frame)
    end
end

function Clique:SpellBookButtonPressed(frame, button)
    -- We can only make changes when out of combat, but our spellbook overlays are
    -- hidden while in combat, so this function should never trigger in combat.
    if InCombatLockdown() then
        return
    end

    -- Get spell information.
    local id = SpellBook_GetSpellID(this:GetParent():GetID());
    local name, rank = GetSpellName(id, SpellBookFrame.bookType)
    if not name then return; end -- Abort if spell didn't exist...

    -- Refuse to bind Passive/Racial Passive spells, since those cannot be cast.
    if IsPassiveSpell(id, SpellBookFrame.bookType) then
        StaticPopup_Show("CLIQUE_PASSIVE_SKILL")
        return
    end

    -- Transform the clicked mousebutton into a usable format.
    if self.editSet == self.clicksets[L.CLICKSET_HARMFUL] then
        button = string.format("%s%d", "harmbutton", self:GetButtonNumber(button))
    elseif self.editSet == self.clicksets[L.CLICKSET_HELPFUL] then
        button = string.format("%s%d", "helpbutton", self:GetButtonNumber(button))
    else
        button = self:GetButtonNumber(button)
    end

    -- Skip this click if mouse-button wasn't detected properly.
    if button == "" then return; end

    -- Detect which modifier keys are held down, if any...
    local modifier = self:GetModifierText()

    -- Automatically remove rank variable if spell has no rank info at all,
    -- otherwise we'd end up with parenthesis like "spell: Attack ()".
    if rank == "" then rank = nil; end

    -- Handle the "Bind spells as rankless when clicking highest rank" user configuration option.
    if rank and self.db.char.autoBindMaxRank then
        -- Analyze the next spell after the one that was clicked...
        local nextSpellId = id + 1
        local nextName
        if nextSpellId <= MAX_SPELLS then -- Only grab next name if within Blizzard's legal spell ID range. NOTE: MAX_SPELLS = 1024.
            nextName = GetSpellName(nextSpellId, SpellBookFrame.bookType)
        end

        -- If the NEXT spell is ANYTHING other than EXACTLY THE SAME SPELL NAME, even allowing "next name" to be empty/nil values (such
        -- as at the end of the spell list), then we understand that the user has clicked on their final rank of the given spell.
        if name ~= nextName then
            rank = nil
        end
    end

    -- Generate string key for CheckBinding purposes, which uses "variable type and value" table key equality to detect duplicates.
    -- NOTE: Technically, "modifier" is always a string/empty string (thus generating a string result), so tostring() is just for extra safety.
    local key = tostring(modifier .. button)

    -- Refuse to bind if key already exists in the current clickset.
    if self:CheckBinding(key) then
        StaticPopup_Show("CLIQUE_BINDING_PROBLEM")
        return
    end

    -- Build the clickset entry's data structure.
    local entry = {
        ["button"] = button,
        ["modifier"] = modifier,
        ["texture"] = GetSpellTexture(id, SpellBookFrame.bookType),
        ["type"] = "spell",
        ["arg1"] = name,
        ["arg2"] = rank,
    }

    -- Add the entry, update the list view, and re-apply all clicksets.
    self.editSet[key] = entry
    self:ListScrollUpdate()
    self:RebuildOOCSet()
    self:PLAYER_REGEN_ENABLED()
end

function Clique:UseOOCSet(frame) -- Arg is optional. Affects ALL frames if not provided.
    self:RemoveClickSet(L.CLICKSET_DEFAULT, frame)
    self:RemoveClickSet(L.CLICKSET_HARMFUL, frame)
    self:RemoveClickSet(L.CLICKSET_HELPFUL, frame)
    self:ApplyClickSet(self.ooc_clickset, frame)
end

function Clique:UseCombatSet(frame) -- Arg is optional. Affects ALL frames if not provided.
    self:RemoveClickSet(self.ooc_clickset, frame)
    self:ApplyClickSet(L.CLICKSET_DEFAULT, frame)
    self:ApplyClickSet(L.CLICKSET_HARMFUL, frame)
    self:ApplyClickSet(L.CLICKSET_HELPFUL, frame)
end

-- Player is LEAVING combat
function Clique:PLAYER_REGEN_ENABLED()
    for frame,registered in pairs(self.incombat_registrations) do
        if registered then
            self:RegisterFrame(frame)
        else
            self:UnregisterFrame(frame)
        end
        self.incombat_registrations[frame] = nil
    end

    self:UseOOCSet()
end

-- Player is ENTERING combat
function Clique:PLAYER_REGEN_DISABLED()
    self:UseCombatSet()
end

local function wipe(t) -- Emulates "table.wipe".
    for k in pairs(t) do
        t[k] = nil
    end

    return t
end

function Clique:RebuildOOCSet()
    local ooc = self.clicksets[L.CLICKSET_OOC]
    local default = self.clicksets[L.CLICKSET_DEFAULT]
    local harm = self.clicksets[L.CLICKSET_HARMFUL]
    local help = self.clicksets[L.CLICKSET_HELPFUL]

    -- The binding priority order is OOC > HELP + HARM > DEFAULT (used as final fallback).
    --
    -- Since help-/harmbuttonX frame attributes take priority over regular button click
    -- attributes, we can't simply "apply the DEFAULT and OOC sets last to overwrite the help/harm
    -- actions with the out of combat actions". Instead, we'll build the "self.ooc_clickset"
    -- table which ONLY contains the HELP/HARM-buttons that DON'T conflict with anything
    -- defined in the OOC set, as well as whatever DEFAULT buttons that DON'T conflict with
    -- the OOC set OR with something bound in BOTH the HELP and HARM sets (because "default"
    -- would never run whenever there are BOTH help and harm button handlers on a frame).
    --
    -- NOTE: If the player doesn't define any DEFAULT or OOC bindings at all, and places
    -- everything in their Harm/Help sets, then BOTH of those FULL sets will be used below
    -- regardless of whether Harm and Help bind the same button, since they're able to
    -- co-exist! That's because the harmbutton bindings only happen on "attackable" units,
    -- and the helpbutton bindings only happen on "friendly/helpful" units!
    --
    -- NOTE: The individual sets below can never contain duplicate/clashing bindings
    -- WITHIN their OWN sets. Because every clickset table is keyed by the full button
    -- combinations, such as "Shift-Alt-1". So we don't need to worry about that.

    self.ooc_clickset = wipe(self.ooc_clickset or {})

    -- Create a hash map of the "taken" combinations within each click-set.
    local takenBinds = {ooc = {}, harm = {}, help = {}}

    -- Give highest priority to bindings defined in the OOC-set.
    for name, entry in pairs(ooc) do
        local key = string.format("%s:%s", entry.modifier, entry.button)
        takenBinds.ooc[key] = true;
        table.insert(self.ooc_clickset, entry)
    end

    -- Now add the unit-dependent HARM bindings that don't clash with any OOC keys above.
    -- NOTE: We avoid that since binding harm/help actions would override clashing OOC bindings.
    for name, entry in pairs(harm) do
        local button = string.gsub(entry.button, "harmbutton", "")
        local key = string.format("%s:%s", entry.modifier, button)
        if not takenBinds.ooc[key] then -- Only bind if it hasn't been bound by OOC above.
            takenBinds.harm[key] = true;
            table.insert(self.ooc_clickset, entry)
        end
    end

    -- Next, add the unit-dependent HELP bindings that don't clash with anything above,
    -- except for HARM which is allowed to "clash" (since help/harm can never conflict ingame).
    for name, entry in pairs(help) do
        local button = string.gsub(entry.button, "helpbutton", "")
        local key = string.format("%s:%s", entry.modifier, button)
        if not takenBinds.ooc[key] then -- Only bind if it hasn't been bound by OOC above.
            takenBinds.help[key] = true;
            table.insert(self.ooc_clickset, entry)
        end
    end

    -- Lastly, add any DEFAULT-set "fallback" bindings which don't clash with the OOC above,
    -- and which hasn't been bound by BOTH "help" and "harm" sets (meaning "default" would
    -- never be able to trigger in that case, so it makes no sense to bind it at all).
    for name, entry in pairs(default) do
        local key = string.format("%s:%s", entry.modifier, entry.button)
        -- Only bind if it HASN'T been bound by OOC above, AND not bound by BOTH "harm" and "help";
        -- it is however TOTALLY OKAY if it's not in OOC but IS in **ONE** OF either "harm" or "help"!
        if not takenBinds.ooc[key] and not (takenBinds.harm[key] and takenBinds.help[key]) then
            table.insert(self.ooc_clickset, entry)
        end
    end

    -- Build a new table of data to show in the tooltip (used if frame-tooltips are enabled).
    self:RebuildTooltipData()
end

function Clique:RegisterFrame(frame)
    if (InCombatLockdown()) then
        self.incombat_registrations[frame] = true -- Will register it after combat.
        return
    end

    local name = frame:GetName()

    if not frame:CanChangeProtectedState() then
        error(string.format("Frame '%s' doesn't allow attribute modification, despite not being in combat.", name), 2) -- This should never happen.
    end

    if name and self.profile.blacklist[name] then
        self:UnregisterFrame(frame) -- We don't allow registration (enabling) of blacklisted frames!
        if CliqueTextListFrame and self.textlist == "FRAMES" and CliqueTextListFrame:IsVisible() then
            Clique:TextListScrollUpdate()
        end
        return
    end

    if not self.ccframes[frame] then
        rawset(self.ccframes, frame, true)
        if CliqueTextListFrame and self.textlist == "FRAMES" and CliqueTextListFrame:IsVisible() then
            Clique:TextListScrollUpdate()
        end
    end

    -- Register "AnyUp" or "AnyDown" on this frame, depending on configuration.
    self:SetClickType(frame)

    -- Apply "out of combat" actions, since we aren't in combat.
    self:UseOOCSet(frame)
end

function Clique:ApplyClickSet(name, frame)
    local set = self.clicksets[name] or name

    if frame then
        for modifier,entry in pairs(set) do
            self:SetAttribute(entry, frame)
        end
    else
        for modifier,entry in pairs(set) do
            self:SetAttributeAllFrames(entry)
        end
    end
end

function Clique:RemoveClickSet(name, frame)
    local set = self.clicksets[name] or name

    if frame then
        for modifier,entry in pairs(set) do
            self:DeleteAttribute(entry, frame)
        end
    else
        for modifier,entry in pairs(set) do
            self:DeleteAttributeAllFrames(entry)
        end
    end
end

function Clique:UnregisterFrame(frame)
    if (InCombatLockdown()) then
        self.incombat_registrations[frame] = false -- Will unregister it after combat.
        return
    end

    local name = frame:GetName()

    if not frame:CanChangeProtectedState() then
        error(string.format("Frame '%s' doesn't allow attribute modification, despite not being in combat.", name), 2) -- This should never happen.
    end

    rawset(self.ccframes, frame, false) -- Important: Remember the given frame with a "false" value, to ensure it exists in ccframes.
    if CliqueTextListFrame and self.textlist == "FRAMES" and CliqueTextListFrame:IsVisible() then
        Clique:TextListScrollUpdate()
    end

    for name,set in pairs(self.clicksets) do
        for modifier,entry in pairs(set) do
            self:DeleteAttribute(entry, frame)
        end
    end

    -- Restore normal "AnyUp" handler on this frame.
    self:SetClickType(frame)
end

function Clique:LinkProfileData()
    -- Set all database links to the profile.
    self.profile = self.db.profile
    self.clicksets = self.profile.clicksets
    self.editSet = self.clicksets[L.CLICKSET_DEFAULT]

    -- Upgrade any outdated data to newer format.
    if (self.profile.tooltips ~= nil) then
        -- The "unit tooltips" setting has been moved from being a per-profile value, to instead
        -- being a per-character value (which is less annoying, since otherwise you'd have to
        -- constantly toggle the option on/off whenever you switch profile). We'll migrate the
        -- setting directly into the matching per-character database, if one already exists.
        -- Otherwise, if the profile name is formatted like a "Character - Realm" profile, then
        -- we'll create the per-character database if it's missing (we may have some false positives
        -- for non-existent characters, but that's no big deal since a character-database is tiny).
        -- NOTE: And yes... if the player was using a custom-named profile such as "Heal Set" or
        -- are using a profile from another character, then we don't auto-migrate "tooltips" into
        -- their current (playing) per-character database here, but they can enable it themselves.
        local charDB = CliqueDB.char[self.db.keys.profile]
        if charDB then
            -- Character database already exists named after this profile. Migrate directly.
            charDB.unitTooltips = self.profile.tooltips
        elseif strlen(self.db.keys.profile) >= 5 and string.find(self.db.keys.profile, " - ") then
            -- The profile name is at least 5 characters long and contains " - ", so we can pretty
            -- safely assume that it's a profile named after a character, such as "Someone - Somerealm",
            -- but they don't have a per-character database yet. We'll therefore create one.
            CliqueDB.char[self.db.keys.profile] = {
                unitTooltips = self.profile.tooltips
            }
        end
        self.profile.tooltips = nil -- Regardless of migration, we'll clear the profile's old value.
    end
end

local function applyCurrentProfile()
    -- Remove existing click bindings.
    for name,set in pairs(Clique.clicksets) do
        Clique:RemoveClickSet(set)
    end
    Clique:RemoveClickSet(Clique.ooc_clickset)

    -- Update our database profile links.
    Clique:LinkProfileData()

    -- Refresh the profile editor if it exists.
    Clique.textlistSelected = nil
    Clique:TextListScrollUpdate()
    Clique:ListScrollUpdate()

    -- Update and apply the clickset.
    Clique:RebuildOOCSet()
    Clique:PLAYER_REGEN_ENABLED()
end

function Clique:DONGLE_PROFILE_CHANGED(event, db, parent, svname, profileKey)
    if db == self.db then
        self:PrintF(L.PROFILE_CHANGED, profileKey)
        applyCurrentProfile()

        -- Ensure Clique window title shows the new profile name.
        if self.UpdateOptionsTitle then
            self:UpdateOptionsTitle()
        end
    end
end

function Clique:DONGLE_PROFILE_COPIED(event, db, parent, svname, copiedFrom, profileKey)
    if db == self.db then
        self:PrintF(L.PROFILE_COPIED, copiedFrom)
        applyCurrentProfile()
    end
end

function Clique:DONGLE_PROFILE_RESET(event, db, parent, svname, profileKey)
    if db == self.db then
        self:PrintF(L.PROFILE_RESET, profileKey)
        applyCurrentProfile()
    end
end


function Clique:DONGLE_PROFILE_DELETED(event, db, parent, svname, profileKey)
    if db == self.db then
        self:PrintF(L.PROFILE_DELETED, profileKey)

        -- Our ACTIVE profile can never be deleted, so we only have to update the profile list window.
        self.textlistSelected = nil
        self:TextListScrollUpdate()
        self:ListScrollUpdate()
    end
end

function Clique:SetAttribute(entry, frame)
    local type, button
    if not tonumber(entry.button) then -- If not purely numeric.
        type, button = select(3, string.find(entry.button, "^(%a+)button(%d+)"))
        frame:SetAttribute(entry.modifier..entry.button, type..button)
        --assert(frame:GetAttribute(entry.modifier..entry.button, type..button)) -- Validate that the attribute was set.
        button = string.format("-%s%s", type, button)
    else
        button = entry.button
    end

    if entry.type == "actionbar" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
    elseif entry.type == "action" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2 or "")
    elseif entry.type == "pet" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2 or "")
    elseif entry.type == "spell" then
        local rank = entry.arg2
        local cast
        if rank then
            if tonumber(rank) then
                -- The rank is a number (pre-2.3) so fill in the format
                cast = L.CAST_FORMAT:format(entry.arg1, rank)
            else
                -- The whole rank string is saved (post-2.3) so use it
                cast = string.format("%s(%s)", entry.arg1, rank)
            end
        else
            cast = entry.arg1
        end

        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."spell"..button, cast)

        frame:SetAttribute(entry.modifier.."bag"..button, entry.arg2)
        frame:SetAttribute(entry.modifier.."slot"..button, entry.arg3)
        frame:SetAttribute(entry.modifier.."item"..button, entry.arg4)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg5 or "")
    elseif entry.type == "item" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."bag"..button, entry.arg1)
        frame:SetAttribute(entry.modifier.."slot"..button, entry.arg2)
        frame:SetAttribute(entry.modifier.."item"..button, entry.arg3)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg4 or "")
    elseif entry.type == "macro" then
        local macro, macroText
        if entry.arg1 then -- Trigger macro slot/index.
            macro = entry.arg1
        else -- Run macro text.
            -- Any "target=clique" will be replaced with the unit that
            -- each bound frame refers to. Such as "target=party1".
            local unit = SecureButton_GetModifiedUnit(frame, entry.modifier.."unit"..button)
            local rawMacro = tostring(entry.arg2)
            if unit and rawMacro then
                macroText = rawMacro:gsub("target%s*=%s*clique", "target="..unit)
            end
        end

        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."macro"..button, macro)
        frame:SetAttribute(entry.modifier.."macrotext"..button, macroText)
    elseif entry.type == "stop" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
    elseif entry.type == "target" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1 or "")
    elseif entry.type == "focus" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1 or "")
    elseif entry.type == "assist" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1 or "")
    elseif entry.type == "click" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
        frame:SetAttribute(entry.modifier.."clickbutton"..button, _G[entry.arg1])
    elseif entry.type == "menu" then
        frame:SetAttribute(entry.modifier.."type"..button, entry.type)
    end
end

function Clique:DeleteAttribute(entry, frame)
    local type, button
    if not tonumber(entry.button) then -- If not purely numeric.
        type, button = select(3, string.find(entry.button, "^(%a+)button(%d+)"))
        frame:SetAttribute(entry.modifier..entry.button, nil)
        button = string.format("-%s%s", type, button)
    else
        button = entry.button
    end

    entry.delete = nil -- Remove variable. Cleans up a legacy Clique bug which always set this to true but never used it anywhere.

    frame:SetAttribute(entry.modifier.."type"..button, nil)
    frame:SetAttribute(entry.modifier..entry.type..button, nil)
end

function Clique:SetAttributeAllFrames(entry)
    for frame,enabled in pairs(self.ccframes) do
        if enabled then
            self:SetAttribute(entry, frame)
        end
    end
end

function Clique:DeleteAttributeAllFrames(entry)
    for frame,enabled in pairs(self.ccframes) do
        self:DeleteAttribute(entry, frame)
    end
end

function Clique:ShowAttributes()
    self:Print("Enabled enhanced debugging.")
    PlayerFrame:SetScript("OnAttributeChanged", function(self, ...) Clique:Print(self:GetName(), ...) end)
    self:Print("Unregistering:")
    self:UnregisterFrame(PlayerFrame)
    self:Print("Registering:")
    self:RegisterFrame(PlayerFrame)
end

Clique.tooltipData = {
    -- Plain sets which contain only the exact bindings described within each set-category.
    -- NOTE: These are mainly used as pre-built tooltip data for building the merged sets...
    -- NOTE: harm ("hostile") means attackable, which includes any attackable neutral NPCs/mobs/critters,
    -- and help ("helpful") means non-attackable, mainly friendly units/players.
    ooc = {},
    default = {},
    harm = {},
    help = {},
    -- Complete, finalized OOC and IN-COMBAT "hostile" and "helpful" sets (with properly merged
    -- data from all relevant sets, in priority-order). As well as "UNIFIED" sets (both help and
    -- harm) for use in the "Clique Bindings" preview window (in unfiltered/"all"-mode).
    merged_ooc_harm = {},
    merged_ooc_help = {},
    merged_ooc_unified = {},
    merged_combat_harm = {},
    merged_combat_help = {},
    merged_combat_unified = {},
}

local function tt_Sort(a, b)
    if a.mod == b.mod then
        return a.unitType < b.unitType -- Sort by type of unit (all/help/harm).
    else
        return a.mod < b.mod -- Sort by modifier text (such as "Shift-LeftButton").
    end
end

local function tt_Build(target, source)
    wipe(target)

    for k,v in pairs(source) do
        local button = Clique:GetButtonText(v.button)
        local mod = string.format("%s%s", v.modifier or "", button)
        local action = string.format("%s (%s)", v.arg1 or "", v.type)
        local unitType = string.match(v.button, "^(h[ea][lr][pm])button")
        if (unitType ~= "help" and unitType ~= "harm") then unitType = "all"; end
        table.insert(target, {mod = mod, action = action, unitType = unitType, fullData = v})
    end

    table.sort(target, tt_Sort)

    return target
end

function Clique:RebuildTooltipData()
    local tt = self.tooltipData

    -- Build the plain OOC, DEFAULT, HARM and HELP tooltip sets. The latter three sets are the IN COMBAT bindings.
    -- NOTE: We mainly build this plain data for use in constructing the other "merged" sets.
    tt_Build(tt.ooc, self.clicksets[L.CLICKSET_OOC])
    tt_Build(tt.default, self.clicksets[L.CLICKSET_DEFAULT])
    tt_Build(tt.harm, self.clicksets[L.CLICKSET_HARMFUL])
    tt_Build(tt.help, self.clicksets[L.CLICKSET_HELPFUL])

    -- Build the "unified" OUT OF COMBAT tooltip set, from the pre-built "ooc_clickset" (which prioritizes "OOC > HELP + HARM > DEFAULT"),
    -- which is ONLY for use in "/clique showbindings". This set accurately contains all keys that are bound while out of combat, and
    -- doesn't even redundantly include any "default (all)" fallback bindings if BOTH harm and help keys are bound already (thus meaning
    -- the "all" fallback binding would be totally unreachable). So it is the cleanest possible data for the unified "showbindings" tooltip.
    tt_Build(tt.merged_ooc_unified, self.ooc_clickset)

    -- Build all of the tooltip sets.
    -- NOTE: This may seem like a lot of work. But even with a HUGE clickset, this WHOLE "RebuildTooltipData" function runs in 1-2 milliseconds.
    local merge_descriptors = {
        -- Now build the "unified" IN COMBAT set, which is ONLY used by "/clique showbindings" to display a compact list of all in-combat
        -- bindings. This uses the "maxSameBinds" feature to ensure that we don't list any "default" keys which are already bound in BOTH
        -- the "harm" AND the "help" sets (which would mean that the "all/default" binding can NEVER run on ANY frames). We achieve this
        -- by saying "add harm/help with -1 limit (unlimited key duplicates allowed; safe since there's no duplicates WITHIN those sets
        -- since both are keyed by their modifier+button combinations)", and then we "add default only if we have less than 2 duplicates",
        -- which in effect means that WHENEVER a key has been bound in BOTH the "harm" and "help" sets, the count will be 2, which means
        -- that the "default" (3rd) key won't be added to the result. The final result is a tooltip-list of ONLY the "all/harm/help"
        -- bindings that will ACTUALLY be reachable in combat! :-)
        {target = tt.merged_combat_unified, sources = {{-1, tt.harm}, {-1, tt.help}, {2, tt.default}}},
        -- Build merged OOC and IN COMBAT "Help" and "Harm" tooltip sets. This is very compact data which we actually show in unitframe
        -- tooltips, since we automatically de-duplicate as follows: For OOC, we follow the same algorithm as "RebuildOOCSet()", which
        -- means that we read the entirety of the OOC set, then any HARM (or HELP) keys that don't clash with OOC, and lastly any
        -- DEFAULT keys which don't clash with *any* of the prior. As for IN COMBAT, we first read the HARM (or HELP) keys, and then
        -- we read any DEFAULT keys which don't clash with the prior. This order of processing is important, since harm/help-button
        -- bindings supercede any normal bindings. So to build the correct tooltip, we must hide the clashes in that exact order.
        --
        -- NOTE: We cannot base our OOC sets on the "ooc_clickset" data, because that set is meant for RAW binding data on the frames
        -- and therefore contains all "default" bindings that WEREN'T bound in BOTH "harm" and "help" (which is the only scenario
        -- where a "default" binding would be totally overridden and unreachable on every unitframe). For any keys where there's ONE
        -- harm OR help binding AND a default binding, the "ooc_clickset" data would say something like "helpbutton1: First Aid,
        -- button1: Cooking", which is intended to be processed as "If you click on a helpful frame, do first aid, otherwise (harm
        -- frames), do cooking", and that's perfect for BINDINGS. But if we used that "ooc_clickset" data for our TOOLTIP, we'd
        -- end up in a situation where our HELP tooltip shows the "First Aid" action (helpbutton1) AND the "Cooking" action (button1),
        -- since neither is marked as "harmful" data. So, instead, we build individual tooltips from scratch below using the OOC set's
        -- priorities, but ONLY using the relevant sets that would be used on specifically harmful or helpful unitframes!
        {target = tt.merged_ooc_harm, sources = {{-1, tt.ooc}, {1, tt.harm}, {1, tt.default}}},
        {target = tt.merged_ooc_help, sources = {{-1, tt.ooc}, {1, tt.help}, {1, tt.default}}},
        {target = tt.merged_combat_harm, sources = {{-1, tt.harm}, {1, tt.default}}},
        {target = tt.merged_combat_help, sources = {{-1, tt.help}, {1, tt.default}}},
    }
    for k,v in ipairs(merge_descriptors) do
        local target = wipe(v.target)

        -- Add non-clashing bindings from all sources, processed in the exact order that the "sources" input table lists them.
        -- NOTE: The order of processing matters, since "harm/help" buttons take priority in WoW over "default" (non-specific) keys.
        local bindCounts = {}
        for sk,sourceInfo in ipairs(v.sources) do
            local maxSameBinds = sourceInfo[1]
            local source = sourceInfo[2]
            for ek,entry in ipairs(source) do
                local button = string.gsub(entry.fullData.button, "^h[ea][lr][pm]button", "")
                local key = string.format("%s:%s", entry.fullData.modifier, button)
                if not bindCounts[key] then bindCounts[key] = 0; end
                if maxSameBinds == -1 or bindCounts[key] < maxSameBinds then
                    bindCounts[key] = bindCounts[key] + 1
                    table.insert(target, entry)
                end
            end
        end

        table.sort(target, tt_Sort)
    end

    -- If Clique's "ShowBindings" tooltip is visible, tell it to forcibly refresh its view of bindings
    -- while preserving its currently active view-type (by sending nil as the first parameter).
    if CliqueTooltip and CliqueTooltip:IsVisible() then
        self:ShowBindings(nil, true)
    end
end

function Clique:AddTooltipLines()
    if not self.db.char.unitTooltips then return end

    local frame = GetMouseFocus()
    if (not frame) or (not self.ccframes[frame]) then return end

    local tt = self.tooltipData
    local unitIsHarmful = UnitCanAttack("player", "mouseover")
    local inCombat = UnitAffectingCombat("player")
    local helpSet = inCombat and tt.merged_combat_help or tt.merged_ooc_help
    local harmSet = inCombat and tt.merged_combat_harm or tt.merged_ooc_harm

    if (not unitIsHarmful) and #helpSet > 0 then
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine(inCombat and "Combat bindings (helpful):" or "Out of combat bindings (helpful):")
        for k,v in ipairs(helpSet) do
            GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
        end
    elseif (unitIsHarmful) and #harmSet > 0 then
        GameTooltip:AddLine(" ");
        GameTooltip:AddLine(inCombat and "Combat bindings (hostile):" or "Out of combat bindings (hostile):")
        for k,v in ipairs(harmSet) do
            GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
        end
    end
end

function Clique:ToggleTooltip()
    self.db.char.unitTooltips = not self.db.char.unitTooltips
    self:PrintF("Showing your active bindings in tooltips has been %s", self.db.char.unitTooltips and "Enabled" or "Disabled")
    if (CliqueOptionsFrame and CliqueOptionsFrame:IsVisible() and CliqueOptionsFrame.refreshOptionsWidgets) then
        CliqueOptionsFrame:refreshOptionsWidgets(); -- Update the "Options" window state to reflect the change.
    end
end

function Clique:ShowBindings(viewType, forceShow)
    -- Determine which view-type to use, and whether the type has changed since last function call.
    -- NOTE: When called via "/clique showbindings", the first parameter is always "showbindings" which we
    -- translate to "show everything" below. That's intentional, to ensure the slash-cmd always shows ALL data.
    local isChanged = false
    if not viewType then
        viewType = self.showBindingsViewType or "" -- Re-use the last active view-type.
    end
    if (viewType ~= "harm" and viewType ~= "help" and viewType ~= "") then viewType = ""; end -- Validate.
    if self.showBindingsViewType ~= viewType then
        isChanged = true
        self.showBindingsViewType = viewType
    end

    -- If the view-type hasn't changed and the tooltip is visible, toggle it (hide it) again, unless forceShow.
    if (not isChanged) and (not forceShow) and CliqueTooltip and CliqueTooltip:IsVisible() then
        CliqueTooltip:Hide()
        return
    end

    if not CliqueTooltip then
        CliqueTooltip = CreateFrame("GameTooltip", "CliqueTooltip", UIParent, "GameTooltipTemplate")
        CliqueTooltip:SetPoint("CENTER", 0, 0)
        CliqueTooltip.close = CreateFrame("Button", nil, CliqueTooltip)
        CliqueTooltip.close:SetHeight(32)
        CliqueTooltip.close:SetWidth(32)
        CliqueTooltip.close:SetPoint("TOPRIGHT", 1, 0)
        CliqueTooltip.close:SetScript("OnClick", function()
            CliqueTooltip:Hide()
        end)
        CliqueTooltip.close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        CliqueTooltip.close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        CliqueTooltip.close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

        CliqueTooltip:EnableMouse()
        CliqueTooltip:SetMovable()
        CliqueTooltip:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
        CliqueTooltip:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);

        CliqueTooltip:RegisterForDrag("LeftButton")
        CliqueTooltip:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        CliqueTooltip:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            ValidateFramePosition(self)
        end)
        CliqueTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    end

    if not CliqueTooltip:IsShown() then
        CliqueTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    end

    -- Describe any active view-type directly in the tooltip header.
    local viewDescription = (viewType == "harm" and "Hostile") or (viewType == "help" and "Helpful") or ""
    CliqueTooltip:SetText("Clique Bindings" .. (viewDescription ~= "" and string.format(": %s", viewDescription) or ""))

    -- Output ALL configured combat and out-of-combat bindings... with optional view-type to only show hostile or helpful unit actions.
    -- NOTE: Because we need to display both the helpful and harmful bindings in a SINGLE, unified list (to avoid making
    -- the tooltip too tall vertically), we'll suffix every binding with "all"/"harm"/"help" to indicate unit type.
    -- NOTE: We use the non-unified tables when we view specific harm/help listings. Otherwise we'd get problems with bindings that contain
    -- one "default (all)" action and one harm or help action on the same key. In a case such as "help + all" being bound (where "all"
    -- would only run on harm-unitframes), there would be no way for us to know that the "all" would only run on harmful units, and we'd
    -- therefore wrongly output BOTH the "help" AND the "all" action below since we'd have no way to filter out which one to show (there
    -- isn't even any guaranteed order of items in the table; the "all" action can be before the "harm" action, so we can't even analyze
    -- the data that way). So instead, we switch our whole view into DIRECTLY seeing the harm/help-specific tables used for unit-tooltips!
    local tt = self.tooltipData
    local sections = {
        {title = "Combat bindings", sources = {all = tt.merged_combat_unified, harm = tt.merged_combat_harm, help = tt.merged_combat_help}},
        {title = "Out of combat bindings", sources = {all = tt.merged_ooc_unified, harm = tt.merged_ooc_harm, help = tt.merged_ooc_help}},
    }
    local viewSource = (viewType == "harm" or viewType == "help") and viewType or "all"
    for i,section in ipairs(sections) do
        CliqueTooltip:AddLine(" ")
        CliqueTooltip:AddLine(section.title .. (viewDescription ~= "" and string.format(" (%s)", string.lower(viewDescription)) or "") .. ":")
        local hasBindings = section.sources[viewSource] and section.sources[viewSource][1] ~= nil; -- Check if 1st entry exists in numeric table.
        if hasBindings then
            for k,v in ipairs(section.sources[viewSource]) do
                CliqueTooltip:AddDoubleLine(string.format("%s (%s)", v.mod, v.unitType), v.action, 1, 1, 1, 1, 1, 1)
            end
        else
            CliqueTooltip:AddLine("Empty.", 1, 1, 1)
        end
    end

    CliqueTooltip:Show()
end

function Clique:SetClickType(frame)
    -- NOTE: RegisterForClicks overwrites the previous registration, thus ensuring only one click-type is active.
    local clickType = Clique.db.char.downClick and "AnyDown" or "AnyUp"
    if frame then
        if not self.ccframes[frame] then clickType = "AnyUp" end -- Restore normal "AnyUp" since we don't use this frame.
        frame:RegisterForClicks(clickType)
    else
        for frame, enabled in pairs(self.ccframes) do
            if enabled then
                frame:RegisterForClicks(clickType)
            else
                frame:RegisterForClicks("AnyUp") -- Restore normal "AnyUp" since we don't use this frame.
            end
        end
    end
end
