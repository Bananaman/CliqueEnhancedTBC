local genv = getfenv(0)
local Clique = genv.Clique
local L = Clique.Locals
local StaticPopupDialogs = genv.StaticPopupDialogs
local TEXT = genv.TEXT
local OKAY = genv.OKAY
local CANCEL = genv.CANCEL
local GameTooltip = genv.GameTooltip
local pairs = genv.pairs

local NUM_ENTRIES = 10
local ENTRY_SIZE = 35
local work = {}

function Clique:OptionsOnLoad()
    -- Create a set of buttons to hook the SpellbookFrame
    self.spellbuttons = {}
    local onclick = function(frame, button) Clique:SpellBookButtonPressed(frame, button) end
    local onleave = function(button)
        button.updateTooltip = nil
        GameTooltip:Hide()
    end

    for i=1,12 do
        local parent = _G["SpellButton"..i]
        local button = CreateFrame("Button", "SpellButtonCliqueCover"..i, parent)
        button:SetID(parent:GetID())
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:RegisterForClicks("AnyUp")
        button:SetAllPoints(parent)
        button:SetScript("OnClick", onclick)
        local highlightTexture = button:GetHighlightTexture()
        button:SetScript("OnEnter", function(self)
            if parent:IsEnabled() == 1 then
                highlightTexture:Show()
                SpellButton_OnEnter(parent)
            else
                highlightTexture:Hide()
            end
        end)
        button:SetScript("OnLeave", onleave)

        button:Hide()
        self.spellbuttons[i] = button
    end

    CreateFrame("CheckButton", "CliquePulloutTab", SpellBookFrame, "SpellBookSkillLineTabTemplate")
    CliquePulloutTab:SetNormalTexture("Interface\\AddOns\\Clique\\Images\\CliqueIcon")
    CliquePulloutTab:SetScript("OnClick", function() Clique:Toggle() end)
    CliquePulloutTab:SetScript("OnEnter", function() local i = 1 end)
    CliquePulloutTab:SetScript("OnShow", function()
        Clique.inuse = false
        for k,v in pairs(self.clicksets) do
            if next(v) then -- Contains elements.
                Clique.inuse = true
                break
            end
        end
        if not Clique.inuse then
            CliqueFlashFrame.texture:Show()
            CliqueFlashFrame.texture:SetAlpha(1.0)

            local counter, loops, fading = 0, 0, true
            CliqueFlashFrame:SetScript("OnUpdate", function(self, elapsed)
                counter = counter + elapsed
                if counter > 0.5 then
                    loops = loops + 0.5
                    fading = not fading
                    counter = counter - 0.5
                end

                if loops > 30 then
                    self.texture:Hide()
                    self:SetScript("OnUpdate", nil)
                    return
                end

                local texture = self.texture
                if fading then
                    texture:SetAlpha(1.0 - (counter / 0.5))
                else
                    texture:SetAlpha(counter / 0.5)
                end
            end)
        end
    end)
    CliquePulloutTab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Clique Configuration")
        GameTooltip:Show()
    end)

    local frame = CreateFrame("Frame", "CliqueFlashFrame", CliquePulloutTab)
    frame:SetWidth(10) frame:SetHeight(10)
    frame:SetPoint("CENTER", 0, 0)

    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    texture:SetHeight(64) texture:SetWidth(64)
    texture:SetPoint("CENTER", 0, 0)
    texture:Hide()
    CliqueFlashFrame.texture = texture

    CliquePulloutTab:Show()

    -- Hook the container buttons
    local containerFunc = function(button)
        if IsShiftKeyDown() and CliqueCustomArg1 then
            if CliqueCustomArg1:HasFocus() then
                CliqueCustomArg1:Insert(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
            elseif CliqueCustomArg2:HasFocus() then
                CliqueCustomArg2:Insert(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
            elseif CliqueCustomArg3:HasFocus() then
                CliqueCustomArg3:Insert(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
            elseif CliqueCustomArg4:HasFocus() then
                CliqueCustomArg4:Insert(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
            elseif CliqueCustomArg5:HasFocus() then
                CliqueCustomArg5:Insert(GetContainerItemLink(this:GetParent():GetID(), this:GetID()))
            end
        end
    end

    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", containerFunc)

    -- Hook the bank buttons
    local bankFunc = function(button)
        if IsShiftKeyDown() and CliqueCustomArg1 then
            if CliqueCustomArg1:HasFocus() then
                CliqueCustomArg1:Insert(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
            elseif CliqueCustomArg2:HasFocus() then
                CliqueCustomArg2:Insert(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
            elseif CliqueCustomArg3:HasFocus() then
                CliqueCustomArg3:Insert(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
            elseif CliqueCustomArg4:HasFocus() then
                CliqueCustomArg4:Insert(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
            elseif CliqueCustomArg5:HasFocus() then
                CliqueCustomArg5:Insert(GetContainerItemLink(BANK_CONTAINER, this:GetID()))
            end
        end
    end

    hooksecurefunc("BankFrameItemButtonGeneric_OnModifiedClick", bankFunc)

    -- Hook the paper doll frame buttons
    local dollFunc = function(button)
        if IsShiftKeyDown() and CliqueCustomArg1 then
            if CliqueCustomArg1:HasFocus() then
                CliqueCustomArg1:Insert(GetInventoryItemLink("player", this:GetID()))
            elseif CliqueCustomArg2:HasFocus() then
                CliqueCustomArg2:Insert(GetInventoryItemLink("player", this:GetID()))
            elseif CliqueCustomArg3:HasFocus() then
                CliqueCustomArg3:Insert(GetInventoryItemLink("player", this:GetID()))
            elseif CliqueCustomArg4:HasFocus() then
                CliqueCustomArg4:Insert(GetInventoryItemLink("player", this:GetID()))
            elseif CliqueCustomArg5:HasFocus() then
                CliqueCustomArg5:Insert(GetInventoryItemLink("player", this:GetID()))
            end
        end
    end
    hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", dollFunc)
end

function Clique:LEARNED_SPELL_IN_TAB()
    local num = GetNumSpellTabs()
    CliquePulloutTab:ClearAllPoints()
    CliquePulloutTab:SetPoint("TOPLEFT","SpellBookSkillLineTab"..(num),"BOTTOMLEFT",0,-17)
end

function Clique:ToggleSpellBookButtons()
    local method = CliqueFrame:IsVisible() and "Show" or "Hide"
    local buttons = self.spellbuttons
    for i=1,12 do
        buttons[i][method](buttons[i])
    end
end

function Clique:Toggle()
    if not CliqueFrame then
        Clique:CreateOptionsFrame()
        CliqueFrame:Hide()
        CliqueFrame:Show()
    else
        if CliqueFrame:IsVisible() then
            CliqueFrame:Hide()
            CliquePulloutTab:SetChecked(nil)
        else
            CliqueFrame:Show()
            CliquePulloutTab:SetChecked(true)
        end
    end

    Clique:ToggleSpellBookButtons()
    self:ListScrollUpdate()
end

-- This code is contributed with permission from Beladona
local ondragstart = function(self)
    self:GetParent():StartMoving()
end

local ondragstop = function(self)
    self:GetParent():StopMovingOrSizing()
    self:GetParent():SetUserPlaced()
end

function Clique:SkinFrame(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\AddOns\\Clique\\images\\backdrop.tga",
        edgeFile = "Interface\\AddOns\\Clique\\images\\borders.tga", tile = true,
        tileSize = 32, edgeSize = 16,
        insets = {left = 16, right = 16, top = 16, bottom = 16}
    });

    frame:EnableMouse()
    frame:SetClampedToScreen(true)

    frame.titleBar = CreateFrame("Button", nil, frame)
    frame.titleBar:SetHeight(32)
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
    frame.titleBar:RegisterForDrag("LeftButton")
    frame.titleBar:SetScript("OnDragStart", ondragstart)
    frame.titleBar:SetScript("OnDragStop", ondragstop)

    frame.headerLeft = frame.titleBar:CreateTexture(nil, "ARTWORK");
    frame.headerLeft:SetTexture("Interface\\AddOns\\Clique\\images\\headCorner.tga");
    frame.headerLeft:SetWidth(32); frame.headerLeft:SetHeight(32);
    frame.headerLeft:SetPoint("TOPLEFT", 0, 0);

    frame.headerRight = frame.titleBar:CreateTexture(nil, "ARTWORK");
    frame.headerRight:SetTexture("Interface\\AddOns\\Clique\\images\\headCorner.tga");
    frame.headerRight:SetTexCoord(1,0,0,1);
    frame.headerRight:SetWidth(32); frame.headerRight:SetHeight(32);
    frame.headerRight:SetPoint("TOPRIGHT", 0, 0);

    frame.header = frame.titleBar:CreateTexture(nil, "ARTWORK");
    frame.header:SetTexture("Interface\\AddOns\\Clique\\images\\header.tga");
    frame.header:SetPoint("TOPLEFT", frame.headerLeft, "TOPRIGHT");
    frame.header:SetPoint("BOTTOMRIGHT", frame.headerRight, "BOTTOMLEFT");

    frame.title = frame.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    frame.title:SetHeight(16);
    frame.title:SetPoint("TOPLEFT", 32, -2); -- NOTE: "32" ensures we don't overlap close-buttons.
    frame.title:SetPoint("TOPRIGHT", -32, -2);
    frame.title:SetJustifyH("CENTER");
    frame.title:SetJustifyV("MIDDLE");

    frame.footerLeft = frame:CreateTexture(nil, "ARTWORK");
    frame.footerLeft:SetTexture("Interface\\AddOns\\Clique\\images\\footCorner.tga");
    frame.footerLeft:SetWidth(48); frame.footerLeft:SetHeight(48);
    frame.footerLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2);

    frame.footerRight = frame:CreateTexture(nil, "ARTWORK");
    frame.footerRight:SetTexture("Interface\\AddOns\\Clique\\images\\footCorner.tga");
    frame.footerRight:SetTexCoord(1,0,0,1);
    frame.footerRight:SetWidth(48); frame.footerRight:SetHeight(48);
    frame.footerRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2);

    frame.footer = frame:CreateTexture(nil, "ARTWORK");
    frame.footer:SetTexture("Interface\\AddOns\\Clique\\images\\footer.tga");
    frame.footer:SetPoint("TOPLEFT", frame.footerLeft, "TOPRIGHT");
    frame.footer:SetPoint("BOTTOMRIGHT", frame.footerRight, "BOTTOMLEFT");
end

function Clique:UpdateOptionsTitle()
    if (not CliqueFrame) or (not CliqueFrame.title) then return end
    CliqueFrame.title:SetText("Clique Enhanced v. " .. Clique.version .. " - " .. tostring(Clique.db.keys.profile));
end

function Clique:CreateOptionsFrame()
    local frames = {}
    self.frames = frames

    local frame = CreateFrame("Frame", "CliqueFrame", SpellBookFrame)
    frame:SetHeight(415)
    frame:SetWidth(400)
    frame:SetPoint("LEFT", SpellBookFrame, "RIGHT", 15, 30)
    self:SkinFrame(frame)
    frame:SetToplevel(true)

    frame:SetScript("OnShow", function(self)
        if InCombatLockdown() then
            Clique:Toggle()
            return
        end
        local parent = self:GetParent()
        self:SetFrameLevel(parent:GetFrameLevel() + 5)
        Clique:UpdateOptionsTitle()
        Clique:ToggleSpellBookButtons()
    end)

    CliqueFrame:SetScript("OnHide", function() Clique:ToggleSpellBookButtons() end)
    CliqueFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    CliqueFrame:SetScript("OnEvent", function(self, event, ...)
        if self:IsVisible() then
            Clique:Toggle()
        end
    end)

    local frame = CreateFrame("Frame", "CliqueListFrame", CliqueFrame)
    frame:SetAllPoints()

    local onclick = function(button)
        local offset = FauxScrollFrame_GetOffset(CliqueListScroll)
        self.listSelected = offset + button.id
        Clique:ListScrollUpdate()
    end

    local ondoubleclick = function(button)
        onclick(button)
        CliqueButtonEdit:Click()
    end

    local onenter = function(button) button:SetBackdropBorderColor(1, 1, 1) end
    local onleave = function(button)
        local selected = FauxScrollFrame_GetOffset(CliqueListScroll) + button.id
        if selected == self.listSelected then
            button:SetBackdropBorderColor(1, 1, 0)
        else
            button:SetBackdropBorderColor(0.3, 0.3, 0.3)
        end
    end

    for i=1,NUM_ENTRIES do
        local entry = CreateFrame("Button", "CliqueList"..i, frame)
        entry.id = i
        entry:SetHeight(ENTRY_SIZE)
        entry:SetWidth(390)
        entry:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 16,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        })

        entry:SetBackdropBorderColor(0.3, 0.3, 0.3)
        entry:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
        entry:SetScript("OnClick", onclick)
        entry:SetScript("OnEnter", onenter)
        entry:SetScript("OnLeave", onleave)
        entry:SetScript("OnDoubleClick", ondoubleclick)

        entry.icon = entry:CreateTexture(nil, "ARTWORK")
        entry.icon:SetHeight(24)
        entry.icon:SetWidth(24)
        entry.icon:SetPoint("LEFT", 5, 0)

        entry.name = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        entry.name:SetPoint("LEFT", entry.icon, "RIGHT", 5, 0)

        entry.binding = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        entry.binding:SetPoint("RIGHT", entry, "RIGHT", -5, 0)
        frames[i] = entry
    end

    frames[1]:SetPoint("TOPLEFT", 5, -55)
    for i=2,NUM_ENTRIES do
        frames[i]:SetPoint("TOP", frames[i-1], "BOTTOM", 0, 2)
    end

    local endButton = _G["CliqueList"..NUM_ENTRIES]
    CreateFrame("ScrollFrame", "CliqueListScroll", CliqueListFrame, "FauxScrollFrameTemplate")
    CliqueListScroll:SetPoint("TOPLEFT", CliqueList1, "TOPLEFT", 0, 0)
    CliqueListScroll:SetPoint("BOTTOMRIGHT", endButton, "BOTTOMRIGHT", 0, 0)

    local texture = CliqueListScroll:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueListScroll, "TOPRIGHT", 14, 0)
    texture:SetPoint("BOTTOMRIGHT", CliqueListScroll, "BOTTOMRIGHT", 23, 0)
    texture:SetGradientAlpha("HORIZONTAL", 0.5, 0.25, 0.05, 0, 0.15, 0.15, 0.15, 1)

    local texture = CliqueListScroll:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueListScroll, "TOPRIGHT", 4, 0)
    texture:SetPoint("BOTTOMRIGHT", CliqueListScroll, "BOTTOMRIGHT", 14, 0)
    texture:SetGradientAlpha("HORIZONTAL", 0.15, 0.15, 0.15, 0.15, 1, 0.5, 0.25, 0.05, 0)

    local update = function() Clique:ListScrollUpdate() end

    CliqueListScroll:SetScript("OnVerticalScroll", update, function(self, offset)
        FauxScrollFrame_OnVerticalScroll(ENTRY_SIZE, update)
    end)

    CliqueListScroll:SetScript("OnShow", update)

    local frame = CreateFrame("Frame", "CliqueTextListFrame", CliqueFrame)
    frame:SetHeight(300)
    frame:SetWidth(250)
    frame:SetPoint("BOTTOMLEFT", CliqueFrame, "BOTTOMRIGHT", 0, 0)
    self:SkinFrame(frame)
    frame:SetFrameStrata("HIGH")

    frame:SetScript("OnShow", function(self)
        local parent = self:GetParent()
        self:SetFrameLevel(parent:GetFrameLevel() + 5)
    end)

    local onclick = function(button)
        local offset = FauxScrollFrame_GetOffset(CliqueTextListScroll)
        if self.textlistSelected == offset + button.id then
            self.textlistSelected = nil
        else
            self.textlistSelected = offset + button.id
        end
        if self.textlist == "FRAMES" then
            local name = button.realValue
            local frame = _G[name]
            if button:GetChecked() then
                self.profile.blacklist[name] = nil
                self:RegisterFrame(frame)
            else
                self.profile.blacklist[name] = true
                self:UnregisterFrame(frame)
            end
        end
        Clique:TextListScrollUpdate()
    end

    local onenter = function(button) button:SetBackdropBorderColor(1, 1, 1) end
    local onleave = function(button)
        local selected = FauxScrollFrame_GetOffset(CliqueTextListScroll) + button.id
        button:SetBackdropBorderColor(0.3, 0.3, 0.3)
    end

    local frames = {}

    for i=1,12 do
        local entry = CreateFrame("CheckButton", "CliqueTextList"..i, frame)
        entry.id = i
        entry:SetHeight(22)
        entry:SetWidth(240)
        entry:SetBackdrop({
            --bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            --edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            --tile = true, tileSize = 8, edgeSize = 16,
            insets = {left = 2, right = 2, top = 2, bottom = 2}
        })

        entry:SetBackdropBorderColor(0.3, 0.3, 0.3)
        entry:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
        entry:SetScript("OnClick", onclick)
        entry:SetScript("OnEnter", onenter)
        entry:SetScript("OnLeave", onleave)

        local texture = entry:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        entry:SetNormalTexture(texture)

        local texture = entry:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        texture:SetBlendMode("ADD")
        entry:SetHighlightTexture(texture)

        local texture = entry:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        entry:SetCheckedTexture(texture)

        entry.name = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        entry.name:SetPoint("LEFT", 25, 0)
        entry.name:SetJustifyH("LEFT")
        entry.name:SetText("Profile Name")
        frames[i] = entry
    end

    frames[1]:SetPoint("TOPLEFT", 5, -25)
    for i=2,12 do
        frames[i]:SetPoint("TOP", frames[i-1], "BOTTOM", 0, 2)
    end

    local endButton = CliqueTextList12
    CreateFrame("ScrollFrame", "CliqueTextListScroll", CliqueTextListFrame, "FauxScrollFrameTemplate")
    CliqueTextListScroll:SetPoint("TOPLEFT", CliqueTextList1, "TOPLEFT", 0, 0)
    CliqueTextListScroll:SetPoint("BOTTOMRIGHT", endButton, "BOTTOMRIGHT", 0, 0)

    local texture = CliqueTextListScroll:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueTextListScroll, "TOPRIGHT", 14, 0)
    texture:SetPoint("BOTTOMRIGHT", CliqueTextListScroll, "BOTTOMRIGHT", 23, 0)
    texture:SetGradientAlpha("HORIZONTAL", 0.5, 0.25, 0.05, 0, 0.15, 0.15, 0.15, 1)

    local texture = CliqueTextListScroll:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueTextListScroll, "TOPRIGHT", 4, 0)
    texture:SetPoint("BOTTOMRIGHT", CliqueTextListScroll, "BOTTOMRIGHT", 14, 0)
    texture:SetGradientAlpha("HORIZONTAL", 0.15, 0.15, 0.15, 0.15, 1, 0.5, 0.25, 0.05, 0)

    local update = function()
        Clique:TextListScrollUpdate()
    end

    CliqueTextListScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(22, update)
    end)
    CliqueTextListFrame:SetScript("OnShow", update)
    CliqueTextListFrame:Hide()

    -- Dropdown Frame
    CreateFrame("Frame", "CliqueDropDown", CliqueFrame, "UIDropDownMenuTemplate")
    CliqueDropDown:SetID(1)
    CliqueDropDown:SetPoint("TOPRIGHT", -115, -25)
    CliqueDropDown:SetScript("OnShow", function(self) Clique:DropDown_OnShow(self) end)

    CliqueDropDownButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L.CLICKSET_DROPDOWN_HELP)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.COMBAT_PRIORITY_HELP1)
        GameTooltip:AddLine(L.COMBAT_PRIORITY_HELP2, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.OOC_PRIORITY_HELP1)
        GameTooltip:AddLine(L.OOC_PRIORITY_HELP2, 1, 1, 1)
        GameTooltip:Show()
    end)
    CliqueDropDownButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local font = CliqueDropDown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    font:SetText("Click Set:")
    font:SetPoint("RIGHT", CliqueDropDown, "LEFT", 5, 3)
    -- Button Creations
    local buttonFunc = function(self, button) Clique:ButtonOnClick(self, button) end

    local button = CreateFrame("Button", "CliqueButtonClose", CliqueFrame.titleBar, "UIPanelCloseButton")
    button:SetHeight(25)
    button:SetWidth(25)
    button:SetPoint("TOPRIGHT", -5, 3)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonPreview", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.PREVIEW)
    button:SetPoint("TOPLEFT", 10, -27)
    button:SetScript("OnClick", buttonFunc)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp") -- Not just leftbutton.
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Live Preview of Bindings")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left-Click:", "View All Bindings", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
        GameTooltip:AddDoubleLine("Shift-Left-Click:", "View Helpful Bindings", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
        GameTooltip:AddDoubleLine("Shift-Right-Click:", "View Hostile Bindings", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local button = CreateFrame("Button", "CliqueButtonCustom", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.CUSTOM)
    button:SetPoint("BOTTOMLEFT", CliqueFrame, "BOTTOMLEFT", 10, 5)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonFrames", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.FRAMES)
    button:SetPoint("LEFT", CliqueButtonCustom, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonProfiles", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.PROFILES)
    button:SetPoint("LEFT", CliqueButtonFrames, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonOptions", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.OPTIONS)
    button:SetPoint("LEFT", CliqueButtonProfiles, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonDelete", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.DELETE)
    button:SetPoint("LEFT", CliqueButtonOptions, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonEdit", CliqueFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.EDIT)
    button:SetPoint("LEFT", CliqueButtonDelete, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    -- Buttons for text list scroll frame

    local button = CreateFrame("Button", "CliqueTextButtonClose", CliqueTextListFrame.titleBar, "UIPanelCloseButton")
    button:SetHeight(25)
    button:SetWidth(25)
    button:SetPoint("TOPRIGHT", -5, 3)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonDeleteProfile", CliqueTextListFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.DELETE)
    button:SetPoint("BOTTOMLEFT", CliqueTextListFrame, "BOTTOMLEFT", 30, 5)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonSetProfile", CliqueTextListFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.SET)
    button:SetPoint("LEFT", CliqueButtonDeleteProfile, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueButtonNewProfile", CliqueTextListFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(60)
    button:SetText(L.NEW)
    button:SetPoint("LEFT", CliqueButtonSetProfile, "RIGHT", 3, 0)
    button:SetScript("OnClick", buttonFunc)

    local frame = CreateFrame("Frame", "CliqueOptionsFrame", CliqueFrame)
    frame:SetHeight(200)
    frame:SetWidth(300)
    frame:SetPoint("CENTER", 0, 0)
    self:SkinFrame(frame)
    frame:SetFrameStrata("DIALOG")
    frame.title:SetText(L["Clique Options"])
    frame:Hide()
    self:CreateOptionsWidgets(frame)

    frame:SetScript("OnShow", function(self)
        local parent = self:GetParent()
        self:SetFrameLevel(parent:GetFrameLevel() + 5)
        self:refreshOptionsWidgets()
    end)

    self.customEntry = {}
    local frame = CreateFrame("Frame", "CliqueCustomFrame", CliqueFrame)
    frame:SetHeight(400)
    frame:SetWidth(450)
    frame:SetPoint("CENTER", 70, -50)
    self:SkinFrame(frame)
    frame:SetFrameStrata("DIALOG")
    frame.title:SetText("Clique Custom Editor");
    frame:Hide()

    frame:SetScript("OnShow", function(self)
        local parent = self:GetParent()
        self:SetFrameLevel(parent:GetFrameLevel() + 5)
    end)

    -- Help text for Custom screen

    local font = frame:CreateFontString("CliqueCustomHelpText", "OVERLAY", "GameFontHighlight")
    font:SetWidth(260) font:SetHeight(100)
    font:SetPoint("TOPRIGHT", -10, -25)
    font:SetText(L.CUSTOM_HELP)

    local checkFunc = function(self) Clique:CustomRadio(self) end
    self.radio = {}

    local buttons = {
        {type = "actionbar", name = L.ACTION_ACTIONBAR},
        {type = "action", name = L.ACTION_ACTION},
        {type = "pet", name = L.ACTION_PET},
        {type = "spell", name = L.ACTION_SPELL},
        {type = "item", name = L.ACTION_ITEM},
        {type = "macro", name = L.ACTION_MACRO},
        {type = "stop", name = L.ACTION_STOP},
        {type = "target", name = L.ACTION_TARGET},
        {type = "focus", name = L.ACTION_FOCUS},
        {type = "assist", name = L.ACTION_ASSIST},
        {type = "click", name = L.ACTION_CLICK},
        {type = "menu", name = L.ACTION_MENU},
    }

    for i=1,#buttons do
        local entry = buttons[i]

        local name = "CliqueRadioButton"..entry.type
        local button = CreateFrame("CheckButton", name, CliqueCustomFrame)
        button:SetHeight(20)
        button:SetWidth(150)

        local texture = button:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\AddOns\\Clique\\images\\RadioEmpty")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        button:SetNormalTexture(texture)

        local texture = button:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\AddOns\\Clique\\images\\RadioChecked")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        texture:SetBlendMode("ADD")
        button:SetHighlightTexture(texture)

        local texture = button:CreateTexture("ARTWORK")
        texture:SetTexture("Interface\\AddOns\\Clique\\images\\RadioChecked")
        texture:SetPoint("LEFT", 0, 0)
        texture:SetHeight(26)
        texture:SetWidth(26)
        button:SetCheckedTexture(texture)

        button.name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.name:SetPoint("LEFT", 25, 0)
        button.name:SetJustifyH("LEFT")

        local entry = buttons[1]
        local name = "CliqueRadioButton"..entry.type
        local button = CreateFrame("CheckButton", name, CliqueCustomFrame)
        button:SetHeight(22)
        button:SetWidth(150)
    end

    local entry = buttons[1]
    local button = _G["CliqueRadioButton"..entry.type]
    button.type = entry.type
    button.name:SetText(entry.name)
    button:SetPoint("TOPLEFT", 5, -30)
    button:SetScript("OnClick", checkFunc)
    self.radio[button] = true

    local prev = button

    for i=2,#buttons do
        local entry = buttons[i]
        local name = "CliqueRadioButton"..entry.type
        local button = _G[name]

        button.type = entry.type
        button.name:SetText(entry.name)
        button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, 0)
        button:SetScript("OnClick", checkFunc)
        self.radio[button] = true
        prev = button
    end

    -- Button to set the binding

    local button = CreateFrame("Button", "CliqueCustomButtonBinding", CliqueCustomFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(30)
    button:SetWidth(175)
    button:SetText("Set Click Binding")
    button:SetPoint("TOP", CliqueCustomHelpText, "BOTTOM", 40, -10)
    button:SetScript("OnClick", function(self) Clique:CustomBinding_OnClick(self) end )
    button:RegisterForClicks("AnyUp")

    -- Button for icon selection

    local button = CreateFrame("Button", "CliqueCustomButtonIcon", CliqueCustomFrame)
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetAllPoints()
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetHeight(30)
    button:SetWidth(30)
    button:SetPoint("RIGHT", CliqueCustomButtonBinding, "LEFT", -15, 0)

    local func = function()
        GameTooltip:SetOwner(button, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Click here to set icon")
        GameTooltip:Show()
    end

    button:SetScript("OnEnter", func)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function() CliqueIconSelectFrame:Show() end)

    -- Create the editboxes for action arguments

    local edit = CreateFrame("EditBox", "CliqueCustomArg1", CliqueCustomFrame, "InputBoxTemplate")
    edit:SetHeight(30)
    edit:SetWidth(200)
    edit:SetPoint("TOPRIGHT", CliqueCustomFrame, "TOPRIGHT", -10, -190)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnTabPressed", function()
        if CliqueCustomArg2:IsVisible() then
            CliqueCustomArg2:SetFocus()
        end
    end)
    edit:SetScript("OnEnterPressed", function() end)

    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edit.label:SetText("Spell Name:")
    edit.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    edit.label:SetJustifyH("RIGHT")
    edit:Hide()

    -- Argument 2

    local edit = CreateFrame("EditBox", "CliqueCustomArg2", CliqueCustomFrame, "InputBoxTemplate")
    edit:SetHeight(30)
    edit:SetWidth(200)
    edit:SetPoint("TOPRIGHT", CliqueCustomArg1, "BOTTOMRIGHT", 0, 0)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnTabPressed", function()
        if CliqueCustomArg3:IsVisible() then
            CliqueCustomArg3:SetFocus()
        end
    end)
    edit:SetScript("OnEnterPressed", function() end)

    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edit.label:SetText("Spell Name:")
    edit.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    edit.label:SetJustifyH("RIGHT")
    edit:Hide()

    -- Multi line edit box

    local edit = CreateFrame("ScrollFrame", "CliqueMulti", CliqueCustomFrame, "CliqueEditTemplate")
    edit:SetPoint("TOPRIGHT", CliqueCustomArg1, "BOTTOMRIGHT", -10, -27)

    local name = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetText("Macro Text:")
    name:SetJustifyH("RIGHT")
    name:SetPoint("RIGHT", CliqueCustomArg2.label)

    local grabber = CreateFrame("Button", "CliqueFocusGrabber", edit)
    grabber:SetPoint("TOPLEFT", 8, -8)
    grabber:SetPoint("BOTTOMRIGHT", -8, 8)
    grabber:SetScript("OnClick", function() CliqueMultiScrollFrameEditBox:SetFocus() end)

    -- Argument 3

    local edit = CreateFrame("EditBox", "CliqueCustomArg3", CliqueCustomFrame, "InputBoxTemplate")
    edit:SetHeight(30)
    edit:SetWidth(200)
    edit:SetPoint("TOPRIGHT", CliqueCustomArg2, "BOTTOMRIGHT", 0, 0)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnTabPressed", function()
        if CliqueCustomArg4:IsVisible() then
            CliqueCustomArg4:SetFocus()
        end
    end)
    edit:SetScript("OnEnterPressed", function() end)

    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edit.label:SetText("Spell Name:")
    edit.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    edit.label:SetJustifyH("RIGHT")
    edit:Hide()

    -- Argument 4

    local edit = CreateFrame("EditBox", "CliqueCustomArg4", CliqueCustomFrame, "InputBoxTemplate")
    edit:SetHeight(30)
    edit:SetWidth(200)
    edit:SetPoint("TOPRIGHT", CliqueCustomArg3, "BOTTOMRIGHT", 0, 0)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnTabPressed", function()
        if CliqueCustomArg5:IsVisible() then
            CliqueCustomArg5:SetFocus()
        end
    end)
    edit:SetScript("OnEnterPressed", function() end)

    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edit.label:SetText("Spell Name:")
    edit.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    edit.label:SetJustifyH("RIGHT")
    edit:Hide()

    -- Argument 5

    local edit = CreateFrame("EditBox", "CliqueCustomArg5", CliqueCustomFrame, "InputBoxTemplate")
    edit:SetHeight(30)
    edit:SetWidth(200)
    edit:SetPoint("TOPRIGHT", CliqueCustomArg4, "BOTTOMRIGHT", 0, 0)
    edit:SetAutoFocus(nil)
    edit:SetScript("OnTabPressed", function()
        if CliqueCustomArg1:IsVisible() then
            CliqueCustomArg1:SetFocus()
        end
    end)
    edit:SetScript("OnEnterPressed", function() end)

    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edit.label:SetText("Spell Name:")
    edit.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    edit.label:SetJustifyH("RIGHT")
    edit:Hide()

    -- Bottom buttons

    local button = CreateFrame("Button", "CliqueCustomButtonCancel", CliqueCustomFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(70)
    button:SetText(L.CANCEL)
    button:SetPoint("BOTTOM", 65, 4)
    button:SetScript("OnClick", buttonFunc)

    local button = CreateFrame("Button", "CliqueCustomButtonSave", CliqueCustomFrame, "UIPanelButtonGrayTemplate")
    button:SetHeight(24)
    button:SetWidth(70)
    button:SetText(L.SAVE)
    button:SetPoint("LEFT", CliqueCustomButtonCancel, "RIGHT", 6, 0)
    button:SetScript("OnClick", buttonFunc)

    -- Create the macro icon frame

    CreateFrame("Frame", "CliqueIconSelectFrame", CliqueCustomFrame)
    CliqueIconSelectFrame:SetWidth(296)
    CliqueIconSelectFrame:SetHeight(250)
    CliqueIconSelectFrame:SetPoint("CENTER",0,0)
    self:SkinFrame(CliqueIconSelectFrame)
    CliqueIconSelectFrame:SetFrameStrata("DIALOG")
    CliqueIconSelectFrame.title:SetText("Select an icon")
    CliqueIconSelectFrame:Hide()

    local button = CreateFrame("Button", "CliqueIconSelectButtonClose", CliqueIconSelectFrame.titleBar, "UIPanelCloseButton")
    button:SetHeight(25)
    button:SetWidth(25)
    button:SetPoint("TOPRIGHT", -5, 3)
    button:SetScript("OnClick", buttonFunc)

    CreateFrame("CheckButton", "CliqueIcon1", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon1:SetID(1)
    CliqueIcon1:SetPoint("TOPLEFT", 25, -35)

    CreateFrame("CheckButton", "CliqueIcon2", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon2:SetID(2)
    CliqueIcon2:SetPoint("LEFT", CliqueIcon1, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon3", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon3:SetID(3)
    CliqueIcon3:SetPoint("LEFT", CliqueIcon2, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon4", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon4:SetID(4)
    CliqueIcon4:SetPoint("LEFT", CliqueIcon3, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon5", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon5:SetID(5)
    CliqueIcon5:SetPoint("LEFT", CliqueIcon4, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon6", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon6:SetID(6)
    CliqueIcon6:SetPoint("TOPLEFT", CliqueIcon1, "BOTTOMLEFT", 0, -10)

    CreateFrame("CheckButton", "CliqueIcon7", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon7:SetID(7)
    CliqueIcon7:SetPoint("LEFT", CliqueIcon6, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon8", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon8:SetID(8)
    CliqueIcon8:SetPoint("LEFT", CliqueIcon7, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon9", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon9:SetID(9)
    CliqueIcon9:SetPoint("LEFT", CliqueIcon8, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon10", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon10:SetID(10)
    CliqueIcon10:SetPoint("LEFT", CliqueIcon9, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon11", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon11:SetID(11)
    CliqueIcon11:SetPoint("TOPLEFT", CliqueIcon6, "BOTTOMLEFT", 0, -10)

    CreateFrame("CheckButton", "CliqueIcon12", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon12:SetID(12)
    CliqueIcon12:SetPoint("LEFT", CliqueIcon11, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon13", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon13:SetID(13)
    CliqueIcon13:SetPoint("LEFT", CliqueIcon12, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon14", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon14:SetID(14)
    CliqueIcon14:SetPoint("LEFT", CliqueIcon13, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon15", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon15:SetID(15)
    CliqueIcon15:SetPoint("LEFT", CliqueIcon14, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon16", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon16:SetID(16)
    CliqueIcon16:SetPoint("TOPLEFT", CliqueIcon11, "BOTTOMLEFT", 0, -10)

    CreateFrame("CheckButton", "CliqueIcon17", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon17:SetID(17)
    CliqueIcon17:SetPoint("LEFT", CliqueIcon16, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon18", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon18:SetID(18)
    CliqueIcon18:SetPoint("LEFT", CliqueIcon17, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon19", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon19:SetID(19)
    CliqueIcon19:SetPoint("LEFT", CliqueIcon18, "RIGHT", 10, 0)

    CreateFrame("CheckButton", "CliqueIcon20", CliqueIconSelectFrame, "CliqueIconTemplate")
    CliqueIcon20:SetID(20)
    CliqueIcon20:SetPoint("LEFT", CliqueIcon19, "RIGHT", 10, 0)

    CreateFrame("ScrollFrame", "CliqueIconScrollFrame", CliqueIconSelectFrame, "FauxScrollFrameTemplate")
    CliqueIconScrollFrame:SetPoint("TOPLEFT", CliqueIcon1, "TOPLEFT", 0, 0)
    CliqueIconScrollFrame:SetPoint("BOTTOMRIGHT", CliqueIcon20, "BOTTOMRIGHT", 10, 0)

    local texture = CliqueIconScrollFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueIconScrollFrame, "TOPRIGHT", 14, 0)
    texture:SetPoint("BOTTOMRIGHT", 23, 0)
    texture:SetVertexColor(0.3, 0.3, 0.3)

    local texture = CliqueIconScrollFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    texture:SetPoint("TOPLEFT", CliqueIconScrollFrame, "TOPRIGHT", 4, 0)
    texture:SetPoint("BOTTOMRIGHT", 14,0)
    texture:SetVertexColor(0.3, 0.3, 0.3)

    local function updateicons()
        Clique:UpdateIconFrame()
    end

    CliqueIconScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        local MACRO_ICON_ROW_HEIGHT = 36
        FauxScrollFrame_OnVerticalScroll(MACRO_ICON_ROW_HEIGHT, updateicons)
    end)

    CliqueIconSelectFrame:SetScript("OnShow", function(self)
        local parent = self:GetParent()
        self:SetFrameLevel(parent:GetFrameLevel() + 5)
        Clique:UpdateIconFrame()
    end)

    -- Create the CliqueHelpText
    CliqueFrame:CreateFontString("CliqueHelpText", "OVERLAY", "GameFontHighlight")
    CliqueHelpText:SetText(L.HELP_TEXT)
    CliqueHelpText:SetPoint("TOPLEFT", 10, -10)
    CliqueHelpText:SetPoint("BOTTOMRIGHT", -10, 10)
    CliqueHelpText:SetJustifyH("CENTER")
    CliqueHelpText:SetJustifyV("CENTER")
    CliqueHelpText:SetPoint("CENTER", 0, 0)

    self.sortList = {}
    self.listSelected = 0
end

function Clique:ListScrollUpdate()
    Clique:ValidateButtons()
    if not CliqueListScroll then return end

    local idx,button
    Clique:SortList()
    local clickCasts = self.sortList
    local offset = FauxScrollFrame_GetOffset(CliqueListScroll)
    FauxScrollFrame_Update(CliqueListScroll, table.getn(clickCasts), NUM_ENTRIES, ENTRY_SIZE)

    if not CliqueListScroll:IsShown() then
        CliqueFrame:SetWidth(400)
    else
        CliqueFrame:SetWidth(425)
    end

    for i=1,NUM_ENTRIES do
        idx = offset + i
        button = _G["CliqueList"..i]
        if idx <= table.getn(clickCasts) then
            Clique:FillListEntry(button,idx)
            button:Show()
            if idx == self.listSelected then
                button:SetBackdropBorderColor(1,1,0)
            else
                button:SetBackdropBorderColor(0.3, 0.3, 0.3)
            end
        else
            button:Hide()
        end
    end
end

local sortFunc = function(a,b)
    local numA = tonumber(a.button) or 0
    local numB = tonumber(b.button) or 0

    if numA == numB then
        return a.modifier < b.modifier
    else
        return numA < numB
    end
end

function Clique:SortList()
    self.sortList = {}
    for k,v in pairs(self.editSet) do
        table.insert(self.sortList, v)
    end
    table.sort(self.sortList, sortFunc)
end

function Clique:ValidateButtons()
    if not CliqueButtonDelete then return end

    local entry = self.sortList[self.listSelected]

    if entry then
        CliqueButtonDelete:Enable()
        CliqueButtonEdit:Enable()
    else
        CliqueButtonDelete:Disable()
        CliqueButtonEdit:Disable()
    end

    -- This should always be enabled
    CliqueButtonCustom:Enable()
    CliqueButtonOptions:Enable()

    -- Disable the help text
    Clique.inuse = false
    for k,v in pairs(self.clicksets) do
        if next(v) then -- Contains elements.
            Clique.inuse = true
            break
        end
    end
    if Clique.inuse then
        CliqueHelpText:Hide()
    else
        CliqueHelpText:Show()
    end
end

function Clique:FillListEntry(frame, idx)
    local entry = self.sortList[idx]

    local type = string.format("%s%s", string.upper(string.sub(entry.type, 1, 1)), string.sub(entry.type, 2))
    local button = entry.button

    frame.icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    frame.binding:SetText(entry.modifier..self:GetButtonText(button))

    local arg1 = tostring(entry.arg1)
    local arg2 = tostring(entry.arg2)
    local arg3 = tostring(entry.arg3)
    local arg4 = tostring(entry.arg4)
    local arg5 = tostring(entry.arg5)

    if entry.type == "action" then
        frame.name:SetText(string.format("Action Button %d%s", arg1, entry.arg2 and (" on " .. arg2) or ""))
    elseif entry.type == "actionbar" then
        frame.name:SetText(string.format("Action Bar: %s", arg1))
    elseif entry.type == "pet" then
        local target = ""
        if entry.arg2 then
            target = " on " .. arg2
        end
        frame.name:SetText(string.format("Pet Action %d%s", arg1, target))
    elseif entry.type == "spell" then
        -- Determine what spell rank to display, if any...
        local rank
        if entry.arg2 then
            if tonumber(entry.arg2) then -- Rank was saved as a number, by old Clique versions.
                rank = string.format("Rank %d", entry.arg2)
            else -- Has SOME "non-nil" value... such as "Rank 2" (full string saved, done by modern Clique versions).
                -- NOTE: This permanently fixes any legacy Clique data that wrongly has an empty string
                -- instead of nil for spells with no rank-data. We don't HAVE TO apply this fix, since
                -- binding spells as "Attack()" vs "Attack" is the same thing, but it's still nice to fix
                -- the core underlying data this way.
                if entry.arg2 == "" then entry.arg2 = nil; end
                rank = entry.arg2 -- Use value as-is... NOTE: Properly REMAINS "nil" if we had to rewrite legacy arg2 above.
            end
        end

        if rank then
            frame.name:SetText(string.format("%s (%s)%s", arg1, rank, entry.arg5 and (" on " .. arg5) or ""))
        else
            frame.name:SetText(string.format("%s%s", arg1, entry.arg5 and " on " .. arg5 or ""))
        end
    elseif entry.type == "menu" then
        frame.name:SetText("Show Menu")
    elseif entry.type == "stop" then
        frame.name:SetText("Stop Casting Current Spell")
    elseif entry.type == "target" then
        frame.name:SetText(string.format("Target Unit: %s", arg1 and entry.arg1 or ""))
    elseif entry.type == "focus" then
        frame.name:SetText(string.format("Set Focus Unit: %s", arg1 and entry.arg1 or ""))
    elseif entry.type == "assist" then
        frame.name:SetText(string.format("Assist Unit: %s", arg1 and entry.arg1 or ""))
    elseif entry.type == "item" then
        if entry.arg1 then
            frame.name:SetText(string.format("Item: %d,%d", arg1, arg2))
        elseif entry.arg3 then
            frame.name:SetText(string.format("Item: %s", arg3))
        end
    elseif entry.type == "macro" then
        frame.name:SetText(string.format("Macro: %s", arg1 and entry.arg1 or string.sub(arg2, 1, 20)))
    end

    frame:Show()
end

function Clique:ButtonOnClick(button, mouseButton)
    local entry = self.sortList[self.listSelected]

    if button == CliqueButtonDelete then
        if InCombatLockdown() then
            StaticPopup_Show("CLIQUE_COMBAT_LOCKDOWN")
            return
        end

        self.editSet[entry.modifier..entry.button] = nil
        local len = table.getn(self.sortList) - 1

        if self.listSelected > len then
            self.listSelected = len
        end

        self:DeleteAction(entry)
        self:RebuildOOCSet()
        self:PLAYER_REGEN_ENABLED()
        entry = nil

        self:ListScrollUpdate()
    elseif button == CliqueButtonClose then
        self:Toggle()
    elseif button == CliqueTextButtonClose then
        CliqueTextListFrame:Hide()
    elseif button == CliqueOptionsButtonClose then
        CliqueOptionsFrame:Hide()
    elseif button == CliqueIconSelectButtonClose then
        CliqueIconSelectFrame:Hide()
    elseif button == CliqueButtonPreview then
        local viewType = "" -- Show all bindings by default.
        if IsShiftKeyDown() then
            if mouseButton == "LeftButton" then
                viewType = "help" -- Shift-left-click = View only helpful-unit bindings.
            elseif mouseButton == "RightButton" then
                viewType = "harm" -- Shift-right-click = View only harmful-unit bindings.
            end
        end
        self:ShowBindings(viewType)
    elseif button == CliqueButtonOptions then
        if CliqueOptionsFrame:IsVisible() then
            CliqueOptionsFrame:Hide()
        else
            CliqueOptionsFrame:Show()
        end
    elseif button == CliqueButtonCustom then
        if CliqueCustomFrame:IsVisible() then
            CliqueCustomFrame:Hide()
        else
            CliqueCustomFrame:Show()
        end
    elseif button == CliqueButtonFrames then
        if CliqueTextListFrame:IsVisible() and self.textlist == "FRAMES" then
            CliqueTextListFrame:Hide()
        else
            CliqueTextListFrame:Show()
        end

        self.textlist = "FRAMES"
        CliqueButtonDeleteProfile:Hide()
        CliqueButtonSetProfile:Hide()
        CliqueButtonNewProfile:Hide()

        self:TextListScrollUpdate()
        CliqueTextListFrame.title:SetText("Clique Frame Editor")
        self.textlistSelected = nil
    elseif button == CliqueButtonProfiles then
        if CliqueTextListFrame:IsVisible() and self.textlist == "PROFILES" then
            CliqueTextListFrame:Hide()
        else
            CliqueTextListFrame:Show()
        end
        self.textlist = "PROFILES"
        self:TextListScrollUpdate()
        CliqueButtonDeleteProfile:Show()
        CliqueButtonSetProfile:Show()
        CliqueButtonNewProfile:Show()

        --CliqueTextListFrame.title:SetText("Profile: " .. self.db.char.profileKey)
        self.textlistSelected = nil
    elseif button == CliqueButtonSetProfile then
        local offset = FauxScrollFrame_GetOffset(CliqueTextListScroll)
        local selected = self.textlistSelected - offset
        local button = _G["CliqueTextList"..selected]
        local profileName = button.realValue
        if (profileName and profileName:len() > 0) then
            self.db:SetProfile(profileName)
        end
    elseif button == CliqueButtonNewProfile then
        StaticPopup_Show("CLIQUE_NEW_PROFILE")
    elseif button == CliqueButtonDeleteProfile then
        local offset = FauxScrollFrame_GetOffset(CliqueTextListScroll)
        local selected = self.textlistSelected - offset
        local button = _G["CliqueTextList"..selected]
        self.db:DeleteProfile(button.realValue)
    elseif button == CliqueButtonEdit then
        -- Make a copy of the entry
        self.customEntry = {}
        for k,v in pairs(entry) do
            self.customEntry[k] = v
        end

        CliqueCustomFrame:Show()

        -- Select the right radio button
        for k,v in pairs(self.radio) do
            if entry.type == k.type then
                self:CustomRadio(k)
                k:SetChecked(true)
            end
        end

        self.customEntry.type = entry.type

        CliqueCustomArg1:SetText(entry.arg1 or "")
        CliqueCustomArg2:SetText(entry.arg2 or "")
        CliqueCustomArg3:SetText(entry.arg3 or "")
        CliqueCustomArg4:SetText(entry.arg4 or "")
        CliqueCustomArg5:SetText(entry.arg5 or "")

        CliqueMultiScrollFrameEditBox:SetText(entry.arg2 or "")
        CliqueCustomButtonIcon.icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

        CliqueCustomButtonBinding.modifier = entry.modifier
        CliqueCustomButtonBinding.button = self:GetButtonNumber(entry.button)
        CliqueCustomButtonBinding:SetText(string.format("%s%s", entry.modifier, self:GetButtonText(entry.button)))

        self.editEntry = entry

    elseif button == CliqueCustomButtonCancel then
        CliqueCustomFrame:Hide()
        CliqueCustomButtonIcon.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        CliqueCustomButtonBinding:SetText("Set Click Binding")
        self.customEntry = {}
        self.editEntry = nil
        self:CustomRadio()

    elseif button == CliqueCustomButtonSave then
        -- Add custom save logic in here
        local entry = self.customEntry

        entry.arg1 = CliqueCustomArg1:GetText()
        entry.arg2 = CliqueCustomArg2:GetText()
        entry.arg3 = CliqueCustomArg3:GetText()
        entry.arg4 = CliqueCustomArg4:GetText()
        entry.arg5 = CliqueCustomArg5:GetText()

        if entry.arg1 == "" then entry.arg1 = nil end
        if entry.arg2 == "" then entry.arg2 = nil end
        if entry.arg3 == "" then entry.arg3 = nil end
        if entry.arg4 == "" then entry.arg4 = nil end
        if entry.arg5 == "" then entry.arg5 = nil end

        if tonumber(entry.arg1) then entry.arg1 = tonumber(entry.arg1) end
        if tonumber(entry.arg2) then entry.arg2 = tonumber(entry.arg2) end
        if tonumber(entry.arg3) then entry.arg3 = tonumber(entry.arg3) end
        if tonumber(entry.arg4) then entry.arg4 = tonumber(entry.arg4) end
        if tonumber(entry.arg5) then entry.arg5 = tonumber(entry.arg5) end

        if entry.type == "macro" then
            local text = CliqueMultiScrollFrameEditBox:GetText()
            if text ~= "" then
                entry.arg2 = text
            end
        end

        local pattern = "Hitem.+|h%[(.+)%]|h"
        if entry.arg1 and string.find(entry.arg1, pattern) then
            entry.arg1 = select(3, string.find(entry.arg1, pattern))
        end
        if entry.arg2 and string.find(entry.arg2, pattern) then
            entry.arg2 = select(3, string.find(entry.arg2, pattern))
        end
        if entry.arg3 and string.find(entry.arg3, pattern) then
            entry.arg3 = select(3, string.find(entry.arg3, pattern))
        end
        if entry.arg4 and string.find(entry.arg4, pattern) then
            entry.arg4 = select(3, string.find(entry.arg4, pattern))
        end
        if entry.arg5 and string.find(entry.arg5, pattern) then
            entry.arg5 = select(3, string.find(entry.arg5, pattern))
        end

        local issue
        local arg1 = entry.arg1 and tostring(entry.arg1)
        local arg2 = entry.arg2 and tostring(entry.arg2)

        if not entry.type then
            issue = "You must select an action type."
        elseif not entry.button then
            issue = "You must set a click-binding."
        elseif entry.type == "action" and not entry.arg1 then
            issue = "You must supply an action button number when creating a custom \"action\"."
        elseif entry.type == "pet" and not entry.arg1 then
            issue = "You must supply a pet action button number when creating a custom action \"pet\"."
        elseif entry.type == "spell" and not (entry.arg1 or (entry.arg2 and entry.arg3) or entry.arg4) then
            issue = "You must supply either a spell name and optionally an item slot/bag or name to consume when creating a \"spell\" action."
        elseif entry.type == "item" and not ((entry.arg1 and entry.arg2) or entry.arg3) then
            issue = "You must supply either a bag/slot, or an item name to use."
        elseif entry.type == "macro" and arg1 and arg2 then
            issue = "You must specify EITHER a macro index, or macro text, not both."
        elseif entry.type == "macro" and not arg1 and not arg2 then
            issue = "You must supply either a macro index, or macro text"
        elseif entry.type == "actionbar" and not arg1 then
            issue = "You must supply an action bar to change to."
        end

        if issue then
            StaticPopupDialogs["CLIQUE_CANT_SAVE"].text = issue
            StaticPopup_Show("CLIQUE_CANT_SAVE")
            return
        end

        -- Delete the one we're editing, if that's the case
        if self.editEntry then
            local key = self.editEntry.modifier..self.editEntry.button
            self.editSet[key] = nil
            self:DeleteAction(self.editEntry)
            self:RebuildOOCSet()
            self.editEntry = nil
        end

        local key = entry.modifier..entry.button
        self.editSet[key] = entry
        self:RebuildOOCSet()
        self:PLAYER_REGEN_ENABLED()
        self:ButtonOnClick(CliqueCustomButtonCancel, mouseButton)
    end

    Clique:ListScrollUpdate()
end

local click_func = function()
    local listButton = this
    if listButton then
        Clique:DropDown_OnClick(listButton)
    end
end

function Clique:DropDown_Initialize()
    local info = {}

    for k,v in pairs(work) do
        info = {}
        info.text = v
        info.value = self.clicksets[v]
        info.func = click_func
        UIDropDownMenu_AddButton(info)
    end
end

function Clique:DropDown_OnClick(listButton)
    UIDropDownMenu_SetSelectedValue(CliqueDropDown, listButton.value)
    Clique.editSet = listButton.value
    self.listSelected = 0
    Clique:ListScrollUpdate()
end

function Clique:DropDown_OnShow(frame)
    work = {}
    for k,v in pairs(self.clicksets) do
        table.insert(work, k)
    end
    table.sort(work)

    UIDropDownMenu_Initialize(frame, function() Clique:DropDown_Initialize() end);
    UIDropDownMenu_SetSelectedValue(frame, self.editSet)
    Clique:ListScrollUpdate()
end

function Clique:CustomBinding_OnClick(frame)
    -- This handles the binding click
    local mod = self:GetModifierText()
    local button = arg1

    if self.editSet == self.clicksets[L.CLICKSET_HARMFUL] then
        button = string.format("%s%d", "harmbutton", self:GetButtonNumber(button))
    elseif self.editSet == self.clicksets[L.CLICKSET_HELPFUL] then
        button = string.format("%s%d", "helpbutton", self:GetButtonNumber(button))
    else
        button = self:GetButtonNumber(button)
    end

    self.customEntry.modifier = mod
    self.customEntry.button = button
    frame:SetText(string.format("%s%s", mod, arg1))
end

local buttonSetup = {
    actionbar = {
        help = L["BS_ACTIONBAR_HELP"],
        arg1 = L["BS_ACTIONBAR_ARG1_LABEL"],
    },
    action = {
        help = L["BS_ACTION_HELP"],
        arg1 = L["BS_ACTION_ARG1_LABEL"],
        arg2 = L["BS_ACTION_ARG2_LABEL"],
    },
    pet = {
        help = L["BS_PET_HELP"],
        arg1 = L["BS_PET_ARG1_LABEL"],
        arg2 = L["BS_PET_ARG2_LABEL"],
    },
    spell = {
        help = L["BS_SPELL_HELP"],
        arg1 = L["BS_SPELL_ARG1_LABEL"],
        arg2 = L["BS_SPELL_ARG2_LABEL"],
        arg3 = L["BS_SPELL_ARG3_LABEL"],
        arg4 = L["BS_SPELL_ARG4_LABEL"],
        arg5 = L["BS_SPELL_ARG5_LABEL"],
    },
    item = {
        help = L["BS_ITEM_HELP"],
        arg1 = L["BS_ITEM_ARG1_LABEL"],
        arg2 = L["BS_ITEM_ARG2_LABEL"],
        arg3 = L["BS_ITEM_ARG3_LABEL"],
        arg4 = L["BS_ITEM_ARG4_LABEL"],
    },
    macro = {
        help = L["BS_MACRO_HELP"],
        arg1 = L["BS_MACRO_ARG1_LABEL"],
        arg2 = L["BS_MACRO_ARG2_LABEL"],
    },
    stop = {
        help = L["BS_STOP_HELP"],
    },
    target = {
        help = L["BS_TARGET_HELP"],
        arg1 = L["BS_TARGET_ARG1_LABEL"],
    },
    focus = {
        help = L["BS_FOCUS_HELP"],
        arg1 = L["BS_FOCUS_ARG1_LABEL"],
    },
    assist = {
        help = L["BS_ASSIST_HELP"],
        arg1 = L["BS_ASSIST_ARG1_LABEL"],
    },
    click = {
        help = L["BS_CLICK_HELP"],
        arg1 = L["BS_CLICK_ARG1_LABEL"],
    },
    menu = {
        help = L["BS_MENU_HELP"],
    },
}

function Clique:CustomRadio(button)
    local anySelected
    for k,v in pairs(self.radio) do
        if k ~= button then
            k:SetChecked(nil)
        end
    end

    if not button or not buttonSetup[button.type] then
        CliqueCustomHelpText:SetText(L.CUSTOM_HELP)
        CliqueCustomArg1:Hide()
        CliqueCustomArg2:Hide()
        CliqueCustomArg3:Hide()
        CliqueCustomArg4:Hide()
        CliqueCustomArg5:Hide()
        CliqueCustomButtonBinding:SetText("Set Click Binding")
        return
    end

    local entry = buttonSetup[button.type]
    self.customEntry.type = button.type

    if button and button.type then
        if not button:GetChecked() then
            self.customEntry.type = nil
        end
    end

    -- Clear any open arguments
    CliqueCustomArg1:SetText("")
    CliqueCustomArg2:SetText("")
    CliqueCustomArg3:SetText("")
    CliqueCustomArg4:SetText("")
    CliqueCustomArg5:SetText("")

    CliqueCustomHelpText:SetText(entry.help)
    CliqueCustomArg1.label:SetText(entry.arg1)
    CliqueCustomArg2.label:SetText(entry.arg2)
    CliqueCustomArg3.label:SetText(entry.arg3)
    CliqueCustomArg4.label:SetText(entry.arg4)
    CliqueCustomArg5.label:SetText(entry.arg5)

    if entry.arg1 then CliqueCustomArg1:Show() else CliqueCustomArg1:Hide() end
    if entry.arg2 then CliqueCustomArg2:Show() else CliqueCustomArg2:Hide() end
    if entry.arg3 then CliqueCustomArg3:Show() else CliqueCustomArg3:Hide() end
    if entry.arg4 then CliqueCustomArg4:Show() else CliqueCustomArg4:Hide() end
    if entry.arg5 then CliqueCustomArg5:Show() else CliqueCustomArg5:Hide() end

    -- Handle MacroText
    if button.type == "macro" then
        CliqueCustomArg2:Hide()
        CliqueMulti:Show()
        CliqueMultiScrollFrameEditBox:SetText("")
    else
        CliqueMulti:Hide()
    end
end

function Clique:UpdateIconFrame()
    local MAX_MACROS = 18;
    local NUM_MACRO_ICONS_SHOWN = 20;
    local NUM_ICONS_PER_ROW = 5;
    local NUM_ICON_ROWS = 4;
    local MACRO_ICON_ROW_HEIGHT = 36;
    local macroPopupOffset = FauxScrollFrame_GetOffset(CliqueIconScrollFrame);
    local numMacroIcons = GetNumMacroIcons();
    local macroPopupIcon,macroPopupButton

    -- Icon list
    for i=1, NUM_MACRO_ICONS_SHOWN do
        macroPopupIcon = _G["CliqueIcon"..i.."Icon"];
        macroPopupButton = _G["CliqueIcon"..i];

        if not macroPopupButton.icon then
            macroPopupButton.icon = macroPopupIcon
        end

        local index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
        if ( index <= numMacroIcons ) then
            macroPopupIcon:SetTexture(GetMacroIconInfo(index));
            macroPopupButton:Show();
        else
            macroPopupIcon:SetTexture("");
            macroPopupButton:Hide();
        end
        macroPopupButton:SetChecked(nil);
    end

    FauxScrollFrame_Update(CliqueIconScrollFrame, ceil(numMacroIcons / NUM_ICONS_PER_ROW) , NUM_ICON_ROWS, MACRO_ICON_ROW_HEIGHT );
end

function Clique:SetSpellIcon(button)
    local texture = button.icon:GetTexture()
    self.customEntry.texture = texture
    CliqueCustomButtonIcon.icon:SetTexture(texture)
    CliqueIconSelectFrame:Hide()
end

StaticPopupDialogs["CLIQUE_PASSIVE_SKILL"] = {
    text = "You can't bind a passive skill.",
    button1 = TEXT(OKAY),
    OnAccept = function()
    end,
    timeout = 0,
    hideOnEscape = 1
}

StaticPopupDialogs["CLIQUE_CANT_SAVE"] = {
    text = "",
    button1 = TEXT(OKAY),
    OnAccept = function()
    end,
    timeout = 0,
    hideOnEscape = 1
}

StaticPopupDialogs["CLIQUE_BINDING_PROBLEM"] = {
    text = "That combination is already bound.  Delete the old one before trying to re-bind.",
    button1 = TEXT(OKAY),
    OnAccept = function()
    end,
    timeout = 0,
    hideOnEscape = 1
}

StaticPopupDialogs["CLIQUE_COMBAT_LOCKDOWN"] = {
    text = "You are currently in combat.  You cannot make changes to your click casting while in combat.",
    button1 = TEXT(OKAY),
    OnAccept = function()
    end,
    timeout = 0,
    hideOnEscape = 1
}

StaticPopupDialogs["CLIQUE_NEW_PROFILE"] = {
    text = TEXT("Enter the name of a new profile you'd like to create"),
    button1 = TEXT(OKAY),
    button2 = TEXT(CANCEL),
    OnAccept = function()
        local editbox = _G[this:GetParent():GetName().."EditBox"]
        local profileName = editbox:GetText()
        if (profileName and profileName:len() > 0) then
            Clique.db:SetProfile(profileName)
        end
    end,
    timeout = 0,
    whileDead = 1,
    exclusive = 1,
    showAlert = 1,
    hideOnEscape = 1,
    hasEditBox = 1,
    maxLetters = 32,
    OnShow = function()
        _G[this:GetName().."Button1"]:Disable();
        _G[this:GetName().."EditBox"]:SetFocus();
    end,
    OnHide = function()
        if ( ChatFrameEditBox:IsVisible() ) then
            ChatFrameEditBox:SetFocus();
        end
        _G[this:GetName().."EditBox"]:SetText("");
    end,
    EditBoxOnEnterPressed = function()
        if ( _G[this:GetParent():GetName().."Button1"]:IsEnabled() == 1 ) then
            local profileName = this:GetText()
            if (profileName and profileName:len() > 0) then
                Clique.db:SetProfile(profileName)
            end
            this:GetParent():Hide();
        end
    end,
    EditBoxOnTextChanged = function ()
        local editBox = _G[this:GetParent():GetName().."EditBox"];
        local txt = editBox:GetText()
        if #txt > 0 then
            _G[this:GetParent():GetName().."Button1"]:Enable();
        else
            _G[this:GetParent():GetName().."Button1"]:Disable();
        end
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide();
        ClearCursor();
    end
}

StaticPopupDialogs["CLIQUE_DELETE_PROFILE"] = {
    text = TEXT("Enter the name of a profile you'd like to delete"),
    button1 = TEXT(OKAY),
    button2 = TEXT(CANCEL),
    OnAccept = function()
        Clique.db:DeleteProfile(_G[this:GetName().."EditBox"]:GetText())
        Clique:DropDownProfile_OnShow()
    end,
    timeout = 0,
    whileDead = 1,
    exclusive = 1,
    showAlert = 1,
    hideOnEscape = 1,
    hasEditBox = 1,
    maxLetters = 32,
    OnShow = function()
        _G[this:GetName().."Button1"]:Disable();
        _G[this:GetName().."EditBox"]:SetFocus();
    end,
    OnHide = function()
        if ( ChatFrameEditBox:IsVisible() ) then
            ChatFrameEditBox:SetFocus();
        end
        _G[this:GetName().."EditBox"]:SetText("");
    end,
    EditBoxOnEnterPressed = function()
        if ( _G[this:GetParent():GetName().."Button1"]:IsEnabled() == 1 ) then
            Clique.db:DeleteProfile(this:GetText())
            Clique:DropDownProfile_OnShow()
            this:GetParent():Hide();
        end
    end,
    EditBoxOnTextChanged = function ()
        local editBox = _G[this:GetParent():GetName().."EditBox"];
        local txt = editBox:GetText()
        if Clique.db.profiles[txt] then
            _G[this:GetParent():GetName().."Button1"]:Enable();
        else
            _G[this:GetParent():GetName().."Button1"]:Disable();
        end
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide();
        ClearCursor();
    end
}

local work = {}
local workDisabled = {}

function Clique:TextListScrollUpdate()
    if not CliqueTextListScroll then return end

    local idx,button
    for k,v in pairs(work) do work[k] = nil end
    for k,v in pairs(workDisabled) do workDisabled[k] = nil end

    if not self.textlist then self.textlist = "FRAMES" end

    if self.textlist == "PROFILES" then
        for k,v in pairs(self.db.profiles) do table.insert(work, k) end
        table.sort(work)
        CliqueTextListFrame.title:SetText("Profile: " .. self.db.keys.profile)

    elseif self.textlist == "FRAMES" then
        for frame,enabled in pairs(self.ccframes) do
            local name = frame:GetName()
            if name then
                table.insert(work, name)
                if not enabled then
                    workDisabled[name] = true -- Signal that the added entry is a disabled one.
                end
            end
        end
        table.sort(work)
    end

    local offset = FauxScrollFrame_GetOffset(CliqueTextListScroll)
    FauxScrollFrame_Update(CliqueTextListScroll, #work, 12, 22)

    if not CliqueTextListScroll:IsShown() then
        CliqueTextListFrame:SetWidth(250)
    else
        CliqueTextListFrame:SetWidth(275)
    end

    local buttonText
    for i=1,12 do
        idx = offset + i
        button = _G["CliqueTextList"..i]
        if idx <= #work then
            button.realValue = work[idx]
            buttonText = button.realValue
            if workDisabled[buttonText] then
                buttonText = buttonText.." (disabled)"
            end
            button.name:SetText(buttonText)
            button:Show()
            -- Change texture
            if self.textlist == "PROFILES" then
                button:SetNormalTexture("Interface\\AddOns\\Clique\\images\\RadioEmpty")
                button:SetCheckedTexture("Interface\\AddOns\\Clique\\images\\RadioChecked")
                button:SetHighlightTexture("Interface\\AddOns\\Clique\\images\\RadioChecked")
            else
                button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            end

            if self.textlistSelected == nil and self.textlist == "PROFILES" then
                if work[idx] == self.db.keys.profile then
                    button:SetChecked(true)
                    CliqueButtonSetProfile:Disable()
                    CliqueButtonDeleteProfile:Disable()
                else
                    button:SetChecked(nil)
                end
            elseif idx == self.textlistSelected and self.textlist == "PROFILES" then
                if work[idx] == self.db.keys.profile then
                    CliqueButtonSetProfile:Disable()
                    CliqueButtonDeleteProfile:Disable()
                else
                    CliqueButtonSetProfile:Enable()
                    CliqueButtonDeleteProfile:Enable()
                end
                button:SetChecked(true)
            elseif self.textlist == "FRAMES" then
                local name = work[idx]
                local frame = _G[name]

                if not self.profile.blacklist then
                    self.profile.blacklist = {}
                end
                local bl = self.profile.blacklist

                if bl[name] or workDisabled[name] then
                    button:SetChecked(nil)
                else
                    button:SetChecked(true)
                end
            else
                button:SetBackdropBorderColor(0.3, 0.3, 0.3)
                button:SetChecked(nil)
            end
        else
            button:Hide()
        end
    end
end

local function makeCheckbox(parent, name, text, width)
    local entry = CreateFrame("CheckButton", name, parent)
    entry:SetHeight(22)
    entry:SetWidth(width)
    entry:SetBackdrop({insets = {left = 2, right = 2, top = 2, bottom = 2}})

    entry:SetBackdropBorderColor(0.3, 0.3, 0.3)
    entry:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
    entry:SetScript("OnEnter", function(self)
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(self.tooltip)
        end
    end)
    entry:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local texture = entry:CreateTexture("ARTWORK")
    texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    texture:SetPoint("LEFT", 0, 0)
    texture:SetHeight(26)
    texture:SetWidth(26)
    entry:SetNormalTexture(texture)

    local texture = entry:CreateTexture("ARTWORK")
    texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    texture:SetPoint("LEFT", 0, 0)
    texture:SetHeight(26)
    texture:SetWidth(26)
    texture:SetBlendMode("ADD")
    entry:SetHighlightTexture(texture)

    local texture = entry:CreateTexture("ARTWORK")
    texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    texture:SetPoint("LEFT", 0, 0)
    texture:SetHeight(26)
    texture:SetWidth(26)
    entry:SetCheckedTexture(texture)

    entry.name = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    entry.name:SetPoint("LEFT", 25, 0)
    entry.name:SetJustifyH("LEFT")
    entry.name:SetText(text)
    return entry
end

function Clique:CreateOptionsWidgets(parent)
    local button = CreateFrame("Button", "CliqueOptionsButtonClose", parent.titleBar, "UIPanelCloseButton")
    button:SetHeight(25)
    button:SetWidth(25)
    button:SetPoint("TOPRIGHT", -5, 3)
    button:SetScript("OnClick", function(self, button) Clique:ButtonOnClick(self, button) end)

    local downClick = makeCheckbox(parent, "CliqueOptionsAnyDown", L.DOWNCLICK_LABEL, 300)
    downClick:SetPoint("TOPLEFT", 5, -25)

    local showTooltips = makeCheckbox(parent, "CliqueOptionsShowTooltips", L.SHOWTOOLTIPS_LABEL, 300)
    showTooltips:SetPoint("TOPLEFT", 5, -45)

    local easterEgg = makeCheckbox(parent, "CliqueOptionsEasterEgg", L.EASTEREGG_LABEL, 300)
    easterEgg:SetPoint("TOPLEFT", 5, -65)

    parent.refreshOptionsWidgets = function(self)
        local downClick = Clique.db.char.downClick
        local showTooltips = Clique.db.profile.tooltips
        local easterEgg = Clique.db.char.easterEgg
        CliqueOptionsAnyDown:SetChecked(downClick)
        CliqueOptionsShowTooltips:SetChecked(showTooltips)
        CliqueOptionsEasterEgg:SetChecked(easterEgg)
    end

    downClick:SetScript("OnClick", function(self)
        Clique.db.char.downClick = not Clique.db.char.downClick
        parent:refreshOptionsWidgets()
        Clique:SetClickType() -- Refresh click-registrations for ALL frames.
    end)

    showTooltips:SetScript("OnClick", function(self)
        Clique.db.profile.tooltips = not Clique.db.profile.tooltips
        parent:refreshOptionsWidgets()
    end)

    easterEgg:SetScript("OnClick", function(self)
        Clique.db.char.easterEgg = not Clique.db.char.easterEgg
        parent:refreshOptionsWidgets()
        Clique:Print(Clique.db.char.easterEgg and L.EASTEREGG_MSG1 or L.EASTEREGG_MSG2)
    end)
end
