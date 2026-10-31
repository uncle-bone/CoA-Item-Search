-- CoA Item Search: search every item of the server (name or id) and add it with one click (.additem, GM account).
-- /items opens the window. The item list (CoAItemSearch_Data, 568k items) loads the first time it opens.

local ROWS, ROW_H, MAX_RESULTS = 14, 26, 500
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000", "ffe6cc80", "ff00ccff" }
local results, loaded = {}, false

local frame = CreateFrame("Frame", "CoAItemSearchFrame", UIParent)
frame:SetSize(460, 520)
frame:SetPoint("CENTER")
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetFrameStrata("DIALOG")
frame:Hide()
tinsert(UISpecialFrames, "CoAItemSearchFrame")      -- Escape closes it

local header = frame:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(300, 64)
header:SetPoint("TOP", 0, 12)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("CoA Item Search")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local box = CreateFrame("EditBox", "CoAItemSearchBox", frame, "InputBoxTemplate")
box:SetSize(250, 22)
box:SetPoint("TOPLEFT", 26, -40)
box:SetAutoFocus(false)

local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
countLabel:SetPoint("TOPLEFT", 26, -66)
countLabel:SetText("Type a name or an item id, then press Enter.")


local scroll = CreateFrame("ScrollFrame", "CoAItemSearchScroll", frame, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 20, -86)
scroll:SetPoint("BOTTOMRIGHT", -40, 20)

local rows = {}
local function Refresh()
    local offset = FauxScrollFrame_GetOffset(scroll)
    for i = 1, ROWS do
        local row, item = rows[i], results[offset + i]
        if item then
            if row.id ~= item.id then row.qty:SetText("") end    -- a new item in this row: back to 1
            row.id = item.id
            row.icon:SetTexture(GetItemIcon(item.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText("|c" .. (QUALITY[item.q] or "ffffffff") .. item.name .. "|r")
            row.info:SetText("id " .. item.id .. "   ilvl " .. item.lvl)
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(scroll, #results, ROWS, ROW_H)
end
scroll:SetScript("OnVerticalScroll", function(self, delta) FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H, Refresh) end)

for i = 1, ROWS do
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(400, ROW_H)
    row:SetPoint("TOPLEFT", 24, -88 - (i - 1) * ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT")
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
    row.name:SetWidth(230)
    row.name:SetJustifyH("LEFT")
    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.info:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 0)
    row.add = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.add:SetSize(80, 20)
    row.add:SetPoint("RIGHT")
    row.add:SetText("Add item")
    row.qty = CreateFrame("EditBox", nil, row)                          -- amount for this item; empty = 1
    row.qty:SetSize(38, 20)                                              -- (InputBoxTemplate breaks at this size)
    row.qty:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    row.qty:SetBackdropColor(0, 0, 0, 0.7)
    row.qty:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    row.qty:SetFontObject(ChatFontNormal)
    row.qty:SetJustifyH("CENTER")
    row.qty:SetTextInsets(3, 3, 0, 0)
    row.qty:SetPoint("RIGHT", row.add, "LEFT", -6, 0)
    row.qty:SetAutoFocus(false)
    row.qty:SetNumeric(true)
    row.qty:SetMaxLetters(4)
    row.qty:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.qty:SetScript("OnEnterPressed", function(self) self:ClearFocus() row.add:Click() end)
    row.add:SetScript("OnClick", function()
        local n = tonumber(row.qty:GetText()) or 1
        SendChatMessage(".additem " .. row.id .. " " .. math.max(1, n), "SAY")
    end)
    row:SetScript("OnEnter", function(self)                  -- tooltip once the client knows the item
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)                  -- shift-click links it in chat
        if IsShiftKeyDown() then ChatEdit_InsertLink(select(2, GetItemInfo(self.id)) or ("item " .. self.id)) end
    end)
    rows[i] = row
end

local function LoadData()
    if loaded then return true end
    local ok = LoadAddOn("CoAItemSearch_Data")
    loaded = ok and CoAItemSearchData ~= nil
    if not loaded then countLabel:SetText("|cffff2020CoAItemSearch_Data is missing or disabled.|r") end
    return loaded
end

local function Search(text)
    wipe(results)
    text = strtrim(text or "")
    if text == "" or not LoadData() then Refresh() return end
    local id = tonumber(text)
    local needle = text:lower()
    for _, chunk in ipairs(CoAItemSearchData) do
        for line in chunk:gmatch("[^\n]+") do
            local e, q, lvl, name = line:match("^(%d+)\1(%d+)\1(%d+)\1(.*)$")
            if e and ((id and tonumber(e) == id) or (not id and name:lower():find(needle, 1, true))) then
                results[#results + 1] = { id = tonumber(e), q = tonumber(q), lvl = lvl, name = name }
                if #results >= MAX_RESULTS then break end
            end
        end
        if #results >= MAX_RESULTS then break end
    end
    countLabel:SetText(#results >= MAX_RESULTS and ("First " .. MAX_RESULTS .. " results: type more to narrow it down.")
        or (#results .. " item(s) found."))
    scroll:SetVerticalScroll(0)
    Refresh()
end

box:SetScript("OnEnterPressed", function(self) Search(self:GetText()) self:ClearFocus() end)
box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
frame:SetScript("OnShow", function() box:SetFocus() Refresh() end)

SLASH_COAITEMSEARCH1 = "/items"
SLASH_COAITEMSEARCH2 = "/itemsearch"
SlashCmdList.COAITEMSEARCH = function(msg)
    frame:Show()
    if msg and msg ~= "" then box:SetText(msg) Search(msg) end
end
