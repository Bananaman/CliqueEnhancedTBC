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
			tooltips = false,
		},
        -- Char: Values which are independently stored per-character, regardless of which profile each character uses.
        char = {
            downClick = false,
            easterEgg = false,
        },
	}
	
	self.db = self:InitializeDB("CliqueDB", self.defaults)
	self.profile = self.db.profile
	self.clicksets = self.profile.clicksets

    self.editSet = self.clicksets[L.CLICKSET_DEFAULT]

    -- Dynamically built to hold all actions that will be registered while out of combat.
    self.ooc_clickset = {}

    -- We MUST build the ooc_clickset here, to ensure it gets applied to all subsequent frame registrations.
    self:RebuildOOCSet()

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

    local id = SpellBook_GetSpellID(this:GetParent():GetID());
    local texture = GetSpellTexture(id, SpellBookFrame.bookType)
    local name, rank = GetSpellName(id, SpellBookFrame.bookType)

    if rank == L.RACIAL_PASSIVE or rank == L.PASSIVE then
		StaticPopup_Show("CLIQUE_PASSIVE_SKILL")
		return
    end
    
    local type = "spell"

	if self.editSet == self.clicksets[L.CLICKSET_HARMFUL] then
		button = string.format("%s%d", "harmbutton", self:GetButtonNumber(button))
	elseif self.editSet == self.clicksets[L.CLICKSET_HELPFUL] then
		button = string.format("%s%d", "helpbutton", self:GetButtonNumber(button))
	else
		button = self:GetButtonNumber(button)
	end

    -- Skip this click if binding wasn't detected properly.
    if button == "" then return; end

    -- Build the structure
    local t = {
		["button"] = button,
		["modifier"] = self:GetModifierText(),
		["texture"] = GetSpellTexture(id, SpellBookFrame.bookType),
		["type"] = type,
		["arg1"] = name,
		["arg2"] = rank,
    }

    -- Enforce string keys for CheckBinding purposes, which uses "type+value" equality to detect duplicates.
    -- NOTE: Technically, t.modifier is always a string/empty string, so the result is always
    -- a string even if "button" is numeric. But we want to be 100000% sure that it's a string!
    local key = tostring(t.modifier .. t.button)
    
    if self:CheckBinding(key) then
		StaticPopup_Show("CLIQUE_BINDING_PROBLEM")
		return
    end
    
    self.editSet[key] = t
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
	local name = frame:GetName()

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

	if frame:CanChangeProtectedState() then
		if InCombatLockdown() then
			self:UseCombatSet(frame)
		else
			self:UseOOCSet(frame)
		end
	end
end

function Clique:ApplyClickSet(name, frame)
	local set = self.clicksets[name] or name

	if frame then
		for modifier,entry in pairs(set) do
			self:SetAttribute(entry, frame)
		end
	else
		for modifier,entry in pairs(set) do
			self:SetAction(entry)
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
			self:DeleteAction(entry)
		end
	end					
end

function Clique:UnregisterFrame(frame)
	assert(not InCombatLockdown(), "An addon attempted to unregister a frame from Clique while in combat.")

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

local function applyCurrentProfile()
    -- Remove existing click bindings.
    for name,set in pairs(Clique.clicksets) do
        Clique:RemoveClickSet(set)
    end
    Clique:RemoveClickSet(Clique.ooc_clickset)

    -- Update our database profile links.
    Clique.profile = Clique.db.profile
    Clique.clicksets = Clique.profile.clicksets
    Clique.editSet = Clique.clicksets[L.CLICKSET_DEFAULT]
    Clique.profileKey = profileKey

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
	local name = frame:GetName()

	-- Set up any special attributes
	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		frame:SetAttribute(entry.modifier..entry.button, type..button)
		assert(frame:GetAttribute(entry.modifier..entry.button, type..button))
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	if entry.type == "actionbar" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)		
	elseif entry.type == "action" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		if entry.arg2 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
		end
	elseif entry.type == "pet" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."action"..button, entry.arg1)
		if entry.arg2 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg2)
		end
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
		if entry.arg5 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg5)
		end
	elseif entry.type == "item" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."bag"..button, entry.arg1)
		frame:SetAttribute(entry.modifier.."slot"..button, entry.arg2)
		frame:SetAttribute(entry.modifier.."item"..button, entry.arg3)
		if entry.arg4 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg4)
		end
	elseif entry.type == "macro" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."macro"..button, entry.arg1)
		else
			local unit = SecureButton_GetModifiedUnit(frame, entry.modifier.."unit"..button)
			local macro = tostring(entry.arg2)
			if unit and macro then
				macro = macro:gsub("target%s*=%s*clique", "target="..unit)
			end

			frame:SetAttribute(entry.modifier.."macro"..button, nil)
			frame:SetAttribute(entry.modifier.."macrotext"..button, macro)
		end
	elseif entry.type == "stop" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	elseif entry.type == "target" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "focus" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "assist" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		if entry.arg1 then
			frame:SetAttribute(entry.modifier.."unit"..button, entry.arg1)
		end
	elseif entry.type == "click" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
		frame:SetAttribute(entry.modifier.."clickbutton"..button, _G[entry.arg1])
	elseif entry.type == "menu" then
		frame:SetAttribute(entry.modifier.."type"..button, entry.type)
	end
end

function Clique:DeleteAttribute(entry, frame)
	local name = frame:GetName()

	local type,button,value

	if not tonumber(entry.button) then
		type,button = select(3, string.find(entry.button, "(%a+)button(%d+)"))
		frame:SetAttribute(entry.modifier..entry.button, nil)
		button = string.format("-%s%s", type, button)
	end

	button = button or entry.button

	entry.delete = true

	frame:SetAttribute(entry.modifier.."type"..button, nil)
	frame:SetAttribute(entry.modifier..entry.type..button, nil)
end

function Clique:SetAction(entry)
	for frame,enabled in pairs(self.ccframes) do
		if enabled then
			self:SetAttribute(entry, frame)
		end
	end
end

function Clique:DeleteAction(entry)
	for frame in pairs(self.ccframes) do
		self:DeleteAttribute(entry, frame)
	end
end

function Clique:ShowAttributes()
	self:Print("Enabled enhanced debugging.")
	PlayerFrame:SetScript("OnAttributeChanged", function(...) self:Print(...) end)
	self:Print("Unregistering:")
	self:UnregisterFrame(PlayerFrame)
	self:Print("Registering:")
	self:RegisterFrame(PlayerFrame)
end

local tt_ooc = {}
local tt_help = {}
local tt_harm = {}
local tt_default = {}

function Clique:RebuildTooltipData()
	local ooc = self.ooc_clickset
	local default = self.clicksets[L.CLICKSET_DEFAULT]
	local harm = self.clicksets[L.CLICKSET_HARMFUL]
	local help = self.clicksets[L.CLICKSET_HELPFUL]

	for k,v in pairs(tt_ooc) do tt_ooc[k] = nil end
	for k,v in pairs(tt_help) do tt_help[k] = nil end
	for k,v in pairs(tt_harm) do tt_harm[k] = nil end
	for k,v in pairs(tt_default) do tt_default[k] = nil end

	-- Build the ooc lines, which includes both helpful and harmful
	for k,v in pairs(ooc) do
		local button = self:GetButtonText(v.button)
		local mod = string.format("%s%s", v.modifier or "", button)
		local action = string.format("%s (%s)", v.arg1 or "", v.type)
		table.insert(tt_ooc, {mod = mod, action = action})
	end

	-- Build the default lines
	for k,v in pairs(default) do
		local button = self:GetButtonText(v.button)
		local mod = string.format("%s%s", v.modifier or "", button)
		local action = string.format("%s (%s)", v.arg1 or "", v.type)
		table.insert(tt_default, {mod = mod, action = action})
	end

	-- Build the harm lines
	for k,v in pairs(harm) do
		local button = self:GetButtonText(v.button)
		local mod = string.format("%s%s", v.modifier or "", button)
		local action = string.format("%s (%s)", v.arg1 or "", v.type)
		table.insert(tt_harm, {mod = mod, action = action})
	end

	-- Build the help lines
	for k,v in pairs(help) do
		local button = self:GetButtonText(v.button)
		local mod = string.format("%s%s", v.modifier or "", button)
		local action = string.format("%s (%s)", v.arg1 or "", v.type)
		table.insert(tt_help, {mod = mod, action = action})
	end

	local function sort(a,b) 
		return a.mod < b.mod
	end

	table.sort(tt_ooc, sort)
	table.sort(tt_default, sort)
	table.sort(tt_harm, sort)
	table.sort(tt_help, sort)
end
	
function Clique:AddTooltipLines()
	if not self.profile.tooltips then return end

	local frame = GetMouseFocus()
	if not frame then return end
	if not self.ccframes[frame] then return end

	-- Add a buffer line
	GameTooltip:AddLine(" ")
	if UnitAffectingCombat("player") then
		if #tt_default ~= 0 then
			GameTooltip:AddLine("Default bindings:")
			for k,v in ipairs(tt_default) do
				GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
			end
		end

		if #tt_help ~= 0 and not UnitCanAttack("player", "mouseover") then
			GameTooltip:AddLine("Helpful bindings:")
			for k,v in ipairs(tt_help) do
				GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
			end
		end

		if #tt_harm ~= 0 and UnitCanAttack("player", "mouseover") then
			GameTooltip:AddLine("Hostile bindings:")
			for k,v in ipairs(tt_harm) do
				GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
			end
		end
	else
		if #tt_ooc ~= 0 then
			GameTooltip:AddLine("Out of combat bindings:")
			for k,v in ipairs(tt_ooc) do
				GameTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
			end
		end
	end
end

function Clique:ToggleTooltip()
	self.profile.tooltips = not self.profile.tooltips
	self:PrintF("Listing of bindings in tooltips has been %s", 
	self.profile.tooltips and "Enabled" or "Disabled")
end

function Clique:ShowBindings()
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
		CliqueTooltip:SetPadding(16)
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
	
	-- Actually fill it with the bindings
	CliqueTooltip:SetText("Clique Bindings")

	if #tt_default > 0 then
		CliqueTooltip:AddLine(" ")
		CliqueTooltip:AddLine("Default bindings:")
		for k,v in ipairs(tt_default) do
			CliqueTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
		end
	end

	if #tt_help > 0 then
		CliqueTooltip:AddLine(" ")
		CliqueTooltip:AddLine("Helpful bindings:")
		for k,v in ipairs(tt_help) do
			CliqueTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
		end
	end

	if #tt_harm > 0 then
		CliqueTooltip:AddLine(" ")
		CliqueTooltip:AddLine("Hostile bindings:")
		for k,v in ipairs(tt_harm) do
			CliqueTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
		end
	end
		
	if #tt_ooc > 0 then
		CliqueTooltip:AddLine(" ")
		CliqueTooltip:AddLine("Out of combat bindings:")
		for k,v in ipairs(tt_ooc) do
			CliqueTooltip:AddDoubleLine(v.mod, v.action, 1, 1, 1, 1, 1, 1)
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
