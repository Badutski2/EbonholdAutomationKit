local EAK = _G.EbonholdAutomationKit
local U

local function EnsureU()
  if not U and EAK then
    U = EAK.Utils
  end
  return U
end

EAK.WeightsUI = EAK.WeightsUI or {}
local W = EAK.WeightsUI

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


W._navOwner = nil
W._navBtnUp = nil
W._navBtnDown = nil

function W:EnsureNavBindings()
  if not self._navOwnerFrame then
    self._navOwnerFrame = CreateFrame("Frame", "EAKWeightNavOwnerFrame", UIParent)
    self._navOwnerFrame:Hide()
    local owner = self._navOwnerFrame
  
  owner._eakNavOnUpdate = owner._eakNavOnUpdate or function(self, elapsed)
    local b = W and W.activeWeightBox
    if not b then return end
    local now = GetTime and GetTime() or 0
    local initDelay = 0.22
    local repDelay = 0.055
    local key = nil
    if IsKeyDown and (IsKeyDown("DOWN") or IsKeyDown("DOWNARROW")) then key = "DOWN"
    elseif IsKeyDown and (IsKeyDown("UP") or IsKeyDown("UPARROW")) then key = "UP"
    elseif IsKeyDown and IsKeyDown("TAB") then key = "TAB"
    end
    if not key then
      self._eakNavHeld = nil
      self._eakNavNext = nil
      return
    end
    if self._eakNavHeld ~= key then
      self._eakNavHeld = key
      self._eakNavNext = 0
    end
    if self._eakNavNext and now < self._eakNavNext then return end
    local dir = 1
    if key == "UP" then dir = -1
    elseif key == "TAB" then
      dir = 1
      if IsShiftKeyDown and IsShiftKeyDown() then dir = -1 end
    end
    if W and W.FocusRelativeWeightBox then
      W._movingFocus = true
      W:FocusRelativeWeightBox(b, dir)
      if not W._moveReleaseFrame then
        W._moveReleaseFrame = CreateFrame("Frame", "EAKNavReleaseFrame_W", UIParent)
      end
      local rf = W._moveReleaseFrame
      rf:Show()
      rf:SetScript("OnUpdate", function()
        rf:SetScript("OnUpdate", nil)
        rf:Hide()
        W._movingFocus = false
      end)
    end
    if self._eakNavNext == 0 then
      self._eakNavNext = now + initDelay
    else
      self._eakNavNext = now + repDelay
    end
  end
  owner:SetScript("OnUpdate", owner._eakNavOnUpdate)
end
  local owner = self._navOwnerFrame
  owner:Show()
  if owner._eakNavActive then return end
  owner._eakNavActive = true
  if not self._navBtnUp then
    self._navBtnUp = CreateFrame("Button", "EAKWeightNavUpButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnUp:Hide()
    self._navBtnUp:SetScript("OnClick", function()
      local b = W and W.activeWeightBox
      if b and W and W.FocusRelativeWeightBox then W:FocusRelativeWeightBox(b, -1) end
    end)
  end
  if not self._navBtnDown then
    self._navBtnDown = CreateFrame("Button", "EAKWeightNavDownButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnDown:Hide()
    self._navBtnDown:SetScript("OnClick", function()
      local b = W and W.activeWeightBox
      if b and W and W.FocusRelativeWeightBox then W:FocusRelativeWeightBox(b, 1) end
    end)
  end
  if not self._navBtnTab then
    self._navBtnTab = CreateFrame("Button", "EAKWeightNavTabButton", UIParent, "SecureActionButtonTemplate")
    self._navBtnTab:Hide()
    self._navBtnTab:SetScript("OnClick", function()
      local b = W and W.activeWeightBox
      if b and W and W.FocusRelativeWeightBox then
        local dir = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
        W:FocusRelativeWeightBox(b, dir)
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

function W:ClearNavBindings()
  if not self._navOwnerFrame then return end
  local owner = self._navOwnerFrame
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(owner) end
  owner._eakNavActive = nil
  owner:Hide()
end

W.panel = nil
W.rows = {}
W.filtered = {}















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
  for key, meta in pairs(echoDB) do
    if type(key) == 'string' and meta and meta.spellId then
      local spellId = tonumber(meta.spellId)
      local quality = tonumber(meta.quality) or 0
      if spellId then
        local name = meta.name or U:SafeSpellName(spellId)
        local ok = true


        if not showAll and playerClass then
          local classes = meta.classes
          if type(classes) ~= "table" or classes[playerClass] ~= true then
            ok = false
          end
        end

        if search ~= "" then
          if (searchMode or 'name') == 'tooltip' then
            local tip = meta.tooltipSearch or (meta.tooltipText and U:NormalizeSearchText(meta.tooltipText)) or ""
            if type(tip) ~= 'string' or tip == '' then


              local lines, text, searchNorm = U:CaptureSpellTooltip(spellId)
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
              or tostring(spellId):find(search, 1, true) ~= nil
          end
        end
        if ok then
          table.insert(out, {
            key = key,
            spellId = spellId,
            quality = quality,
            icon = meta.icon,
            name = name,
            weight = U:GetWeight(profile, key, spellId),
            blacklisted = U:IsBlacklisted(profile, key, spellId),
          })
        end
      end
    end
  end

local key = EbonholdAutomationKitDB.ui and EbonholdAutomationKitDB.ui.sortKey or 'name'
local asc = (EbonholdAutomationKitDB.ui and EbonholdAutomationKitDB.ui.sortAsc ~= false)

local function cmp(x, y)
  if asc then return x < y else return x > y end
end

table.sort(out, function(a, b)
  if not a or not b then return false end
  local anRaw = a.name or ""
  local bnRaw = b.name or ""
  local an = U:StripWoWFormatting(anRaw):lower()
  local bn = U:StripWoWFormatting(bnRaw):lower()
  local aw = tonumber(a.weight) or 0
  local bw = tonumber(b.weight) or 0
  local ar = RarityRank(a.quality)
  local br = RarityRank(b.quality)
  local ak = a.key or ""
  local bk = b.key or ""

  if key == 'blacklist' then
    local abl = a.blacklisted and 1 or 0
    local bbl = b.blacklisted and 1 or 0
    if abl ~= bbl then return cmp(abl, bbl) end
    if an ~= bn then return cmp(an, bn) end
    if ar ~= br then return cmp(ar, br) end
    if aw ~= bw then return cmp(aw, bw) end
    if ak ~= bk then return cmp(ak, bk) end
    return false
  elseif key == 'weight' then
    if aw ~= bw then return cmp(aw, bw) end
    if an ~= bn then return cmp(an, bn) end
    if ar ~= br then return cmp(ar, br) end
    if ak ~= bk then return cmp(ak, bk) end
    return false
  elseif key == 'rarity' then
    if ar ~= br then return cmp(ar, br) end
    if an ~= bn then return cmp(an, bn) end
    if aw ~= bw then return cmp(aw, bw) end
    if ak ~= bk then return cmp(ak, bk) end
    return false
  else

    if an ~= bn then return cmp(an, bn) end
    if ar ~= br then return cmp(ar, br) end
    if aw ~= bw then return cmp(aw, bw) end
    if ak ~= bk then return cmp(ak, bk) end
    return false
  end
end)



  return out
end

local function CreateRow(parent, idx)
  local row = CreateFrame("Frame", nil, parent)
  local ROW_H = 30
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

  local weightBox = CreateFrame("EditBox", nil, row)
  weightBox._eakIsEchoWeightBox = true


  weightBox:EnableMouse(true)
  weightBox:SetAutoFocus(false)
  if weightBox.EnableKeyboard then weightBox:EnableKeyboard(true) end
  weightBox:SetMultiLine(false)
  if weightBox.SetAltArrowKeyMode then weightBox:SetAltArrowKeyMode(false) end
  weightBox:SetFontObject(ChatFontNormal)

  if weightBox.SetTextColor then weightBox:SetTextColor(1, 1, 1) end
  if weightBox.SetTextInsets then weightBox:SetTextInsets(6, 6, 3, 3) end
  weightBox:SetSize(60, 20)
  weightBox:SetPoint("RIGHT", -42, 0)
  weightBox:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  weightBox:SetBackdropColor(0, 0, 0, 0.35)
  weightBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  weightBox:SetNumeric(false)
weightBox:SetJustifyH("CENTER")

  if weightBox.EnableKeyboard then weightBox:EnableKeyboard(true) end
local rarity = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
rarity:SetWidth(80)
rarity:SetJustifyH("CENTER")
rarity:SetPoint("RIGHT", weightBox, "LEFT", -12, 0)


name:SetPoint("RIGHT", rarity, "LEFT", -10, 0)


  hover:ClearAllPoints()
  hover:SetPoint("LEFT", icon, "LEFT", -2, 0)
  hover:SetPoint("RIGHT", rarity, "LEFT", -6, 0)
  hover:SetPoint("TOP", row, "TOP", 0, 0)
  hover:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)

  hover:SetFrameLevel(row:GetFrameLevel() + 1)
  weightBox:SetFrameLevel(row:GetFrameLevel() + 2)




  weightBox:SetScript("OnMouseDown", function(self)
    self._eakClicked = true
    self:SetFocus()
  end)

  weightBox:SetScript("OnMouseUp", function(self)
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

  weightBox:SetScript("OnEditFocusGained", function(self)
    W.activeWeightBox = self
    if W and W.EnsureNavBindings then W:EnsureNavBindings() end
    if self.SetAltArrowKeyMode then self:SetAltArrowKeyMode(true) end
    self._origText = self:GetText()
    
    if self.HighlightText then self:HighlightText() end
  end)

  weightBox:SetScript("OnEditFocusLost", function(self)
  if W._scrolling or W._movingFocus then return end
  if W.activeWeightBox == self then W.activeWeightBox = nil end
  if W and W.ClearNavBindings then W:ClearNavBindings() end
  if self.SetAltArrowKeyMode then self:SetAltArrowKeyMode(false) end
  self:SetScript("OnUpdate", nil)
  if self.HighlightText then self:HighlightText(0, 0) end

  if not row.data then return end
  local t = self:GetText() or ""
  local n = tonumber(t)
  local p = EAK:GetProfile()
  if t == "" then
    p.weights[row.data.key] = 0
  elseif n ~= nil then
    p.weights[row.data.key] = n
  else
    local saved = U:GetWeight(p, row.data.key, row.data.spellId)
    self:SetText(tostring(saved or 0))
  end
  W:Refresh()
end)

  weightBox:SetScript("OnTabPressed", function(self)
    if W and W.FocusRelativeWeightBox then
      local dir = (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1
      W:FocusRelativeWeightBox(self, dir)
    end
  end)

  weightBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    if not row.data then return end
    local t = self:GetText() or ""
    local n = tonumber(t)
    local p = EAK:GetProfile()
    if t == "" then
      p.weights[row.data.key] = 0
      row.data.weight = 0
    elseif n ~= nil then
      p.weights[row.data.key] = n
      row.data.weight = n
    else

      return
    end
  end)

  weightBox:SetScript("OnEscapePressed", function(self)
    if self._origText ~= nil then
      self:SetText(self._origText)
      if row.data then
        local p = EAK:GetProfile()
        p.weights[row.data.key] = tonumber(self._origText) or 0
        row.data.weight = tonumber(self._origText) or row.data.weight
      end
    end
    self:ClearFocus()
  end)

  weightBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  weightBox:SetScript("OnTabPressed", function(self)

    if self.HighlightText then self:HighlightText(0, 0) end
    local dir = 1
    if type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() then dir = -1 end
    if W and W.FocusRelativeWeightBox then
      W:FocusRelativeWeightBox(self, dir)
    end
  end)
  if weightBox.SetAltArrowKeyMode then weightBox:SetAltArrowKeyMode(false) end




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
    W:Refresh()
  end)

  local bl = CreateFrame("CheckButton", NextName("EAK_WCB"), row, "ChatConfigCheckButtonTemplate")
  bl:SetSize(24, 24)
  bl:SetHitRectInsets(0, 0, 0, 0)
  bl:SetPoint("RIGHT", -8, 0)
  bl:SetFrameLevel(row:GetFrameLevel() + 2)
  local blText = _G[bl:GetName() .. "Text"]
  if blText then blText:SetText("") end
  bl.tooltip = "Blacklist this Echo (never pick it)"
  bl:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  bl:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bl:SetScript("OnClick", function(self)
    if not row.data then return end
    local p = EAK:GetProfile()
    p.blacklist[row.data.key] = self:GetChecked() and true or nil
    W:Refresh()
  end)

  row.nameText = name
  row.rarityText = rarity
  row.weightBox = weightBox
  row.deleteBtn = del
  row.blacklist = bl

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
        GameTooltip:AddLine(U:SafeSpellName(sid), 1, 1, 1)
        GameTooltip:AddLine("SpellID: " .. tostring(sid), 0.9, 0.9, 0.9)
      end
    end
    if row.data.blacklisted then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Blacklisted", 1, 0.4, 0.4)
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


function W:CommitWeightBox(box, row)
  if not box or not row or not row.data then return true end
  local t = box:GetText() or ""
  local p = EAK:GetProfile()
  local n = tonumber(t)

  if t == "" then
    p.weights[row.data.key] = 0
    row.data.weight = 0
    box:SetText("0")
    return true
  end

  if n ~= nil then
    p.weights[row.data.key] = n
    row.data.weight = n
    return true
  end
  local U2 = EnsureU()
  local saved = (U2 and U2:GetWeight(p, row.data.key, row.data.spellId)) or 0
  box:SetText(tostring(saved))
  row.data.weight = saved
  return false
end


function W:FocusRelativeWeightBox(curBox, dir)
  if not self.scrollFrame or not self.filtered or #self.filtered == 0 then return end
  dir = tonumber(dir) or 1
  if dir == 0 then dir = 1 end

  local curIndex = nil
  local curRow = nil
  for _, row in ipairs(self.rows or {}) do
    if row and row.weightBox == curBox then
      curIndex = tonumber(row.absIndex)
      curRow = row
      break
    end
  end
  if not curIndex then return end


  if curRow then
    self:CommitWeightBox(curBox, curRow)
  end



  self._movingFocus = true
  if curBox and curBox.HighlightText then curBox:HighlightText(0, 0) end
  if curBox and curBox.ClearFocus then curBox:ClearFocus() end

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
    if row and tonumber(row.absIndex) == target and row.weightBox then
      row.weightBox:SetFocus()
      if row.weightBox.HighlightText then row.weightBox:HighlightText() end
      break
    end
  end

  if not self._moveReleaseFrame then
    self._moveReleaseFrame = CreateFrame("Frame", nil, UIParent)
    self._moveReleaseFrame:Hide()
  end
  local rf = self._moveReleaseFrame
  rf:Show()
  rf:SetScript("OnUpdate", function()
    rf:SetScript("OnUpdate", nil)
    rf:Hide()
    W._movingFocus = false
  end)
end

local function setHeaderText(headerName, headerRarity, headerWeight)
  local key = EbonholdAutomationKitDB.ui.sortKey or "name"
  local asc = (EbonholdAutomationKitDB.ui.sortAsc ~= false)
  local up = " |cffaaaaaa▲|r"
  local dn = " |cffaaaaaa▼|r"

  if key == "name" then
    headerName:SetText("Echo Name" .. (asc and up or dn))
    headerRarity:SetText("Rarity")
    headerWeight:SetText("Weight")
  elseif key == "rarity" then
    headerName:SetText("Echo Name")
    headerRarity:SetText("Rarity" .. (asc and up or dn))
    headerWeight:SetText("Weight")
  else
    headerName:SetText("Echo Name")
    headerRarity:SetText("Rarity")
    headerWeight:SetText("Weight" .. (asc and up or dn))
  end
end


function W:Refresh()
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

  local ROW_H = 30
  FauxScrollFrame_Update(self.scrollFrame, #self.filtered, #self.rows, ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.scrollFrame)

  for i = 1, #self.rows do
    local row = self.rows[i]
    local idx = i + offset
    local data = self.filtered[idx]
    if data then
      row.data = data
      row.absIndex = idx
			local r,g,b = U:RarityColor(data.quality)
			row.nameText:SetText(data.name or "Unknown")
			row.nameText:SetTextColor(r,g,b)
			if row.rarityText then
				row.rarityText:SetText(RarityName(data.quality))
				row.rarityText:SetTextColor(r,g,b)
			end
			if data.icon then
				row.iconTex:SetTexture(data.icon)
				row.iconTex:Show()
			else
				row.iconTex:Hide()
			end
			if not (row.weightBox and row.weightBox:HasFocus()) then
				row.weightBox:SetText(tostring(data.weight or 0))

				if row.weightBox.SetCursorPosition then row.weightBox:SetCursorPosition(0) end
				if row.weightBox.HighlightText then row.weightBox:HighlightText(0, 0) end
			end
      row.blacklist:SetChecked(data.blacklisted)
      row:Show()
    else
      row.data = nil
      row.absIndex = nil
      row:Hide()
    end
  end

  if self.headerName and self.headerRarity and self.headerWeight then
    setHeaderText(self.headerName, self.headerRarity, self.headerWeight)
  end

  if self.countText then
    local total = U:TableSize(EAK:GetEchoDB() or {})
    self.countText:SetText("Echoes Shown: " .. tostring(#self.filtered) .. " / " .. tostring(total))
  end
end

function W:CreatePanel(parentName)
  if self.panel then return end
  local U = EnsureU()
  if not U then return end

  local panel = CreateFrame("Frame", "EAK_WeightsPanel", InterfaceOptionsFramePanelContainer)
  panel.name = "Echo Weights"
  panel.parent = parentName
  self.panel = panel

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Echo Weights")

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)


  help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)


  help:SetHeight(100)

  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")
  help:SetNonSpaceWrap(true)

  help:SetText(
    "New Echoes are added to your database automatically whenever they appear during a roll.\n\n" ..
    "Imported a bad profile (or your list got messy)? You can remove any Echo entry using the X button."
  )

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
  search:SetScript("OnTextChanged", function() W:Refresh() end)

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
    W:Refresh()
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
  UpdateModeButtons()

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
    if W.activeWeightBox and W.activeWeightBox.ClearFocus then
      if W.activeWeightBox.HighlightText then W.activeWeightBox:HighlightText(0, 0) end
      W.activeWeightBox:ClearFocus()
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

local headerWeight = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
headerWeight:SetWidth(60)
headerWeight:SetJustifyH("CENTER")
headerWeight:SetPoint("RIGHT", -54, 0)
headerWeight:SetText("Weight")

local headerRarity = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
headerRarity:SetWidth(80)
headerRarity:SetJustifyH("CENTER")
headerRarity:SetPoint("RIGHT", headerWeight, "LEFT", -12, 0)
headerRarity:SetText("Rarity")


headerName:SetPoint("RIGHT", headerRarity, "LEFT", -10, 0)

  local headerBL = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerBL:SetPoint("RIGHT", -10, 0)
  headerBL:SetText("BL")
  headerBL:SetTextColor(1, 0.4, 0.4)

  self.headerName = headerName
  self.headerRarity = headerRarity
  self.headerWeight = headerWeight

  local function ToggleSort(newKey)
    local ui = EbonholdAutomationKitDB.ui
    if not ui then
      EbonholdAutomationKitDB.ui = { sortKey = newKey, sortAsc = true }
      ui = EbonholdAutomationKitDB.ui
    end
    local prevKey = ui.sortKey or 'name'
    if prevKey == newKey then

      ui.sortAsc = not (ui.sortAsc ~= false)
    else

      ui.sortKey = newKey
      if newKey == 'blacklist' then

        ui.sortAsc = false
      else
        ui.sortAsc = true
      end
    end
  end

  local nameBtn = CreateFrame("Button", nil, header)
  nameBtn:SetAllPoints(headerName)
  nameBtn:SetScript("OnClick", function()
    ToggleSort('name')
    W:Refresh()
  end)

local rarityBtn = CreateFrame("Button", nil, header)
rarityBtn:SetAllPoints(headerRarity)
rarityBtn:SetScript("OnClick", function()
  ToggleSort('rarity')
  W:Refresh()
end)

  local weightBtn = CreateFrame("Button", nil, header)
  weightBtn:SetAllPoints(headerWeight)
  weightBtn:SetScript("OnClick", function()
    ToggleSort('weight')
    W:Refresh()
  end)

  local blBtn = CreateFrame("Button", nil, header)
  blBtn:SetAllPoints(headerBL)
  blBtn:SetScript("OnClick", function()
    ToggleSort('blacklist')
    W:Refresh()
  end)

  local scroll = CreateFrame("ScrollFrame", "EAK_WeightsScroll", listContainer, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -26)
  scroll:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 8)
  self.scrollFrame = scroll
  scroll:SetScript("OnVerticalScroll", function(self, offset)

    W._scrolling = true
    if W.activeWeightBox and W.activeWeightBox.ClearFocus then
      W.activeWeightBox:ClearFocus()
    end
    W._scrolling = false
    FauxScrollFrame_OnVerticalScroll(self, offset, 30, function() W:Refresh() end)
  end)


  local sb = _G[scroll:GetName() .. "ScrollBar"]
  if sb and sb.ClearAllPoints then
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    0, 4)
    sb:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 0, 12)


    local function clearActive()
      if W.activeWeightBox and W.activeWeightBox.ClearFocus then
        if W.activeWeightBox.HighlightText then W.activeWeightBox:HighlightText(0, 0) end
        W.activeWeightBox:ClearFocus()
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

  local ROW_H = 30
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
    W:Refresh()
  end)
  self.showAllBtn = showAllBtn

  panel.refresh = function() W:Refresh() end

  panel:SetScript("OnShow", function()
    if panel.refresh then panel.refresh() end
    U:After(0, function()
      if panel:IsShown() and panel.refresh then panel.refresh() end
    end)
  end)

  panel:SetScript("OnHide", function()
        if W and W.activeWeightBox and W.activeWeightBox.ClearFocus then
      if W.activeWeightBox.HighlightText then W.activeWeightBox:HighlightText(0, 0) end
      W.activeWeightBox:ClearFocus()
    end
    W.activeWeightBox = nil
  end)
  InterfaceOptions_AddCategory(panel)

  self:Refresh()
end