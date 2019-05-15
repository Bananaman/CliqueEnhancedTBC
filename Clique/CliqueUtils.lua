--[[---------------------------------------------------------------------------------
  Clique by Cladhaire <cladhaire@gmail.com>
  Clique Enhanced by VideoPlayerCode <https://github.com/VideoPlayerCode/CliqueEnhancedTBC>
----------------------------------------------------------------------------------]]

local IsAltKeyDown = IsAltKeyDown;
local IsControlKeyDown = IsControlKeyDown;
local IsShiftKeyDown = IsShiftKeyDown;
local SecureButton_GetButtonSuffix = SecureButton_GetButtonSuffix;
local pairs = pairs;
local tonumber = tonumber;
local type = type;

local buttonMap = setmetatable({
    [1] = "LeftButton",
    [2] = "RightButton",
    [3] = "MiddleButton",
    [4] = "Button4",
    [5] = "Button5",
}, {
    -- Handles any future, missing key lookups, such as "6" = "Button6", etc...
    __index = function(t, k)
        return "Button" .. k;
    end
})

function Clique:GetModifierText()
    -- Based on the code of Blizzard's "SecureButton_GetModifierPrefix".
    local modifier = "";

    if (IsShiftKeyDown()) then
        modifier = "Shift-"..modifier;
    end
    if (IsControlKeyDown()) then
        modifier = "Ctrl-"..modifier;
    end
    if (IsAltKeyDown()) then
        modifier = "Alt-"..modifier;
    end

    return modifier;
end

-- Converts a button label such as "LeftButton" to its numeric value (ie. 1).
-- Returns an empty string on failure.
function Clique:GetButtonNumber(button)
    -- Sometimes Clique calls this function with input that's already a number/numeric string. In that case, we should
    -- simply return the same input as-a-number, while also verifying that it's valid (number starting from 1 or higher).
    local num, inputType;
    inputType = type(button);
    if (inputType == "string") then
        button = button:gsub("^h[ea][lr][pm]button", ""); -- Removes any helpbutton/harmbutton prefix.
        num = tonumber(button); -- Attempt to coerce string input into a number instead.
    elseif (inputType == "number") then
        num = button;
    end
    if (num) then -- Input was numeric or a numeric string (successfully converted into a number).
        return (num >= 1) and num or ""; -- Discard negative results.
    end

    -- Call Blizzard's API which converts LeftButton="1", RightButton="2", MiddleButton="3", Button4="4", Button5="5",
    -- and any invalid input into "-<input as tostring()>" (so asking for "Button6" would make it return "-Button6").
    -- However, we DON'T want the result as string and we DON'T want the invalid (minus-prefixed) results. So we'll
    -- simply pass everything through tonumber() which returns nil if it doesn't get a clean number/numeric string.
    num = tonumber( ( SecureButton_GetButtonSuffix(button or "") ) ); -- NOTE: Double parenthesis to only keep 1st return value.
    return (num and num >= 1) and num or ""; -- Discard negative results.
end

-- Converts a button number such as "1" to its human-readable label (ie. "LeftButton").
-- Returns an empty string on failure.
function Clique:GetButtonText(num)
    -- Attempt to coerce string input into a number instead.
    if (type(num) == "string") then
        -- NOTE: "tonumber" will never throw an error; it simply returns nil on invalid input.
        -- NOTE: Double parenthesis are NECESSARY to throw away gsub's 2nd return value!
        num = tonumber( ( num:gsub("^h[ea][lr][pm]button", "") ) ); -- Removes any helpbutton/harmbutton prefix.
    end

    -- If the result (or original input) wasn't a clean number, or is less than 1, we received invalid input.
    if (type(num) ~= "number" or num < 1) then return ""; end

    -- Convert the number to a button label. This ALWAYS succeeds since buttonMap generates "ButtonX" for any "unsupported" buttons.
    return buttonMap[num];
end

function Clique:CheckBinding(key)
    return key and self.editSet[key] -- Returns binding-data if "key" provided and exists in set, otherwise nil.
end

function Clique:HookScript(frame, script, fn)
    -- Safely sets or hooks script handlers on a frame, without tainting Blizzard's scripts or overwriting any existing scripts.
    -- NOTE: "HookScript" securely adds actions after the existing handler, without overwriting/tainting the original script,
    -- but it cannot execute (does nothing) if no script exists. So we'll dynamically "SetScript" instead in that case.
    if (frame:GetScript(script)) then
        frame:HookScript(script, fn);
    else
        frame:SetScript(script, fn);
    end
end

