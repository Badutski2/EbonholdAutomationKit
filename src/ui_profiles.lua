local EAK = _G.EbonholdAutomationKit
local U = EAK.Utils

EAK.ProfilesUI = EAK.ProfilesUI or {}
local P = EAK.ProfilesUI

P.panel = nil


local __uid = 0
local function NextName(prefix)
  __uid = __uid + 1
  return "EAK_" .. (prefix or "W") .. "_" .. __uid
end


local __timers, __timerFrame = {}, nil
local function After(seconds, fn)
  if type(fn) ~= "function" then return end
  seconds = tonumber(seconds) or 0
  if seconds <= 0 then
    pcall(fn)
    return
  end
  if not __timerFrame then
    __timerFrame = CreateFrame("Frame")
    __timerFrame:Hide()
    __timerFrame:SetScript("OnUpdate", function(self)
      local now = GetTime()
      for i = #__timers, 1, -1 do
        local t = __timers[i]
        if now >= t.at then
          table.remove(__timers, i)
          pcall(t.fn)
        end
      end
      if #__timers == 0 then self:Hide() end
    end)
  end
  table.insert(__timers, { at = GetTime() + seconds, fn = fn })
  __timerFrame:Show()
end


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
  sub:SetHeight(55)
  sub:SetJustifyH("LEFT")
  sub:SetJustifyV("TOP")
  sub:SetNonSpaceWrap(true)
  sub:SetWordWrap(true)
  sub:SetText("Create/delete profiles, and import/export profiles (including settings, rarity weights, echo weights/blacklist, and the global Echo database).")


  local content = CreateFrame("Frame", name .. "Content", panel)
  content:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -78)
  content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)

  panel.content = content
  panel.header = header
  panel.sub = sub
  return panel, content
end
local function CreateEditBox(parent, height, multiline)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:EnableMouse(true)
  eb:SetAutoFocus(false)
  eb:SetMultiLine(multiline == true)
  eb:SetFontObject(ChatFontNormal)

  if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 3, 3) end
  eb:SetHeight(height)
  eb:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  eb:SetBackdropColor(0, 0, 0, 0.35)
  eb:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(eb, { multiline = (multiline == true) })
  end
  return eb
end

local function EnsureProfilesDB()
  local db = EbonholdAutomationKitDB
  db.profiles = db.profiles or {}

  local active = EAK:GetProfileName()
  if type(db.profiles[active]) ~= "table" then
    db.profiles[active] = {}
  end
end

local function RefreshAllPanels()
  if EAK.Options and EAK.Options.RefreshMain then EAK.Options:RefreshMain() end
  if EAK.RarityUI and EAK.RarityUI.panel and EAK.RarityUI.panel.refresh then EAK.RarityUI.panel.refresh() end
  if EAK.WeightsUI and EAK.WeightsUI.Refresh then EAK.WeightsUI:Refresh() end
  if EAK.HistoryUI and EAK.HistoryUI.Refresh then EAK.HistoryUI:Refresh() end
end

local function DeepCopyTable(src, seen)
  if type(src) ~= 'table' then return src end
  seen = seen or {}
  if seen[src] then return seen[src] end
  local dst = {}
  seen[src] = dst
  for k, v in pairs(src) do
    if type(v) == 'table' then
      dst[k] = DeepCopyTable(v, seen)
    else
      dst[k] = v
    end
  end
  return dst
end

function P:CreatePanel(parentName)
  if self.panel then return end
  EnsureProfilesDB()

  local panel, content = MakePanel("EbonholdAutomationKitProfiles", parentName, "Profiles")
  self.panel = panel

  local activeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  activeLabel:SetPoint("TOPLEFT", 16, -10)
  activeLabel:SetText("Active Profile")

  local dd = CreateFrame("Frame", "EAK_ProfileDropdown", content, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", -10, -6)

  local function OnSelect(profileName)
    EnsureProfilesDB()
    EbonholdAutomationKitDB.profileKey = profileName
    EAK:GetProfile()
    UIDropDownMenu_SetText(dd, profileName)
    RefreshAllPanels()
  end

  local function InitializeDropdown()
    EnsureProfilesDB()
    local selected = EAK:GetProfileName()

    local names = {}
    for name in pairs(EbonholdAutomationKitDB.profiles) do
      table.insert(names, name)
    end
    table.sort(names)

    for _, name in ipairs(names) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = name
      info.func = function() OnSelect(name) end
      info.checked = (name == selected)
      UIDropDownMenu_AddButton(info)
    end

    UIDropDownMenu_SetText(dd, selected)
  end

  UIDropDownMenu_Initialize(dd, InitializeDropdown)
  UIDropDownMenu_SetWidth(dd, 200)
  UIDropDownMenu_JustifyText(dd, "LEFT")

  local statusTip = "Tip: profiles + settings are per-character. The Echo Database is account-wide. Use export/import to share everything."


  local tabRow = CreateFrame("Frame", nil, content)
  tabRow:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 16, -8)
  tabRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -16, -8)
  tabRow:SetHeight(24)

  local manageTab = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
  manageTab:SetSize(110, 22)
  manageTab:SetPoint("LEFT", 0, 0)
  manageTab:SetText("Manage")

  local ioTab = CreateFrame("Button", nil, tabRow, "UIPanelButtonTemplate")
  ioTab:SetSize(140, 22)
  ioTab:SetPoint("LEFT", manageTab, "RIGHT", 6, 0)
  ioTab:SetText("Import / Export")

  local status = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", 16, 14)
  status:SetPoint("BOTTOMRIGHT", -16, 14)
  status:SetHeight(40)
  status:SetJustifyH("LEFT")
  status:SetJustifyV("TOP")
  status:SetNonSpaceWrap(true)
  status:SetWordWrap(true)
  status:SetTextColor(0.8, 0.8, 0.8)
  status:SetText(statusTip)

  local __statusToken = 0
  local function SetStatusTemp(msg, r, g, b, seconds)
    __statusToken = __statusToken + 1
    local token = __statusToken
    if r and g and b then
      status:SetText(U:ColorText(msg, r, g, b))
    else
      status:SetText(tostring(msg or ""))
    end
    if seconds and seconds > 0 then
      After(seconds, function()
        if __statusToken == token then
          status:SetText(statusTip)
        end
      end)
    end
  end



  local host = CreateFrame("Frame", nil, content)
  host:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 0, -14)
  host:SetPoint("TOPRIGHT", tabRow, "BOTTOMRIGHT", 0, -14)
  host:SetPoint("BOTTOMLEFT", status, "TOPLEFT", 0, 14)
  host:SetPoint("BOTTOMRIGHT", status, "TOPRIGHT", 0, 14)

  local manageFrame = CreateFrame("Frame", nil, host)
  manageFrame:SetAllPoints(host)

  local ioFrame = CreateFrame("Frame", nil, host)
  ioFrame:SetAllPoints(host)
  ioFrame:Hide()

  local function SelectTab(which)
    panel._activeTab = which
    if which == "import" then
      manageFrame:Hide()
      ioFrame:Show()
      manageTab:Enable()
      ioTab:Disable()
    else
      ioFrame:Hide()
      manageFrame:Show()
      ioTab:Enable()
      manageTab:Disable()
    end
  end

  manageTab:SetScript("OnClick", function() SelectTab("manage") end)
  ioTab:SetScript("OnClick", function() SelectTab("import") end)
  SelectTab(panel._activeTab or "manage")


  local cdHeader = manageFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  cdHeader:SetPoint("TOPLEFT", 0, 0)
  cdHeader:SetText("Create / Delete")

  local nameLabel = manageFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  nameLabel:SetPoint("TOPLEFT", cdHeader, "BOTTOMLEFT", 0, -10)
  nameLabel:SetText("Profile name")

  local nameBox = CreateEditBox(manageFrame, 22, false)
  nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -6)
  nameBox:SetPoint("RIGHT", manageFrame, "RIGHT", -220, 0)
  nameBox:SetText("")

  local newBtn = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
  newBtn:SetSize(90, 22)
  newBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
  newBtn:SetText("Create")

  local delBtn = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
  delBtn:SetSize(90, 22)
  delBtn:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -6)
  delBtn:SetText("Delete")

  local resetBtn = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
  resetBtn:SetSize(180, 22)
  resetBtn:SetPoint("TOPLEFT", delBtn, "BOTTOMLEFT", 0, -14)
  resetBtn:SetText("Reset Profile to Defaults")

  local __resetConfirm = 0

  newBtn:SetScript("OnClick", function()
    EnsureProfilesDB()
    local n = U:Trim(nameBox:GetText() or "")
    if n == "" then
      SetStatusTemp("Insert Profile Name", 1, 0.4, 0.4, 3)
      return
    end
    if not EbonholdAutomationKitDB.profiles[n] then
      EbonholdAutomationKitDB.profiles[n] = {}
    end
    EbonholdAutomationKitDB.profileKey = n
    EAK:GetProfile()
    UIDropDownMenu_SetText(dd, n)
    SetStatusTemp("Created profile: " .. n, 0.6, 1, 0.6, 3)
    RefreshAllPanels()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end)

  delBtn:SetScript("OnClick", function()
    EnsureProfilesDB()
    local db = EbonholdAutomationKitDB
    local cur = EAK:GetProfileName()

    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if count <= 1 then
      SetStatusTemp("Can't delete the last profile", 1, 0.4, 0.4, 3)
      return
    end

    db.profiles[cur] = nil


    local fallback = EAK:GetCharacterDefaultProfileName()
    if type(db.profiles[fallback]) == "table" then
      db.profileKey = fallback
    else
      local names = {}
      for name in pairs(db.profiles) do
        table.insert(names, name)
      end
      table.sort(names)
      db.profileKey = names[1] or fallback
      if type(db.profiles[db.profileKey]) ~= "table" then
        db.profiles[db.profileKey] = {}
      end
    end

    EAK:GetProfile()
    UIDropDownMenu_SetText(dd, db.profileKey)
    status:SetText(U:ColorText("Deleted profile: " .. cur, 0.6, 1, 0.6))
    RefreshAllPanels()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end)

  resetBtn:SetScript("OnClick", function()
    EnsureProfilesDB()
    local cur = EAK:GetProfileName()

    __resetConfirm = __resetConfirm + 1
    local token = __resetConfirm

    if resetBtn._armed ~= true then
      resetBtn._armed = true
      resetBtn:SetText("Confirm Reset")
      SetStatusTemp("This will wipe ALL settings in profile: " .. cur, 1, 0.82, 0.2, 3)
      After(3, function()
        if __resetConfirm == token then
          resetBtn._armed = false
          resetBtn:SetText("Reset Profile to Defaults")
        end
      end)
      return
    end

    resetBtn._armed = false
    resetBtn:SetText("Reset Profile to Defaults")
    EbonholdAutomationKitDB.profiles[cur] = {}
    EAK:GetProfile()
    SetStatusTemp("Reset profile: " .. cur, 0.6, 1, 0.6, 3)
    RefreshAllPanels()
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end)


    local ieHeader = ioFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  ieHeader:SetPoint("TOPLEFT", 0, 0)
  ieHeader:SetText("Import / Export")

  local ieInfo = ioFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ieInfo:SetPoint("TOPLEFT", ieHeader, "BOTTOMLEFT", 0, -8)
  ieInfo:SetPoint("RIGHT", ioFrame, "RIGHT", 0, 0)
  ieInfo:SetHeight(36)
  ieInfo:SetJustifyH("LEFT")
  ieInfo:SetJustifyV("TOP")
  ieInfo:SetNonSpaceWrap(true)
  ieInfo:SetWordWrap(true)
  ieInfo:SetText("Use the popup window for large profile strings (includes all settings, weights, blacklists, and the global Echo database).")

  local ioPopup = nil
  local function EnsureIOPopup()
    if ioPopup then return ioPopup end
    local f = CreateFrame("Frame", NextName("ProfilesIOPopup"), UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    f:SetWidth(740)
    f:SetHeight(460)
    f:SetPoint("CENTER")
    f:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Profile Import / Export")

    local help = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    help:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    help:SetHeight(32)
    help:SetJustifyH("LEFT")
    help:SetJustifyV("TOP")
    help:SetNonSpaceWrap(true)
    help:SetWordWrap(true)
    help:SetText("Export copies the active profile. Import replaces/creates a profile name, and merges settings + the global Echo database.")

    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 86)
    bg:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.35)
    bg:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

    local scroll = CreateFrame("ScrollFrame", NextName("ProfilesIOScroll"), bg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:EnableMouse(true)
    edit:SetAutoFocus(false)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    if edit.SetTextColor then edit:SetTextColor(1, 1, 1) end
    if edit.SetTextInsets then edit:SetTextInsets(6, 6, 4, 4) end
    if edit.SetCountInvisibleLetters then edit:SetCountInvisibleLetters(false) end
    if edit.SetMaxLetters then edit:SetMaxLetters(0) end
    if edit.SetAltArrowKeyMode then edit:SetAltArrowKeyMode(false) end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)

    if U and U.EnhanceEditBox then
      U:EnhanceEditBox(edit, { multiline = true })
    end

    local function ResizeEdit()
      local w = (scroll.GetWidth and scroll:GetWidth() or 500) - 10
      if w < 120 then w = 120 end
      if edit.SetWidth then edit:SetWidth(w) end
    end

    local function UpdateScrollChild()
      ResizeEdit()
      local h = (edit.GetStringHeight and edit:GetStringHeight() or 0) + 16
      local minH = (scroll.GetHeight and scroll:GetHeight() or 120)
      if h < minH then h = minH end
      if edit.SetHeight then edit:SetHeight(h) end
      if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end

    local __pending = false
    local function QueueUpdate()
      if __pending then return end
      __pending = true
      After(0, function()
        __pending = false
        UpdateScrollChild()
      end)
    end

    edit:SetScript("OnTextChanged", QueueUpdate)

    f:SetScript("OnShow", function()
      EbonholdAutomationKitDB.uiProfiles = EbonholdAutomationKitDB.uiProfiles or {}
      if f.backupCB and f.backupCB.SetChecked then
        f.backupCB:SetChecked(EbonholdAutomationKitDB.uiProfiles.backupBeforeImport == true)
      end
      QueueUpdate()
    end)

    f:SetScript("OnSizeChanged", function() QueueUpdate() end)

    local status2 = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status2:SetPoint("BOTTOMLEFT", 16, 54)
    status2:SetPoint("BOTTOMRIGHT", -16, 54)
    status2:SetHeight(28)
    status2:SetJustifyH("LEFT")
    status2:SetJustifyV("TOP")
    status2:SetNonSpaceWrap(true)
    status2:SetWordWrap(true)
    status2:SetTextColor(0.8, 0.8, 0.8)
    status2:SetText("")

    local function SetPopupStatus(msg, r, g, b)
      if r and g and b then
        status2:SetText(U:ColorText(msg, r, g, b))
      else
        status2:SetText(tostring(msg or ""))
      end
    end

    local nameLabel2 = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel2:SetPoint("BOTTOMLEFT", 16, 32)
    nameLabel2:SetText("Import into profile name")

    local nameBox2 = CreateEditBox(f, 22, false)
    nameBox2:SetPoint("LEFT", nameLabel2, "RIGHT", 12, 0)
    nameBox2:SetPoint("RIGHT", f, "RIGHT", -260, 0)
    nameBox2:SetText("Imported")

    EbonholdAutomationKitDB.uiProfiles = EbonholdAutomationKitDB.uiProfiles or {}
    local backupCB = CreateFrame("CheckButton", NextName("ProfilesBackup2"), f, "OptionsCheckButtonTemplate")
    backupCB:SetPoint("BOTTOMLEFT", 16, 10)
    backupCB:SetHitRectInsets(0, -260, 0, 0)
    local lbl2 = _G[backupCB:GetName() .. "Text"]
    if lbl2 then lbl2:SetText("Backup target before import") end
    backupCB:SetChecked(EbonholdAutomationKitDB.uiProfiles.backupBeforeImport == true)
    backupCB:SetScript("OnClick", function(self)
      EbonholdAutomationKitDB.uiProfiles.backupBeforeImport = self:GetChecked() and true or false
    end)

    local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectBtn:SetSize(90, 22)
    selectBtn:SetPoint("BOTTOMRIGHT", -16, 10)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
      edit:SetFocus()
      edit:HighlightText()
    end)

    local clearBtn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn2:SetSize(70, 22)
    clearBtn2:SetPoint("RIGHT", selectBtn, "LEFT", -8, 0)
    clearBtn2:SetText("Clear")
    clearBtn2:SetScript("OnClick", function()
      edit:SetText("")
      SetPopupStatus("", nil, nil, nil)
      QueueUpdate()
      edit:SetFocus()
    end)

    local exportBtn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn2:SetSize(90, 22)
    exportBtn2:SetPoint("RIGHT", clearBtn2, "LEFT", -8, 0)
    exportBtn2:SetText("Export")
    exportBtn2:SetScript("OnClick", function()
      local prof = EAK:GetProfile()
      local exported = U:ExportProfile(prof)
      edit:SetText(exported or "")
      QueueUpdate()
      if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
      edit:SetFocus()
      edit:HighlightText()
      SetPopupStatus("Exported current profile (includes settings + echo database)", 0.6, 1, 0.6)
      SetStatusTemp("Exported current profile (includes settings + echo database)", 0.6, 1, 0.6, 3)
    end)

    local importBtn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn2:SetSize(90, 22)
    importBtn2:SetPoint("RIGHT", exportBtn2, "LEFT", -8, 0)
    importBtn2:SetText("Import")
    importBtn2:SetScript("OnClick", function()
      EnsureProfilesDB()
      local s = edit:GetText() or ""
      local importedProfile, importedEchoDB, importedSettings, err = U:ImportProfile(s)
      if not importedProfile then
        SetPopupStatus("Import failed: " .. tostring(err), 1, 0.4, 0.4)
        SetStatusTemp("Import failed: " .. tostring(err), 1, 0.4, 0.4, 4)
        return
      end

      local name = U:Trim(nameBox2:GetText() or "")
      if name == "" then name = "Imported" end

      EbonholdAutomationKitDB.uiProfiles = EbonholdAutomationKitDB.uiProfiles or {}
      local doBackup = (EbonholdAutomationKitDB.uiProfiles.backupBeforeImport == true)

      if doBackup and type(EbonholdAutomationKitDB.profiles[name]) == "table" then
        local base = name .. "_backup"
        local backupName = base
        local i = 1
        while EbonholdAutomationKitDB.profiles[backupName] do
          i = i + 1
          backupName = base .. "_" .. tostring(i)
        end
        EbonholdAutomationKitDB.profiles[backupName] = DeepCopyTable(EbonholdAutomationKitDB.profiles[name])
        SetStatusTemp("Created backup profile: " .. backupName, 0.6, 1, 0.6, 3)
      end

      EbonholdAutomationKitDB.profiles[name] = importedProfile
      EbonholdAutomationKitDB.profileKey = name
      EAK:GetProfile()

      if type(importedSettings) == "table" then
        local function Merge(dst, src)
          if type(src) ~= "table" then return dst end
          dst = type(dst) == "table" and dst or {}
          for k, v in pairs(src) do
            if v ~= nil then dst[k] = v end
          end
          return dst
        end
        EbonholdAutomationKitDB.ui = Merge(EbonholdAutomationKitDB.ui, importedSettings.ui)
        EbonholdAutomationKitDB.uiAutoHistory = Merge(EbonholdAutomationKitDB.uiAutoHistory, importedSettings.uiAutoHistory)
        EbonholdAutomationKitDB.uiLogbook = Merge(EbonholdAutomationKitDB.uiLogbook, importedSettings.uiLogbook)
        EbonholdAutomationKitDB.uiProfiles = Merge(EbonholdAutomationKitDB.uiProfiles, importedSettings.uiProfiles)
      end

      if type(importedEchoDB) == "table" then
        local dst = EAK:GetEchoDB()
        for key, meta in pairs(importedEchoDB) do
          if type(key) == "string" and key:match("^%d+:%d+$") and type(meta) == "table" then
            local d = dst[key] or {}
            d.spellId = tonumber(meta.spellId) or d.spellId
            d.quality = tonumber(meta.quality) or d.quality
            d.name = meta.name or d.name
            d.icon = meta.icon or d.icon
            d.lastSeen = meta.lastSeen or d.lastSeen
            d.classes = d.classes or {}
            if type(meta.classes) == "table" then
              for cls, ok in pairs(meta.classes) do
                if ok then d.classes[cls] = true end
              end
            end
            dst[key] = d
          end
        end
      end

      SetPopupStatus("Imported into profile: " .. name .. " (settings + echo DB merged)", 0.6, 1, 0.6)
      SetStatusTemp("Imported into profile: " .. name .. " (settings + echo DB merged)", 0.6, 1, 0.6, 4)

      edit:SetText("")
      QueueUpdate()
      UIDropDownMenu_SetText(dd, name)
      RefreshAllPanels()

      InterfaceOptionsFrame_OpenToCategory(panel)
      InterfaceOptionsFrame_OpenToCategory(panel)
    end)

    f.edit = edit
    f.nameBox = nameBox2
    f.backupCB = backupCB

    if type(UISpecialFrames) == "table" and f.GetName then
      table.insert(UISpecialFrames, f:GetName())
    end

    ioPopup = f
    return ioPopup
  end

  local openExport = CreateFrame("Button", nil, ioFrame, "UIPanelButtonTemplate")
  openExport:SetSize(180, 24)
  openExport:SetPoint("TOPLEFT", ieInfo, "BOTTOMLEFT", 0, -14)
  openExport:SetText("Open Export Window")
  openExport:SetScript("OnClick", function()
    local f = EnsureIOPopup()
    f:Show()
    if f.edit then
      local prof = EAK:GetProfile()
      local exported = U:ExportProfile(prof)
      f.edit:SetText(exported or "")
      if f.edit.HighlightText then f.edit:HighlightText() end
      if f.edit.SetFocus then f.edit:SetFocus() end
    end
  end)

  local openImport = CreateFrame("Button", nil, ioFrame, "UIPanelButtonTemplate")
  openImport:SetSize(180, 24)
  openImport:SetPoint("LEFT", openExport, "RIGHT", 10, 0)
  openImport:SetText("Open Import Window")
  openImport:SetScript("OnClick", function()
    local f = EnsureIOPopup()
    f:Show()
    if f.edit then
      f.edit:SetText("")
      if f.edit.SetFocus then f.edit:SetFocus() end
    end
  end)
panel:SetScript("OnShow", function()
    UIDropDownMenu_SetText(dd, EAK:GetProfileName())
    SelectTab(panel._activeTab or "manage")
  end)

  InterfaceOptions_AddCategory(panel)
end
