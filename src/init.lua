local addonName = ...


EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
EbonholdAutomationKitGlobal.echoDB = EbonholdAutomationKitGlobal.echoDB or {}

EbonholdAutomationKitDB = EbonholdAutomationKitDB or {}

local EAK = {}
_G.EbonholdAutomationKit = EAK

EAK.addonName = addonName
EAK.runtime = {
  enabledThisSession = false,
  startButton = nil,
  stopButton = nil,
  lastKnownLevel = nil,
  lastChoiceHash = nil,
  uiBlock = { requested = false, blocked = false, frames = {}, ticker = nil },
}

local function DeepCopyDefaults(dst, src)
  if type(dst) ~= 'table' then dst = {} end
  for k, v in pairs(src) do
    if type(v) == 'table' then
      if type(dst[k]) ~= 'table' then dst[k] = {} end
      DeepCopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end


EAK.profileDefaults = {
  minLevelRequirement = 12,
  minScoreToKeep = 0,

  maxRollUsageInRow = 10,
  allowReroll = true,

  allowBanish = false,


  autoSelectDelay = 0.15,


  pickConfirmTimeout = 8.0,
  preferUnowned = true,

  databaseFillingMode = false,
  ownedPenalty = 0.35,
  qualityBonus = { [0]=0, [1]=5, [2]=12, [3]=25, [4]=45 },
  qualityMultiplier = { [0]=1.00, [1]=1.05, [2]=1.12, [3]=1.20, [4]=1.35 },

  pauseIfMultipleAbove = false,
  pauseMultipleAboveValue = 0,
  pauseIfOnlyBlacklisted = false,
  weights = {},
  blacklist = {},
  stackTargets = {},
}

EAK.defaults = {
  profileKey = nil,
  profiles = {},

  historyAutomation = {
    maxEntries = 200,
    entries = {},
    byLevel = {},
  },

  history = {
    maxEntries = 200,
    entries = {},
  },
  ui = {
    sortKey = 'name',
    sortAsc = true,
    showMinimap = false,
    showAllEchoes = false,
    weightsSearchMode = 'name',
    showStartStopButton = true,
  },
  uiProfiles = {
    backupBeforeImport = true,
  },
  uiStacks = {
    sortKey = 'name',
    sortAsc = true,
  }
}

function EAK:GetEchoDB()
  EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
  EbonholdAutomationKitGlobal.echoDB = EbonholdAutomationKitGlobal.echoDB or {}

  EbonholdAutomationKitGlobal.ui = EbonholdAutomationKitGlobal.ui or {}
  return EbonholdAutomationKitGlobal.echoDB
end

local function MigratePerCharacterEchoDBToGlobal()

  local src = EbonholdAutomationKitDB and EbonholdAutomationKitDB.echoDB
  if type(src) ~= "table" then return end

  local any = false
  for _ in pairs(src) do any = true break end
  if not any then
    EbonholdAutomationKitDB.echoDB = nil
    return
  end

  local dst = EAK:GetEchoDB()
  local _, classToken = UnitClass("player")

  for key, meta in pairs(src) do
    if type(key) == "string" and key:match("^%d+:%d+$") and type(meta) == "table" then
      local d = dst[key] or {}
      d.spellId = tonumber(meta.spellId) or d.spellId
      d.quality = tonumber(meta.quality) or d.quality
      d.name = meta.name or d.name
      d.icon = meta.icon or d.icon
      d.lastSeen = meta.lastSeen or d.lastSeen
      d.classes = d.classes or {}
      if type(meta.classes) == "table" then
        for ck, cv in pairs(meta.classes) do
          if cv then d.classes[ck] = true end
        end
      end
      if classToken then d.classes[classToken] = true end
      dst[key] = d
    end
  end


  EbonholdAutomationKitDB.echoDB = nil
end

local function MigratePerCharacterLogbookToGlobal()

  local src = EbonholdAutomationKitDB and EbonholdAutomationKitDB.logbook
  if type(src) ~= "table" then return end
  local sc = src.counts
  local sl = src.lastSeen
  if type(sc) ~= "table" or type(sl) ~= "table" then
    EbonholdAutomationKitDB.logbook = nil
    return
  end

  local any = false
  for _ in pairs(sc) do any = true break end
  if not any then
    EbonholdAutomationKitDB.logbook = nil
    return
  end

  EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
  local g = EbonholdAutomationKitGlobal
  g.logbook = g.logbook or { totalSeen = 0, counts = {}, lastSeen = {}, raritySeen = nil }
  g.logbook.counts = g.logbook.counts or {}
  g.logbook.lastSeen = g.logbook.lastSeen or {}

  for key, n in pairs(sc) do
    local nn = tonumber(n) or 0
    if nn ~= 0 then
      g.logbook.counts[key] = (tonumber(g.logbook.counts[key]) or 0) + nn
    end
  end
  for key, stamp in pairs(sl) do
    local s = tonumber(stamp) or 0
    local cur = tonumber(g.logbook.lastSeen[key]) or 0
    if s > cur then
      g.logbook.lastSeen[key] = s
    end
  end
  g.logbook.totalSeen = (tonumber(g.logbook.totalSeen) or 0) + (tonumber(src.totalSeen) or 0)
  g.logbook.raritySeen = nil

  EbonholdAutomationKitDB.logbook = nil
end

function EAK:GetCharacterDefaultProfileName()
  local n = (UnitName and UnitName("player")) or nil
  if type(n) ~= "string" or n == "" then
    n = "Default"
  end
  return n
end

local function EnsureCharacterProfile()
  local db = EbonholdAutomationKitDB
  db.profiles = db.profiles or {}

  local charKey = EAK:GetCharacterDefaultProfileName()


  if db.__charInit ~= true then
    local count = 0
    for _ in pairs(db.profiles) do count = count + 1 end
    if charKey ~= "Default" and count == 1 and type(db.profiles["Default"]) == "table" and type(db.profiles[charKey]) ~= "table" then
      db.profiles[charKey] = db.profiles["Default"]
      db.profiles["Default"] = nil
    end
    db.__charInit = true
    db.__charName = charKey
    db.__charGuid = (UnitGUID and UnitGUID("player")) or nil
  end

  if type(db.profiles[charKey]) ~= "table" then
    db.profiles[charKey] = {}
  end
  DeepCopyDefaults(db.profiles[charKey], EAK.profileDefaults)

  do
    local p = db.profiles[charKey]
    local v = tonumber(p.maxRollUsageInRow) or 10
    if v < 1 then v = 1 elseif v > 10 then v = 10 end
    p.maxRollUsageInRow = v
  end

  if type(db.profileKey) ~= "string" or db.profileKey == "" or type(db.profiles[db.profileKey]) ~= "table" then
    db.profileKey = charKey
  end
end

function EAK:GetProfileName()
  local db = EbonholdAutomationKitDB
  db.profiles = db.profiles or {}

  local key = db.profileKey
  if type(key) == "string" and key ~= "" and type(db.profiles[key]) == "table" then
    return key
  end

  local charKey = self:GetCharacterDefaultProfileName()
  if type(db.profiles[charKey]) ~= "table" then
    db.profiles[charKey] = {}
  end
  db.profileKey = charKey
  return charKey
end

function EAK:GetProfile()
  local db = EbonholdAutomationKitDB
  db.profiles = db.profiles or {}

  local name = self:GetProfileName()
  local p = db.profiles[name]
  if type(p) ~= "table" then
    p = {}
    db.profiles[name] = p
  end
  DeepCopyDefaults(p, self.profileDefaults)

  do
    local v = tonumber(p.maxRollUsageInRow) or 10
    if v < 1 then v = 1 elseif v > 10 then v = 10 end
    p.maxRollUsageInRow = v
  end
  return p
end


local function SetFrameShown(frame, shown)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shown)
  else
    if shown then frame:Show() else frame:Hide() end
  end
end


local DEFAULT_START_BTN_POS = { point = "TOP", relPoint = "TOP", x = 0, y = -70 }
local DEFAULT_START_BTN_NOTE = "Hold Right-Click to Move"

local function GetSavedStartButtonPos()
  local g = EbonholdAutomationKitGlobal
  if type(g) ~= 'table' or type(g.ui) ~= 'table' then return nil end
  local p = g.ui.startButtonPos
  if type(p) ~= 'table' then return nil end
  if not p.point or not p.relPoint then return nil end
  return p
end

local function SaveStartButtonPosFromFrame(frame)
  if not frame or not frame.GetPoint then return end
  local point, _, relPoint, x, y = frame:GetPoint(1)
  if not point or not relPoint then return end
  EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
  EbonholdAutomationKitGlobal.ui = EbonholdAutomationKitGlobal.ui or {}
  EbonholdAutomationKitGlobal.ui.startButtonPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function ApplyStartStopButtonPos()
  local p = GetSavedStartButtonPos() or DEFAULT_START_BTN_POS
  local function apply(btn)
    if not btn then return end
    btn:ClearAllPoints()
    btn:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
  end
  apply(EAK.runtime.startButton)
  apply(EAK.runtime.stopButton)
end

function EAK:SetStartButtonNote(note)
  self.runtime.startButtonNote = note
  if self.runtime.startButton and self.runtime.startButton.sub and (not self.runtime.enabledThisSession) then
    self.runtime.startButton.sub:SetText(note or DEFAULT_START_BTN_NOTE)
  end
end


local function UIBlocker_ForceInvisible(frame, slot)
  if slot.setalpha then pcall(slot.setalpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
end

local function UIBlocker_Apply(frame, slot)
  if not slot.init then
    slot.show = frame.Show
    slot.hide = frame.Hide
    slot.setshown = frame.SetShown
    slot.setalpha = frame.SetAlpha
    slot.getalpha = frame.GetAlpha
    slot.ismouse = frame.IsMouseEnabled
    slot.alpha = (slot.getalpha and slot.getalpha(frame)) or 1
    slot.mouse = (slot.ismouse and slot.ismouse(frame)) or nil
    slot.onshow = frame:GetScript("OnShow")
    slot.onhide = frame:GetScript("OnHide")
    slot.init = true
  end

  UIBlocker_ForceInvisible(frame, slot)

  frame.Show = function(self, ...)
    if slot.show then pcall(slot.show, self, ...) end
    UIBlocker_ForceInvisible(self, slot)
  end

  if frame.Hide and slot.hide then
    frame.Hide = function(self, ...)
      return pcall(slot.hide, self, ...)
    end
  end

  if frame.SetShown and slot.setshown then
    frame.SetShown = function(self, shown)
      pcall(slot.setshown, self, shown)
      if shown then UIBlocker_ForceInvisible(self, slot) end
    end
  end

  if frame.SetAlpha and slot.setalpha then
    frame.SetAlpha = function(self, a)
      local b = EAK and EAK.runtime and EAK.runtime.uiBlock
      if b and b.requested then
        return pcall(slot.setalpha, self, 0)
      end
      return pcall(slot.setalpha, self, a)
    end
  end
end

function EAK:TryBlockServerUI()
  local b = self.runtime.uiBlock
  local any = false
  local names = { "ProjectEbonholdPerkFrame", "PerkChoice1", "PerkChoice2", "PerkChoice3", "PerkHideButton", "PerkChooseButton" }
  for i = 1, #names do
    local f = _G[names[i]]
    if f then
      b.frames[f] = b.frames[f] or {}
      UIBlocker_Apply(f, b.frames[f])
      any = true
    end
  end
  b.blocked = any
  return any
end

function EAK:RestoreServerUI()
  local b = self.runtime.uiBlock
  if not b or type(b.frames) ~= 'table' then return end
  for frame, slot in pairs(b.frames) do
    if frame and slot and slot.init then
      if slot.show then frame.Show = slot.show end
      if slot.hide then frame.Hide = slot.hide end
      if slot.setshown then frame.SetShown = slot.setshown end
      if slot.setalpha then frame.SetAlpha = slot.setalpha end
      frame:SetScript("OnShow", slot.onshow)
      frame:SetScript("OnHide", slot.onhide)
      if slot.setalpha and slot.alpha ~= nil then pcall(slot.setalpha, frame, slot.alpha) end
      if slot.mouse ~= nil and frame.EnableMouse then pcall(frame.EnableMouse, frame, slot.mouse) end
    end
  end
  b.frames = {}
  b.blocked = false
end

function EAK:SetServerUIBlocked(on)
  local b = self.runtime.uiBlock
  b.requested = (on == true)
  if not b.requested then
    if b.ticker then b.ticker:SetScript("OnUpdate", nil) end
    self:RestoreServerUI()
    return
  end
  if self:TryBlockServerUI() then
    if b.ticker then b.ticker:SetScript("OnUpdate", nil) end
    return
  end
  if not b.ticker then
    b.ticker = CreateFrame("Frame", nil, UIParent)
  end
  b.ticker:SetScript("OnUpdate", function(self)
    if not EAK.runtime.uiBlock.requested then
      self:SetScript("OnUpdate", nil)
      return
    end
    if EAK:TryBlockServerUI() then
      self:SetScript("OnUpdate", nil)
    end
  end)
end

function EAK:RevealServerUI()
  self:SetServerUIBlocked(false)
  local U = self.Utils
  local function TryOpenPerkUI()
    local pe = _G.ProjectEbonhold
    if not pe then return end
    local ui = pe.PerkUI
    local svc = pe.PerkService
    if ui and type(ui.Show) == 'function' and svc and type(svc.GetCurrentChoice) == 'function' then
      local ok, choices = pcall(svc.GetCurrentChoice)
      if ok and type(choices) == 'table' then
        pcall(ui.Show, choices)
      end
    end
  end
  local function After(delay, fn)
    if U and U.After then
      U:After(delay, fn)
      return
    end
    if type(fn) ~= "function" then return end
    delay = tonumber(delay) or 0
    if delay < 0 then delay = 0 end
    if not self.runtime._uiRevealAfterFrame then
      local f = CreateFrame("Frame")
      f.q = {}
      f:SetScript("OnUpdate", function(_, elapsed)
        local q = f.q
        if not q or #q == 0 then return end
        for i = #q, 1, -1 do
          local it = q[i]
          it.t = it.t - elapsed
          if it.t <= 0 then
            table.remove(q, i)
            pcall(it.fn)
          end
        end
      end)
      self.runtime._uiRevealAfterFrame = f
    end
    table.insert(self.runtime._uiRevealAfterFrame.q, { t = delay, fn = fn })
  end

  local token = (self.runtime.uiRevealToken or 0) + 1
  self.runtime.uiRevealToken = token
  local tries = 0

  local function IsShown(f)
    return f and f.IsShown and f:IsShown()
  end
  local function TryShow(f)
    if not f then return end
    if f.SetShown then
      pcall(f.SetShown, f, true)
    else
      pcall(f.Show, f)
    end
  end
  local function Step()
    if self.runtime.uiRevealToken ~= token then return end
    tries = tries + 1
    TryOpenPerkUI()
    TryShow(_G.ProjectEbonholdPerkFrame)
    TryShow(_G.PerkChoice1)
    TryShow(_G.PerkChoice2)
    TryShow(_G.PerkChoice3)
    TryShow(_G.PerkChooseButton)
    TryShow(_G.PerkHideButton)
    if IsShown(_G.ProjectEbonholdPerkFrame) or IsShown(_G.PerkChoice1) then return end
    if tries < 20 then
      After(0.05, Step)
    end
  end
  After(0.05, Step)
end


function EAK:SetEnabledThisSession(on)
  local ui = (EbonholdAutomationKitDB and EbonholdAutomationKitDB.ui) or {}
  local show = (ui.showStartStopButton ~= false)

  if not show then
    self.runtime.enabledThisSession = false
    SetFrameShown(self.runtime.startButton, false)
    SetFrameShown(self.runtime.stopButton, false)
    self:SetServerUIBlocked(false)
    if self.runtime.startButton and self.runtime.startButton.sub then
      self.runtime.startButton.sub:SetText(self.runtime.startButtonNote or DEFAULT_START_BTN_NOTE)
    end
    return
  end

  self.runtime.enabledThisSession = (on == true)
  SetFrameShown(self.runtime.startButton, not self.runtime.enabledThisSession)
  SetFrameShown(self.runtime.stopButton, self.runtime.enabledThisSession)

  self:SetServerUIBlocked(self.runtime.enabledThisSession)

  if not self.runtime.enabledThisSession and self.runtime.startButton and self.runtime.startButton.sub then
    self.runtime.startButton.sub:SetText(self.runtime.startButtonNote or DEFAULT_START_BTN_NOTE)
  end
end

local function CreateStartButton()
  local btn = CreateFrame("Button", "EAK_StartButton", UIParent)
  btn:SetFrameStrata("DIALOG")
  btn:SetSize(280, 64)
  btn:SetPoint(DEFAULT_START_BTN_POS.point, UIParent, DEFAULT_START_BTN_POS.relPoint, DEFAULT_START_BTN_POS.x, DEFAULT_START_BTN_POS.y)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  btn:RegisterForDrag("RightButton")
  btn:SetMovable(true)
  if btn.SetClampedToScreen then btn:SetClampedToScreen(true) end

  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  btn:SetBackdropColor(0, 0, 0, 0.55)
  btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.95)

  local glow = btn:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints(btn)
  glow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(0.7, 0.75, 0.85)
  glow:SetAlpha(0.18)
  btn.glow = glow

  local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  text:SetPoint("CENTER", btn, "CENTER", 0, 0)
  text:SetText("Start Picking Echoes")
  text:SetFont("Fonts\\MORPHEUS.TTF", 16)
  btn.text = text

  local sub = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  sub:SetPoint("TOP", text, "BOTTOM", 0, -2)
  sub:SetText(DEFAULT_START_BTN_NOTE)
  sub:SetTextColor(0.8, 0.8, 0.8)
  btn.sub = sub

  btn:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveStartButtonPosFromFrame(self)
    ApplyStartStopButtonPos()
  end)

  btn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.65, 0.70, 0.80, 0.95)
    self.glow:SetAlpha(0.30)
    self.text:SetTextColor(1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.95)
    self.glow:SetAlpha(0.18)
    self.text:SetTextColor(1, 0.82, 0)
  end)

  btn:SetScript("OnUpdate", function(self)
    local t = GetTime()
    self.glow:SetAlpha(0.14 + 0.10 * math.abs(math.sin(t * 0.9)))
  end)

  btn:SetScript("OnClick", function()
    EAK:SetStartButtonNote(nil)
    EAK.runtime.pauseResumeArmed = nil
    EAK.runtime.pauseResumeKind = nil
    EAK:SetEnabledThisSession(true)
    if EAK.Engine and EAK.Engine.TryRequestChoice then
      EAK.Engine:TryRequestChoice()
    end
  end)

  return btn
end

local function CreateStopButton()
  local btn = CreateFrame("Button", "EAK_StopButton", UIParent)
  btn:SetFrameStrata("DIALOG")
  btn:SetSize(260, 54)
  btn:SetPoint(DEFAULT_START_BTN_POS.point, UIParent, DEFAULT_START_BTN_POS.relPoint, DEFAULT_START_BTN_POS.x, DEFAULT_START_BTN_POS.y)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  btn:RegisterForDrag("RightButton")
  btn:SetMovable(true)
  if btn.SetClampedToScreen then btn:SetClampedToScreen(true) end

  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  btn:SetBackdropColor(0.12, 0, 0, 0.60)
  btn:SetBackdropBorderColor(0.50, 0.20, 0.20, 0.95)

  local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  text:SetPoint("CENTER", btn, "CENTER", 0, 0)
  text:SetText("Stop Picking Echoes")
  text:SetFont("Fonts\\MORPHEUS.TTF", 16)
  btn.text = text

  btn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.85, 0.35, 0.35, 0.95)
    self.text:SetTextColor(1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.50, 0.20, 0.20, 0.95)
    self.text:SetTextColor(1, 0.82, 0)
  end)

  btn:SetScript("OnClick", function()
    EAK:SetStartButtonNote(nil)
    EAK.runtime.pauseResumeArmed = nil
    EAK.runtime.pauseResumeKind = nil
    EAK:SetEnabledThisSession(false)
  end)

  btn:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveStartButtonPosFromFrame(self)
    ApplyStartStopButtonPos()
  end)

  return btn
end

local function OnPlayerLogin()
  DeepCopyDefaults(EbonholdAutomationKitDB, EAK.defaults)

  if type(EbonholdAutomationKitDB.historyAutomation) == 'table' then
    EbonholdAutomationKitDB.historyAutomation.pending = {}
  end

  EAK:GetEchoDB()
  MigratePerCharacterEchoDBToGlobal()
  MigratePerCharacterLogbookToGlobal()
  EnsureCharacterProfile()

  if type(EbonholdAutomationKitDB.profiles) == "table" then
    for _, prof in pairs(EbonholdAutomationKitDB.profiles) do
      if type(prof) == "table" then
        prof.whitelist = nil
      end
    end
  end

  EAK.runtime.startButton = CreateStartButton()
  EAK.runtime.stopButton = CreateStopButton()

  ApplyStartStopButtonPos()
  EAK.runtime.pauseResumeArmed = nil
  EAK.runtime.pauseResumeKind = nil
  EAK:SetEnabledThisSession(false)
  EAK.runtime.lastKnownLevel = UnitLevel("player")

  if EAK.Options and EAK.Options.Initialize then
    EAK.Options:Initialize()
  end

  if EAK.Engine and EAK.Engine.Initialize then
    EAK.Engine:Initialize()
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    OnPlayerLogin()

    if EAK and EAK.Utils and EAK.Utils.After then
      EAK.Utils:After(2, function()
        if EAK and EAK.TryHookServerPerkChatLinks then
          EAK:TryHookServerPerkChatLinks(true)
        end
      end)
    end


    if EAK.Utils and EAK.Utils.After then
      EAK.Utils:After(1, function()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Ebonhold Automation Kit|r |cff00ff00Loaded|r - Use |cff00ff00/eak|r to configure.")
        end
      end)
    end
  elseif event == "PLAYER_LEVEL_UP" then
    local newLevel = ...
    EAK.runtime.lastKnownLevel = tonumber(newLevel) or UnitLevel("player")
  elseif event == "PLAYER_ENTERING_WORLD" then


    local isLogin, isReload = ...
    if isLogin or isReload then
      EAK:SetStartButtonNote(nil)
      EAK.runtime.pauseResumeArmed = nil
      EAK.runtime.pauseResumeKind = nil
      EAK:SetEnabledThisSession(false)
    end
    EAK.runtime.lastKnownLevel = UnitLevel("player")
  end
end)

function EAK:_HookPerkChoiceFrame(frame)
  if not frame then return false end
  local function GetData()
    local idx = frame.perkIndex
    if idx == nil then
      local n = frame.GetName and frame:GetName() or nil
      if type(n) == 'string' then
        local m = n:match('PerkChoice(%d+)')
        if m then idx = tonumber(m) and (tonumber(m) - 1) or nil end
      end
    end
    local cur = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice()
    local d = (type(cur) == 'table' and idx ~= nil) and cur[idx + 1] or nil
    if type(d) ~= 'table' then return nil end
    return d
  end

  local btn = frame.selectButton
  if btn and not btn._eakLinkHooked and btn.GetScript and btn.SetScript then
    local orig = btn:GetScript('OnClick')
    btn:SetScript('OnClick', function(self, button, ...)
      if button == 'LeftButton' and EAK and EAK.Utils and EAK.Utils.TryInsertSpellLink then
        local d = GetData()
        if d and d.spellId and EAK.Utils:TryInsertSpellLink(d.spellId, d.quality) then
          return
        end
      end
      if orig then return orig(self, button, ...) end
    end)
    btn._eakLinkHooked = true
  end

  if frame.HookScript and not frame._eakLinkMouseHooked then
    frame._eakLinkMouseHooked = true
    frame:HookScript('OnMouseUp', function(self, button)
      if button ~= 'LeftButton' then return end
      if EAK and EAK.Utils and EAK.Utils.TryInsertSpellLink then
        local d = GetData()
        if d and d.spellId then
          EAK.Utils:TryInsertSpellLink(d.spellId, d.quality)
        end
      end
    end)
  end

  return btn ~= nil
end

function EAK:TryHookServerPerkChatLinks(retry)
  self.runtime = self.runtime or {}
  if self.runtime.serverPerkLinkHooked and not retry then return true end

  local hooked = false
  local seen = {}

  local function AddFrame(fr)
    if not fr then return end
    if seen[fr] then return end
    seen[fr] = true
    if self:_HookPerkChoiceFrame(fr) then hooked = true end
  end

  for i = 1, 10 do
    AddFrame(_G['PerkChoice' .. i])
  end

  local roots = { _G.ProjectEbonholdEmpowermentFrame, _G.ProjectEbonholdPerkFrame }
  for _, root in ipairs(roots) do
    if root and root.GetChildren then
      local function Walk(node, depth)
        if not node or depth > 5 then return end
        if node.selectButton then AddFrame(node) end
        local kids = { node:GetChildren() }
        for _, c in ipairs(kids) do
          Walk(c, depth + 1)
        end
      end
      Walk(root, 1)
    end
  end

  if hooked then
    self.runtime.serverPerkLinkHooked = true
    return true
  end

  if retry and self.Utils and self.Utils.After then
    self.Utils:After(2, function()
      if EAK and EAK.TryHookServerPerkChatLinks then
        EAK:TryHookServerPerkChatLinks(true)
      end
    end)
  end
  return false
end






function EAK:ResetStartStopButtonPos()
  EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
  EbonholdAutomationKitGlobal.ui = EbonholdAutomationKitGlobal.ui or {}
  EbonholdAutomationKitGlobal.ui.startButtonPos = nil
  ApplyStartStopButtonPos()
end

function EAK:OpenConfig()

  if type(InterfaceOptionsFrame_OpenToCategory) == "function" and EAK.Options and EAK.Options.mainPanel then
    InterfaceOptionsFrame_OpenToCategory(EAK.Options.mainPanel)
    InterfaceOptionsFrame_OpenToCategory(EAK.Options.mainPanel)
  else
    if InterfaceOptionsFrame and InterfaceOptionsFrame.Show then InterfaceOptionsFrame:Show() end
  end
end

SLASH_EAK1 = "/eak"
SlashCmdList["EAK"] = function(msg)
  msg = (msg or "")
  msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
  local low = msg:lower()

  local function Say(s)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and s then
      DEFAULT_CHAT_FRAME:AddMessage(s)
    end
  end

  if low == "info" then
    Say("|cffffd100Ebonhold Automation Kit|r commands:")
    Say("  |cff00ff00/eak|r - Open configuration")
    Say("  |cff00ff00/eak info|r - Show commands")
    Say("  |cff00ff00/eak resetpos|r - Reset the Start/Stop button position")
    Say("  |cff00ff00/eak toggle|r - Toggle the Start/Stop button visibility")
    return
  end

  if low == "resetpos" then
    EAK:ResetStartStopButtonPos()
    Say("|cffffd100Ebonhold Automation Kit|r: Start/Stop button position reset.")
    return
  end

  
  if low == "toggle" then
    EbonholdAutomationKitDB = EbonholdAutomationKitDB or {}
    EbonholdAutomationKitDB.ui = EbonholdAutomationKitDB.ui or {}
    local ui = EbonholdAutomationKitDB.ui
    if ui.showStartStopButton == false then
      ui.showStartStopButton = true
    else
      ui.showStartStopButton = false
    end
    local showNow = (ui.showStartStopButton ~= false)
    if EAK and EAK.Options and EAK.Options.showBtnCB and EAK.Options.showBtnCB.SetChecked then
      EAK.Options.showBtnCB:SetChecked(showNow)
    end
    if EAK and EAK.SetEnabledThisSession then
      EAK:SetEnabledThisSession(EAK.runtime and EAK.runtime.enabledThisSession == true)
    end
    Say("|cffffd100Ebonhold Automation Kit|r: Start/Stop button " .. (showNow and "shown." or "hidden."))
    return
  end

EAK:OpenConfig()
end
