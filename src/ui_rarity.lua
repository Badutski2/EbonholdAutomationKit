local EAK = _G.EbonholdAutomationKit
local U = EAK.Utils

EAK.RarityUI = EAK.RarityUI or {}
local R = EAK.RarityUI

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


R._navOwnerFrame = nil
R._navBtnUp = nil
R._navBtnDown = nil
R.activeBox = nil

function R:EnsureNavBindings()
  if not self._navOwnerFrame then
    self._navOwnerFrame = CreateFrame("Frame", "EAKRarityNavOwnerFrame", UIParent)
    self._navOwnerFrame:Hide()
  end
  local owner = self._navOwnerFrame
  owner:Show()
  if owner._eakNavActive then return end
  owner._eakNavActive = true
  if not self._navBtnUp then
    self._navBtnUp = CreateFrame("Button", "EAKRarityNavUpButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnUp:Hide()
    self._navBtnUp:SetScript("OnClick", function()
      local b = R and R.activeBox
      if b and U and U._EAK_TabMove then U:_EAK_TabMove(b, -1) end
    end)
  end
  if not self._navBtnDown then
    self._navBtnDown = CreateFrame("Button", "EAKRarityNavDownButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnDown:Hide()
    self._navBtnDown:SetScript("OnClick", function()
      local b = R and R.activeBox
      if b and U and U._EAK_TabMove then U:_EAK_TabMove(b, 1) end
    end)
  end
  if not self._navBtnTab then
    self._navBtnTab = CreateFrame("Button", "EAKRarityNavTabButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnTab:Hide()
    self._navBtnTab:SetScript("OnClick", function()
      local b = R and R.activeBox
      local dir = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
      if b and b._eakTabMoveFn then
        local n = b._eakTabMoveFn(b, dir)
        if n and n.SetFocus then n:SetFocus() end
      elseif b and U and U._EAK_TabMove then
        U:_EAK_TabMove(b, dir)
      end
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

function R:ClearNavBindings()
  if not self._navOwnerFrame then return end
  local owner = self._navOwnerFrame
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(owner) end
  owner._eakNavActive = nil
  owner:Hide()
end


R.panel = nil

local function MakePanel(name, parentName, title)
  local panel = CreateFrame("Frame", name, InterfaceOptionsFramePanelContainer)
  panel.name = title or name
  panel.parent = parentName

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 16, -16)
  header:SetText(title or name)

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  sub:SetHeight(70)
  sub:SetJustifyH("LEFT")
  sub:SetJustifyV("TOP")
  sub:SetNonSpaceWrap(true)
  sub:SetWordWrap(true)
  sub:SetText("These values adjust how much rarity affects scoring. Bonus is added to the base weight, then multiplied.")


  local content = CreateFrame("Frame", name .. "Content", panel)
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -78)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)

  panel.content = content
  panel.header = header
  panel.sub = sub

  return panel, content
end


local defBonus = { [0]=0,[1]=5,[2]=12,[3]=25,[4]=45 }
local defMult  = { [0]=1.00,[1]=1.05,[2]=1.12,[3]=1.20,[4]=1.35 }

local function EnsureTables(p)
  if type(p.qualityBonus) ~= "table" then p.qualityBonus = {} end
  if type(p.qualityMultiplier) ~= "table" then p.qualityMultiplier = {} end
  for i=0,4 do
    if p.qualityBonus[i] == nil then p.qualityBonus[i] = defBonus[i] end
    if p.qualityMultiplier[i] == nil then p.qualityMultiplier[i] = defMult[i] end
  end
end

local function CreateNumberBox(parent, width)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:SetAutoFocus(false)
  eb:SetMultiLine(false)
  if eb.EnableKeyboard then eb:EnableKeyboard(true) end
  if eb.SetAltArrowKeyMode then eb:SetAltArrowKeyMode(false) end


  eb:SetFontObject(GameFontHighlightSmall)
  if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
  local fs = eb.GetFontString and eb:GetFontString() or nil
  if fs and fs.SetTextColor then
    fs:SetTextColor(1, 1, 1)
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1) end
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  end
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 3, 3) end
  eb:SetHeight(20)
  eb:SetWidth(width)
  eb:EnableMouse(true)
  eb:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  eb:SetBackdropColor(0, 0, 0, 0.35)
  eb:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  eb:SetJustifyH("CENTER")
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return eb
end

local function ForceBoxStyle(eb)
  if not eb then return end
  if eb.SetFontObject then eb:SetFontObject(GameFontHighlightSmall) end
  if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
  local fs = eb.GetFontString and eb:GetFontString() or nil
  if fs and fs.SetTextColor then
    fs:SetTextColor(1, 1, 1)
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1) end
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
  end
end

local function RarityName(q)

  if q == 0 then return "|cffffffffCommon|r" end
  if q == 1 then return "|cff1eff00Uncommon|r" end
  if q == 2 then return "|cff0070ddRare|r" end
  if q == 3 then return "|cffa335eeEpic|r" end
  if q == 4 then return "|cffff8000Legendary|r" end
  return "Unknown"
end

function R:CreatePanel(parentName)
  if self.panel then return end
  local panel, content = MakePanel("EbonholdAutomationKitRarityWeights", parentName, "Rarity Weights")
  self.panel = panel

  panel.rows = panel.rows or {}

  local function GetP()
    local p = EAK:GetProfile()
    EnsureTables(p)
    return p
  end

  local container = CreateFrame("Frame", nil, content)
  container:SetPoint("TOPLEFT", 16, -10)
  container:SetPoint("TOPRIGHT", -16, -10)
  container:SetHeight(190)
  container:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  container:SetBackdropColor(0, 0, 0, 0.35)
  container:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

  local header = CreateFrame("Frame", nil, container)
  header:SetPoint("TOPLEFT", 4, -4)
  header:SetPoint("TOPRIGHT", -4, -4)
  header:SetHeight(22)

  local headerBG = header:CreateTexture(nil, "BACKGROUND")
  headerBG:SetAllPoints(header)
  headerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
  headerBG:SetVertexColor(1, 1, 1, 0.06)

  local h1 = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h1:SetPoint("LEFT", 10, 0)
  h1:SetText("Rarity")


  local BONUS_X = 150
  local MULT_X  = 260

  local h2 = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h2:SetPoint("LEFT", BONUS_X, 0)
  h2:SetText("Bonus")

  local h3 = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h3:SetPoint("LEFT", MULT_X, 0)
  h3:SetText("Multiplier")

  panel.rows = {}

  local function ApplyBox(box, q, isMultiplier)
    local p = GetP()
    local raw = U:Trim(box:GetText() or "")

    raw = raw:gsub(",", ".")
    local num = tonumber(raw)
    if num == nil then

      if isMultiplier then
        box:SetText(tostring(p.qualityMultiplier[q] or defMult[q]))
      else
        box:SetText(tostring(p.qualityBonus[q] or defBonus[q]))
      end
      return
    end
    if isMultiplier then
      p.qualityMultiplier[q] = num
      box:SetText(tostring(num))
    else
      p.qualityBonus[q] = num
      box:SetText(tostring(num))
    end
  end

  local y = -32
  for q = 0, 4 do
    local row = CreateFrame("Frame", nil, container)
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", -8, y)
    row:SetHeight(26)

    local rname = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rname:SetPoint("LEFT", 2, 0)
    rname:SetText(RarityName(q))

    local bonus = CreateNumberBox(row, 80)
    bonus:SetPoint("LEFT", BONUS_X, 0)
    bonus:SetText(tostring(GetP().qualityBonus[q] or defBonus[q]))
    ForceBoxStyle(bonus)
    if bonus.SetAltArrowKeyMode then bonus:SetAltArrowKeyMode(false) end
    bonus:SetScript("OnEditFocusGained", function(self)
      R.activeBox = self
      if R and R.EnsureNavBindings then R:EnsureNavBindings() end
      if self.SetAltArrowKeyMode then
        if self.GetAltArrowKeyMode then self._eakOldAltArrows = self:GetAltArrowKeyMode() else self._eakOldAltArrows = false end
        self:SetAltArrowKeyMode(true)
      end
      if self.HighlightText then self:HighlightText() end
    end)
    bonus:SetScript("OnEditFocusLost", function(self)
  if R._scrolling or R._movingFocus then return end
  if R.activeBox == self then R.activeBox = nil end
  if R and R.ClearNavBindings then R:ClearNavBindings() end
  if self.SetAltArrowKeyMode then self:SetAltArrowKeyMode(self._eakOldAltArrows and true or false) end
  self._eakOldAltArrows = nil
  ApplyBox(self, q, false)
end)

    bonus._eakGridRow = q
    bonus._eakGridCol = 1
    bonus._eakIsRarityBox = true

    local mult = CreateNumberBox(row, 80)
    mult:SetPoint("LEFT", MULT_X, 0)
    mult:SetText(tostring(GetP().qualityMultiplier[q] or defMult[q]))
    ForceBoxStyle(mult)
    if mult.SetAltArrowKeyMode then mult:SetAltArrowKeyMode(false) end
    mult:SetScript("OnEditFocusGained", function(self)
      R.activeBox = self
      if R and R.EnsureNavBindings then R:EnsureNavBindings() end
      if self.SetAltArrowKeyMode then
        if self.GetAltArrowKeyMode then self._eakOldAltArrows = self:GetAltArrowKeyMode() else self._eakOldAltArrows = false end
        self:SetAltArrowKeyMode(true)
      end
      if self.HighlightText then self:HighlightText() end
    end)
    mult:SetScript("OnEditFocusLost", function(self)
  if R._scrolling or R._movingFocus then return end
  if R.activeBox == self then R.activeBox = nil end
  if R and R.ClearNavBindings then R:ClearNavBindings() end
  if self.SetAltArrowKeyMode then self:SetAltArrowKeyMode(self._eakOldAltArrows and true or false) end
  self._eakOldAltArrows = nil
  ApplyBox(self, q, true)
end)

    mult._eakGridRow = q
    mult._eakGridCol = 2

    panel.rows[q] = { bonus = bonus, mult = mult }

    local function TabMove(box, dir)
      local r = box._eakGridRow
      local c = box._eakGridCol
      if r == nil or c == nil then return nil end
      local nr, nc = r, c
      if dir == 1 then
        if c == 1 then
          nc = 2
        else
          nc = 1
          nr = r + 1
        end
      else
        if c == 2 then
          nc = 1
        else
          nc = 2
          nr = r - 1
        end
      end
      if nr < 0 then nr = 4 end
      if nr > 4 then nr = 0 end
      local rowRef = panel.rows[nr]
      if not rowRef then return nil end
      return (nc == 1) and rowRef.bonus or rowRef.mult
    end

    local function ArrowMove(box, dir)
      local r = box._eakGridRow
      local c = box._eakGridCol
      if r == nil or c == nil then return nil end
      local nr = r + dir
      if nr < 0 then nr = 4 end
      if nr > 4 then nr = 0 end
      local rowRef = panel.rows[nr]
      if not rowRef then return nil end
      return (c == 1) and rowRef.bonus or rowRef.mult
    end

    bonus:SetScript("OnTabPressed", function(self)
      local dir = 1
      if type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() then dir = -1 end
      local n = TabMove(self, dir)
      if n and n.SetFocus then
        R._movingFocus = true
        self:ClearFocus()
        n:SetFocus()
        if n.HighlightText then n:HighlightText() end
        if not R._moveReleaseFrame then
          R._moveReleaseFrame = CreateFrame("Frame", nil, UIParent)
          R._moveReleaseFrame:Hide()
        end
        local rf = R._moveReleaseFrame
        rf:Show()
        rf:SetScript("OnUpdate", function()
          rf:SetScript("OnUpdate", nil)
          rf:Hide()
          R._movingFocus = false
        end)
      end
    end)
    mult:SetScript("OnTabPressed", function(self)
      local dir = 1
      if type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() then dir = -1 end
      local n = TabMove(self, dir)
      if n and n.SetFocus then
        R._movingFocus = true
        self:ClearFocus()
        n:SetFocus()
        if n.HighlightText then n:HighlightText() end
        if not R._moveReleaseFrame then
          R._moveReleaseFrame = CreateFrame("Frame", nil, UIParent)
          R._moveReleaseFrame:Hide()
        end
        local rf = R._moveReleaseFrame
        rf:Show()
        rf:SetScript("OnUpdate", function()
          rf:SetScript("OnUpdate", nil)
          rf:Hide()
          R._movingFocus = false
        end)
      end
    end)

    bonus._eakTabMoveFn = TabMove
    mult._eakTabMoveFn = TabMove

    if U and U.EnhanceEditBox then
      U:EnhanceEditBox(bonus)
      U:EnhanceEditBox(mult)
    end
    y = y - 28
  end

  local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  resetBtn:SetSize(140, 22)
  resetBtn:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, -12)
  resetBtn:SetText("Reset to Defaults")
  resetBtn:SetScript("OnClick", function()
    local p = GetP()
    p.qualityBonus = { [0]=0,[1]=5,[2]=12,[3]=25,[4]=45 }
    p.qualityMultiplier = { [0]=1.00,[1]=1.05,[2]=1.12,[3]=1.20,[4]=1.35 }
    for q=0,4 do
      if panel.rows and panel.rows[q] then
        panel.rows[q].bonus:SetText(tostring(p.qualityBonus[q]))
        panel.rows[q].mult:SetText(tostring(p.qualityMultiplier[q]))
        if panel.rows[q].bonus.SetCursorPosition then panel.rows[q].bonus:SetCursorPosition(0) end
        if panel.rows[q].mult.SetCursorPosition then panel.rows[q].mult:SetCursorPosition(0) end
        if panel.rows[q].bonus.HighlightText then panel.rows[q].bonus:HighlightText(0, 0) end
        if panel.rows[q].mult.HighlightText then panel.rows[q].mult:HighlightText(0, 0) end
      end
    end
  end)

  panel._lastAnchor = resetBtn

  panel.refresh = function()
    local p2 = EAK:GetProfile()
    EnsureTables(p2)
    for q=0,4 do
      if panel.rows and panel.rows[q] then
        panel.rows[q].bonus:SetText(tostring(p2.qualityBonus[q] or defBonus[q]))
        panel.rows[q].mult:SetText(tostring(p2.qualityMultiplier[q] or defMult[q]))


        if panel.rows[q].bonus.SetCursorPosition then panel.rows[q].bonus:SetCursorPosition(0) end
        if panel.rows[q].mult.SetCursorPosition then panel.rows[q].mult:SetCursorPosition(0) end
        if panel.rows[q].bonus.HighlightText then panel.rows[q].bonus:HighlightText(0, 0) end
        if panel.rows[q].mult.HighlightText then panel.rows[q].mult:HighlightText(0, 0) end

        ForceBoxStyle(panel.rows[q].bonus)
        ForceBoxStyle(panel.rows[q].mult)
      end
    end
  end

  panel:SetScript("OnShow", function()




    if panel.refresh then panel.refresh() end
    U:After(0, function()
      if panel:IsShown() and panel.refresh then panel.refresh() end
    end)
  end)
  InterfaceOptions_AddCategory(panel)
end