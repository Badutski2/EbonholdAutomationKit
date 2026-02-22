local EAK = _G.EbonholdAutomationKit
if not EAK then return end
local U

local function EnsureU()
  if not U and EAK then
    U = EAK.Utils
  end
  return U
end

EAK.StacksUI = EAK.StacksUI or {}
local S = EAK.StacksUI

local function _EAKNavAcquire()
  if not EAK then return end
  EAK._eakNavKeyDownUsers = (EAK._eakNavKeyDownUsers or 0) + 1
  if EAK._eakNavKeyDownUsers == 1 then
    if GetCVar and SetCVar then
      EAK._eakNavKeyDownOrig = GetCVar("ActionButtonUseKeyDown")
      SetCVar("ActionButtonUseKeyDown", "1")
    end
  end
end

local function _EAKNavRelease()
  if not EAK then return end
  local n = (EAK._eakNavKeyDownUsers or 0) - 1
  if n < 0 then n = 0 end
  EAK._eakNavKeyDownUsers = n
  if n == 0 then
    if GetCVar and SetCVar and EAK._eakNavKeyDownOrig ~= nil then
      SetCVar("ActionButtonUseKeyDown", tostring(EAK._eakNavKeyDownOrig))
    end
  end
end


S._navOwnerFrame = nil
S._navBtnUp = nil
S._navBtnDown = nil

function S:_NavMove(dir)
  local b = self and self.activeStacksBox
  local UU = EnsureU()
  if not b or not UU or not UU._EAK_TabMove then return end
  self._movingFocus = true
  UU:_EAK_TabMove(b, dir)
  if not self._moveReleaseFrame then
    self._moveReleaseFrame = CreateFrame("Frame", nil, UIParent)
    self._moveReleaseFrame:Hide()
  end
  local rf = self._moveReleaseFrame
  rf:Show()
  rf:SetScript("OnUpdate", function()
    rf:SetScript("OnUpdate", nil)
    rf:Hide()
    S._movingFocus = false
  end)
end

function S:EnsureNavBindings()
  if not self._navOwnerFrame then
    self._navOwnerFrame = CreateFrame("Frame", "EAKStacksNavOwnerFrame", UIParent)
    self._navOwnerFrame:Hide()
  end
  local owner = self._navOwnerFrame
  owner:Show()
  if owner._eakNavActive then return end
  owner._eakNavActive = true
  if not self._navBtnUp then
    self._navBtnUp = CreateFrame("Button", "EAKStacksNavUpButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnUp:Hide()
    self._navBtnUp:SetScript("OnClick", function()
      if S and S._NavMove then S:_NavMove(-1) end
    end)
  end
  if not self._navBtnDown then
    self._navBtnDown = CreateFrame("Button", "EAKStacksNavDownButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnDown:Hide()
    self._navBtnDown:SetScript("OnClick", function()
      if S and S._NavMove then S:_NavMove(1) end
    end)
  end
  if not self._navBtnTab then
    self._navBtnTab = CreateFrame("Button", "EAKStacksNavTabButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnTab:Hide()
    self._navBtnTab:SetScript("OnClick", function()
      local dir = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
      if S and S._NavMove then S:_NavMove(dir) end
    end)
  end
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(owner) end
  if type(SetOverrideBinding) == "function" then
    SetOverrideBinding(owner, true, "UP", "CLICK "..self._navBtnUp:GetName()..":LeftButton")
    SetOverrideBinding(owner, true, "DOWN", "CLICK "..self._navBtnDown:GetName()..":LeftButton")
    SetOverrideBinding(owner, true, "UPARROW", "CLICK "..self._navBtnUp:GetName()..":LeftButton")
    SetOverrideBinding(owner, true, "DOWNARROW", "CLICK "..self._navBtnDown:GetName()..":LeftButton")
    SetOverrideBinding(owner, true, "TAB", "CLICK "..self._navBtnTab:GetName()..":LeftButton")
  elseif type(SetOverrideBindingClick) == "function" then
    SetOverrideBindingClick(owner, true, "UP", self._navBtnUp:GetName())
    SetOverrideBindingClick(owner, true, "DOWN", self._navBtnDown:GetName())
    SetOverrideBindingClick(owner, true, "UPARROW", self._navBtnUp:GetName())
    SetOverrideBindingClick(owner, true, "DOWNARROW", self._navBtnDown:GetName())
    SetOverrideBindingClick(owner, true, "TAB", self._navBtnTab:GetName())
  end
end

function S:ClearNavBindings()
  if not self._navOwnerFrame then return end
  local owner = self._navOwnerFrame
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(owner) end
  owner._eakNavActive = nil
  owner:Hide()
end


S.panel = nil
S.rows = {}
S.filtered = {}

local ROW_H = 30

local _nameCounter = 0
local function NextName(prefix)
  _nameCounter = _nameCounter + 1
  return (prefix or "EAK") .. "_" .. _nameCounter
end

local function RarityName(q)
  q = tonumber(q) or 0
  if q <= 0 then return "Common" end
  if q == 1 then return "Uncommon" end
  if q == 2 then return "Rare" end
  if q == 3 then return "Epic" end
  return "Legendary"
end

local function RarityRank(q)
  q = tonumber(q) or 0
  if q < 0 then q = 0 end
  if q > 4 then q = 4 end
  return q
end

local function GetSortedList(profile, search)
  local out = {}
  local U = EnsureU()
  if not U then return out end

  search = U:Trim((search or ""):lower())

  local ui = EbonholdAutomationKitDB.ui or {}
  local showAll = (ui.showAllEchoes == true)
  local searchMode = ui.weightsSearchMode or 'name'
  local _, playerClass = UnitClass("player")

  local echoDB = EAK:GetEchoDB() or {}
  local keys = {}

  for k in pairs(echoDB) do
    if type(k) == 'string' and k:match("^%d+:%d+$") then
      keys[k] = true
    end
  end

  if type(profile) == "table" then
    local t = profile.weights
    if type(t) == "table" then
      for k in pairs(t) do
        if type(k) == 'string' and k:match("^%d+:%d+$") then keys[k] = true end
      end
    end

    t = profile.blacklist
    if type(t) == "table" then
      for k in pairs(t) do
        if type(k) == 'string' and k:match("^%d+:%d+$") then keys[k] = true end
      end
    end

    t = profile.echoMeta
    if type(t) == "table" then
      for k in pairs(t) do
        if type(k) == 'string' and k:match("^%d+:%d+$") then keys[k] = true end
      end
    end
  end

  for key in pairs(keys) do
    local sid, q = U:ParseKey(key)
    sid = tonumber(sid)
    q = tonumber(q) or 0
    if sid then
      local meta = echoDB[key]
      if type(meta) ~= "table" then meta = {} end

      meta.spellId = tonumber(meta.spellId) or sid
      meta.quality = tonumber(meta.quality) or q

      if (not meta.name) or meta.name == "" then
        meta.name = U:SafeSpellName(sid)
      end

      if meta.icon == nil and GetSpellInfo then
        local _, _, icon = GetSpellInfo(sid)
        if icon then meta.icon = icon end
      end

      echoDB[key] = meta

      local ok = true
      if not showAll and playerClass then
        local classes = meta.classes
        if type(classes) ~= "table" or classes[playerClass] ~= true then
          ok = false
        end
      end

      local name = meta.name or U:SafeSpellName(sid)
      local quality = tonumber(meta.quality) or 0

      if ok and search ~= "" then
        if (searchMode or 'name') == 'tooltip' then
          local tip = meta.tooltipSearch or (meta.tooltipText and U:NormalizeSearchText(meta.tooltipText)) or ""
          if type(tip) ~= 'string' or tip == '' then
            local lines, text, searchNorm = U:CaptureSpellTooltip(sid)
            if lines and text and searchNorm then
              meta.tooltipLines = lines
              meta.tooltipText = text
              meta.tooltipSearch = searchNorm
              meta.tooltipCapturedAt = U:NowStamp()
              echoDB[key] = meta
              tip = searchNorm
            end
          end
          ok = (type(tip) == 'string' and tip ~= '' and tip:find(search, 1, true) ~= nil)
        else
          local rname = RarityName(quality)
          ok = (name and name:lower():find(search, 1, true) ~= nil)
            or (rname and rname:lower():find(search, 1, true) ~= nil)
            or tostring(quality):find(search, 1, true) ~= nil
            or tostring(key):find(search, 1, true) ~= nil
            or tostring(sid):find(search, 1, true) ~= nil
        end
      end

      if ok then
        table.insert(out, {
          key = key,
          spellId = sid,
          quality = quality,
          icon = meta.icon,
          name = name,
          stacks = U:GetStackTarget(profile, sid),
        })
      end
    end
  end

  local uiS = EbonholdAutomationKitDB.uiStacks or {}
  local key = uiS.sortKey or 'name'
  local asc = (uiS.sortAsc ~= false)

  local function cmp(x, y)
    if asc then return x < y else return x > y end
  end

  table.sort(out, function(a, b)
    if not a or not b then return false end
    local anRaw = a.name or ""
    local bnRaw = b.name or ""
    local an = U:StripWoWFormatting(anRaw):lower()
    local bn = U:StripWoWFormatting(bnRaw):lower()
    local ar = RarityRank(a.quality)
    local br = RarityRank(b.quality)
    local ast = tonumber(a.stacks) or 0
    local bst = tonumber(b.stacks) or 0
    local ak = a.key or ""
    local bk = b.key or ""

    if key == 'stacks' then
      if ast ~= bst then return cmp(ast, bst) end
      if an ~= bn then return cmp(an, bn) end
      if ar ~= br then return cmp(ar, br) end
      if ak ~= bk then return cmp(ak, bk) end
      return false
    elseif key == 'rarity' then
      if ar ~= br then return cmp(ar, br) end
      if an ~= bn then return cmp(an, bn) end
      if ast ~= bst then return cmp(ast, bst) end
      if ak ~= bk then return cmp(ak, bk) end
      return false
    else
      if an ~= bn then return cmp(an, bn) end
      if ar ~= br then return cmp(ar, br) end
      if ast ~= bst then return cmp(ast, bst) end
      if ak ~= bk then return cmp(ak, bk) end
      return false
    end
  end)

  return out
end

local function CreateRow(parent, idx)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  row:EnableMouse(false)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 30, 0)
  row.iconTex = icon

  local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  name:SetJustifyH("LEFT")

  local hover = CreateFrame("Button", nil, row)
  hover:EnableMouse(true)

  local stacksBox = CreateFrame("EditBox", nil, row)
  stacksBox:EnableMouse(true)
  stacksBox:SetAutoFocus(false)
  if stacksBox.EnableKeyboard then stacksBox:EnableKeyboard(true) end
  stacksBox:SetMultiLine(false)
  if stacksBox.SetAltArrowKeyMode then stacksBox:SetAltArrowKeyMode(false) end
  stacksBox:SetFontObject(ChatFontNormal)
  if stacksBox.SetTextColor then stacksBox:SetTextColor(1, 1, 1) end
  if stacksBox.SetTextInsets then stacksBox:SetTextInsets(6, 6, 3, 3) end
  stacksBox:SetSize(60, 20)
  stacksBox:SetPoint("RIGHT", -12, 0)
  stacksBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  stacksBox:SetBackdropColor(0, 0, 0, 0.35)
  stacksBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  stacksBox:SetNumeric(false)
  stacksBox:SetJustifyH("CENTER")

  local rarity = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rarity:SetWidth(80)
  rarity:SetJustifyH("CENTER")
  rarity:SetPoint("RIGHT", stacksBox, "LEFT", -12, 0)

  name:SetPoint("RIGHT", rarity, "LEFT", -10, 0)

  hover:ClearAllPoints()
  hover:SetPoint("LEFT", icon, "LEFT", -2, 0)
  hover:SetPoint("RIGHT", rarity, "LEFT", -6, 0)
  hover:SetPoint("TOP", row, "TOP", 0, 0)
  hover:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)

  hover:SetFrameLevel(row:GetFrameLevel() + 1)
  stacksBox:SetFrameLevel(row:GetFrameLevel() + 2)

  stacksBox:SetScript("OnMouseDown", function(self)
    self._eakClicked = true
    self:SetFocus()
  end)

  stacksBox:SetScript("OnMouseUp", function(self)
    if self._eakClicked then
      self._eakClicked = nil
      self:SetScript("OnUpdate", function(s)
        s:SetScript("OnUpdate", nil)
        if s.HasFocus and s:HasFocus() and s.HighlightText then
          s:HighlightText()
        elseif s.HighlightText then
          s:HighlightText()
        end
      end)
    end
  end)

  stacksBox:SetScript("OnEditFocusGained", function(self)
    S.activeStacksBox = self
    if S and S.EnsureNavBindings then S:EnsureNavBindings() end
    self._origText = self:GetText()
    if self.SetAltArrowKeyMode then
      if self.GetAltArrowKeyMode then
        self._eakOldAltArrows = self:GetAltArrowKeyMode()
      else
        self._eakOldAltArrows = false
      end
      self:SetAltArrowKeyMode(true)
    end
    if self.HighlightText then self:HighlightText() end
  end)

  stacksBox:SetScript("OnEditFocusLost", function(self)
  if S._scrolling or S._movingFocus then return end
  if S.activeStacksBox == self then S.activeStacksBox = nil end
  if S and S.ClearNavBindings then S:ClearNavBindings() end
  if self.SetAltArrowKeyMode then self:SetAltArrowKeyMode(self._eakOldAltArrows and true or false) end
  self._eakOldAltArrows = nil
  if self.HighlightText then self:HighlightText(0, 0) end

  if not row.data then return end
  local txt = tostring(self:GetText() or "")
  local val = tonumber(txt)
  if not val then val = 0 end
  val = math.floor(val + 0.5)

  local p = EAK:GetProfile()
  p.stackTargets = p.stackTargets or {}

  if val < 1 then
    p.stackTargets[row.data.spellId] = nil
    self:SetText("")
  else
    p.stackTargets[row.data.spellId] = val
  end
end)

  stacksBox:SetScript("OnTabPressed", function(self)
    local dir = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
    if S and S._NavMove then S:_NavMove(dir) end
  end)

  stacksBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    if not row.data then return end
    local txt = tostring(self:GetText() or "")
    local val = tonumber(txt)
    if not val then return end
    val = math.floor(val + 0.5)
    row.data.stacks = val
  end)

  stacksBox:SetScript("OnEscapePressed", function(self)
    if self._origText ~= nil then
      self:SetText(self._origText)
      if row.data then
        local p = EAK:GetProfile()
        p.stackTargets = p.stackTargets or {}
        local v = tonumber(self._origText) or 0
        if v < 1 then
          p.stackTargets[row.data.spellId] = nil
        else
          p.stackTargets[row.data.spellId] = math.floor(v + 0.5)
        end
      end
    end
    self:ClearFocus()
  end)

  stacksBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  stacksBox:SetScript("OnKeyDown", function(self, key)
    if key == "UP" then
      if S and S.FocusRelativeStacksBox then
        S:FocusRelativeStacksBox(self, -1)
      end
    elseif key == "DOWN" then
      if S and S.FocusRelativeStacksBox then
        S:FocusRelativeStacksBox(self, 1)
      end
    end
  end)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(stacksBox)
  end

  local del = CreateFrame("Button", nil, row)
  del:SetSize(18, 18)
  del:SetPoint("LEFT", 4, 0)
  del:SetNormalFontObject(GameFontNormalSmall)
  del:SetText("|cffff6666X|r")
  del:SetFrameLevel(row:GetFrameLevel() + 2)
  del:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Remove this Echo from your profile settings", 1, 1, 1, true)
    GameTooltip:AddLine("(Does not delete it from the global Echo database)", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
  end)
  del:SetScript("OnLeave", function() GameTooltip:Hide() end)
  del:SetScript("OnClick", function(self)
    if not row.data then return end
    local p = EAK:GetProfile()
    if p.weights then p.weights[row.data.key] = nil end
    if p.blacklist then p.blacklist[row.data.key] = nil end
    if p.echoMeta then p.echoMeta[row.data.key] = nil end
    if p.stackTargets then p.stackTargets[row.data.spellId] = nil end
    S:Refresh()
  end)

  row.nameText = name
  row.rarityText = rarity
  row.stacksBox = stacksBox
  row.deleteBtn = del

  local function ShowSpellTooltip(owner)
    if not row.data or not row.data.spellId then return end
    local U = EnsureU()
    if not U then return end
    GameTooltip:SetOwner(owner or row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local sid = row.data.spellId
    local link = (type(GetSpellLink) == 'function') and GetSpellLink(sid) or nil
    if link and link ~= "" then
      GameTooltip:SetHyperlink(link)
    else
      local ok = pcall(function() GameTooltip:SetHyperlink("spell:" .. tostring(sid)) end)
      if not ok then
        GameTooltip:ClearLines()
        local U = EnsureU()
        GameTooltip:AddLine((U and U:SafeSpellName(sid)) or tostring(sid), 1, 1, 1)
        GameTooltip:AddLine("SpellID: " .. tostring(sid), 0.9, 0.9, 0.9)
      end
    end

    local p = EAK:GetProfile()
    local tgt = (U and U:GetStackTarget(p, sid)) or 0
    if tgt and tgt >= 1 then
      local owned = 0
      if EAK.Engine and EAK.Engine.CountOwnedStacks then
        owned = tonumber(EAK.Engine:CountOwnedStacks(sid)) or 0
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Target: " .. tostring(tgt) .. "   Owned: " .. tostring(owned), 0.9, 0.9, 0.9)
    end

    GameTooltip:Show()
  end

  hover:SetScript("OnEnter", function(self) ShowSpellTooltip(self) end)
  hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  hover:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    if not row.data or not row.data.spellId then return end
    if type(IsModifiedClick) == 'function' then
      if IsModifiedClick("CHATLINK") then self._eakLinkDown = true return end
    end
    if type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() then self._eakLinkDown = true return end
    self._eakLinkDown = nil
  end)

  hover:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then return end
    if not self._eakLinkDown then return end
    self._eakLinkDown = nil
    if not row.data or not row.data.spellId then return end
    local U = EnsureU()
    if U and U.TryInsertSpellLink and U:TryInsertSpellLink(row.data.spellId, row.data.quality, true) then
      GameTooltip:Hide()
    end
  end)

  return row
end


function S:CommitStacksBox(box, row)
  if not box or not row or not row.data then return true end
  local txt = tostring(box:GetText() or "")
  local p = EAK:GetProfile()
  p.stackTargets = p.stackTargets or {}
  local val = tonumber(txt)
  if txt == "" then val = 0 end
  if val == nil then
    local U = EnsureU()
    local saved = (U and U:GetStackTarget(p, row.data.spellId)) or 0
    row.data.stacks = saved
    if saved >= 1 then box:SetText(tostring(saved)) else box:SetText("") end
    return false
  end
  val = math.floor(val + 0.5)
  if val < 1 then
    p.stackTargets[row.data.spellId] = nil
    row.data.stacks = 0
    box:SetText("")
  else
    p.stackTargets[row.data.spellId] = val
    row.data.stacks = val
    box:SetText(tostring(val))
  end
  return true
end

function S:FocusRelativeStacksBox(curBox, dir)
  if not self.scrollFrame or not self.filtered or #self.filtered == 0 then return end
  dir = tonumber(dir) or 1
  if dir == 0 then dir = 1 end

  local curIndex
  local curRow
  for _, row in ipairs(self.rows or {}) do
    if row and row.stacksBox == curBox then
      curIndex = tonumber(row.absIndex)
      curRow = row
      break
    end
  end
  if not curIndex or not curRow then return end

  self:CommitStacksBox(curBox, curRow)

  self._movingFocus = true
  if curBox and curBox.HighlightText then curBox:HighlightText(0, 0) end
  if curBox and curBox.ClearFocus then curBox:ClearFocus() end
  self._movingFocus = false

  local total = #self.filtered
  local target = curIndex + dir
  if target < 1 then target = total end
  if target > total then target = 1 end

  local offset = FauxScrollFrame_GetOffset(self.scrollFrame) or 0
  local visible = #self.rows
  local newOffset = offset

  if target <= offset then
    newOffset = target - 1
  elseif target > (offset + visible) then
    newOffset = target - visible
  end
  if newOffset < 0 then newOffset = 0 end

  if newOffset ~= offset then
    local sb = _G[self.scrollFrame:GetName() .. "ScrollBar"]
    if sb and sb.SetValue then
      sb:SetValue(newOffset * ROW_H)
    else
      self.scrollFrame:SetVerticalScroll(newOffset * ROW_H)
    end
  end

  self:Refresh()

  for _, row in ipairs(self.rows or {}) do
    if row and tonumber(row.absIndex) == target and row.stacksBox and row.stacksBox.SetFocus then
      row.stacksBox:SetFocus()
      if row.stacksBox.HighlightText then row.stacksBox:HighlightText() end
      break
    end
  end
end


local function setHeaderText(headerName, headerRarity, headerStacks)
  local uiS = EbonholdAutomationKitDB.uiStacks or {}
  local key = uiS.sortKey or "name"
  local asc = (uiS.sortAsc ~= false)
  local up = " |cffaaaaaa▲|r"
  local dn = " |cffaaaaaa▼|r"

  if key == "name" then
    headerName:SetText("Echo Name" .. (asc and up or dn))
    headerRarity:SetText("Rarity")
    headerStacks:SetText("Stacks")
  elseif key == "rarity" then
    headerName:SetText("Echo Name")
    headerRarity:SetText("Rarity" .. (asc and up or dn))
    headerStacks:SetText("Stacks")
  else
    headerName:SetText("Echo Name")
    headerRarity:SetText("Rarity")
    headerStacks:SetText("Stacks" .. (asc and up or dn))
  end
end

function S:Refresh()
  if not self.panel then return end
  local U = EnsureU()
  if not U then return end
  local profile = EAK:GetProfile()
  self.filtered = GetSortedList(profile, self.searchBox and self.searchBox:GetText() or "")

  if self.showAllBtn then
    local ui = EbonholdAutomationKitDB.ui or {}
    local showAll = (ui.showAllEchoes == true)
    self.showAllBtn:SetText(showAll and "Show Class Echoes" or "Show All Echoes")
  end

  FauxScrollFrame_Update(self.scrollFrame, #self.filtered, #self.rows, ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.scrollFrame)

  for i = 1, #self.rows do
    local row = self.rows[i]
    local idx = i + offset
    local data = self.filtered[idx]
    if data then
      row.data = data
      row.absIndex = idx
      local r, g, b = U:RarityColor(data.quality)
      row.nameText:SetText(data.name or "Unknown")
      row.nameText:SetTextColor(r, g, b)
      if row.rarityText then
        row.rarityText:SetText(RarityName(data.quality))
        row.rarityText:SetTextColor(r, g, b)
      end
      if data.icon then
        row.iconTex:SetTexture(data.icon)
        row.iconTex:Show()
      else
        row.iconTex:Hide()
      end
      if not (row.stacksBox and row.stacksBox:HasFocus()) then
        local v = tonumber(data.stacks) or 0
        if v >= 1 then
          row.stacksBox:SetText(tostring(v))
        else
          row.stacksBox:SetText("")
        end
        if row.stacksBox.SetCursorPosition then row.stacksBox:SetCursorPosition(0) end
        if row.stacksBox.HighlightText then row.stacksBox:HighlightText(0, 0) end
      end
      row:Show()
    else
      row.data = nil
      row.absIndex = nil
      row:Hide()
    end
  end

  if self.headerName and self.headerRarity and self.headerStacks then
    setHeaderText(self.headerName, self.headerRarity, self.headerStacks)
  end

  if self.countText then
    local total = U:TableSize(EAK:GetEchoDB() or {})
    self.countText:SetText("Echoes Shown: " .. tostring(#self.filtered) .. " / " .. tostring(total))
  end
end

function S:CreatePanel(parentName)
  if self.panel then return end
  local U = EnsureU()
  if not U then return end

  EbonholdAutomationKitDB.uiStacks = EbonholdAutomationKitDB.uiStacks or { sortKey = 'name', sortAsc = true }

  local panel = CreateFrame("Frame", "EAK_StacksPanel", InterfaceOptionsFramePanelContainer)
  panel.name = "Echo Stacks"
  panel.parent = parentName
  self.panel = panel

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Echo Stacks")

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  help:SetHeight(100)
  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")
  help:SetNonSpaceWrap(true)
  help:SetText("Set a max stack target per Echo. Leave it blank (or 0) to ignore stacks for that Echo.\n\nWhen you reach the target, the automation treats that Echo as blacklisted.")
  local searchLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", 16, -110)
  searchLabel:SetText("Search")

  local search = CreateFrame("EditBox", nil, panel)
  search:SetSize(200, 20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetFontObject(ChatFontNormal)
  if search.SetTextColor then search:SetTextColor(1, 1, 1) end
  if search.SetTextInsets then search:SetTextInsets(6, 6, 3, 3) end
  search:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  search:SetBackdropColor(0, 0, 0, 0.35)
  search:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  search:SetScript("OnTextChanged", function() S:Refresh() end)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(search)
  end
  self.searchBox = search

  local modeFrame = CreateFrame("Frame", nil, panel)
  modeFrame:SetSize(118, 20)
  modeFrame:SetPoint("LEFT", search, "RIGHT", 8, 0)

  local modeNameBtn = CreateFrame("Button", nil, modeFrame, "UIPanelButtonTemplate")
  modeNameBtn:SetSize(58, 20)
  modeNameBtn:SetPoint("LEFT", 0, 0)
  modeNameBtn:SetText("Name")

  local modeTipBtn = CreateFrame("Button", nil, modeFrame, "UIPanelButtonTemplate")
  modeTipBtn:SetSize(58, 20)
  modeTipBtn:SetPoint("LEFT", modeNameBtn, "RIGHT", 2, 0)
  modeTipBtn:SetText("Tooltip")

  local function UpdateModeButtons()
    EbonholdAutomationKitDB.ui = EbonholdAutomationKitDB.ui or {}
    local ui = EbonholdAutomationKitDB.ui
    local mode = ui.weightsSearchMode or 'name'
    if mode == 'tooltip' then
      modeTipBtn:Disable()
      modeNameBtn:Enable()
    else
      modeNameBtn:Disable()
      modeTipBtn:Enable()
    end
  end

  local function SetMode(mode)
    EbonholdAutomationKitDB.ui = EbonholdAutomationKitDB.ui or {}
    EbonholdAutomationKitDB.ui.weightsSearchMode = mode
    UpdateModeButtons()
    S:Refresh()
  end

  modeNameBtn:SetScript("OnClick", function() SetMode('name') end)
  modeTipBtn:SetScript("OnClick", function() SetMode('tooltip') end)

  modeNameBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Search by Echo name / ID", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  modeNameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  modeTipBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Search by spell tooltip text", 1, 1, 1, true)
    GameTooltip:AddLine("(Tooltips are saved automatically as Echoes appear.)", 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
  end)
  modeTipBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.modeNameBtn = modeNameBtn
  self.modeTooltipBtn = modeTipBtn

  local listContainer = CreateFrame("Frame", nil, panel)
  listContainer:SetPoint("TOPLEFT", 16, -136)
  listContainer:SetPoint("TOPRIGHT", -16, -136)
  listContainer:SetHeight(272)
  listContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  listContainer:SetBackdropColor(0, 0, 0, 0.35)
  listContainer:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  listContainer:EnableMouse(true)
  listContainer:SetScript("OnMouseDown", function()
    if S.activeStacksBox and S.activeStacksBox.ClearFocus then
      if S.activeStacksBox.HighlightText then S.activeStacksBox:HighlightText(0, 0) end
      S.activeStacksBox:ClearFocus()
    end
  end)

  local header = CreateFrame("Frame", nil, listContainer)
  header:SetPoint("TOPLEFT", 4, -4)
  header:SetPoint("TOPRIGHT", -28, -4)
  header:SetHeight(22)

  local headerBG = header:CreateTexture(nil, "BACKGROUND")
  headerBG:SetAllPoints(header)
  headerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
  headerBG:SetVertexColor(1, 1, 1, 0.06)

  local headerName = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerName:SetPoint("LEFT", 10, 0)
  headerName:SetText("Echo Name")

  local headerStacks = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerStacks:SetWidth(60)
  headerStacks:SetJustifyH("CENTER")
  headerStacks:SetPoint("RIGHT", -34, 0)
  headerStacks:SetText("Stacks")

  local headerRarity = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerRarity:SetWidth(80)
  headerRarity:SetJustifyH("CENTER")
  headerRarity:SetPoint("RIGHT", headerStacks, "LEFT", -12, 0)
  headerRarity:SetText("Rarity")

  headerName:SetPoint("RIGHT", headerRarity, "LEFT", -10, 0)

  self.headerName = headerName
  self.headerRarity = headerRarity
  self.headerStacks = headerStacks

  local function ToggleSort(newKey)
    EbonholdAutomationKitDB.uiStacks = EbonholdAutomationKitDB.uiStacks or { sortKey = newKey, sortAsc = true }
    local uiS = EbonholdAutomationKitDB.uiStacks
    local prevKey = uiS.sortKey or 'name'
    if prevKey == newKey then
      uiS.sortAsc = not (uiS.sortAsc ~= false)
    else
      uiS.sortKey = newKey
      uiS.sortAsc = true
    end
  end

  local nameBtn = CreateFrame("Button", nil, header)
  nameBtn:SetAllPoints(headerName)
  nameBtn:SetScript("OnClick", function()
    ToggleSort('name')
    S:Refresh()
  end)

  local rarityBtn = CreateFrame("Button", nil, header)
  rarityBtn:SetAllPoints(headerRarity)
  rarityBtn:SetScript("OnClick", function()
    ToggleSort('rarity')
    S:Refresh()
  end)

  local stacksBtn = CreateFrame("Button", nil, header)
  stacksBtn:SetAllPoints(headerStacks)
  stacksBtn:SetScript("OnClick", function()
    ToggleSort('stacks')
    S:Refresh()
  end)

  local scroll = CreateFrame("ScrollFrame", "EAK_StacksScroll", listContainer, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -26)
  scroll:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 8)
  self.scrollFrame = scroll
  scroll:SetScript("OnVerticalScroll", function(self, offset)
    S._scrolling = true
    if S.activeStacksBox and S.activeStacksBox.ClearFocus then
      S.activeStacksBox:ClearFocus()
    end
    S._scrolling = false
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() S:Refresh() end)
  end)

  local sb = _G[scroll:GetName() .. "ScrollBar"]
  if sb and sb.ClearAllPoints then
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, 4)
    sb:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 0, 12)

    local function clearActive()
      if S.activeStacksBox and S.activeStacksBox.ClearFocus then
        if S.activeStacksBox.HighlightText then S.activeStacksBox:HighlightText(0, 0) end
        S.activeStacksBox:ClearFocus()
      end
    end
    if sb.HookScript then
      sb:HookScript("OnMouseDown", function() clearActive() end)
    elseif sb.SetScript and sb.GetScript then
      local prev = sb:GetScript("OnMouseDown")
      sb:SetScript("OnMouseDown", function(self, btn)
        clearActive()
        if prev then prev(self, btn) end
      end)
    end
  end

  local content = CreateFrame("Frame", nil, listContainer)
  content:SetPoint("TOPLEFT", 0, -26)
  content:SetPoint("BOTTOMRIGHT", -24, 8)

  scroll:SetFrameLevel(listContainer:GetFrameLevel() + 1)
  content:SetFrameLevel(scroll:GetFrameLevel() + 1)

  self.rows = {}
  for i = 1, 8 do
    local row = CreateRow(content, i)
    row:SetFrameLevel(content:GetFrameLevel() + 1)
    row:SetPoint("TOPLEFT", 0, - (i-1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, - (i-1) * ROW_H)
    table.insert(self.rows, row)
  end

  local countText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  countText:SetPoint("TOPLEFT", listContainer, "BOTTOMLEFT", 4, -6)
  countText:SetText("")
  self.countText = countText

  local showAllBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  showAllBtn:SetSize(150, 20)
  showAllBtn:SetPoint("TOPLEFT", listContainer, "BOTTOMRIGHT", -150, 0)
  showAllBtn:SetText("Show All Echoes")
  showAllBtn:SetScript("OnClick", function()
    EbonholdAutomationKitDB.ui = EbonholdAutomationKitDB.ui or {}
    local ui = EbonholdAutomationKitDB.ui
    ui.showAllEchoes = not (ui.showAllEchoes == true)
    S:Refresh()
  end)
  self.showAllBtn = showAllBtn

  panel.refresh = function() S:Refresh() end

  panel:SetScript("OnShow", function()
    UpdateModeButtons()
    if panel.refresh then panel.refresh() end
    U:After(0, function()
      if panel:IsShown() and panel.refresh then panel.refresh() end
    end)
  end)

  panel:SetScript("OnHide", function()
    if S and S.activeStacksBox and S.activeStacksBox.ClearFocus then
      if S.activeStacksBox.HighlightText then S.activeStacksBox:HighlightText(0, 0) end
      S.activeStacksBox:ClearFocus()
    end
    S.activeStacksBox = nil
  end)

  InterfaceOptions_AddCategory(panel)

  self:Refresh()
end