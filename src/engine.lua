local EAK = _G.EbonholdAutomationKit
local U = EAK.Utils

EAK.Engine = EAK.Engine or {}
local Engine = EAK.Engine

Engine.state = {
  hooked = false,
  hookedService = false,
  rerollsUsedThisPick = 0,
  currentLevel = nil,
}

local NormalizeChoices







local function LRU_Ensure(slot, cap)
  if type(slot) ~= 'table' then slot = {} end
  slot.cap = tonumber(slot.cap or cap or 40) or 40
  slot.order = slot.order or {}
  slot.set = slot.set or {}
  return slot
end

local function LRU_Has(slot, key)
  if not slot or not key then return false end
  return slot.set and slot.set[key] == true
end

local function LRU_Add(slot, key)
  if not slot or not key then return end
  if slot.set[key] then return end
  table.insert(slot.order, 1, key)
  slot.set[key] = true
  local cap = tonumber(slot.cap) or 40
  while #slot.order > cap do
    local old = table.remove(slot.order)
    if old then slot.set[old] = nil end
  end
end

local function Chat(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and msg then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  end
end


local function _EAK_ErrKey(tag, err)
  return tostring(tag or "EAK") .. "|" .. tostring(err or "err")
end

function Engine:_OnFatalError(tag, err)
  self.state = self.state or {}
  if self.state._fatalError then return end
  self.state._fatalError = true
  local msg = "|cffff3333EAK error|r in " .. tostring(tag or "unknown") .. ": " .. tostring(err or "unknown")
  Chat(msg)
  if EAK and EAK.runtime then
    EAK.runtime.enabledThisSession = false
    EAK.runtime.pendingPick = nil
    EAK.runtime.pendingSelect = nil
    EAK.runtime.pendingBanish = nil
    EAK.runtime.lastChoiceHash = nil
  end
  if EAK and EAK.RevealServerUI then
    pcall(function() EAK:RevealServerUI() end)
  end
end

local function _EAK_xpcall(tag, fn)
  return xpcall(fn, function(e)
    local ds = ""
    if type(debugstack) == "function" then
      ds = "\n" .. debugstack(2, 10, 10)
    end
    return tostring(e) .. ds
  end)
end

local function GetRerollsRemaining(profile)

  if ProjectEbonhold and ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData then
    local runData = ProjectEbonhold.PlayerRunService.GetCurrentData() or {}
    local used = tonumber(runData.usedRerolls or 0) or 0
    local total = tonumber(runData.totalRerolls or 0) or 0
    if total > 0 then
      return math.max(0, total - used), total, used
    end
  end


  local total = profile.maxRollUsageInRow
  if total == nil then total = profile.maxRerollsPerLevel end
  total = tonumber(total or 10) or 10
  local used = Engine.state.rerollsUsedThisPick or 0
  return math.max(0, total - used), total, used
end

local function IsBanishSystemEnabled()
  return (ProjectEbonhold and ProjectEbonhold.Constants and ProjectEbonhold.Constants.ENABLE_BANISH_SYSTEM) and true or false
end

local function GetBanishesRemaining()
  if not IsBanishSystemEnabled() then return 0 end

  local rem = 0
  if ProjectEbonhold and ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData then
    local runData = ProjectEbonhold.PlayerRunService.GetCurrentData() or {}
    rem = tonumber(runData.remainingBanishes or 0) or 0
  end

  if rem <= 0 then
    local g = _G and _G["EbonholdPlayerRunData"]
    if type(g) == "table" then
      local gr = tonumber(g.remainingBanishes or 0) or 0
      if gr > 0 then rem = gr end
    end
  end

  return rem
end



local function GetServerUsedRerolls()
  if ProjectEbonhold and ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData then
    local ok, runData = pcall(ProjectEbonhold.PlayerRunService.GetCurrentData)
    if ok and type(runData) == 'table' then
      return tonumber(runData.usedRerolls or 0) or 0
    end
  end
  return nil
end


local function CountOwnedStacks(spellId)



  local grantedN, grantedMax = 0, nil
  if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks then
    local ok, granted = pcall(ProjectEbonhold.PerkService.GetGrantedPerks)
    if ok and type(granted) == 'table' then
      local name = GetSpellInfo(spellId)
      if name then
        local list = granted[name]
        if type(list) == 'table' then
          grantedN = #list
          if grantedN > 0 then grantedMax = list[1].maxStack end
        end
      end
    end
  end

  local lockedN, lockedMax = 0, nil
  if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetLockedPerks then
    local ok, locked = pcall(ProjectEbonhold.PerkService.GetLockedPerks)
    if ok and type(locked) == 'table' then
      for _, ent in ipairs(locked) do
        if ent and tonumber(ent.spellId or 0) == tonumber(spellId or 0) then
          lockedN = lockedN + (tonumber(ent.stack or 0) or 0)
          local ms = tonumber(ent.maxStack)
          if ms then lockedMax = lockedMax and math.max(lockedMax, ms) or ms end
        end
      end
    end
  end

  local maxStack = grantedMax
  if lockedMax then maxStack = maxStack and math.max(maxStack, lockedMax) or lockedMax end
  return (grantedN + lockedN), maxStack
end

local function ScoreChoice(profile, choice)
  local spellId = choice.spellId
  local quality = choice.quality or 0
  local key = U:MakeKey(spellId, quality)


  local ownedStacks, maxStack = CountOwnedStacks(spellId)

  if U:IsBlacklisted(profile, key, spellId) then
    return -1e9, "Blacklisted", ownedStacks, maxStack
  end

  local base = U:GetWeight(profile, key, spellId)

  local bonus = 0
  if profile.qualityBonus then
    bonus = tonumber(profile.qualityBonus[quality] or 0) or 0
  end
  local mult = 1
  if profile.qualityMultiplier then
    mult = tonumber(profile.qualityMultiplier[quality] or 1) or 1
  end

  local ownedFactor = 1
  local ownedReason = ""
  if profile.preferUnowned ~= false and ownedStacks and ownedStacks > 0 then
    local pen = tonumber(profile.ownedPenalty or 0.35) or 0.35
    pen = U:Clamp(pen, 0, 1)
    ownedFactor = (1 - pen) ^ ownedStacks
    ownedReason = string.format("Owned x%d", ownedStacks)
  end

  local score = (base + bonus) * mult * ownedFactor

  local parts = {}
  table.insert(parts, string.format("base=%s", tostring(base)))
  if bonus ~= 0 then table.insert(parts, string.format("qBonus=%s", tostring(bonus))) end
  if mult ~= 1 then table.insert(parts, string.format("qMul=%.2f", mult)) end
  if ownedReason ~= "" then
    table.insert(parts, ownedReason)
    table.insert(parts, string.format("ownedFactor=%.3f", ownedFactor))
  end

  return score, table.concat(parts, ", "), ownedStacks, maxStack
end

local function HashChoices(choices)
  if type(choices) ~= 'table' then return nil end





  local src = choices
  if ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
    local cc = ProjectEbonhold.Perks.currentChoice
    if #cc > #choices then
      src = cc
    end
  end

  local parts, seen = {}, {}
  for _, c in ipairs(src) do
    if c and c.spellId then
      local sid = tonumber(c.spellId)
      if sid then
        local q = tonumber(c.quality) or 0
        local token = tostring(sid) .. ":" .. tostring(q)
        if not seen[token] then
          seen[token] = true
          table.insert(parts, token)
        end
      end
    end
  end

  if #parts == 0 then return nil end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function HashChoicesSpellOnly(choices)
  if type(choices) ~= 'table' then return nil end

  local src = choices
  if ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
    local cc = ProjectEbonhold.Perks.currentChoice
    if #cc > #choices then
      src = cc
    end
  end

  local parts, seen = {}, {}
  for _, c in ipairs(src) do
    if c and c.spellId then
      local sid = tonumber(c.spellId)
      if sid then
        local token = tostring(sid)
        if not seen[token] then
          seen[token] = true
          table.insert(parts, token)
        end
      end
    end
  end

  if #parts == 0 then return nil end
  table.sort(parts)
  return table.concat(parts, "|")
end


local function LearnChoices(profile, choices)
  if type(choices) ~= 'table' then return end

  profile.weights = profile.weights or {}
  profile.blacklist = profile.blacklist or {}
  profile.echoMeta = profile.echoMeta or {}

  local echoDB = EAK:GetEchoDB()
  local _, classToken = UnitClass("player")

  local seen = 0
  for _, c in ipairs(choices) do
    if c and c.spellId then
      local sid = tonumber(c.spellId)
      if sid then
        local q = tonumber(c.quality) or 0
        local key = U:MakeKey(sid, q)
        if key then
          if profile.weights[key] == nil and profile.weights[sid] == nil then
            profile.weights[key] = 0
          end


          local name, _, icon = GetSpellInfo(sid)
          name = name or U:SafeSpellName(sid)
          local meta = echoDB[key] or {}
          meta.spellId = sid
          meta.quality = q
          meta.name = name
          meta.icon = icon
          meta.lastSeen = U:NowStamp()
          meta.classes = meta.classes or {}
          if classToken then meta.classes[classToken] = true end
          echoDB[key] = meta


          local m = profile.echoMeta[key] or {}
          m.lastSeen = meta.lastSeen
          profile.echoMeta[key] = m
        end

        seen = seen + 1
        if seen >= 3 then break end
      end
    end
  end
end




local function RecordLogbookTxn(logbookKey, choices, pickLevel)
  if type(choices) ~= 'table' then return end
  local key = logbookKey or HashChoices(choices)
  if not key then return end
  EAK.runtime._logbookLRU = LRU_Ensure(EAK.runtime._logbookLRU, 120)
  if LRU_Has(EAK.runtime._logbookLRU, key) then return end
  LRU_Add(EAK.runtime._logbookLRU, key)
  U:LogbookRecordChoices(choices, pickLevel)
end

function Engine:TryRequestChoice()
  if not ProjectEbonhold then return end

  local fn = nil
  if ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestChoice then
    fn = ProjectEbonhold.PerkService.RequestChoice
  elseif ProjectEbonhold.Perks and ProjectEbonhold.Perks.RequestChoice then
    fn = ProjectEbonhold.Perks.RequestChoice
  end
  if not fn then return end



  EAK.runtime.forceNextPickLevel = true
  EAK.runtime._eak_requesting_choice = true
  local ok, r1, r2, r3, r4 = pcall(fn)
  EAK.runtime._eak_requesting_choice = nil
  if ok then return r1, r2, r3, r4 end
end


function Engine:TryRequestChoiceRefresh()
  if not ProjectEbonhold then return end

  local fn = nil
  if ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestChoice then
    fn = ProjectEbonhold.PerkService.RequestChoice
  elseif ProjectEbonhold.Perks and ProjectEbonhold.Perks.RequestChoice then
    fn = ProjectEbonhold.Perks.RequestChoice
  end
  if not fn then return end


  EAK.runtime._eak_requesting_choice = true
  local ok, r1, r2, r3, r4 = pcall(fn)
  EAK.runtime._eak_requesting_choice = nil
  if ok then return r1, r2, r3, r4 end
end


function Engine:HandleChoices(choices)
  local profile = EAK:GetProfile()

  if not EAK.runtime.enabledThisSession then return end


  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  if EAK.runtime.writeLockUntil and nowT < EAK.runtime.writeLockUntil then
    return
  end

  local charLvl = self:_GetStableLevel()

  local offer = EAK.runtime.lastOffer
  local lvl = (offer and offer.level) or U:AutomationHistoryPeekNextLevel()




  local h = HashChoices(choices)
  local offerSig = HashChoicesSpellOnly(choices)
  local offerSeq = (offer and offer.seq) or (EAK.runtime.offerSeq or 0)
  local nonce = tostring(EAK.runtime.sessionNonce or "0")
  local viewKey = (offer and offer.viewKey) or (h and (nonce .. "|" .. tostring(offerSeq) .. "|" .. tostring(lvl) .. "|" .. tostring(h))) or nil
  local dedupeKey = viewKey or h
  if dedupeKey and EAK.runtime.lastChoiceHash == dedupeKey then
    return
  end
  EAK.runtime.lastChoiceHash = dedupeKey

  local txnId = (offer and offer.txnId) or (h and (nonce .. "|" .. tostring(offerSeq) .. "|" .. tostring(lvl) .. "|" .. tostring(math.floor((nowT or 0) * 1000)) .. "|" .. tostring(h))) or nil


  if EAK.runtime.pendingPick then
    return
  end


  if EAK.runtime.pendingSelect and h and EAK.runtime.pendingSelect.offerHash and EAK.runtime.pendingSelect.offerHash ~= h then
    EAK.runtime.pendingSelect = nil
  end


  if EAK.runtime.pendingSelect and EAK.runtime.pendingSelect.offerHash == h then
    return
  end

  do
    local pb = EAK.runtime.pendingBanish
    if pb then
      local age = pb.startedAt and (nowT - pb.startedAt) or 0
      local maxWait = 6.0
      local sigNow = offerSig or h
      local sigWas = pb.offerSig or pb.offerHash
      if sigWas and sigNow and sigWas ~= sigNow then
        EAK.runtime.pendingBanish = nil
      elseif sigWas and sigNow and sigWas == sigNow then
        if age < maxWait then return end
        EAK.runtime.pendingBanish = nil
        if EAK.runtime.forceNewOfferView and EAK.runtime.forceNewOfferViewUntilHash == h then
          EAK.runtime.forceNewOfferView = false
          EAK.runtime.forceNewOfferViewUntilHash = nil
        end
      else
        if age < 2.0 then return end
        EAK.runtime.pendingBanish = nil
      end
    end
  end

  local evaluated = {}
  local best, bestScore, bestWhy = nil, -1e18, ""
  local bestCandidates = {}
  local bestUnowned, bestUnownedScore, bestUnownedWhy = nil, -1e18, ""
  local bestUnownedCandidates = {}
  local ownedBySpell = {}
  local echoDB = EAK:GetEchoDB()
  local dbFill = (profile.databaseFillingMode == true)

  for _, c in ipairs(choices or {}) do
    local score, why, ownedStacks, maxStack = ScoreChoice(profile, c)
    ownedStacks = tonumber(ownedStacks or 0) or 0
    ownedBySpell[tonumber(c.spellId) or 0] = ownedStacks
    local key = U:MakeKey(c.spellId, c.quality or 0)
    local meta = key and echoDB and echoDB[key] or nil
    local stTarget = U:GetStackTarget(profile, c.spellId)
    local stCapped = (stTarget >= 1 and ownedStacks >= stTarget)
    if stCapped then
      score = -1e9
      why = "Stack cap (" .. tostring(ownedStacks) .. "/" .. tostring(stTarget) .. ")"
    end
    local isBL = U:IsBlacklisted(profile, key, c.spellId)
    local isBLEffective = isBL or stCapped
    table.insert(evaluated, {
      key = key,
      spellId = c.spellId,
      name = (meta and meta.name) or U:SafeSpellName(c.spellId),
      icon = meta and meta.icon or nil,
      quality = (meta and meta.quality) or (c.quality or 0),
      score = score,
      why = why,
      owned = ownedStacks,
      maxStack = maxStack,
      stackTarget = stTarget,
      stackCapped = stCapped,
      blacklisted = isBL,
      blacklistedEffective = isBLEffective,
    })
    if score > bestScore then
      bestScore, best, bestWhy = score, c, why
      bestCandidates = { { c = c, why = why } }
    elseif math.abs(score - bestScore) < 1e-6 then
      table.insert(bestCandidates, { c = c, why = why })
    end


    if (profile.preferUnowned ~= false) and ownedStacks == 0 and score > -1e8 then
      if score > bestUnownedScore then
        bestUnownedScore, bestUnowned, bestUnownedWhy = score, c, why
        bestUnownedCandidates = { { c = c, why = why } }
      elseif math.abs(score - bestUnownedScore) < 1e-6 then
        table.insert(bestUnownedCandidates, { c = c, why = why })
      end
    end


  end


  local dbFillHadUnseen = false
  local dbFillClass = (offer and offer.unseenClass) or select(2, UnitClass("player"))
  if dbFill then
    local bestQ, bestList = -1, {}
    local anyQ, anyList = -1, {}
    for _, ev in ipairs(evaluated) do
      local q = tonumber(ev.quality) or 0
      if q > anyQ then anyQ, anyList = q, { ev }
      elseif q == anyQ then table.insert(anyList, ev) end

      local isUnseen = false
      if offer and offer.unseen and ev.key and offer.unseen[ev.key] then
        isUnseen = true
      else
        local meta = ev.key and echoDB and echoDB[ev.key] or nil
        local seenForClass = (meta and meta.classes and dbFillClass and meta.classes[dbFillClass]) and true or false
        if not seenForClass then isUnseen = true end
      end

      if isUnseen then
        dbFillHadUnseen = true
        if q > bestQ then bestQ, bestList = q, { ev }
        elseif q == bestQ then table.insert(bestList, ev) end
      end
    end

    local function PickFrom(list)
      if not list or #list == 0 then return nil end
      if #list == 1 then return list[1] end
      return list[math.random(1, #list)]
    end

    local chosenEv = PickFrom(dbFillHadUnseen and bestList or anyList)
    if chosenEv then
      best = { spellId = chosenEv.spellId, quality = chosenEv.quality }
      bestScore = tonumber(chosenEv.quality) or 0
      if dbFillHadUnseen then
        bestWhy = "DBFill: picked unseen for class " .. tostring(dbFillClass or "?")
      else
        bestWhy = "DBFill: no unseen available; picked highest quality"
      end
    end
  end



  if (not dbFill) and #bestCandidates > 1 then
    local idx = math.random(1, #bestCandidates)
    best = bestCandidates[idx].c
    bestWhy = (bestCandidates[idx].why or "") .. " (tie-break=random)"
  end

  local preferUnownedEnabled = (not dbFill) and (profile.preferUnowned ~= false)
  local preferUnownedForced = false
  local ownedOnlyOffer = false

  if preferUnownedEnabled then
    if #bestUnownedCandidates > 1 then
      local idx = math.random(1, #bestUnownedCandidates)
      bestUnowned = bestUnownedCandidates[idx].c
      bestUnownedWhy = (bestUnownedCandidates[idx].why or "") .. " (tie-break=random)"
    end

    if bestUnowned and (bestUnownedScore or -1e18) > -1e8 then
      if not best or tonumber(best.spellId or 0) ~= tonumber(bestUnowned.spellId or 0) then
        preferUnownedForced = true
      end
      best = bestUnowned
      bestScore = bestUnownedScore
      bestWhy = (bestUnownedWhy or "") .. (preferUnownedForced and " (preferUnowned=forced)" or " (preferUnowned)")
    else
      ownedOnlyOffer = true
    end
  end



  local minLvl = tonumber(profile.minLevelRequirement or 12) or 12
  local allowRerollNow = (tonumber(lvl) or 0) >= minLvl
  if dbFill then
    minLvl = 1
    allowRerollNow = true
  end


  local maxInRow = profile.maxRollUsageInRow
  if maxInRow == nil then maxInRow = profile.maxRerollsPerLevel end
  maxInRow = tonumber(maxInRow or 10) or 10
  if maxInRow < 0 then maxInRow = 0 end
  local usedThisPick = tonumber(Engine.state.rerollsUsedThisPick or 0) or 0
  local capRemaining = math.max(0, maxInRow - usedThisPick)


  local rerollsRemaining, totalR, usedR = GetRerollsRemaining(profile)

  local effectiveRerollsRemaining = (allowRerollNow and math.min(rerollsRemaining or 0, capRemaining)) or 0
  local minScore = tonumber(profile.minScoreToKeep) or 0

  if (not dbFill) and profile.pauseIfMultipleAbove then
    local thr = tonumber(profile.pauseMultipleAboveValue) or 0
    local good = 0
    for _, ev in ipairs(evaluated) do
      if (ev.score or -1e18) >= thr then
        good = good + 1
      end
    end
    if good >= 2 then
      local msg = string.format("Paused: %d Echoes are at/above your pause threshold (%.1f).", good, thr)

      self:_AppendPendingStep(lvl, evaluated, { action = 'pause', pauseKind = 'multipleAbove', aboveCount = good, threshold = thr, reason = msg, viewKey = viewKey, offerSeq = offerSeq, offerHash = h })
      if EAK.SetStartButtonNote then
        EAK:SetStartButtonNote("|cffffaa00Paused|r: Multiple above threshold")
      end
      Chat("|cffffd100Ebonhold Automation Kit|r " .. msg)
      EAK.runtime.pendingSelect = nil
      EAK.runtime.pauseResumeArmed = true
      EAK.runtime.pauseResumeKind = 'multipleAbove'
      EAK:SetEnabledThisSession(false)
      if EAK.RevealServerUI then EAK:RevealServerUI() end
      return
    end
  end

    if (profile.allowBanish == true) and IsBanishSystemEnabled() and (GetBanishesRemaining() > 0) then
    local function NormName(n)
      n = U:StripWoWFormatting(n or "")
      n = U:Trim(n)
      return (n ~= "") and string.lower(n) or ""
    end

    local function GetKnownQualitiesByName(name)
      local target = NormName(name)
      local seen = {}
      if target == "" then return seen end
      local echoDB2 = EAK:GetEchoDB() or {}
      for key, meta in pairs(echoDB2) do
        if type(meta) == "table" then
          local nm = meta.name
          if nm and NormName(nm) == target then
            local q = tonumber(meta.quality)
            if q == nil and type(key) == "string" then
              local _, qq = U:ParseKey(key)
              q = tonumber(qq) or 0
            end
            q = tonumber(q) or 0
            seen[q] = true
          end
        end
      end
      return seen
    end

    local function HasAllCRU(seen)
      return (seen and seen[0] and seen[1] and seen[2]) and true or false
    end

    local function CallRawBanish(perkIndex)
      perkIndex = tonumber(perkIndex)
      if perkIndex == nil or perkIndex < 0 or perkIndex > 2 then return false end

      local function Try(fn)
        if type(fn) ~= "function" then return false end
        local ok, ret = pcall(fn, perkIndex)
        return ok and (ret == true)
      end

      if self._origSvcBanishPerk then
        return Try(self._origSvcBanishPerk)
      elseif self._origPerksBanishPerk then
        return Try(self._origPerksBanishPerk)
      elseif ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.BanishPerk then
        return Try(ProjectEbonhold.PerkService.BanishPerk)
      elseif ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.BanishPerk then
        return Try(ProjectEbonhold.Perks.BanishPerk)
      end
      return false
    end

    local function DoBanish(idx, ev, msg)
      if not idx or not ev then return false end
      local perkIndex = idx - 1
      local nowT = (type(GetTime) == 'function') and GetTime() or 0
      local remB = GetBanishesRemaining()
      if remB <= 0 then return false end

      EAK.runtime._banishOfferLRU = LRU_Ensure(EAK.runtime._banishOfferLRU, 80)
      local bkey = tostring(offerSig or h or "?")
      if LRU_Has(EAK.runtime._banishOfferLRU, bkey) then
        return false
      end
      LRU_Add(EAK.runtime._banishOfferLRU, bkey)

      EAK.runtime.forceNewOfferView = true
      EAK.runtime.pendingSelect = nil
      EAK.runtime.forceNewOfferViewUntilHash = h

      local pb = { slot = perkIndex, offerHash = h, offerSig = (offerSig or h), offerSeq = offerSeq, viewKey = viewKey, startedAt = nowT }
      EAK.runtime.pendingBanish = pb

      local delay = 0.15
      U:After(delay, function()
        if EAK.runtime.pendingBanish ~= pb then return end
        if not EAK.runtime.enabledThisSession then
          EAK.runtime.pendingBanish = nil
          return
        end

        local rt = EAK and EAK.runtime
        local prevBH = rt and rt._inBanishHook
        if rt then rt._skipNextBanishHistory = true
        rt._inBanishHook = true end
        local ok = CallRawBanish(perkIndex)
        if rt then rt._inBanishHook = prevBH
        rt._skipNextBanishHistory = nil end
        if not ok then
          EAK.runtime.pendingBanish = nil
          return
        end

        self:_AppendPendingStep(lvl, evaluated or {}, {
          action = "banish",
          txnId = txnId,
          viewKey = viewKey,
          offerSeq = offerSeq,
          offerHash = h,
          charLevel = charLvl,
          spellId = ev.spellId,
          key = ev.key,
          quality = ev.quality,
          banishIndex = perkIndex,
          banishesRemaining = math.max(0, (tonumber(remB) or 0) - 1),
          banishesRemainingBefore = remB,
          bestScore = bestScore,
          bestWhy = bestWhy,
          minScoreToKeep = minScore,
          reason = msg,
        })

        Chat("|cffffd100Ebonhold Automation Kit|r " .. msg)
      end)

      return true
    end

    if dbFill then
      local bestIdx, bestEv, bestMsg, bestScore = nil, nil, nil, 1e18

      for i, ev in ipairs(evaluated) do
        local q = tonumber(ev.quality) or 0
        local seen = GetKnownQualitiesByName(ev.name)
        if q == 3 and seen[3] then
          local sc = tonumber(ev.score) or 0
          if sc < bestScore then
            bestScore = sc
            bestIdx, bestEv = i, ev
            bestMsg = string.format("DBFill: Auto banish %s (Epic already known).", tostring(ev.name or "?"))
          end
        end
      end

      if not bestIdx then
        for i, ev in ipairs(evaluated) do
          local q = tonumber(ev.quality) or 0
          if q >= 0 and q <= 2 then
            local seen = GetKnownQualitiesByName(ev.name)
            if HasAllCRU(seen) then
              local sc = tonumber(ev.score) or 0
              if sc < bestScore then
                bestScore = sc
                bestIdx, bestEv = i, ev
                bestMsg = string.format("DBFill: Auto banish %s (Common/Uncommon/Rare already complete).", tostring(ev.name or "?"))
              end
            end
          end
        end
      end

      if bestIdx and bestEv and bestMsg then
        if DoBanish(bestIdx, bestEv, bestMsg) then
          return
        end
      end
    else
      local bestIdx, bestEv, bestMsg, bestScore = nil, nil, nil, 1e18
      for i, ev in ipairs(evaluated) do
        if ev.blacklistedEffective then
          local sc = tonumber(ev.score) or 0
          if sc < bestScore then
            bestScore = sc
            bestIdx, bestEv = i, ev
            bestMsg = string.format("Auto banish: %s is blacklisted.", tostring(ev.name or "?"))
          end
        end
      end

      if bestIdx and bestEv and bestMsg then
        if DoBanish(bestIdx, bestEv, bestMsg) then
          return
        end
      end
    end
  end

if (not dbFill) and profile.pauseIfOnlyBlacklisted and effectiveRerollsRemaining <= 0 then
    local allBL = true
    for _, ev in ipairs(evaluated) do
      if not ev.blacklistedEffective then
        allBL = false
        break
      end
    end
    if allBL then
      local msg = "Paused: only blacklisted Echoes remain and no rerolls are available."
      self:_AppendPendingStep(lvl, evaluated, { action = 'pause', pauseKind = 'onlyBlacklisted', reason = msg, viewKey = viewKey, offerSeq = offerSeq, offerHash = h })
      if EAK.SetStartButtonNote then
        EAK:SetStartButtonNote("|cffffaa00Paused|r: Only blacklisted")
      end
      Chat("|cffffd100Ebonhold Automation Kit|r " .. msg)
      EAK.runtime.pendingSelect = nil
      EAK.runtime.pauseResumeArmed = true
      EAK.runtime.pauseResumeKind = 'onlyBlacklisted'
      EAK:SetEnabledThisSession(false)
      if EAK.RevealServerUI then EAK:RevealServerUI() end
      return
    end
  end

  local shouldReroll
  if dbFill then
    shouldReroll = allowRerollNow and (effectiveRerollsRemaining > 0) and (not dbFillHadUnseen)
  else
    shouldReroll = (profile.allowReroll ~= false) and allowRerollNow and (effectiveRerollsRemaining > 0) and ((bestScore < minScore) or (preferUnownedEnabled and ownedOnlyOffer))
  end

  local entry = {
    ts = U:NowStamp(),
    level = lvl,
    offered = evaluated,
    decision = {
      action = shouldReroll and "reroll" or "select",
      txnId = txnId,
    viewKey = viewKey,
      offerSeq = offerSeq,
      offerHash = h,
      charLevel = charLvl,
      databaseFillingMode = dbFill,
      dbFillClass = dbFillClass,
      dbFillHadUnseen = dbFillHadUnseen,
      spellId = best and best.spellId or nil,
      key = best and U:MakeKey(best.spellId, best.quality or 0) or nil,
      quality = best and (best.quality or 0) or nil,
      bestScore = bestScore,
      bestWhy = bestWhy,
      minScoreToKeep = minScore,
      allowRerollNow = allowRerollNow,
      rerollGateMinLevel = minLvl,
      rerollGatePickLevel = lvl,
      preferUnownedEnabled = preferUnownedEnabled,
      preferUnownedForced = preferUnownedForced,
      ownedOnlyOffer = ownedOnlyOffer,
      bestOwnedStacks = best and (ownedBySpell[tonumber(best.spellId) or 0] or 0) or 0,
      streakUsedThisPick = usedThisPick,
      streakCap = maxInRow,
      streakRemaining = capRemaining,
      serverRerollsRemaining = rerollsRemaining,
      serverRerollsTotal = totalR,
      serverRerollsUsed = usedR,
      effectiveRerollsRemaining = effectiveRerollsRemaining,
    }
  }

  if shouldReroll then
    local nextUsed = (usedThisPick or 0) + 1
    local cap = maxInRow or 0
    if dbFill then
      entry.decision.reason = string.format("DBFill: no unseen available; rerolling (server %d/%d, streak %d/%d)", tonumber(rerollsRemaining or 0), tonumber(totalR or 0), nextUsed, cap)
    elseif preferUnownedEnabled and ownedOnlyOffer then
      entry.decision.reason = string.format("Single Echo Mode: owned-only offer (best %.1f). Rerolling (server %d/%d, streak %d/%d)", bestScore, tonumber(rerollsRemaining or 0), tonumber(totalR or 0), nextUsed, cap)
    else
      entry.decision.reason = string.format("Best score %.1f < min %.1f (server %d/%d, streak %d/%d)", bestScore, minScore, tonumber(rerollsRemaining or 0), tonumber(totalR or 0), nextUsed, cap)
    end

    Engine:_AppendPendingStep(lvl, evaluated or {}, {
      action = 'reroll',
      txnId = txnId,
    viewKey = viewKey,
      offerSeq = offerSeq,
      offerHash = h,
      charLevel = charLvl,
      databaseFillingMode = dbFill,
      dbFillClass = dbFillClass,
      dbFillHadUnseen = dbFillHadUnseen,
      bestScore = bestScore,
      bestWhy = bestWhy,
      minScoreToKeep = minScore,
      allowRerollNow = allowRerollNow,
      rerollGateMinLevel = minLvl,
      rerollGatePickLevel = lvl,
      preferUnownedEnabled = preferUnownedEnabled,
      preferUnownedForced = preferUnownedForced,
      ownedOnlyOffer = ownedOnlyOffer,
      bestOwnedStacks = best and (ownedBySpell[tonumber(best.spellId) or 0] or 0) or 0,
      streakUsedThisPick = usedThisPick,
      streakCap = maxInRow,
      streakRemaining = capRemaining,
      serverRerollsRemaining = rerollsRemaining,
      serverRerollsTotal = totalR,
      serverRerollsUsed = usedR,
      effectiveRerollsRemaining = effectiveRerollsRemaining,
      reason = entry.decision.reason,
    })

    if not (Engine._origSvcRequestReroll or Engine._origPerksRequestReroll) then
      Engine.state.rerollsUsedThisPick = (Engine.state.rerollsUsedThisPick or 0) + 1
      EAK.runtime.pendingSelect = nil
    end



    EAK.runtime.forceNewOfferView = true
    EAK.runtime.forceNewOfferViewUntilHash = h


    EAK.runtime.pendingSelect = nil

    EAK.runtime._skipNextRerollHistory = true
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestReroll then
      ProjectEbonhold.PerkService.RequestReroll()
    elseif ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.RequestReroll then
      ProjectEbonhold.Perks.RequestReroll()
    end
    return
  end


  if dbFill then
    if dbFillHadUnseen then
      entry.decision.reason = "DBFill: selected unseen (spell+quality) for class " .. tostring(dbFillClass or "?")
    else
      entry.decision.reason = "DBFill: no unseen available; selected highest quality"
    end
  elseif allowRerollNow then
    if (profile.allowReroll ~= false) and (bestScore < minScore) and (effectiveRerollsRemaining <= 0) and (rerollsRemaining or 0) > 0 and capRemaining <= 0 then
      entry.decision.reason = string.format("Selected best score %.1f (min %.1f) - reroll cap reached (%d/%d)", bestScore, minScore, usedThisPick, maxInRow)
    else
      if preferUnownedEnabled and ownedOnlyOffer then
        entry.decision.reason = string.format("Single Echo Mode: owned-only offer (best %.1f). No rerolls available.", bestScore)
      else
        entry.decision.reason = string.format("Selected best score %.1f (min %.1f)", bestScore, minScore)
      end
    end
  else
    if preferUnownedEnabled and ownedOnlyOffer then
      entry.decision.reason = string.format("Single Echo Mode: owned-only offer (best %.1f). Rerolls disabled until Lv. %d", bestScore, minLvl)
    else
      entry.decision.reason = string.format("Selected best score %.1f (min %.1f) - rerolls disabled until Lv. %d", bestScore, minScore, minLvl)
    end
  end



  Engine:_AppendPendingStep(lvl, evaluated or {}, {
    action = 'select',
    txnId = txnId,
    viewKey = viewKey,
    offerSeq = offerSeq,
    offerHash = h,
    charLevel = charLvl,
    databaseFillingMode = dbFill,
    dbFillClass = dbFillClass,
    dbFillHadUnseen = dbFillHadUnseen,
    spellId = best and best.spellId or nil,
    key = best and U:MakeKey(best.spellId, best.quality or 0) or nil,
    quality = best and (best.quality or 0) or 0,
    bestScore = bestScore,
    bestWhy = bestWhy,
    minScoreToKeep = minScore,
    allowRerollNow = allowRerollNow,
    rerollGateMinLevel = minLvl,
    rerollGatePickLevel = lvl,
    preferUnownedEnabled = preferUnownedEnabled,
    preferUnownedForced = preferUnownedForced,
    ownedOnlyOffer = ownedOnlyOffer,
    bestOwnedStacks = best and (ownedBySpell[tonumber(best.spellId) or 0] or 0) or 0,
    streakUsedThisPick = usedThisPick,
    streakCap = maxInRow,
    streakRemaining = capRemaining,
    serverRerollsRemaining = rerollsRemaining,
    serverRerollsTotal = totalR,
    serverRerollsUsed = usedR,
    effectiveRerollsRemaining = effectiveRerollsRemaining,
    reason = entry.decision.reason,
  })



  local delay = 0.15

  if best and ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.SelectPerk then

    EAK.runtime.pendingSelect = {
      offerHash = h,
      offerSeq = (EAK.runtime.lastOffer and EAK.runtime.lastOffer.seq) or (EAK.runtime.offerSeq or 0),
      spellId = best.spellId,
    }
    U:After(delay, function()
      if not EAK.runtime.enabledThisSession then return end
      ProjectEbonhold.PerkService.SelectPerk(best.spellId)
    end)
  end
end

function Engine:HookPerkUI()
  self:HookPerkService()
  if self.state.hooked then return end

  if ProjectEbonhold and ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.Show then
    local orig = ProjectEbonhold.PerkUI.Show
    ProjectEbonhold.PerkUI.Show = function(...)
      local args = {...}
      local choices = args[1]
      local ok, a1, a2, a3, a4 = _EAK_xpcall("PerkUI.Show", function()

              local r1, r2, r3, r4 = orig(unpack(args))
              if type(choices) == 'table' and #choices > 0 then


                do
                  local preHash = HashChoices(choices)
                  if preHash then
                    local _, cls = UnitClass("player")
                    local db = EAK:GetEchoDB()
                    local unseen = {}
                    local nSeen = 0
                    for _, cc in ipairs(choices) do
                      if cc and cc.spellId then
                        local sid = tonumber(cc.spellId)
                        if sid then
                          local q = tonumber(cc.quality) or 0
                          local k = U:MakeKey(sid, q)
                          if k then
                            local meta = db and db[k] or nil
                            local isSeen = (meta and meta.classes and cls and meta.classes[cls]) and true or false
                            if not isSeen then unseen[k] = true end
                          end
                          nSeen = nSeen + 1
                          if nSeen >= 3 then break end
                        end
                      end
                    end
                    EAK.runtime._offerPreSeen = { hash = preHash, classToken = cls, unseen = unseen }
                  end
                end


                LearnChoices(EAK:GetProfile(), choices)



                if Engine:CheckPendingPick(choices) then
                  return r1, r2, r3, r4
                end


                local okCache = Engine:CacheOffer(choices)
                if not okCache then
                  return r1, r2, r3, r4
                end


                local hh = HashChoices(choices)
                local lk = (EAK.runtime.lastOffer and EAK.runtime.lastOffer.viewKey) or hh
                if lk then EAK.runtime.lastLearnHash = lk end


                Engine:HandleChoices(choices)
              end
              return r1, r2, r3, r4
      end)
      if ok then return a1, a2, a3, a4 end
      Engine:_OnFatalError("PerkUI.Show", a1)
    end

    if ProjectEbonhold.PerkUI.UpdateSinglePerk and not self.state.hookedUpdateSinglePerk then
      local origUSP = ProjectEbonhold.PerkUI.UpdateSinglePerk
            ProjectEbonhold.PerkUI.UpdateSinglePerk = function(...)
        local args = {...}
        local perkIndex = args[1]
        local ok, a1, a2, a3, a4 = _EAK_xpcall("PerkUI.UpdateSinglePerk", function()
                  local a, b, c, d = origUSP(unpack(args))

                  local cur = nil
                  if ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.currentChoice then
                    cur = NormalizeChoices(ProjectEbonhold.Perks.currentChoice)
                  elseif ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then
                    local ok, raw = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
                    if ok then cur = NormalizeChoices(raw) end
                  end

                  if cur and type(cur) == 'table' and #cur > 0 then
                    if EAK and EAK.runtime and EAK.runtime.pendingBanish and tonumber(EAK.runtime.pendingBanish.slot or -1) == tonumber(perkIndex or -2) then
                      EAK.runtime.pendingBanish = nil
                    end

                    LearnChoices(EAK:GetProfile(), cur)

                    if not Engine:CheckPendingPick(cur) then
                      local okCache = Engine:CacheOffer(cur)
                      if okCache then
                        local hh = HashChoices(cur)
                        local lk = (EAK.runtime.lastOffer and EAK.runtime.lastOffer.viewKey) or hh
                        if lk then EAK.runtime.lastLearnHash = lk end
                        Engine:HandleChoices(cur)
                      end
                    end
                  end

                  return a, b, c, d
        end)
        if ok then return a1, a2, a3, a4 end
        Engine:_OnFatalError("PerkUI.UpdateSinglePerk", a1)
      end

      self.state.hookedUpdateSinglePerk = true
    end





    if ProjectEbonhold.PerkUI.ResetSelection and not self.state.hookedResetSelection then
      local origRS = ProjectEbonhold.PerkUI.ResetSelection
            ProjectEbonhold.PerkUI.ResetSelection = function(...)
        local args = { ... }
        local ok, a1, a2, a3, a4 = _EAK_xpcall("PerkUI.ResetSelection", function()
                  local a, b, c, d = origRS(unpack(args))
                  if EAK and EAK.runtime and EAK.runtime.pendingPick then
                    local pick = EAK.runtime.pendingPick
                    if pick and (not pick.sawOfferChange) then
                      local cur = nil
                      if ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
                        cur = NormalizeChoices(ProjectEbonhold.Perks.currentChoice) or ProjectEbonhold.Perks.currentChoice
                      end
                      local h = cur and HashChoices(cur) or nil
                      if h and pick.offerHash and h ~= pick.offerHash then
                      else
                        Engine:_FailPendingPick('server_rejected', cur)
                      end
                    end
                  end
                  return a, b, c, d
        end)
        if ok then return a1, a2, a3, a4 end
        Engine:_OnFatalError("PerkUI.ResetSelection", a1)
      end

      self.state.hookedResetSelection = true
    end
    self.state.hooked = true
  end
end

NormalizeChoices = function(raw)
  if type(raw) ~= 'table' then return nil end
  local n = #raw
  if n == 0 then return nil end
  if n == 3 then return raw end

  local out = {}
  for i = 1, math.min(3, n) do
    local c = raw[i]
    if c and c.spellId then
      table.insert(out, { spellId = c.spellId, quality = c.quality })
    end
  end
  if #out > 0 then return out end
  return raw
end

local function CopyChoices(raw)
  if type(raw) ~= 'table' then return nil end
  local out = {}
  local seen = 0
  for _, c in ipairs(raw) do
    if c and c.spellId then
      table.insert(out, { spellId = c.spellId, quality = c.quality })
      seen = seen + 1
      if seen >= 3 then break end
    end
  end
  if #out == 0 then return nil end
  return out
end




function Engine:_GetStableLevel()
  local lvl = tonumber(UnitLevel("player")) or 1
  local cached = tonumber(self.state and self.state.currentLevel) or lvl
  if cached > lvl then lvl = cached end
  if lvl > 80 then lvl = 80 end
  return lvl
end

function Engine:CacheOffer(choices)
  if type(choices) ~= 'table' then return false end

  local profile = EAK:GetProfile()
  local echoDB = EAK:GetEchoDB()
  local evaluated = {}
  local seen = 0
  for _, c in ipairs(choices) do
    if c and c.spellId then
      local sid = tonumber(c.spellId)
      if sid then
        local q = tonumber(c.quality) or 0
        local score, why, ownedStacks, maxStack = ScoreChoice(profile, { spellId = sid, quality = q })
        ownedStacks = tonumber(ownedStacks or 0) or 0
        local key = U:MakeKey(sid, q)
        local stTarget = U:GetStackTarget(profile, sid)
        local stCapped = (stTarget >= 1 and ownedStacks >= stTarget)
        if stCapped then
          score = -1e9
          why = "Stack cap (" .. tostring(ownedStacks) .. "/" .. tostring(stTarget) .. ")"
        end
        local isBL = U:IsBlacklisted(profile, key, sid)
        local isBLEffective = isBL or stCapped
        local meta = key and echoDB and echoDB[key] or nil
        table.insert(evaluated, {
          key = key,
          spellId = sid,
          name = (meta and meta.name) or U:SafeSpellName(sid),
          icon = meta and meta.icon or nil,
          quality = (meta and meta.quality) or q,
          score = score,
          why = why,
          owned = ownedStacks,
          maxStack = maxStack,
          stackTarget = stTarget,
          stackCapped = stCapped,
          blacklisted = isBL,
          blacklistedEffective = isBLEffective,
        })
        seen = seen + 1
        if seen >= 3 then break end
      end
    end
  end

  local h = HashChoices(choices)
  if not h then return false end






  local prev = EAK.runtime.lastOffer
  local forceNext = (EAK.runtime.forceNextPickLevel == true)
  local forceNew = (EAK.runtime.forceNewOfferView == true)






  EAK.runtime._seenOfferByHash = EAK.runtime._seenOfferByHash or {}
  local seenRec = EAK.runtime._seenOfferByHash[h]

  local lvl
  if (not forceNext) and prev and prev.hash == h and prev.level then
    lvl = tonumber(prev.level) or U:AutomationHistoryPeekNextLevel()
  else
    lvl = U:AutomationHistoryPeekNextLevel()
  end

  if (not forceNext) and (not forceNew) and seenRec and prev and prev.hash and prev.hash ~= h then
    local seenLvl = tonumber(seenRec.level or -1) or -1
    if seenLvl < (tonumber(lvl) or 0) then
      EAK.runtime._staleResends = (tonumber(EAK.runtime._staleResends) or 0) + 1

      local nowT0 = (type(GetTime) == 'function') and GetTime() or 0
      local lastReq = tonumber(EAK.runtime._staleReqAt or 0) or 0
      if (nowT0 - lastReq) > 0.5 then
        EAK.runtime._staleReqAt = nowT0
        U:After(0, function()
          if Engine and Engine.TryRequestChoice then
            Engine:TryRequestChoice()
          end
        end)
      end
      return false
    end
  end






  local sameView = (not forceNew) and (not forceNext) and prev and (prev.hash == h) and (tonumber(prev.level or -1) == tonumber(lvl))

  if not sameView then
    EAK.runtime.offerSeq = (tonumber(EAK.runtime.offerSeq) or 0) + 1
  end
  local seq = tonumber(EAK.runtime.offerSeq) or 0


  if forceNew then
    local untilHash = EAK.runtime.forceNewOfferViewUntilHash
    if (not untilHash) or (untilHash ~= h) then
      EAK.runtime.forceNewOfferView = false
      EAK.runtime.forceNewOfferViewUntilHash = nil
    end
  end
  if forceNext then EAK.runtime.forceNextPickLevel = false end

  local nonce = tostring(EAK.runtime.sessionNonce or "0")
  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  local nowMs = math.floor((nowT or 0) * 1000)

  local txnId, viewKey, ts
  if sameView and prev then
    txnId = prev.txnId
    viewKey = prev.viewKey
    ts = prev.ts
    nowT = prev.t or nowT
    nowMs = prev.ms or nowMs
  else
    txnId = nonce .. "|" .. tostring(seq) .. "|" .. tostring(lvl) .. "|" .. tostring(nowMs) .. "|" .. tostring(h)
    viewKey = nonce .. "|" .. tostring(seq) .. "|" .. tostring(lvl) .. "|" .. tostring(h)
    ts = U:NowStamp()
  end


  local unseenTbl, unseenCls = nil, nil
  local pre = EAK.runtime._offerPreSeen
  if pre and pre.hash == h then
    unseenCls = pre.classToken
    if type(pre.unseen) == 'table' then
      unseenTbl = {}
      for kk, vv in pairs(pre.unseen) do if vv then unseenTbl[kk] = true end end
    end
  end
  if pre and pre.hash == h then EAK.runtime._offerPreSeen = nil end

  EAK.runtime.lastOffer = {
    ts = ts,
    t = nowT,
    ms = nowMs,
    txnId = txnId,
    viewKey = viewKey,
    level = lvl,
    hash = h,
    seq = seq,
    offered = evaluated,
    unseen = unseenTbl,
    unseenClass = unseenCls,
  }







  local rerollIdx = tonumber(self.state and self.state.rerollsUsedThisPick or 0) or 0
  local await = EAK.runtime and EAK.runtime._rerollAwait or nil
  if await then
    local nowT2 = (type(GetTime) == 'function') and GetTime() or 0
    local usedNow = GetServerUsedRerolls()
    local expected = tonumber(await.expectedUsed or 0) or 0
    if usedNow ~= nil and expected > 0 then
      if usedNow >= expected then

        EAK.runtime._rerollAwait = nil
      else

        rerollIdx = math.max(0, rerollIdx - 1)
        if (nowT2 - (tonumber(await.t) or nowT2)) > 10.0 then
          EAK.runtime._rerollAwait = nil
        end
      end
    else

      rerollIdx = math.max(0, rerollIdx - 1)
      if (nowT2 - (tonumber(await.t) or nowT2)) > 10.0 then
        if EAK.runtime then EAK.runtime._rerollAwait = nil end
      end
    end
  end


  EAK.runtime._seenOfferByHash[h] = { level = lvl, t = (type(GetTime) == 'function') and GetTime() or 0 }

local logbookKey = tostring(lvl) .. "|" .. tostring(rerollIdx) .. "|" .. tostring(h)
  RecordLogbookTxn(logbookKey, choices, lvl)
  return true

end















function Engine:_EnsurePendingHistory(level)
  local ph = EAK.runtime.pendingHistory
  if not ph or ph.level ~= level then
    ph = { level = level, steps = {} }
    EAK.runtime.pendingHistory = ph
  end
  ph.steps = ph.steps or {}
  return ph
end

function Engine:_AppendPendingStep(level, offered, decision)
  local ph = self:_EnsurePendingHistory(level)
  local steps = ph.steps
  local last = steps[#steps]
  if last and last.decision and decision then


    if last.decision.action == decision.action
      and tonumber(last.decision.spellId or 0) == tonumber(decision.spellId or 0)
      and (last.decision.reason or '') == (decision.reason or '')
      and tostring(last.decision.viewKey or '') == tostring(decision.viewKey or '')
      and tonumber(last.decision.offerSeq or 0) == tonumber(decision.offerSeq or 0) then
      return
    end
  end
  table.insert(steps, { ts = U:NowStamp(), t = (type(GetTime) == 'function') and GetTime() or nil, offered = offered or {}, decision = decision or {} })
end

local function GetGrantedSnapshot(spellId)



  local granted = nil
  if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks then
    local ok, g = pcall(ProjectEbonhold.PerkService.GetGrantedPerks)
    if ok and type(g) == 'table' then
      granted = g
    end
  end
  if (not granted) and ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.grantedPerks) == 'table' then
    granted = ProjectEbonhold.Perks.grantedPerks
  end
  if type(granted) ~= 'table' then
    granted = {}
  end


  local locked = nil
  if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetLockedPerks then
    local okL, l = pcall(ProjectEbonhold.PerkService.GetLockedPerks)
    if okL and type(l) == 'table' then
      locked = l
    end
  end
  if (not locked) and ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.lockedPerks) == 'table' then
    locked = ProjectEbonhold.Perks.lockedPerks
  end

  local total = 0
  for _, list in pairs(granted) do
    if type(list) == 'table' then
      total = total + #list
    end
  end

  local lockedSpellCount = 0
  if type(locked) == 'table' then
    for _, ent in ipairs(locked) do
      if ent then
        local st = tonumber(ent.stack or 0) or 0
        total = total + st
        if spellId and tonumber(ent.spellId or 0) == tonumber(spellId or 0) then
          lockedSpellCount = lockedSpellCount + st
        end
      end
    end
  end

  local spellCount = nil
  if spellId then
    local name = GetSpellInfo(spellId)
    if name then
      local list = granted[name]
      if type(list) == 'table' then
        spellCount = #list + lockedSpellCount
      else
        spellCount = 0 + lockedSpellCount
      end
    end
  end

  return total, spellCount
end

function Engine:_IsPendingPickConfirmed(pick, currentChoices)
  if not pick then return false end


  local afterTotal, afterSpell = GetGrantedSnapshot(pick.spellId)
  if afterTotal ~= nil then
    local beforeTotal = tonumber(pick.grantedTotalBefore) or 0
    if afterTotal > beforeTotal then
      return true
    end
  end
  if afterSpell ~= nil then
    local beforeSpell = tonumber(pick.grantedSpellBefore) or 0
    if afterSpell > beforeSpell then
      return true
    end
  end

  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  local startedAt = tonumber(pick.startedAt) or nowT
  local age = (nowT or 0) - (startedAt or 0)

  local curChoice = nil
  if ProjectEbonhold and ProjectEbonhold.Perks then
    curChoice = ProjectEbonhold.Perks.currentChoice
  end
  if (curChoice == nil or (type(curChoice) == 'table' and #curChoice == 0)) and age > 0.10 then
    return true
  end

  if pick.sawOfferChange and age > 0.10 then
    return true
  end





  return false
end

function Engine:_CommitPendingPick(reason)
  local pick = EAK.runtime.pendingPick
  if not pick then return end


  local commitKey = pick.viewKey or pick.txnId or pick.pickToken
  if commitKey then
    EAK.runtime._commitLRU = LRU_Ensure(EAK.runtime._commitLRU, 60)
    if LRU_Has(EAK.runtime._commitLRU, commitKey) then

      EAK.runtime.pendingPick = nil
      EAK.runtime.pendingSelect = nil
      EAK.runtime.pendingBanish = nil
      EAK.runtime.pendingHistory = nil
      self.state.rerollsUsedThisPick = 0
      return
    end
    LRU_Add(EAK.runtime._commitLRU, commitKey)
  end



  do
    local q = (pick.finalDecision and tonumber(pick.finalDecision.quality)) or nil
    if q == nil then
      q = 0
      if type(pick.offered) == 'table' then
        for _, ev in ipairs(pick.offered) do
          if ev and tonumber(ev.spellId) == tonumber(pick.spellId) then
            q = tonumber(ev.quality) or 0
            break
          end
        end
      end
    end

    local key = U:MakeKey(pick.spellId, q)
    local echoDB = EAK:GetEchoDB()
    if echoDB and key then
      local sid = tonumber(pick.spellId)
      local meta = echoDB[key] or {}
      meta.spellId = tonumber(meta.spellId) or sid
      meta.quality = tonumber(meta.quality) or q
      meta.name = meta.name or (GetSpellInfo(sid) or U:SafeSpellName(sid))
      local _, _, icon = GetSpellInfo(sid)
      meta.icon = meta.icon or icon

      meta.pickedCount = (tonumber(meta.pickedCount) or 0) + 1
      local stamp = U:NowStamp()
      meta.lastPickedAt = stamp
      meta.lastPickedPickLevel = tonumber(pick.level) or meta.lastPickedPickLevel
      if not meta.firstPickedAt then meta.firstPickedAt = stamp end
      if not meta.firstPickedPickLevel then meta.firstPickedPickLevel = tonumber(pick.level) end

      local score = pick.finalDecision and pick.finalDecision.bestScore or nil
      if score ~= nil then meta.lastPickScore = tonumber(score) end
      local why = pick.finalDecision and (pick.finalDecision.bestWhy or pick.finalDecision.reason) or nil
      if type(why) == 'string' then
        why = U:Trim(why)
        if #why > 220 then why = why:sub(1, 217) .. "..." end
        meta.lastPickReasonShort = why
      end


      if not meta.tooltipText or not meta.tooltipSearch or meta.tooltipSearch == '' then
        local lines, text, search = U:CaptureSpellTooltip(sid)
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


  do
    local steps = pick.autoContext and (pick.historySteps or {}) or {}

    if not pick.autoContext then
      if pick.finalDecision then
        table.insert(steps, { offered = pick.offered or {}, decision = pick.finalDecision })
      end
    else
      local hasSelect = false
      for _, st in ipairs(steps) do
        if st and st.decision and st.decision.action == 'select' and st.decision.spellId then
          hasSelect = true
          break
        end
      end
      if not hasSelect and pick.finalDecision then
        table.insert(steps, { offered = pick.offered or {}, decision = pick.finalDecision })
      end
    end

    for _, st in ipairs(steps) do
      if st and st.decision and st.decision.action then
        U:AutomationHistoryAddAttempt(pick.level, st.offered or {}, st.decision)
      end
    end
  end


  EAK.runtime.pendingPick = nil
  EAK.runtime.pendingSelect = nil
  EAK.runtime.pendingHistory = nil
  EAK.runtime._advanceForPickToken = nil
  EAK.runtime._serverRejectRetryKey = nil


  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  EAK.runtime.writeLockUntil = (nowT or 0) + 0.40

  self.state.rerollsUsedThisPick = 0


  local hadDeferred = false

  local deferred = EAK.runtime._deferredChoices
  if deferred and EAK.runtime._deferredPickToken == pick.pickToken then
    EAK.runtime._deferredChoices = nil
    EAK.runtime._deferredPickToken = nil
    hadDeferred = true




    U:After(0.25, function()
      if not (EAK.runtime.enabledThisSession) then return end
      if EAK.runtime.pendingPick or EAK.runtime.pendingSelect then return end

      local expectedLvl = U:AutomationHistoryPeekNextLevel()
      local dh = HashChoices(deferred)
      local lo = EAK.runtime.lastOffer
      local alreadyCached = (lo and dh and lo.hash == dh and tonumber(lo.level or 0) == tonumber(expectedLvl))

      if not alreadyCached then

        EAK.runtime.forceNextPickLevel = true

        EAK.runtime.lastChoiceHash = nil
        EAK.runtime.lastLearnHash = nil

        local dpre = EAK.runtime._deferredPreSeen
        if dpre and dh and dpre.hash == dh then
          EAK.runtime._offerPreSeen = dpre
        else
          EAK.runtime._offerPreSeen = nil
        end
        Engine:CacheOffer(deferred)
        EAK.runtime._deferredPreSeen = nil
      end



      if EAK.runtime.pendingPick or EAK.runtime.pendingSelect then return end
      Engine:HandleChoices(deferred)
    end)
  end

  if not hadDeferred then
    EAK.runtime.forceNextPickLevel = true
    EAK.runtime.forceNewOfferView = true
    EAK.runtime.lastChoiceHash = nil
    EAK.runtime.lastLearnHash = nil
  end

  if pick.resumeAfterCommit and (not EAK.runtime.enabledThisSession) then
    local token = (EAK.runtime._resumeToken or 0) + 1
    EAK.runtime._resumeToken = token
    U:After(0.05, function()
      if EAK.runtime._resumeToken ~= token then return end
      if EAK.runtime.enabledThisSession then return end
      if EAK.runtime.pauseResumeArmed ~= true then return end
      EAK.runtime.pauseResumeArmed = nil
      EAK.runtime.pauseResumeKind = nil
      if EAK.SetStartButtonNote then EAK:SetStartButtonNote(nil) end
      EAK:SetEnabledThisSession(true)
      Engine:TryRequestChoice()
    end)
  end
end

function Engine:_FailPendingPick(failReason, currentChoices)
  local pick = EAK.runtime.pendingPick
  if not pick then return end

  local reason = failReason or "failed"
  if currentChoices then
    local h = HashChoices(currentChoices)
    if h and pick.offerHash and h ~= pick.offerHash then
      reason = reason .. " (offer changed)"
    end
  end


if failReason == 'server_rejected' then

  if not currentChoices and ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
    currentChoices = NormalizeChoices(ProjectEbonhold.Perks.currentChoice) or ProjectEbonhold.Perks.currentChoice
  end

  pick.retries = (tonumber(pick.retries) or 0) + 1
  local profile = EAK:GetProfile() or {}
  local maxRetries = tonumber(profile.serverRejectMaxRetries) or 5
  local delay = tonumber(profile.serverRejectRetryDelay) or 1.0
  if delay < 0.25 then delay = 0.25 end

  local decision = {
    action = 'rejected',
    reason = 'server_rejected',
    retries = pick.retries,
    max = maxRetries,
    viewKey = pick.viewKey,
    offerSeq = pick.offerSeq,
    offerHash = pick.offerHash,
    spellId = pick.spellId,
  }


  self:_AppendPendingStep(pick.level or 0, pick.offered or currentChoices or {}, decision)
  if pick.autoContext then
    U:AutomationHistoryAddAttempt(pick.level, pick.offered or currentChoices or {}, decision)
  end


  if pick.retries <= maxRetries then
    if EAK.SetStartButtonNote then
      EAK:SetStartButtonNote("|cffffaa00Retrying|r: server rejected (" .. tostring(pick.retries) .. "/" .. tostring(maxRetries) .. ")")
    end
    Chat("|cffffd100Ebonhold Automation Kit|r server rejected; retrying in " .. tostring(delay) .. "s (" .. tostring(pick.retries) .. "/" .. tostring(maxRetries) .. ")")


    EAK.runtime.pendingPick = nil
    EAK.runtime.pendingSelect = nil
    EAK.runtime._advanceForPickToken = nil


    EAK.runtime.lastChoiceHash = nil
    EAK.runtime.lastLearnHash = nil


    EAK.runtime._deferredChoices = nil
    EAK.runtime._deferredPickToken = nil

    local nowT = (type(GetTime) == 'function') and GetTime() or 0
    EAK.runtime.writeLockUntil = (nowT or 0) + delay

    local retryKey = tostring(pick.viewKey or pick.txnId or pick.pickToken or "0") .. "|" .. tostring(pick.retries)
    EAK.runtime._serverRejectRetryKey = retryKey

    U:After(delay, function()
      if not (EAK and EAK.runtime and EAK.runtime.enabledThisSession) then return end
      if EAK.runtime._serverRejectRetryKey ~= retryKey then return end
      if EAK.runtime.pendingPick or EAK.runtime.pendingSelect then return end


      local ch = nil
      if ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
        ch = NormalizeChoices(ProjectEbonhold.Perks.currentChoice) or ProjectEbonhold.Perks.currentChoice
      end
      if not ch and currentChoices then ch = currentChoices end

      if ch then
        EAK.runtime.lastChoiceHash = nil
        Engine:HandleChoices(ch)
      else

        Engine:TryRequestChoiceRefresh()
      end
    end)

    return
  end

end




  local errKey = pick.viewKey or pick.txnId or pick.pickToken
  if errKey then
    EAK.runtime._errorLRU = LRU_Ensure(EAK.runtime._errorLRU, 60)
    if not LRU_Has(EAK.runtime._errorLRU, errKey) then
      LRU_Add(EAK.runtime._errorLRU, errKey)
      if pick.autoContext then
        U:AutomationHistoryAddError(pick.level, {
          txnId = pick.txnId,
          offerHash = pick.offerHash,
          offerSeq = pick.offerSeq,
          spellId = pick.spellId,
          reason = reason,
          offered = pick.offered or {},
          steps = pick.historySteps or {},
          retries = pick.retries,
          resendCount = pick.resendCount,
        })
      end
    end
  elseif pick.autoContext then
    U:AutomationHistoryAddError(pick.level, {
      offerHash = pick.offerHash,
      offerSeq = pick.offerSeq,
      spellId = pick.spellId,
      reason = reason,
      offered = pick.offered or {},
      steps = pick.historySteps or {},
      retries = pick.retries,
      resendCount = pick.resendCount,
    })
  end



  self:_AppendPendingStep(pick.level or 0, pick.offered or {}, {
    action = 'error',


    errorKey = errKey or pick.viewKey or pick.txnId or pick.pickToken or "error",
    reason = reason,
    viewKey = pick.viewKey,
    offerSeq = pick.offerSeq,
    offerHash = pick.offerHash,
  })
  if EAK.SetStartButtonNote then
    EAK:SetStartButtonNote("|cffff5555Paused|r: " .. tostring(errKey or pick.viewKey or pick.txnId or pick.pickToken or "error"))
  end
  Chat("|cffffd100Ebonhold Automation Kit|r Paused: " .. tostring(reason))
  if EAK.runtime.enabledThisSession then
    EAK:SetEnabledThisSession(false)
  end


  EAK.runtime.pendingPick = nil
  EAK.runtime.pendingSelect = nil
  EAK.runtime._advanceForPickToken = nil

  self.state.rerollsUsedThisPick = 0


  EAK.runtime.lastChoiceHash = nil
  EAK.runtime.lastLearnHash = nil


  EAK.runtime._deferredChoices = nil
  EAK.runtime._deferredPickToken = nil
  EAK.runtime._deferredPreSeen = nil

  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  EAK.runtime.writeLockUntil = (nowT or 0) + 0.40

end

function Engine:CheckPendingPick(currentChoices)
  local pick = EAK.runtime.pendingPick
  if not pick then return false end

  if self:_IsPendingPickConfirmed(pick, currentChoices) then

    if currentChoices then
      EAK.runtime._deferredChoices = CopyChoices(currentChoices) or currentChoices
      EAK.runtime._deferredPickToken = pick.pickToken

      local pre = EAK.runtime._offerPreSeen
      local hh = HashChoices(currentChoices)
      if pre and hh and pre.hash == hh then
        local cp = {}
        if type(pre.unseen) == 'table' then
          for kk, vv in pairs(pre.unseen) do if vv then cp[kk] = true end end
        end
        EAK.runtime._deferredPreSeen = { hash = hh, classToken = pre.classToken, unseen = cp }
      else
        EAK.runtime._deferredPreSeen = nil
      end
    end
    self:_CommitPendingPick('confirmed')
    if currentChoices then return true end
    return false
  end


  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  local started = tonumber(pick.startedAt) or nowT
  local age = (nowT or 0) - (started or 0)
  local timeout = tonumber(EAK:GetProfile() and EAK:GetProfile().pickConfirmTimeout) or 8.0
  if timeout < 2.0 then timeout = 2.0 end
  if age >= timeout then
    self:_FailPendingPick('timeout', currentChoices)
    return false
  end





  if currentChoices then
    EAK.runtime._deferredChoices = CopyChoices(currentChoices) or currentChoices
    EAK.runtime._deferredPickToken = pick.pickToken

      local pre = EAK.runtime._offerPreSeen
      local hh = HashChoices(currentChoices)
      if pre and hh and pre.hash == hh then
        local cp = {}
        if type(pre.unseen) == 'table' then
          for kk, vv in pairs(pre.unseen) do if vv then cp[kk] = true end end
        end
        EAK.runtime._deferredPreSeen = { hash = hh, classToken = pre.classToken, unseen = cp }
      else
        EAK.runtime._deferredPreSeen = nil
      end
  end

  if currentChoices and pick.offerHash then
    local h = HashChoices(currentChoices)
    if h and h == pick.offerHash then
      pick.resendCount = (tonumber(pick.resendCount) or 0) + 1
      if pick.resendCount >= 1 and (tonumber(pick.retries) or 0) < 3 and self._origSelectPerk and pick.spellId then
        pick.retries = (tonumber(pick.retries) or 0) + 1
        U:After(0, function()
          if EAK.runtime.pendingPick == pick and self._origSelectPerk then
            pcall(self._origSelectPerk, pick.spellId)
          end
        end)
      end
      return true
    elseif h and pick.offerHash and h ~= pick.offerHash then
      pick.sawOfferChange = true
    end
  end


  return true
end

function Engine:OnSelectPerk(spellId)
  local sid = tonumber(spellId)
  if not sid then return end


  local offer = EAK.runtime.lastOffer
  local lvl = (offer and offer.level) or U:AutomationHistoryPeekNextLevel()
  local offerHash = offer and offer.hash or nil
  local offerSeq = offer and offer.seq or nil
  if not offerSeq and EAK.runtime.pendingSelect and tonumber(EAK.runtime.pendingSelect.spellId or 0) == sid then
    offerSeq = EAK.runtime.pendingSelect.offerSeq
    offerHash = offerHash or EAK.runtime.pendingSelect.offerHash
  end
  if not offerSeq then
    EAK.runtime._pickSeq = (EAK.runtime._pickSeq or 0) + 1
    offerSeq = EAK.runtime._pickSeq
  end

  local profile = EAK:GetProfile()


  local offered = (offer and offer.offered) or nil
  if type(offered) ~= 'table' or #offered == 0 then
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then
      local ok, raw = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
      local cur = ok and NormalizeChoices(raw) or nil
      if cur then
        self:CacheOffer(cur)
        offer = EAK.runtime.lastOffer
        offered = (offer and offer.offered) or offered
        offerHash = (offer and offer.hash) or offerHash
        offerSeq = (offer and offer.seq) or offerSeq
      end
    end
  end


  local wasOffered = false
  local pickedQ, pickedKey, pickedScore, pickedWhy = 0, nil, nil, nil
  if type(offered) == 'table' then
    for _, ev in ipairs(offered) do
      if tonumber(ev.spellId) == sid then
        wasOffered = true
        pickedQ = tonumber(ev.quality) or 0
        pickedKey = ev.key
        pickedScore = ev.score
        pickedWhy = ev.why
        break
      end
    end
  end
  if (type(offered) == 'table' and #offered > 0) and not wasOffered then
    return
  end

  pickedQ = tonumber(pickedQ) or 0
  pickedKey = pickedKey or U:MakeKey(sid, pickedQ)
  if pickedScore == nil then
    pickedScore, pickedWhy = ScoreChoice(profile, { spellId = sid, quality = pickedQ })
  end


  local totalR = profile.maxRollUsageInRow
  if totalR == nil then totalR = profile.maxRerollsPerLevel end
  totalR = tonumber(totalR or 10) or 10
  local usedR = tonumber(Engine.state.rerollsUsedThisPick or 0) or 0
  local rerollsRemaining = math.max(0, totalR - usedR)

  local pickToken = tostring(offerSeq or 0) .. ':' .. tostring(sid)


  local existing = EAK.runtime.pendingPick
  if existing and existing.pickToken == pickToken then
    existing.duplicateCalls = (tonumber(existing.duplicateCalls) or 0) + 1
    return
  end


  local lbChoices = {}
  if type(offered) == 'table' and #offered > 0 then
    for i = 1, math.min(3, #offered) do
      local ev = offered[i]
      if ev and ev.spellId then
        table.insert(lbChoices, { spellId = ev.spellId, quality = ev.quality })
      end
    end
  else
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then
      local ok, raw = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
      local cur = ok and NormalizeChoices(raw) or nil
      if cur then
        for i = 1, math.min(3, #cur) do
          local c = cur[i]
          if c and c.spellId then
            table.insert(lbChoices, { spellId = c.spellId, quality = c.quality })
          end
        end
      end
    end
  end


  local beforeTotal, beforeSpell = GetGrantedSnapshot(sid)

  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  local nowMs = math.floor((nowT or 0) * 1000)
  local nonce = tostring(EAK.runtime.sessionNonce or "0")
  local txnId = (offer and offer.txnId) or (nonce .. "|" .. tostring(offerSeq or 0) .. "|" .. tostring(lvl) .. "|" .. tostring(nowMs) .. "|" .. tostring(offerHash or ""))



  local vh = offerHash or HashChoices(lbChoices)
  local viewKey = (offer and offer.viewKey) or (nonce .. "|" .. tostring(offerSeq or 0) .. "|" .. tostring(lvl) .. "|" .. tostring(vh or ""))



  local autoContext = false
  if EAK.runtime.pendingSelect and tonumber(EAK.runtime.pendingSelect.spellId or 0) == sid then
    autoContext = true
  end
  local ph0 = EAK.runtime.pendingHistory
  if not autoContext and ph0 and tonumber(ph0.level or 0) == tonumber(lvl) and type(ph0.steps) == 'table' and #ph0.steps > 0 then
    autoContext = true
  end

  local resumeAfterCommit = false
  if (not EAK.runtime.enabledThisSession) and (EAK.runtime.pauseResumeArmed == true) then
    resumeAfterCommit = true
  end


  local stepsCopy = {}
  local ph = EAK.runtime.pendingHistory
  if ph and tonumber(ph.level or 0) == tonumber(lvl) and type(ph.steps) == 'table' then
    for _, st in ipairs(ph.steps) do
      table.insert(stepsCopy, st)
    end
  end

  local finalDecision = {
    action = 'select',
    txnId = txnId,
    viewKey = viewKey,
    offerSeq = offerSeq,
    offerHash = offerHash,
    charLevel = self:_GetStableLevel(),
    spellId = sid,
    key = pickedKey,
    quality = pickedQ,
    bestScore = pickedScore,
    bestWhy = pickedWhy,
    minScoreToKeep = tonumber(profile.minScoreToKeep) or 0,
    rerollsRemaining = rerollsRemaining,
    rerollsTotal = totalR,
    rerollsUsed = usedR,
    reason = 'Selected',
  }

  if autoContext then
    local last = stepsCopy[#stepsCopy]
    if not (last and last.decision and last.decision.action == 'select' and tonumber(last.decision.spellId or 0) == sid) then
      table.insert(stepsCopy, { offered = offered or {}, decision = finalDecision })
    end
  end

  EAK.runtime.pendingPick = {
    pickToken = pickToken,
    txnId = txnId,
    viewKey = viewKey,
    spellId = sid,
    offerHash = offerHash,
    offerSeq = offerSeq,
    level = lvl,
    offered = offered or {},
    logbookChoices = lbChoices,
    grantedTotalBefore = beforeTotal,
    grantedSpellBefore = beforeSpell,
    autoContext = autoContext,
    resumeAfterCommit = resumeAfterCommit,
    historySteps = stepsCopy,
    finalDecision = finalDecision,
    resendCount = 0,
    retries = 0,
    startedAt = nowT,
  }


end



function Engine:_OnRerollRequested(source)

  if EAK and EAK.runtime then
    if EAK.runtime._inRerollHook then return end
  end


  self.state.rerollsUsedThisPick = (self.state.rerollsUsedThisPick or 0) + 1




  do
    local nowT = (type(GetTime) == 'function') and GetTime() or 0
    local usedBefore = GetServerUsedRerolls()
    if EAK and EAK.runtime then
      EAK.runtime._rerollAwait = {
        expectedUsed = (usedBefore ~= nil) and (tonumber(usedBefore) + 1) or nil,
        t = nowT,
      }
    end
  end


  EAK.runtime.forceNewOfferView = true
  EAK.runtime.pendingSelect = nil


  local offer = EAK.runtime.lastOffer
  local lvl = (offer and offer.level) or U:AutomationHistoryPeekNextLevel()
  local offered = (offer and offer.offered) or {}
  local offerHash = (offer and offer.hash) or nil
  EAK.runtime.forceNewOfferViewUntilHash = offerHash
  local offerSeq = (offer and offer.seq) or (EAK.runtime.offerSeq or 0)
  local viewKey = (offer and offer.viewKey) or nil
  local txnId = (offer and offer.txnId) or nil


  local skip = EAK.runtime._skipNextRerollHistory == true
  if skip then
    EAK.runtime._skipNextRerollHistory = nil
    local ph = EAK.runtime.pendingHistory
    if ph and tonumber(ph.level or 0) == tonumber(lvl) and type(ph.steps) == 'table' and #ph.steps > 0 then
      local last = ph.steps[#ph.steps]
      if last and last.decision and last.decision.action == 'reroll' then
        return
      end
    end
  end

  local profile = EAK:GetProfile()
  local rem, totalR, usedR = GetRerollsRemaining(profile)
    local decision = {
    action = 'reroll',
    txnId = txnId,
    viewKey = viewKey,
    offerSeq = offerSeq,
    offerHash = offerHash,
    charLevel = self:_GetStableLevel(),

    rerollsRemaining = rem,
    rerollsTotal = totalR,
    rerollsUsed = usedR,
    serverRerollsRemaining = rem,
    serverRerollsTotal = totalR,
    serverRerollsUsed = usedR,
    reason = (source == 'manual') and 'Manual reroll' or 'Reroll',
  }

  self:_AppendPendingStep(lvl, offered, decision)
end

function Engine:_OnBanishRequested(source, perkIndex)

  if EAK and EAK.runtime then
    if EAK.runtime._inBanishHook then return end
  end

  local idx0 = tonumber(perkIndex)
  if idx0 == nil then return end

  local nowT = (type(GetTime) == 'function') and GetTime() or 0
  EAK.runtime.forceNewOfferView = true
  EAK.runtime.pendingSelect = nil

  local offer = EAK.runtime.lastOffer
  local lvl = (offer and offer.level) or U:AutomationHistoryPeekNextLevel()
  local offered = (offer and offer.offered) or {}
  local offerHash = (offer and offer.hash) or nil
  EAK.runtime.forceNewOfferViewUntilHash = offerHash
  local offerSeq = (offer and offer.seq) or (EAK.runtime.offerSeq or 0)
  local viewKey = (offer and offer.viewKey) or nil
  local txnId = (offer and offer.txnId) or nil

  EAK.runtime.pendingBanish = { slot = idx0, offerHash = offerHash, offerSeq = offerSeq, viewKey = viewKey, startedAt = nowT }

  local skip = EAK.runtime._skipNextBanishHistory == true
  if skip then
    EAK.runtime._skipNextBanishHistory = nil
    local ph = EAK.runtime.pendingHistory
    if ph and tonumber(ph.level or 0) == tonumber(lvl) and type(ph.steps) == 'table' and #ph.steps > 0 then
      local last = ph.steps[#ph.steps]
      if last and last.decision and last.decision.action == 'banish' then
        return
      end
    end
  end

  local banishSid, banishQ, banishKey = nil, 0, nil
  if type(offered) == 'table' then
    local ev = offered[idx0 + 1]
    if ev then
      banishSid = tonumber(ev.spellId or 0)
      banishQ = tonumber(ev.quality or 0) or 0
      banishKey = ev.key or (banishSid and U:MakeKey(banishSid, banishQ) or nil)
    end
  end
  if banishSid == 0 then banishSid = nil end

  local remB = GetBanishesRemaining()
  local decision = {
    action = 'banish',
    txnId = txnId,
    viewKey = viewKey,
    offerSeq = offerSeq,
    offerHash = offerHash,
    charLevel = self:_GetStableLevel(),
    banishIndex = idx0,
    spellId = banishSid,
    key = banishKey,
    quality = banishQ,
    banishesRemaining = remB,
    reason = (source == 'manual') and 'Manual banish' or 'Banish',
  }

  self:_AppendPendingStep(lvl, offered, decision)
end

function Engine:HookPerkService()



  if not ProjectEbonhold then return end

  local ps = ProjectEbonhold.PerkService
  local perks = ProjectEbonhold.Perks

  local function GetCurrentChoiceUnsafe()
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then
      local ok, cur = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
      if ok then return cur end
    end
    if ProjectEbonhold and ProjectEbonhold.Perks then
      return ProjectEbonhold.Perks.currentChoice
    end
    return nil
  end

  local function ShouldAdvancePickLevel()
    local rt = EAK and EAK.runtime
    if not rt then return false end


    if rt._eak_requesting_choice then return true end





    local pick = rt.pendingPick
    if not pick then return false end

    local cur = GetCurrentChoiceUnsafe()
    if not (cur == nil or (type(cur) == 'table' and #cur == 0)) then
      return false
    end

    local token = pick.pickToken
    if token and rt._advanceForPickToken == token then
      return false
    end
    rt._advanceForPickToken = token
    return true
  end


  local function HookRequestChoice(tbl, origField)
    if not tbl or type(tbl) ~= 'table' then return false end
    if not tbl.RequestChoice or type(tbl.RequestChoice) ~= 'function' then return false end
    if self[origField] then return true end

    self[origField] = tbl.RequestChoice
    tbl.RequestChoice = function(...)




      if ShouldAdvancePickLevel() then
        EAK.runtime.forceNextPickLevel = true

        EAK.runtime.pendingSelect = nil
      end
      return self[origField](...)
    end
    return true
  end


  local function HookRequestReroll(tbl, origField)
    if not tbl or type(tbl) ~= 'table' then return false end
    if not tbl.RequestReroll or type(tbl.RequestReroll) ~= 'function' then return false end
    if self[origField] then return true end

    self[origField] = tbl.RequestReroll
    tbl.RequestReroll = function(...)

      if EAK.runtime._inRerollHook then
        return self[origField](...)
      end


      self:_OnRerollRequested('manual')


      EAK.runtime._inRerollHook = true
      local ok, r1, r2, r3, r4 = pcall(self[origField], ...)
      EAK.runtime._inRerollHook = false
      if ok then return r1, r2, r3, r4 end
    end
    return true
  end

  local function HookBanishPerk(tbl, origField)
    if not tbl or type(tbl) ~= 'table' then return false end
    if not tbl.BanishPerk or type(tbl.BanishPerk) ~= 'function' then return false end
    if self[origField] then return true end

    self[origField] = tbl.BanishPerk
    tbl.BanishPerk = function(...)
      local idx = select(1, ...)

      if EAK.runtime._inBanishHook then
        return self[origField](...)
      end

      self:_OnBanishRequested('manual', idx)

      EAK.runtime._inBanishHook = true
      local ok, r1, r2, r3, r4 = pcall(self[origField], ...)
      EAK.runtime._inBanishHook = false
      if ok then return r1, r2, r3, r4 end
    end
    return true
  end


  local function HookSelectPerk(tbl, origField)
    if not tbl or type(tbl) ~= 'table' then return false end
    if not tbl.SelectPerk or type(tbl.SelectPerk) ~= 'function' then return false end
    if self[origField] then return true end

    self[origField] = tbl.SelectPerk

    if origField == "_origSvcSelectPerk" then
      self._origSelectPerk = self[origField]
    elseif (not self._origSelectPerk) and origField == "_origPerksSelectPerk" then
      self._origSelectPerk = self[origField]
    end

    tbl.SelectPerk = function(...)
      local sid = select(1, ...)

      if type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() and EAK and EAK.Utils and EAK.Utils.TryInsertSpellLink then
        local q = nil
        local ch = nil
        if ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.currentChoice) == 'table' then
          ch = ProjectEbonhold.Perks.currentChoice
        elseif ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then
          local okc, raw = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
          if okc then ch = raw end
        end
        if type(ch) == 'table' then
          for _, c in ipairs(ch) do
            if c and tonumber(c.spellId) == tonumber(sid) then
              q = tonumber(c.quality) or 0
              break
            end
          end
        end
        if EAK.Utils:TryInsertSpellLink(sid, q) then
          return false
        end
      end

      if EAK and EAK.runtime and EAK.runtime._inSelectHook then
        return self[origField](...)
      end

      if EAK and EAK.runtime then EAK.runtime._inSelectHook = true end
      local ok, r1, r2, r3, r4 = pcall(self[origField], ...)
      if EAK and EAK.runtime then EAK.runtime._inSelectHook = false end
      if ok and r1 ~= false then
        self:OnSelectPerk(sid)
        return r1, r2, r3, r4
      end

      if EAK and EAK.runtime and EAK.runtime.pendingSelect and tonumber(EAK.runtime.pendingSelect.spellId or 0) == tonumber(sid or 0) then
        EAK.runtime.pendingSelect = nil
        EAK.runtime.lastChoiceHash = nil
        EAK.runtime.lastLearnHash = nil
      end

      if ok then return r1, r2, r3, r4 end
      return false
    end
    return true
  end


  self.state.hookedChoice = HookRequestChoice(ps, "_origSvcRequestChoice") or self.state.hookedChoice
  self.state.hookedChoice = HookRequestChoice(perks, "_origPerksRequestChoice") or self.state.hookedChoice

  self.state.hookedReroll = HookRequestReroll(ps, "_origSvcRequestReroll") or self.state.hookedReroll
  self.state.hookedReroll = HookRequestReroll(perks, "_origPerksRequestReroll") or self.state.hookedReroll

  self.state.hookedBanish = HookBanishPerk(ps, "_origSvcBanishPerk") or self.state.hookedBanish
  self.state.hookedBanish = HookBanishPerk(perks, "_origPerksBanishPerk") or self.state.hookedBanish

  self.state.hookedSelect = HookSelectPerk(ps, "_origSvcSelectPerk") or self.state.hookedSelect
  self.state.hookedSelect = HookSelectPerk(perks, "_origPerksSelectPerk") or self.state.hookedSelect


  local svcDone = true
  if ps and type(ps) == 'table' then
    if ps.RequestChoice and not self._origSvcRequestChoice then svcDone = false end
    if ps.RequestReroll and not self._origSvcRequestReroll then svcDone = false end
    if ps.BanishPerk and not self._origSvcBanishPerk then svcDone = false end
    if ps.SelectPerk and not self._origSvcSelectPerk then svcDone = false end
  end
  local perksDone = true
  if perks and type(perks) == 'table' then
    if perks.RequestChoice and not self._origPerksRequestChoice then perksDone = false end
    if perks.RequestReroll and not self._origPerksRequestReroll then perksDone = false end
    if perks.BanishPerk and not self._origPerksBanishPerk then perksDone = false end
    if perks.SelectPerk and not self._origPerksSelectPerk then perksDone = false end
  end

  if svcDone and perksDone then
    self.state.hookedService = true
  end
end

function Engine:Initialize()


  if not EAK.runtime.sessionNonce then
    local t = (type(time) == 'function') and time() or 0
    local r = (type(math.random) == 'function') and math.random(100000, 999999) or 0
    EAK.runtime.sessionNonce = tostring(t) .. ":" .. tostring(r)
  end

  self.state.currentLevel = UnitLevel("player")
  self.state.rerollsUsedThisPick = 0

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LEVEL_UP")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LEVEL_UP" then
      local newLevel = select(1, ...)
      self.state.currentLevel = tonumber(newLevel) or UnitLevel("player")
    elseif event == "PLAYER_ENTERING_WORLD" then
      self.state.rerollsUsedThisPick = 0
      self.state.currentLevel = UnitLevel("player")
      EAK.runtime.pendingPick = nil
      EAK.runtime.pendingSelect = nil
      EAK.runtime.pendingBanish = nil
      EAK.runtime.pendingHistory = nil
      EAK.runtime._advanceForPickToken = nil
      EAK.runtime.lastChoiceHash = nil

      if (self.state.currentLevel or 1) <= 1 then
        U:ClearAutomationHistory()
        EAK.runtime._didClearAutomationForReset = true
        EAK.runtime._logbookLRU = nil
        EAK.runtime._commitLRU = nil
        EAK.runtime._errorLRU = nil

        local t = (type(time) == 'function') and time() or 0
        local r = (type(math.random) == 'function') and math.random(100000, 999999) or 0
        EAK.runtime.sessionNonce = tostring(t) .. ":" .. tostring(r)
      end
    end
  end)


  local ticker = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    ticker = ticker + elapsed
    if ticker < 1.25 then return end
    ticker = 0

    local hadOffer = false



    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice then


      local ok, raw = pcall(ProjectEbonhold.PerkService.GetCurrentChoice)
      local cur = ok and NormalizeChoices(raw) or nil
      if cur then
        hadOffer = true



        if Engine:CheckPendingPick(cur) then
          return
        end

        local h = HashChoices(cur)
        Engine:CacheOffer(cur)

        local lk = (EAK.runtime.lastOffer and EAK.runtime.lastOffer.viewKey) or h
        if lk and EAK.runtime.lastLearnHash ~= lk then
          EAK.runtime.lastLearnHash = lk
          LearnChoices(EAK:GetProfile(), cur)
          if EAK.runtime.enabledThisSession then
            Engine:HandleChoices(cur)
          end
        end
      end
    end


    Engine:CheckPendingPick(nil)









    local curLevel = UnitLevel("player") or 1
    if curLevel <= 1 then
      if not EAK.runtime._didClearAutomationForReset then
        U:ClearAutomationHistory()
        EAK.runtime._didClearAutomationForReset = true
        EAK.runtime._logbookLRU = nil
        EAK.runtime._commitLRU = nil
        EAK.runtime._errorLRU = nil

        local t = (type(time) == 'function') and time() or 0
        local r = (type(math.random) == 'function') and math.random(100000, 999999) or 0
        EAK.runtime.sessionNonce = tostring(t) .. ":" .. tostring(r)
      end

      EAK.runtime.lastChoiceHash = nil
      EAK.runtime.lastLearnHash = nil
      EAK.runtime.lastLogbookHash = nil
      EAK.runtime.pendingPick = nil
      EAK.runtime.pendingSelect = nil
      EAK.runtime.pendingBanish = nil
      EAK.runtime.pendingHistory = nil
      self.state.rerollsUsedThisPick = 0
    else
      EAK.runtime._didClearAutomationForReset = false
    end
  end)


  local tries = 0
  local hooker = CreateFrame("Frame")
  hooker:SetScript("OnUpdate", function(self, elapsed)
    tries = tries + 1
    Engine:HookPerkUI()
    if (Engine.state.hooked and Engine.state.hookedService) or tries > 600 then
      self:SetScript("OnUpdate", nil)
    end
  end)
end
