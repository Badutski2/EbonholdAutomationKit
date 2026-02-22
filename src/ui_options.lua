local EAK = _G.EbonholdAutomationKit
local U = EAK.Utils

EAK.Options = EAK.Options or {}
local Opt = EAK.Options




local __uid = 0
local function NextName(prefix)
  __uid = __uid + 1
  return "EAK_" .. (prefix or "W") .. "_" .. __uid
end

local function MakePanel(name, parent, title, useScroll, subtitleText)
  local panel = CreateFrame("Frame", name, InterfaceOptionsFramePanelContainer)
  panel.name = title or name
  panel.parent = parent

  local header = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  header:SetPoint("TOPLEFT", 16, -16)
  header:SetText(title or name)


  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT")
  sub:SetJustifyV("TOP")
  sub:SetNonSpaceWrap(true)
  sub:SetWordWrap(true)


  local topOffsetY
  if subtitleText and subtitleText ~= "" then
    sub:SetText(subtitleText)
    sub:SetHeight(40)
    topOffsetY = -78
  else
    sub:SetText("")
    sub:SetHeight(0)
    topOffsetY = -56
  end

  if useScroll == nil then useScroll = true end

  local scroll, content
  if useScroll then

    scroll = CreateFrame("ScrollFrame", name .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, topOffsetY)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    content = CreateFrame("Frame", name .. "Content", scroll)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    content:SetWidth(1)
    content:SetHeight(2600)
    scroll:SetScrollChild(content)


    local function FitScrollChildWidth()
      if not scroll or not content or not scroll.GetWidth then return end
      local w = scroll:GetWidth()
      if not w or w < 50 then return end

      local sb = _G[scroll:GetName() .. "ScrollBar"]
      local sbw = (sb and sb.GetWidth and sb:GetWidth()) or 16


      w = w - sbw - 16
      if w < 1 then w = 1 end
      content:SetWidth(w)
    end

    panel.FitScrollChildWidth = FitScrollChildWidth

    if scroll.HookScript then
      scroll:HookScript("OnShow", function() U:After(0, FitScrollChildWidth) end)
      scroll:HookScript("OnSizeChanged", function() U:After(0, FitScrollChildWidth) end)
    end
    if panel.HookScript then
      panel:HookScript("OnShow", function() U:After(0, FitScrollChildWidth) end)
    end

    panel.scroll = scroll
  else

    content = CreateFrame("Frame", name .. "Content", panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, topOffsetY)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 10)
  end

  panel.content = content
  panel.header = header
  panel.sub = sub

  return panel, header, sub, content
end

local function CreateLabel(parent, text)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetJustifyH("LEFT")
  fs:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  fs:SetNonSpaceWrap(true)
  fs:SetWordWrap(true)
  fs:SetText(text or "")
  return fs
end

local function CreateCheckbox(parent, text)
  local cb = CreateFrame("CheckButton", NextName("CB"), parent, "ChatConfigCheckButtonTemplate")
  local t = _G[cb:GetName() .. "Text"]
  if t then
    t:SetText(text)
    t:SetWidth(520)
    t:SetJustifyH("LEFT")
    if t.SetNonSpaceWrap then t:SetNonSpaceWrap(true) end
    if t.SetWordWrap then t:SetWordWrap(true) end
  end

  cb:SetHeight(34)
  return cb
end

local function CreateSliderRow(parent, labelText, minV, maxV, step)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(590)
  row:SetHeight(56)

  local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 0, 0)
  label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  label:SetJustifyH("LEFT")
  label:SetNonSpaceWrap(true)
  label:SetWordWrap(true)
  label:SetText(labelText or "")

  local slider = CreateFrame("Slider", NextName("Slider"), row, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  slider:SetWidth(320)
  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

  local low = _G[slider:GetName() .. "Low"]
  local high = _G[slider:GetName() .. "High"]
  local txt = _G[slider:GetName() .. "Text"]
  if low then low:SetText(tostring(minV)) end
  if high then high:SetText(tostring(maxV)) end
  if txt then txt:SetText("") end

  local valueText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  valueText:SetText("")
  row.label = label
  row.slider = slider
  row.valueText = valueText

  return row
end

local function CreateIntegerRow(parent, labelText, minV, maxV)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(590)
  row:SetHeight(46)

  local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 0, 0)
  label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  label:SetJustifyH("LEFT")
  label:SetNonSpaceWrap(true)
  label:SetWordWrap(true)
  label:SetText(labelText or "")

  local eb = CreateFrame("EditBox", nil, row)
  eb:EnableMouse(true)
  eb:SetAutoFocus(false)
  eb:SetMultiLine(false)
  eb:SetFontObject(ChatFontNormal)


  if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
  if eb.SetTextInsets then eb:SetTextInsets(6, 6, 3, 3) end
  eb:SetSize(80, 20)
  eb:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
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

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(eb)
  end

  local hint = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("LEFT", eb, "RIGHT", 8, 0)
  if maxV == nil then
    if minV ~= nil then
      hint:SetText(string.format("(min %d)", minV))
    else
      hint:SetText("(integer)")
    end
  else
    hint:SetText(string.format("(range %d-%d)", minV or 0, maxV))
  end

  row.label = label
  row.editBox = eb
  row.hint = hint
  row.minV = minV
  row.maxV = maxV
  return row
end

local function ApplyIntegerBox(row, getter, setter)
  if not row or not row.editBox then return end
  local raw = U:Trim(row.editBox:GetText() or "")
  local num = tonumber(raw)
  if num == nil then
    row.editBox:SetText(tostring(getter()))
    return
  end
  num = math.floor(num + 0.5)
  num = U:Clamp(num, row.minV or num, row.maxV or num)
  setter(num)
  row.editBox:SetText(tostring(num))
end

local function AnchorBelow(widget, prev, x, y)
  widget:ClearAllPoints()
  if not prev then
    widget:SetPoint("TOPLEFT", 16, -10)
  else
    widget:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x or 0, y or -14)
  end
end

function Opt:RefreshMain()
  local p = EAK:GetProfile()

  if self.automationPanel and self.automationPanel.widgets then
    local w = self.automationPanel.widgets

    w.rerollCB:SetChecked(p.allowReroll ~= false)
    if w.banishCB then w.banishCB:SetChecked(p.allowBanish == true) end
    w.preferCB:SetChecked(p.preferUnowned ~= false)
    if w.dbFillCB then w.dbFillCB:SetChecked(p.databaseFillingMode == true) end

    w.minLvl.slider:SetValue(U:Clamp(p.minLevelRequirement or 12, 1, 80))
    w.minLvl.valueText:SetText(tostring(U:Round(p.minLevelRequirement or 12)))


    w.delay.slider:SetValue(150)
    w.delay.valueText:SetText("150 ms")
  end

  if self.scoringPanel and self.scoringPanel.widgets then
    local w = self.scoringPanel.widgets

    w.minScore.editBox:SetText(tostring(U:Round(tonumber(p.minScoreToKeep) or 0)))
    if w.minScore.editBox.SetCursorPosition then w.minScore.editBox:SetCursorPosition(0) end
    if w.minScore.editBox.HighlightText then w.minScore.editBox:HighlightText(0, 0) end

    w.pen.slider:SetValue(U:Clamp((p.ownedPenalty or 0.35) * 100, 0, 100))
    w.pen.valueText:SetText(tostring(U:Round((p.ownedPenalty or 0.35) * 100)) .. "%")
  end

  if self.rulesPanel and self.rulesPanel.widgets then
    local w = self.rulesPanel.widgets

    local cap = p.maxRollUsageInRow
    if cap == nil then cap = p.maxRerollsPerLevel end
    w.maxR.slider:SetValue(U:Clamp(cap or 10, 1, 10))
    w.maxR.valueText:SetText(tostring(U:Round(cap or 10)))

    w.pauseMultiCB:SetChecked(p.pauseIfMultipleAbove == true)
    w.pauseMultiVal.editBox:SetText(tostring(U:Round(tonumber(p.pauseMultipleAboveValue) or 0)))
    if w.pauseMultiVal.editBox.SetCursorPosition then w.pauseMultiVal.editBox:SetCursorPosition(0) end
    if w.pauseMultiVal.editBox.HighlightText then w.pauseMultiVal.editBox:HighlightText(0, 0) end

    w.pauseBLOnlyCB:SetChecked(p.pauseIfOnlyBlacklisted == true)
  end
end

function Opt:Initialize()
  if self.initialized then return end
  self.initialized = true

  local function AttachOnShow(pnl)
    pnl:SetScript("OnShow", function()
      if pnl.refresh then pnl.refresh() end

      U:After(0, function()
        if pnl:IsShown() and pnl.refresh then pnl.refresh() end
      end)
    end)
  end


  local mainPanel, header, sub, mainContent = MakePanel("EbonholdAutomationKitOptions", nil, "Ebonhold Automation Kit", true)
  self.mainPanel = mainPanel

  local showBtnCB = CreateCheckbox(mainContent, "Show/Hide Button")
  AnchorBelow(showBtnCB, nil, -4, -6)
  showBtnCB:SetScript("OnClick", function(self)
    EbonholdAutomationKitDB.ui = EbonholdAutomationKitDB.ui or {}
    local ui = EbonholdAutomationKitDB.ui
    ui.showStartStopButton = self:GetChecked() and true or false
    if EAK and EAK.runtime then
      EAK:SetStartButtonNote(nil)
      EAK.runtime.pauseResumeArmed = nil
      EAK.runtime.pauseResumeKind = nil
    end
    if EAK and EAK.SetEnabledThisSession then
      EAK:SetEnabledThisSession(false)
    end
  end)
  self.showBtnCB = showBtnCB

  local tip = mainContent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  tip:SetJustifyH("LEFT")
  tip:SetJustifyV("TOP")
  tip:SetNonSpaceWrap(true)
  tip:SetWordWrap(true)

  local BULLET = "\226\128\162 "

  local HELP_TEXT = table.concat({
    "Automates the |cff66ccffEbonhold Echo|r choice system. You control everything through weights, rarity tuning, rerolls, banishing, and pause rules.",
    "",
    "|cff00ff00Quick Start|r",
    BULLET .. "Open settings with |cff00ff00/eak|r",
    BULLET .. "After login or |cff00ff00/reload|r, click |cffffff00Start Picking Echoes|r (top of your screen)",
    BULLET .. "Click again to stop at any time",
    BULLET .. "Session-only: it turns off on relog/reload",
    BULLET .. "While running, the server perk UI is hidden to prevent flicker",
    BULLET .. "If a pause rule triggers, the perk UI is shown and the 3 choices open automatically",
    "",
    "|cff00ff00Scoring|r",
    BULLET .. "Highest score wins (ties are random)",
    BULLET .. "Score = (Weight + Rarity Bonus) × Rarity Multiplier × Owned Factor",
    BULLET .. "Single Echo Mode reduces scores for Echoes you already own: (1 - ownedPenalty)^stacks",
    BULLET .. "Blacklisted Echoes are avoided whenever possible",
    "",
    "|cff00ff00Rerolls + Banishing|r",
    BULLET .. "Reroll when the best score is below your Minimum Score (if rerolls are available)",
    BULLET .. "Max roll usage in a row limits streak rerolls until a pick happens",
    BULLET .. "Database Filling Mode uses rerolls to discover unseen Echoes for your class in the global Echo DB",
    BULLET .. "Automatic Banishing can banish blacklisted offers when banishes are available",
    "",
    "|cff00ff00History|r",
    BULLET .. "Picks, rerolls, and banishes are logged (including manual actions)",
    "",
    "|cff00ff00Profiles + Import / Export|r",
    BULLET .. "Import/Export includes: profile settings, weights, rarity rules, blacklist, and the global Echo database",
    BULLET .. "Commands: |cff00ff00/eak info|r",
  }, "\n")

  tip:SetText(HELP_TEXT)






  local function LayoutHelp()
    if mainPanel.FitScrollChildWidth then mainPanel.FitScrollChildWidth() end

    tip:ClearAllPoints()
    if Opt.showBtnCB then
      tip:SetPoint("TOPLEFT", Opt.showBtnCB, "BOTTOMLEFT", 4, -10)
    else
      tip:SetPoint("TOPLEFT", mainContent, "TOPLEFT", 16, -1)
    end
    tip:SetPoint("TOPRIGHT", mainContent, "TOPRIGHT", -16, 1)

    tip:SetHeight(840)
    mainContent:SetHeight(880)

    tip:SetText(HELP_TEXT)
  end

  mainPanel.refresh = function()
    if Opt.showBtnCB then
      local ui = (EbonholdAutomationKitDB and EbonholdAutomationKitDB.ui) or {}
      Opt.showBtnCB:SetChecked(ui.showStartStopButton ~= false)
    end
    LayoutHelp()
    U:After(0, LayoutHelp)
    U:After(0.05, LayoutHelp)
  end
  AttachOnShow(mainPanel)


  InterfaceOptions_AddCategory(mainPanel)


  local autoPanel, _, _, autoContent = MakePanel("EbonholdAutomationKitOptionsAutomation", mainPanel.name, "Automation", false, "Configure automation behavior: rerolls, banish, single-echo mode, database filling mode, and minimum Echoes before rolling.")
  self.automationPanel = autoPanel

  local last = nil

  local minLvl = CreateSliderRow(autoContent, "Minimum Echoes before Rolling (recommended 12)", 1, 80, 1)
  AnchorBelow(minLvl, last, 0, -12)
  last = minLvl
  minLvl.slider:SetScript("OnValueChanged", function(self, val)
    val = U:Round(val)
    local p = EAK:GetProfile()
    p.minLevelRequirement = val
    minLvl.valueText:SetText(tostring(val))
  end)

  local rerollCB = CreateCheckbox(autoContent, "Enable Automatic Rerolling")
  AnchorBelow(rerollCB, last, -4, -6)
  last = rerollCB
  rerollCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.allowReroll = self:GetChecked() and true or false
  end)

  local banishCB = CreateCheckbox(autoContent, "Enable Automatic Banishing")
  AnchorBelow(banishCB, last, 0, -6)
  last = banishCB
  banishCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.allowBanish = self:GetChecked() and true or false
  end)

  local preferCB = CreateCheckbox(autoContent, "Single Echo Mode (collect one of each Echo)")
  AnchorBelow(preferCB, last, 0, -6)
  last = preferCB
  preferCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.preferUnowned = self:GetChecked() and true or false
  end)

  local dbFillCB = CreateCheckbox(autoContent, "Database Filling Mode")
  AnchorBelow(dbFillCB, last, 0, -6)
  last = dbFillCB
  dbFillCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.databaseFillingMode = self:GetChecked() and true or false
  end)

  local dbFillNote = autoContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  dbFillNote:SetPoint("TOPLEFT", dbFillCB, "BOTTOMLEFT", 24, -2)
  dbFillNote:SetPoint("RIGHT", autoContent, "RIGHT", -16, 0)
  dbFillNote:SetJustifyH("LEFT")
  dbFillNote:SetJustifyV("TOP")
  if dbFillNote.SetNonSpaceWrap then dbFillNote:SetNonSpaceWrap(true) end
  if dbFillNote.SetWordWrap then dbFillNote:SetWordWrap(true) end
  dbFillNote:SetText("When enabled: ignores weights/blacklist/prefer-unowned/min-score & pause rules. Uses rerolls to find unseen Echoes for your class in the global Echo DB.")
  dbFillNote:SetHeight(42)
  last = dbFillNote

  local delay = CreateSliderRow(autoContent, "Echo Selection Delay (fixed at 150 ms)", 150, 150, 10)
  AnchorBelow(delay, last, 0, -10)
  last = delay
  delay.slider:Disable()
  delay.slider:SetValue(150)
  delay.valueText:SetText("150 ms")

  autoPanel.widgets = {
    minLvl = minLvl,
    rerollCB = rerollCB,
    banishCB = banishCB,
    preferCB = preferCB,
    dbFillCB = dbFillCB,
    delay = delay,
  }
  autoPanel.refresh = function() Opt:RefreshMain() end
  AttachOnShow(autoPanel)
  InterfaceOptions_AddCategory(autoPanel)


  local scoringPanel, _, _, scoreContent = MakePanel("EbonholdAutomationKitOptionsScoring", mainPanel.name, "Scoring", false, "Tune scoring rules that decide what gets picked.")
  self.scoringPanel = scoringPanel

  local last = nil

  local minScore = CreateIntegerRow(scoreContent, "Minimum Score (reroll below)", 0, nil)
  AnchorBelow(minScore, last, 0, -12)
  last = minScore
  minScore.editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  minScore.editBox:SetScript("OnEditFocusLost", function()
    ApplyIntegerBox(minScore,
      function()
        local p = EAK:GetProfile()
        return U:Round(tonumber(p.minScoreToKeep) or 0)
      end,
      function(v)
        local p = EAK:GetProfile()
        p.minScoreToKeep = v
      end
    )
  end)

  local pen = CreateSliderRow(scoreContent, "Weight Penalty Per Stack", 0, 100, 1)
  AnchorBelow(pen, last, 0, -10)
  last = pen
  pen.slider:SetScript("OnValueChanged", function(self, val)
    val = U:Round(val)
    local p = EAK:GetProfile()
    p.ownedPenalty = U:Clamp(val / 100, 0, 1)
    pen.valueText:SetText(tostring(val) .. "%")
  end)

  scoringPanel.widgets = {
    minScore = minScore,
    pen = pen,
  }
  scoringPanel.refresh = function() Opt:RefreshMain() end
  AttachOnShow(scoringPanel)
  InterfaceOptions_AddCategory(scoringPanel)


  local rulesPanel, _, _, rulesContent = MakePanel("EbonholdAutomationKitOptionsRules", mainPanel.name, "Reroll / Pause", false, "Configure reroll limits and safety pauses that stop automation for manual choices.")
  self.rulesPanel = rulesPanel

  local last = nil

  local maxR = CreateSliderRow(rulesContent, "Maximum Continuous Roll Usage", 1, 10, 1)
  AnchorBelow(maxR, last, 0, -12)
  last = maxR
  maxR.slider:SetScript("OnValueChanged", function(self, val)
    val = U:Round(val)
    local p = EAK:GetProfile()
    p.maxRollUsageInRow = val
    p.maxRerollsPerLevel = nil
    maxR.valueText:SetText(tostring(val))
  end)

  local pauseMultiCB = CreateCheckbox(rulesContent, "Pause Echo Picking if 2+ Echoes are at/above the Pause Threshold")
  AnchorBelow(pauseMultiCB, last, -4, -6)
  last = pauseMultiCB
  pauseMultiCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.pauseIfMultipleAbove = self:GetChecked() and true or false
  end)

  local pauseMultiVal = CreateIntegerRow(rulesContent, "Pause Threshold (score at/above)", 0, nil)
  AnchorBelow(pauseMultiVal, last, 0, -10)
  last = pauseMultiVal
  pauseMultiVal.editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  pauseMultiVal.editBox:SetScript("OnEditFocusLost", function()
    ApplyIntegerBox(pauseMultiVal,
      function()
        local p = EAK:GetProfile()
        return U:Round(tonumber(p.pauseMultipleAboveValue) or 0)
      end,
      function(v)
        local p = EAK:GetProfile()
        p.pauseMultipleAboveValue = v
      end
    )
  end)

  local pauseBLOnlyCB = CreateCheckbox(rulesContent, "Pause Auto-Picking if only blacklisted Echoes remain")
  AnchorBelow(pauseBLOnlyCB, last, -4, -6)
  last = pauseBLOnlyCB
  pauseBLOnlyCB:SetScript("OnClick", function(self)
    local p = EAK:GetProfile()
    p.pauseIfOnlyBlacklisted = self:GetChecked() and true or false
  end)

  rulesPanel.widgets = {
    maxR = maxR,
    pauseMultiCB = pauseMultiCB,
    pauseMultiVal = pauseMultiVal,
    pauseBLOnlyCB = pauseBLOnlyCB,
  }
  rulesPanel.refresh = function() Opt:RefreshMain() end
  AttachOnShow(rulesPanel)
  InterfaceOptions_AddCategory(rulesPanel)


  if EAK.ProfilesUI and EAK.ProfilesUI.CreatePanel then
    EAK.ProfilesUI:CreatePanel(mainPanel.name)
  end
  if EAK.RarityUI and EAK.RarityUI.CreatePanel then
    EAK.RarityUI:CreatePanel(mainPanel.name)
  end
  if EAK.WeightsUI and EAK.WeightsUI.CreatePanel then
    EAK.WeightsUI:CreatePanel(mainPanel.name)
  end
  if EAK.StacksUI and EAK.StacksUI.CreatePanel then
    EAK.StacksUI:CreatePanel(mainPanel.name)
  end
  if EAK.HistoryUI and EAK.HistoryUI.CreatePanel then
    EAK.HistoryUI:CreatePanel(mainPanel.name)
  end


  Opt:RefreshMain()
end
