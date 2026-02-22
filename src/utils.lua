local EAK = _G.EbonholdAutomationKit
EAK.Utils = EAK.Utils or {}
local U = EAK.Utils

function U:Clamp(x, a, b)
  if x == nil then return a end
  if x < a then return a end
  if x > b then return b end
  return x
end

function U:Round(x)
  if not x then return 0 end
  return math.floor(x + 0.5)
end

function U:Trim(s)
  if type(s) ~= 'string' then return '' end
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end



function U:Encode(s)
  s = tostring(s or "")
  s = s:gsub(" ", "+")
  return (s:gsub("([^%w%-%_%.~%+])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

function U:Decode(s)
  s = tostring(s or "")
  s = s:gsub("%+", " ")
  s = s:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return s
end

function U:ColorText(text, r, g, b)
  return string.format("|cff%02x%02x%02x%s|r", (r or 1)*255, (g or 1)*255, (b or 1)*255, text or "")
end

function U:StripWoWFormatting(s)
  if type(s) ~= 'string' then return '' end


  s = s:gsub('|c%x%x%x%x%x%x%x%x', '')
  s = s:gsub('|r', '')

  s = s:gsub('|T.-|t', '')

  s = s:gsub('|H[^|]+|h([^|]+)|h', '%1')
  return s
end



function U:NormalizeSearchText(s)
  if type(s) ~= 'string' then return '' end
  s = self:StripWoWFormatting(s)
  s = s:lower()
  s = s:gsub('%s+', ' ')
  s = self:Trim(s)
  return s
end


function U:_GetScanTooltip()
  if self._scanTooltip and self._scanTooltip.SetOwner then
    return self._scanTooltip
  end
  local tt = CreateFrame('GameTooltip', 'EAK_ScanTooltip', UIParent, 'GameTooltipTemplate')
  tt:SetOwner(UIParent, 'ANCHOR_NONE')
  tt:Hide()
  self._scanTooltip = tt
  return tt
end


function U:CaptureSpellTooltip(spellId)
  local sid = tonumber(spellId)
  if not sid then return nil, nil, nil end

  local tt = self:_GetScanTooltip()



  pcall(function() tt:SetOwner(UIParent, 'ANCHOR_NONE') end)

  tt:ClearLines()

  local name = (GetSpellInfo and GetSpellInfo(sid)) or self:SafeSpellName(sid)
  local link = (type(GetSpellLink) == 'function') and GetSpellLink(sid) or nil



  if type(link) ~= 'string' or link == '' or not link:find('|Hspell:') then
    link = string.format('|cff71d5ff|Hspell:%d|h[%s]|h|r', sid, tostring(name))
  end

  local ok = pcall(function() tt:SetHyperlink(link) end)
  if not ok then
    pcall(function() tt:SetHyperlink('spell:' .. tostring(sid)) end)
  end


  pcall(function() tt:Show() end)

  local lines = {}
  for i = 1, 30 do
    local fs = _G['EAK_ScanTooltipTextLeft' .. i]
    if not fs then break end
    local t = fs:GetText()
    if t and t ~= '' then
      t = self:Trim(self:StripWoWFormatting(t))
      if t ~= '' then
        table.insert(lines, t)
      end
    end
  end

  tt:Hide()

  if #lines == 0 then return nil, nil, nil end
  local tooltipText = table.concat(lines, "\n")
  local tooltipSearch = self:NormalizeSearchText(tooltipText)
  return lines, tooltipText, tooltipSearch
end




function U:EnsureSpellMeta(spellId, quality)
  local sid = tonumber(spellId)
  if not sid then return nil end
  local q = tonumber(quality) or 0


  self._ensuredSpellMeta = self._ensuredSpellMeta or {}
  local guardKey = tostring(sid)
  local guarded = self._ensuredSpellMeta[guardKey]

  local echoDB = (EAK and EAK.GetEchoDB) and EAK:GetEchoDB() or nil
  if not echoDB then return nil end

  local key = self:MakeKey(sid, q)
  if not key then return nil end

  local meta = echoDB[key] or {}
  meta.spellId = tonumber(meta.spellId) or sid
  meta.quality = tonumber(meta.quality) or q

  local needName = (not meta.name) or (meta.name == tostring(key)) or (meta.name == self:SafeSpellName(sid))
  local needIcon = (meta.icon == nil)

  if (needName or needIcon or not meta.tooltipText or not meta.tooltipSearch or meta.tooltipSearch == '') and not guarded then

    local stamp = self:NowStamp()
    local lines, text, search = self:CaptureSpellTooltip(sid)
    if lines and text and search then
      meta.tooltipLines = meta.tooltipLines or lines
      meta.tooltipText = meta.tooltipText or text
      meta.tooltipSearch = meta.tooltipSearch or search
      meta.tooltipCapturedAt = meta.tooltipCapturedAt or stamp
    end

    if GetSpellInfo then
      local name, _, icon = GetSpellInfo(sid)
      if name and name ~= '' then meta.name = name end
      if icon then meta.icon = meta.icon or icon end
    end
    self._ensuredSpellMeta[guardKey] = true
  else

    if GetSpellInfo and (needName or needIcon) then
      local name, _, icon = GetSpellInfo(sid)
      if needName and name and name ~= '' then meta.name = name end
      if needIcon and icon then meta.icon = icon end
    end
  end

  echoDB[key] = meta
  return meta
end

function U:NowStamp()
  local t = date("%Y-%m-%d %H:%M:%S")
  return t
end

function U:SafeSpellName(spellId)
  local name = GetSpellInfo(spellId)
  if name and name ~= "" then return name end
  return "Spell " .. tostring(spellId)
end

function U:MakeKey(spellId, quality)
  spellId = tonumber(spellId)
  quality = tonumber(quality) or 0
  if not spellId then return nil end
  return tostring(spellId) .. ":" .. tostring(quality)
end

function U:ParseKey(key)
  if type(key) == 'number' then return key, 0 end
  if type(key) ~= 'string' then return nil, nil end
  local sid, q = key:match('^(%d+):(%d+)$')
  sid = tonumber(sid)
  q = tonumber(q)
  return sid, q
end

function U:GetEchoMeta(key)
  if not EAK or not EAK.GetEchoDB then return nil end
  local echoDB = EAK:GetEchoDB()
  if type(echoDB) ~= 'table' then return nil end
  return echoDB[key]
end

function U:GetWeight(profile, key, spellId)
  if not profile or not profile.weights then return 0 end
  local w = profile.weights[key]
  if w ~= nil then return tonumber(w) or 0 end
  if spellId ~= nil then
    w = profile.weights[spellId]
    if w ~= nil then return tonumber(w) or 0 end
  end
  local sid = tonumber(spellId)
  if sid == nil then
    sid = self:ParseKey(key)
  end
  if sid and profile.weights[sid] ~= nil then
    return tonumber(profile.weights[sid]) or 0
  end
  return 0
end

function U:GetStackTarget(profile, spellId)
  if type(profile) ~= 'table' then return 0 end
  local st = profile.stackTargets
  if type(st) ~= 'table' then return 0 end
  local sid = tonumber(spellId) or spellId
  local t = tonumber(st[sid]) or 0
  if t < 0 then t = 0 end
  return math.floor(t + 0.5)
end

function U:IsBlacklisted(profile, key, spellId)
  if not profile or not profile.blacklist then return false end
  if profile.blacklist[key] then return true end
  if spellId and profile.blacklist[spellId] then return true end
  local sid = tonumber(spellId)
  if sid == nil then sid = self:ParseKey(key) end
  if sid and profile.blacklist[sid] then return true end
  return false
end

function U:RarityColor(quality)
  quality = tonumber(quality) or 0
  if quality <= 0 then return 1, 1, 1 end
  if quality == 1 then return 0.12, 1.00, 0.00 end
  if quality == 2 then return 0.00, 0.44, 0.87 end
  if quality == 3 then return 0.64, 0.21, 0.93 end
  return 1.00, 0.50, 0.00
end

function U:TableSize(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end



function U:ExportProfile(profile)
  if type(profile) ~= 'table' then return '' end
  local function b(v) return v and 1 or 0 end
  local parts = {}
  table.insert(parts, "EAK2")
  table.insert(parts, "min=" .. tostring(profile.minScoreToKeep or 0))
  table.insert(parts, "minlvl=" .. tostring(profile.minLevelRequirement or 12))
  table.insert(parts, "reroll=" .. tostring(b(profile.allowReroll ~= false)))
  table.insert(parts, "banish=" .. tostring(b(profile.allowBanish == true)))
  table.insert(parts, "dbfill=" .. tostring(b(profile.databaseFillingMode == true)))
  local cap = profile.maxRollUsageInRow
  if cap == nil then cap = profile.maxRerollsPerLevel end
  table.insert(parts, "maxu=" .. tostring(cap or 10))

  table.insert(parts, "delay=" .. tostring(0.15))
  table.insert(parts, "pto=" .. tostring(profile.pickConfirmTimeout or 8.0))
  table.insert(parts, "prefer=" .. tostring(b(profile.preferUnowned ~= false)))
  table.insert(parts, "pen=" .. tostring(profile.ownedPenalty or 0.35))

  table.insert(parts, "pmulti=" .. tostring(b(profile.pauseIfMultipleAbove == true)))
  table.insert(parts, "pmval=" .. tostring(profile.pauseMultipleAboveValue or 0))
  table.insert(parts, "pbl=" .. tostring(b(profile.pauseIfOnlyBlacklisted == true)))

  local q = {}
  for i=0,4 do
    local v = 0
    if profile.qualityBonus and profile.qualityBonus[i] ~= nil then v = profile.qualityBonus[i] end
    table.insert(q, i .. "," .. tostring(v))
  end
  table.insert(parts, "q=" .. table.concat(q, ";"))

  local qm = {}
  for i=0,4 do
    local v = 1
    if profile.qualityMultiplier and profile.qualityMultiplier[i] ~= nil then v = profile.qualityMultiplier[i] end
    table.insert(qm, i .. "," .. tostring(v))
  end
  table.insert(parts, "qm=" .. table.concat(qm, ";"))

  local w = {}
  for k, weight in pairs(profile.weights or {}) do
    if tonumber(weight) then
      if type(k) == 'string' and k:match('^%d+:%d+$') then

        table.insert(w, k .. ":" .. tostring(weight))
      elseif tonumber(k) then

        table.insert(w, tostring(k) .. ":" .. tostring(weight))
      end
    end
  end
  table.sort(w)
  table.insert(parts, "w=" .. table.concat(w, ";"))

  local bl = {}
  for k, v in pairs(profile.blacklist or {}) do
    if v then
      if type(k) == 'string' and k:match('^%d+:%d+$') then
        table.insert(bl, k)
      elseif tonumber(k) then
        table.insert(bl, tostring(k))
      end
    end
  end
  table.sort(bl)
  table.insert(parts, "bl=" .. table.concat(bl, ";"))

  local st = {}
  for sid, target in pairs(profile.stackTargets or {}) do
    local t = tonumber(target)
    if t and t >= 1 then
      table.insert(st, tostring(tonumber(sid) or sid) .. ":" .. tostring(math.floor(t + 0.5)))
    end
  end
  table.sort(st)
  table.insert(parts, "st=" .. table.concat(st, ";"))


  local settings = {}
  local ui = EbonholdAutomationKitDB.ui or {}
  table.insert(settings, "ui," .. tostring(ui.sortKey or "name") .. "," .. tostring(b(ui.sortAsc ~= false)) .. "," .. tostring(b(ui.showAllEchoes == true)) .. "," .. tostring(b(ui.showMinimap == true)) .. "," .. tostring(b(ui.showStartStopButton ~= false)))
  local uia = EbonholdAutomationKitDB.uiAutoHistory or {}
  table.insert(settings, "uia," .. tostring(uia.sortKey or "level") .. "," .. tostring(b(uia.sortAsc == true)) .. "," .. self:Encode(tostring(uia.filter or "all")) .. "," .. self:Encode(tostring(uia.search or "")))
  local uil = EbonholdAutomationKitDB.uiLogbook or {}
  table.insert(settings, "uil," .. tostring(uil.sortKey or "count") .. "," .. tostring(b(uil.sortAsc == true)) .. "," .. self:Encode(tostring(uil.search or "")))

  local uip = EbonholdAutomationKitDB.uiProfiles or {}
  table.insert(settings, "uip," .. tostring(b(uip.backupBeforeImport == true)))
  table.insert(parts, "set=" .. self:Encode(table.concat(settings, ";")))


  local dbParts = {}
  local echoDB = (EAK and EAK.GetEchoDB and EAK:GetEchoDB()) or {}
  for key, meta in pairs(echoDB) do
    if type(key) == 'string' and key:match('^%d+:%d+$') then
      local sid = tonumber(meta and meta.spellId) or (select(1, self:ParseKey(key)))
      if sid then
        local name = (meta and meta.name) or self:SafeSpellName(sid)
        local classes = ""
        if meta and type(meta.classes) == "table" then
          local tmp = {}
          for cls, ok in pairs(meta.classes) do
            if ok then table.insert(tmp, tostring(cls)) end
          end
          table.sort(tmp)
          classes = table.concat(tmp, ".")
        end
        table.insert(dbParts, key .. "," .. self:Encode(name) .. "," .. classes)
      end
    end
  end
  table.sort(dbParts)
  table.insert(parts, "db=" .. table.concat(dbParts, ";"))

  return table.concat(parts, "|")
end

function U:ImportProfile(str)
  if type(str) ~= 'string' then return nil, nil, nil, "Invalid input" end
  str = self:Trim(str)
  if str == "" then return nil, nil, nil, "Empty input" end
  local tag = str:match("^(EAK%d+)%|")
  if (tag ~= "EAK1" and tag ~= "EAK2") and str:sub(1,3) ~= "EAK" then
    return nil, nil, nil, "Not an EAK profile string"
  end

  local p = {}
  p.weights = {}
  p.blacklist = {}
  p.qualityBonus = { [0]=0,[1]=5,[2]=12,[3]=25,[4]=45 }
  p.qualityMultiplier = { [0]=1.00,[1]=1.05,[2]=1.12,[3]=1.20,[4]=1.35 }


  local importedEchoDB = nil


  local importedSettings = nil

  for token in string.gmatch(str, "([^|]+)") do
    local k, v = token:match("^([^=]+)=(.*)$")
    if k and v then
      if k == "min" then p.minScoreToKeep = tonumber(v) or 0
      elseif k == "minlvl" then p.minLevelRequirement = tonumber(v) or 12
      elseif k == "reroll" then p.allowReroll = (tonumber(v) or 1) ~= 0
      elseif k == "banish" then p.allowBanish = (tonumber(v) or 0) ~= 0
      elseif k == "dbfill" then p.databaseFillingMode = (tonumber(v) or 0) ~= 0
      elseif k == "maxu" then p.maxRollUsageInRow = tonumber(v) or 10
      elseif k == "maxr" then p.maxRollUsageInRow = tonumber(v) or 10
      elseif k == "delay" then p.autoSelectDelay = tonumber(v) or 0.10
      elseif k == "pto" then p.pickConfirmTimeout = tonumber(v) or 8.0
      elseif k == "prefer" then p.preferUnowned = (tonumber(v) or 1) ~= 0
      elseif k == "pen" then p.ownedPenalty = tonumber(v) or 0.35
      elseif k == "pmulti" then p.pauseIfMultipleAbove = (tonumber(v) or 0) ~= 0
      elseif k == "pmval" then p.pauseMultipleAboveValue = tonumber(v) or 0
      elseif k == "pbl" then p.pauseIfOnlyBlacklisted = (tonumber(v) or 0) ~= 0
      elseif k == "q" then
        for pair in string.gmatch(v, "([^;]+)") do
          local qi, qv = pair:match("^(%d+),(.+)$")
          qi = tonumber(qi)
          qv = tonumber(qv)
          if qi ~= nil and qv ~= nil then p.qualityBonus[qi] = qv end
        end
      elseif k == "qm" then
        for pair in string.gmatch(v, "([^;]+)") do
          local qi, qv = pair:match("^(%d+),(.+)$")
          qi = tonumber(qi)
          qv = tonumber(qv)
          if qi ~= nil and qv ~= nil then p.qualityMultiplier[qi] = qv end
        end
      elseif k == "w" then
        for pair in string.gmatch(v, "([^;]+)") do

          local sid, q, wt = pair:match('^(%d+):(%d+):(.+)$')
          if sid and q and wt then
            local key = self:MakeKey(sid, q)
            wt = tonumber(wt)
            if key and wt then p.weights[key] = wt end
          else
            local lsid, lwt = pair:match('^(%d+):(.+)$')
            lsid = tonumber(lsid)
            lwt = tonumber(lwt)
            if lsid and lwt then p.weights[lsid] = lwt end
          end
        end
      elseif k == "bl" then
        for sid in string.gmatch(v, "([^;]+)") do

          if sid:match('^%d+:%d+$') then
            p.blacklist[sid] = true
          else
            local n = tonumber(sid)
            if n then p.blacklist[n] = true end
          end
        end
      elseif k == "st" then
        p.stackTargets = p.stackTargets or {}
        for pair in string.gmatch(v, "([^;]+)") do
          local sid, tgt = pair:match('^(%d+):(%d+)$')
          sid = tonumber(sid)
          tgt = tonumber(tgt)
          if sid and tgt then
            p.stackTargets[sid] = math.floor(tgt + 0.5)
          end
        end
      elseif k == "db" then
        importedEchoDB = importedEchoDB or {}
        for pair in string.gmatch(v, "([^;]+)") do

          local key, encName, classStr = pair:match("^([^,]+),([^,]*),(.*)$")
          if not key then
            key, encName = pair:match("^([^,]+),(.+)$")
            classStr = ""
          end
          if not key then
            key = pair
            encName = ""
            classStr = ""
          end
          if key and key:match('^%d+:%d+$') then
            local sid, q = self:ParseKey(key)
            sid = tonumber(sid)
            q = tonumber(q) or 0
            if sid then
              local name = (encName and encName ~= "") and self:Decode(encName) or self:SafeSpellName(sid)
              local _, _, icon = GetSpellInfo(sid)
              local classes = {}
              if classStr and classStr ~= "" then
                for cls in string.gmatch(classStr, "([^%.]+)") do
                  if cls and cls ~= "" then classes[cls] = true end
                end
              end
              importedEchoDB[key] = {
                spellId = sid,
                quality = q,
                name = name,
                icon = icon,
                lastSeen = self:NowStamp(),
                classes = classes,
              }
            end
          end
        end
      elseif k == "set" then
        local decoded = self:Decode(v or "")
        importedSettings = importedSettings or {}
        for part in string.gmatch(decoded, "([^;]+)") do
          local fields = {}
          for f in string.gmatch((part or "") .. ",", "([^,]*),") do
            table.insert(fields, f)
            if #fields > 20 then break end
          end
          local kind = fields[1]
          if kind == "ui" then
            importedSettings.ui = importedSettings.ui or {}
            importedSettings.ui.sortKey = (fields[2] and fields[2] ~= "" and fields[2]) or "name"
            importedSettings.ui.sortAsc = (tonumber(fields[3]) or 1) ~= 0
            importedSettings.ui.showAllEchoes = (tonumber(fields[4]) or 0) ~= 0
            importedSettings.ui.showMinimap = (tonumber(fields[5]) or 0) ~= 0
            importedSettings.ui.showStartStopButton = (tonumber(fields[6]) or 1) ~= 0
          elseif kind == "uia" then
            importedSettings.uiAutoHistory = importedSettings.uiAutoHistory or {}
            importedSettings.uiAutoHistory.sortKey = (fields[2] and fields[2] ~= "" and fields[2]) or "level"
            importedSettings.uiAutoHistory.sortAsc = (tonumber(fields[3]) or 0) ~= 0
            importedSettings.uiAutoHistory.filter = (fields[4] and fields[4] ~= "") and self:Decode(fields[4]) or "all"
            importedSettings.uiAutoHistory.search = (fields[5] and fields[5] ~= "") and self:Decode(fields[5]) or ""
          elseif kind == "uil" then
            importedSettings.uiLogbook = importedSettings.uiLogbook or {}
            importedSettings.uiLogbook.sortKey = (fields[2] and fields[2] ~= "" and fields[2]) or "count"
            importedSettings.uiLogbook.sortAsc = (tonumber(fields[3]) or 0) ~= 0
            importedSettings.uiLogbook.search = (fields[4] and fields[4] ~= "") and self:Decode(fields[4]) or ""
          elseif kind == "uip" then
            importedSettings.uiProfiles = importedSettings.uiProfiles or {}
            importedSettings.uiProfiles.backupBeforeImport = (tonumber(fields[2]) or 0) ~= 0
          end
        end
      end
    end
  end


  return p, importedEchoDB, importedSettings, nil
end

function U:PushHistory(entry)
  if not entry then return end
  local db = EbonholdAutomationKitDB
  db.history = db.history or { maxEntries = 200, entries = {} }
  db.history.entries = db.history.entries or {}
  table.insert(db.history.entries, 1, entry)
  local maxN = db.history.maxEntries or 200
  while #db.history.entries > maxN do
    table.remove(db.history.entries)
  end
end





function U:GetAutomationHistory()
  local db = EbonholdAutomationKitDB
  db.historyAutomation = db.historyAutomation or { maxEntries = 200, entries = {}, errors = {}, byLevel = {}, nextLevel = 2, scheme = 2, pending = {} }
  local h = db.historyAutomation
  h.entries = h.entries or {}
  h.errors = h.errors or {}
  h.byLevel = h.byLevel or {}



  if type(h.pending) ~= 'table' then h.pending = {} end



  if h.scheme ~= 2 then
    local newEntries = {}
    for _, e in ipairs(h.entries) do
      if e then
        table.insert(newEntries, e)
      end
    end
    for i, e in ipairs(newEntries) do
      local lvl = i + 1
      if lvl < 2 then lvl = 2 end
      if lvl > 80 then lvl = 80 end
      e.level = lvl
    end
    h.entries = newEntries
    h.scheme = 2
  end


  local cleaned = {}
  for _, e in ipairs(h.entries) do
    if e and e.finalPick and e.finalPick.spellId then
      table.insert(cleaned, e)
    end
  end
  h.entries = cleaned


  for i, e in ipairs(h.entries) do
    local lvl = i + 1
    if lvl < 2 then lvl = 2 end
    if lvl > 80 then lvl = 80 end
    e.level = lvl
  end


  local nl = (#h.entries) + 2
  if nl < 2 then nl = 2 end
  if nl > 80 then nl = 80 end
  h.nextLevel = nl


  h.byLevel = {}
  for i, e in ipairs(h.entries) do
    if e and e.level then
      h.byLevel[tonumber(e.level) or 0] = i
    end
  end

  return h
end

function U:AutomationHistoryPeekNextLevel()
  local h = self:GetAutomationHistory()
  local nl = tonumber(h.nextLevel) or 2
  if nl < 2 then nl = 2 end
  if nl > 80 then nl = 80 end
  h.nextLevel = nl
  return nl
end


function U:ClearAutomationHistory()
  local h = self:GetAutomationHistory()
  h.entries = {}
  h.errors = {}
  h.byLevel = {}
  h.nextLevel = 2
  h.scheme = 2
  h.pending = {}
end

function U:AutomationHistoryAddError(level, info)
  level = tonumber(level) or 0
  if level < 2 then level = 2 end
  if level > 80 then level = 80 end

  local h = self:GetAutomationHistory()
  h.errors = h.errors or {}
  info = type(info) == 'table' and info or {}

  local e = {
    kind = 'error',
    ts = self:NowStamp(),
    t = (type(GetTime) == 'function') and GetTime() or nil,
    level = level,
    txnId = info.txnId,
    offerHash = info.offerHash,
    offerSeq = info.offerSeq,
    spellId = info.spellId,
    reason = info.reason,
    offered = info.offered or {},
    steps = info.steps or {},
    retries = info.retries,
    resendCount = info.resendCount,
  }

  table.insert(h.errors, 1, e)

  local maxN = tonumber(h.maxEntries) or 200
  if maxN < 50 then maxN = 50 end
  while #h.errors > maxN do
    table.remove(h.errors)
  end
end


function U:AutomationHistoryAddAttempt(level, offered, decision)
  level = tonumber(level) or 0
  if level < 2 then return end
  if level > 80 then level = 80 end

  local h = self:GetAutomationHistory()
  h.pending = h.pending or {}
  local entry = h.pending[level]
  if not entry then
    entry = {
      level = level,
      tsFirst = self:NowStamp(),
      tsFinal = nil,
      attempts = {},
      finalPick = nil,
    }
    h.pending[level] = entry
  end

  entry.attempts = entry.attempts or {}
  local attempt = {
    ts = self:NowStamp(),
    t = (type(GetTime) == 'function') and GetTime() or nil,
    offered = offered or {},
    decision = decision or {},
  }
  table.insert(entry.attempts, attempt)


  if decision and decision.action == "select" and decision.spellId then

    if entry._committed then return end
    entry._committed = true

    entry.finalPick = {
      spellId = decision.spellId,
      key = decision.key,
      quality = decision.quality,
      score = decision.bestScore,
      why = decision.bestWhy,
      rerollsUsed = decision.rerollsUsed,
      rerollsTotal = decision.rerollsTotal,
      rerollsRemaining = decision.rerollsRemaining,
    }
    entry.tsFinal = attempt.ts


    table.insert(h.entries, entry)
    h.pending[level] = nil


    local maxN = tonumber(h.maxEntries) or 200
    if maxN < 50 then maxN = 50 end
    while #h.entries > maxN do
      table.remove(h.entries, 1)
    end


    h.byLevel = {}
    for i, e in ipairs(h.entries) do
      local lv = i + 1
      if lv < 2 then lv = 2 end
      if lv > 80 then lv = 80 end
      e.level = lv
      h.byLevel[lv] = i
      e._committed = nil
    end


    local nl = (#h.entries) + 2
    if nl < 2 then nl = 2 end
    if nl > 80 then nl = 80 end
    h.nextLevel = nl
  end
end

function U:GetLogbook()
  EbonholdAutomationKitGlobal = EbonholdAutomationKitGlobal or {}
  local g = EbonholdAutomationKitGlobal
  g.logbook = g.logbook or { totalSeen = 0, counts = {}, lastSeen = {}, raritySeen = nil }
  g.logbook.counts = g.logbook.counts or {}
  g.logbook.lastSeen = g.logbook.lastSeen or {}
  g.logbook.totalSeen = tonumber(g.logbook.totalSeen) or 0


  if type(g.logbook.raritySeen) ~= 'table' then
    g.logbook.raritySeen = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0 }
    local total = 0
    for key, n in pairs(g.logbook.counts) do
      local _, q = self:ParseKey(key)
      q = tonumber(q) or 0
      local nn = tonumber(n) or 0
      g.logbook.raritySeen[q] = (tonumber(g.logbook.raritySeen[q]) or 0) + nn
      total = total + nn
    end
    g.logbook.totalSeen = total
  else

    for q = 0, 4 do
      g.logbook.raritySeen[q] = tonumber(g.logbook.raritySeen[q]) or 0
    end
  end

  return g.logbook
end

function U:ResetLogbook()
  local lb = self:GetLogbook()
  lb.totalSeen = 0
  lb.counts = {}
  lb.lastSeen = {}
  lb.raritySeen = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0 }
end


function U:LogbookRecordChoices(choices, pickLevel)
  if type(choices) ~= 'table' then return end
  local lb = self:GetLogbook()
  lb.raritySeen = lb.raritySeen or { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0 }

  local echoDB = (EAK and EAK.GetEchoDB) and EAK:GetEchoDB() or nil
  pickLevel = tonumber(pickLevel)

  local stamp = self:NowStamp()

  local seen = 0
  local dedupe = {}
  for _, c in ipairs(choices) do
    if c and c.spellId then
      local sid = tonumber(c.spellId)
      if sid then
        local q = tonumber(c.quality) or 0
        local token = tostring(sid) .. ":" .. tostring(q)
        if not dedupe[token] then
          dedupe[token] = true
          local key = self:MakeKey(sid, q)
          if key then
            lb.counts[key] = (tonumber(lb.counts[key]) or 0) + 1
            lb.totalSeen = (tonumber(lb.totalSeen) or 0) + 1
            lb.raritySeen[q] = (tonumber(lb.raritySeen[q]) or 0) + 1
            lb.lastSeen[key] = stamp


            if echoDB then
              local meta = echoDB[key] or {}
              meta.spellId = tonumber(meta.spellId) or sid
              meta.quality = tonumber(meta.quality) or q
              meta.name = meta.name or (GetSpellInfo(sid) or self:SafeSpellName(sid))
              local _, _, icon = GetSpellInfo(sid)
              meta.icon = meta.icon or icon

              meta.seenCount = tonumber(lb.counts[key]) or 0
              meta.lastSeen = stamp
              meta.lastSeenAt = stamp
              if not meta.firstSeenAt then meta.firstSeenAt = stamp end

              if pickLevel then
                meta.lastSeenPickLevel = pickLevel
                if not meta.firstSeenPickLevel then meta.firstSeenPickLevel = pickLevel end
              end


              if not meta.tooltipText or not meta.tooltipSearch or meta.tooltipSearch == '' then
                local lines, text, search = self:CaptureSpellTooltip(sid)
                if lines and text and search then
                  meta.tooltipLines = lines
                  meta.tooltipText = text
                  meta.tooltipSearch = search
                  meta.tooltipCapturedAt = stamp
                end
              end

              echoDB[key] = meta
            end
          end
          seen = seen + 1
          if seen >= 3 then break end
        end
      end
    end
  end
end




local _afterFrame
local _afterQueue = {}
function U:After(delay, fn)
  if type(fn) ~= 'function' then return end
  delay = tonumber(delay) or 0
  if delay < 0 then delay = 0 end

  if not _afterFrame then
    _afterFrame = CreateFrame('Frame')
    _afterFrame:SetScript('OnUpdate', function(_, elapsed)
      if #_afterQueue == 0 then return end
      for i = #_afterQueue, 1, -1 do
        local item = _afterQueue[i]
        item.t = item.t - elapsed
        if item.t <= 0 then
          table.remove(_afterQueue, i)
          pcall(item.fn)
        end
      end
    end)
  end

  table.insert(_afterQueue, { t = delay, fn = fn })
end

U._eakEditGroups = U._eakEditGroups or {}

local function _EAK_FindPanelRoot(f)
  local p = f
  while p and p ~= UIParent do
    if rawget(p, "name") ~= nil then return p end
    p = p.GetParent and p:GetParent() or nil
  end
  return (f and f.GetParent and f:GetParent()) or UIParent
end

function U:_EAK_RegisterEditBox(eb, group)
  group = group or _EAK_FindPanelRoot(eb)
  local t = self._eakEditGroups[group]
  if not t then
    t = {}
    self._eakEditGroups[group] = t
  end
  for i = 1, #t do
    if t[i] == eb then
      eb._eakGroupKey = group
      return
    end
  end
  table.insert(t, eb)
  eb._eakGroupKey = group
end

function U:_EAK_IsFocusableEditBox(eb)
  if not eb then return false end
  if eb.IsShown and not eb:IsShown() then return false end
  if eb.IsVisible and not eb:IsVisible() then return false end
  if eb.IsEnabled and not eb:IsEnabled() then return false end
  return true
end

function U:_EAK_FindNextEditBox(group, cur, dir)
  local t = self._eakEditGroups[group]
  if not t or #t == 0 then return nil end
  local n = #t
  local idx = 1
  for i = 1, n do
    if t[i] == cur then idx = i break end
  end
  for step = 1, n do
    local j = idx + (dir * step)
    while j < 1 do j = j + n end
    while j > n do j = j - n end
    local eb = t[j]
    if self:_EAK_IsFocusableEditBox(eb) then return eb end
  end
  return nil
end

function U:_EAK_TabMove(cur, dir)
  local group = cur and cur._eakGroupKey
  if not group then group = _EAK_FindPanelRoot(cur) end
  local nextBox = self:_EAK_FindNextEditBox(group, cur, dir)
  if nextBox and nextBox.SetFocus then
    nextBox:SetFocus()
    if nextBox.HighlightText then nextBox:HighlightText() end
  end
end

function U:EnhanceEditBox(eb, opts)
  if not eb or eb._eakEnhanced then return end
  opts = opts or {}
  local isMulti = (opts.multiline == true) or (eb.GetMultiLine and eb:GetMultiLine())
  local enableTab = (opts.enableTab ~= false) and (not isMulti)
  self:_EAK_RegisterEditBox(eb, opts.group)
  eb._eakEnhanced = true
  if eb.EnableKeyboard then eb:EnableKeyboard(true) end
  if eb.SetAutoFocus then eb:SetAutoFocus(false) end
  if eb.HookScript then
    eb:HookScript("OnMouseDown", function(self)
      self._eakClicked = true
      if self.SetFocus then self:SetFocus() end
    end)
    eb:HookScript("OnMouseUp", function(self)
      if self._eakClicked then
        self._eakClicked = nil
        U:After(0, function()
          if self and self.HighlightText then self:HighlightText() end
        end)
      end
    end)
    eb:HookScript("OnEditFocusGained", function(self)
      if self.HighlightText then self:HighlightText() end
    end)
    eb:HookScript("OnEditFocusLost", function(self)
      if self.HighlightText then self:HighlightText(0, 0) end
    end)
    eb:HookScript("OnHide", function(self)
      if self.ClearFocus then self:ClearFocus() end
    end)
  end
  if enableTab and not eb:GetScript("OnTabPressed") then
    eb:SetScript("OnTabPressed", function(self)
      local dir = 1
      if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then dir = -1 end
      if self.HighlightText then self:HighlightText(0, 0) end
      U:_EAK_TabMove(self, dir)
    end)
  end

end

function U:BuildSpellLink(spellId, quality)
  local sid = tonumber(spellId)
  if not sid then return nil end
  local link = (type(GetSpellLink) == 'function') and GetSpellLink(sid) or nil
  if type(link) == 'string' and link ~= '' and link:find('|Hspell:') then
    return link
  end
  local name = (GetSpellInfo and GetSpellInfo(sid)) or nil
  if not name or name == '' then return nil end
  name = tostring(name):gsub("|", ""):gsub("[%c]", "")
  return "|cff71d5ff|Hspell:" .. tostring(sid) .. "|h[" .. name .. "]|h|r"
end

function U:TryInsertSpellLink(spellId, quality, force)
  local okClick = (force == true)
  if not okClick then
    if type(IsModifiedClick) == 'function' then
      okClick = IsModifiedClick("CHATLINK")
    end
    if not okClick and type(IsShiftKeyDown) == 'function' then
      okClick = IsShiftKeyDown()
    end
  end
  if not okClick then return false end

  local link = self:BuildSpellLink(spellId, quality)
  if not link then
    local sid = tonumber(spellId)
    if not sid then return false end
    local t = self:SafeSpellName(sid)
    t = tostring(t or ("Spell " .. tostring(sid))):gsub("|", ""):gsub("[%c]", "")
    t = t .. " (" .. tostring(sid) .. ")"
    local eb = nil
    if type(ChatEdit_GetActiveWindow) == "function" then
      local ok, r = pcall(ChatEdit_GetActiveWindow)
      if ok and r then eb = r end
    end
    if not eb and type(ChatEdit_ChooseBoxForSend) == "function" then
      local chatFrame = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1 or _G.ChatFrame2
      local ok, r = pcall(ChatEdit_ChooseBoxForSend, chatFrame)
      if ok and r then eb = r end
    end
    if eb and type(ChatEdit_ActivateChat) == "function" then
      pcall(ChatEdit_ActivateChat, eb)
    end
    if not eb then
      eb = _G.ChatFrame1EditBox or _G.ChatFrameEditBox or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame2EditBox
    end
    if eb then
      if eb.Show then pcall(eb.Show, eb) end
      if eb.SetFocus then pcall(eb.SetFocus, eb) end
      if eb.Insert then
        local ok = pcall(eb.Insert, eb, t)
        if ok then return true end
      end
      if eb.InsertText then
        local ok = pcall(eb.InsertText, eb, t)
        if ok then return true end
      end
    end
    return false
  end

  if type(ChatEdit_InsertLink) == 'function' then
    local ok, inserted = pcall(ChatEdit_InsertLink, link)
    if ok and inserted then return true end
  end

  local eb = nil
  if type(ChatEdit_GetActiveWindow) == "function" then
    local ok, r = pcall(ChatEdit_GetActiveWindow)
    if ok and r then eb = r end
  end

  if not eb and type(ChatEdit_ChooseBoxForSend) == "function" then
    local chatFrame = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1 or _G.ChatFrame2
    local ok, r = pcall(ChatEdit_ChooseBoxForSend, chatFrame)
    if ok and r then eb = r end
  end

  if eb and type(ChatEdit_ActivateChat) == "function" then
    pcall(ChatEdit_ActivateChat, eb)
  end

  if not eb then
    eb = _G.ChatFrame1EditBox or _G.ChatFrameEditBox or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame2EditBox
  end

  if eb then
    if eb.Show then pcall(eb.Show, eb) end
    if eb.SetFocus then pcall(eb.SetFocus, eb) end
    local add = link
    if type(eb.GetText) == "function" then
      local cur = eb:GetText() or ""
      if cur ~= "" and not cur:match("%s$") then add = " " .. link end
    end
    if eb.Insert then
      local ok = pcall(eb.Insert, eb, add)
      if ok then return true end
    end
    if eb.InsertText then
      local ok = pcall(eb.InsertText, eb, add)
      if ok then return true end
    end
  end

  return false
end



EAK.Nav = EAK.Nav or {}
local N = EAK.Nav
N.frame = N.frame
N.activeBox = nil
N.moveFunc = nil
N.owner = N.owner
N.nopBtn = N.nopBtn
N.bindUsers = N.bindUsers or 0
N.keys = { UP = false, DOWN = false, TAB = false }
N.nextRepeat = { UP = 0, DOWN = 0, TAB = 0 }
N.initialDelay = 0.25
N.repeatDelay = 0.06
N._deactTimer = nil

function N:Init()
  if self.frame then return end
  self.frame = CreateFrame("Frame", "EAKNavFrame", UIParent)
  self.frame:Hide()
  self.frame:SetScript("OnUpdate", function(_, elapsed) N:OnUpdate(elapsed) end)
end

function N:EnsureBindings()
  if self.owner then return end
  self.owner = CreateFrame("Frame", "EAKNavOwnerFrame", UIParent)
  self.owner:Hide()
  self.nopBtn = CreateFrame("Button", "EAKNavNopButton", UIParent, "SecureActionButtonTemplate")
  self.nopBtn:Hide()
  self.nopBtn:SetScript("OnClick", function() end)
end

function N:BindKeys()
  self:EnsureBindings()
  local o = self.owner
  o:Show()
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(o) end
  if type(SetOverrideBinding) == "function" then
    local b = self.nopBtn:GetName()
    SetOverrideBinding(o, true, "UP", "CLICK "..b..":LeftButton")
    SetOverrideBinding(o, true, "DOWN", "CLICK "..b..":LeftButton")
    SetOverrideBinding(o, true, "UPARROW", "CLICK "..b..":LeftButton")
    SetOverrideBinding(o, true, "DOWNARROW", "CLICK "..b..":LeftButton")
    SetOverrideBinding(o, true, "TAB", "CLICK "..b..":LeftButton")
  elseif type(SetOverrideBindingClick) == "function" then
    local b = self.nopBtn:GetName()
    SetOverrideBindingClick(o, true, "UP", b)
    SetOverrideBindingClick(o, true, "DOWN", b)
    SetOverrideBindingClick(o, true, "UPARROW", b)
    SetOverrideBindingClick(o, true, "DOWNARROW", b)
    SetOverrideBindingClick(o, true, "TAB", b)
  end
end

function N:UnbindKeys()
  if not self.owner then return end
  if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(self.owner) end
  self.owner:Hide()
end

function N:Acquire()
  self.bindUsers = (self.bindUsers or 0) + 1
  if self.bindUsers == 1 then self:BindKeys() end
end

function N:Release()
  local n = (self.bindUsers or 0) - 1
  if n < 0 then n = 0 end
  self.bindUsers = n
  if n == 0 then self:UnbindKeys() end
end

function N:Activate(box, moveFunc)
  self:Init()
  self:Acquire()
  self.activeBox = box
  self.moveFunc = moveFunc
  self.frame:Show()
end

function N:ScheduleDeactivate()
  self:Init()
  self._deactTimer = 0
  self.frame:Show()
end

function N:DeactivateIfNotNavFocus()
  local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if f and f._eakNavEnabled and f._eakNavMove then
    self.activeBox = f
    self.moveFunc = f._eakNavMove
    return
  end
  self.activeBox = nil
  self.moveFunc = nil
  self:Release()
  self.keys.UP = false
  self.keys.DOWN = false
  self.keys.TAB = false
  self.nextRepeat.UP = 0
  self.nextRepeat.DOWN = 0
  self.nextRepeat.TAB = 0
  if self.frame then self.frame:Hide() end
end

function N:Move(dir, kind)
  local b = self.activeBox
  local mv = self.moveFunc
  if not b or not mv then return end
  mv(b, dir, kind)
  local nf = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if nf and nf._eakNavEnabled and nf._eakNavMove then
    self.activeBox = nf
    self.moveFunc = nf._eakNavMove
  end
end

function N:OnUpdate(elapsed)
  if self._deactTimer ~= nil then
    self._deactTimer = self._deactTimer + elapsed
    if self._deactTimer >= 0 then
      self._deactTimer = nil
      self:DeactivateIfNotNavFocus()
    end
  end
  if not self.activeBox then return end
  local t = (GetTime and GetTime()) or 0

  local function handle(key, down, dirFunc)
    local was = self.keys[key]
    if down and not was then
      self.keys[key] = true
      self.nextRepeat[key] = t + self.initialDelay
      self:Move(dirFunc(), key)
      return
    end
    if (not down) and was then
      self.keys[key] = false
      self.nextRepeat[key] = 0
      return
    end
    if down and was then
      local nr = self.nextRepeat[key]
      if nr and nr > 0 and t >= nr then
        self.nextRepeat[key] = t + self.repeatDelay
        self:Move(dirFunc(), key)
      end
    end
  end

  local upDown = IsKeyDown and (IsKeyDown("UP") or IsKeyDown("UPARROW"))
  local downDown = IsKeyDown and (IsKeyDown("DOWN") or IsKeyDown("DOWNARROW"))
  local tabDown = IsKeyDown and IsKeyDown("TAB")
  handle("UP", upDown, function() return -1 end)
  handle("DOWN", downDown, function() return 1 end)
  handle("TAB", tabDown, function() return (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1 end)
end

