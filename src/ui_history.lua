local EAK = _G.EbonholdAutomationKit
local U = EAK.Utils

EAK.HistoryUI = EAK.HistoryUI or {}
local HU = EAK.HistoryUI

HU.auto = HU.auto or { panel = nil, rows = {}, selectedIndex = 1, display = {}, sortKey = "level", sortAsc = true, filter = "all", search = "", popup = nil }
HU.book = HU.book or { panel = nil, rows = {}, filtered = {}, search = "", sortKey = "count", sortAsc = false }

local function EnsureUtils()
  if U then return true end
  if EAK and EAK.Utils then U = EAK.Utils return true end
  local e = _G.EbonholdAutomationKit
  if e and e.Utils then
    EAK = e
    U = e.Utils
    return true
  end
  return false
end

function HU:GetTextPopup()
  if self._textPopup then return self._textPopup end

  local f = CreateFrame("Frame", "EAK_HistoryTextPopup", UIParent)
  f:SetSize(760, 520)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("Export")
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local sf = CreateFrame("ScrollFrame", "EAK_HistoryTextPopupScroll", f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 16, -46)
  sf:SetPoint("BOTTOMRIGHT", -34, 16)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetFontObject(ChatFontNormal)
  eb:SetAutoFocus(false)
  eb:SetWidth(700)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  eb:SetScript("OnTextChanged", function(self)
    sf:UpdateScrollChildRect()
  end)
  sf:SetScrollChild(eb)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(eb, { multiline = true })
  end

  f.eb = eb

  f:SetScript("OnShow", function()
    if f.eb then
      f.eb:SetFocus()
      f.eb:HighlightText()
      sf:SetVerticalScroll(0)
    end
  end)
  f:Hide()

  self._textPopup = f
  return f
end

function HU:ShowTextPopup(title, text)
  local f = self:GetTextPopup()
  f.title:SetText(title or "Export")
  f.eb:SetText(text or "")
  f:Show()
end

local function Auto_GetSortState()
  EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
  local ui = EbonholdAutomationKitDB.uiAutoHistory
  local key = ui.sortKey or HU.auto.sortKey or "level"
  local asc = (ui.sortAsc == true)
  if ui.sortKey == nil and ui.sortAsc == nil then
    key = "level"
    asc = true
  end
  return key, asc
end

local function Auto_SetSort(key)
  EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
  local ui = EbonholdAutomationKitDB.uiAutoHistory
  if ui.sortKey == key then
    ui.sortAsc = not (ui.sortAsc == true)
  else
    ui.sortKey = key
    if key == "level" then ui.sortAsc = true
    elseif key == "name" then ui.sortAsc = true
    else ui.sortAsc = false end
  end
end

local function Auto_GetViewState()
  EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
  local ui = EbonholdAutomationKitDB.uiAutoHistory
  local filter = ui.filter or HU.auto.filter or "all"
  local search = ui.search or HU.auto.search or ""
  if filter == nil or filter == "" then filter = "all" end
  if search == nil then search = "" end
  return tostring(filter), tostring(search)
end

local function Auto_SetFilter(filter)
  EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
  EbonholdAutomationKitDB.uiAutoHistory.filter = filter
end

local function Auto_SetSearch(text)
  EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
  EbonholdAutomationKitDB.uiAutoHistory.search = text
end

local function Auto_FilterLabel(f)
  f = tostring(f or "all")
  if f == "all" then return "All" end
  if f == "picks" then return "Picks" end
  if f == "offers" then return "Offers" end
  if f == "rolls" then return "Rolls" end
  if f == "banished" then return "Banished" end
  if f == "errors" then return "Errors" end
  if f == "priority" then return "Priority" end
  return f
end

local function CountRerolls(entry)
  if entry and entry.kind == 'banish' then
    return 0
  end
  local fp = entry and entry.finalPick or nil
  if fp and fp.rerollsUsed ~= nil then
    return tonumber(fp.rerollsUsed) or 0
  end
  local n = 0
  for _, a in ipairs(entry and entry.attempts or {}) do
    if a and a.decision and a.decision.action == "reroll" then
      n = n + 1
    end
  end
  return n
end

local function GetPickMeta(entry)
  if entry and entry.kind == 'banish' then
    local sid = tonumber(entry.spellId)
    local q = tonumber(entry.quality) or 0
    if not sid then return nil, "", q end
    local name = entry.name or U:SafeSpellName(sid)
    return sid, name, q
  end
  local pick = entry and entry.finalPick or nil
  local sid = pick and pick.spellId or nil
  local q = pick and pick.quality or nil

  if not sid then
    return nil, "", 0
  end

  sid = tonumber(sid)
  q = tonumber(q)
  if q == nil then
    local key = pick and pick.key or nil
    if key then
      local _, pq = U:ParseKey(key)
      q = tonumber(pq)
    end
  end
  if q == nil then
    local echoDB = EAK:GetEchoDB() or {}
    for qq = 0, 4 do
      local key = U:MakeKey(sid, qq)
      local meta = echoDB[key]
      if meta then
        q = tonumber(meta.quality) or qq
        break
      end
    end
  end
  if q == nil then q = 0 end

  local name = U:SafeSpellName(sid)
  return sid, name, q
end

local function GetAutoDisplayList()
  local h = U:GetAutomationHistory()
  local entries = h.entries or {}
  local errors = h.errors or {}
  local out = {}

  local filter, search = Auto_GetViewState()
  HU.auto.filter = filter
  HU.auto.search = search
  local s = U:StripWoWFormatting(U:Trim(search or "")):lower()

  local function entryName(e)
    if e and e.kind == 'error' then
      local sid = tonumber(e.spellId)
      if sid then return U:SafeSpellName(sid) end
      return ""
    end
    local _, n = GetPickMeta(e)
    return n or ""
  end

  local function matchesSearch(e)
    if s == "" then return true end

    local wantedQ = {}
    local textTokens = {}
    for w in string.gmatch(s, "%S+") do
      local tok = tostring(w):lower()
      local q = nil
      if tok == "common" then q = 0
      elseif tok == "uncommon" then q = 1
      elseif tok == "rare" then q = 2
      elseif tok == "epic" then q = 3
      elseif tok == "legendary" or tok == "legend" then q = 4 end

      if q ~= nil then
        wantedQ[q] = true
      else
        table.insert(textTokens, tok)
      end
    end

    local function scanOfferedText(off, token)
      if type(off) ~= 'table' then return false end
      for _, c in ipairs(off) do
        local sid = tonumber(c and c.spellId)
        if sid then
          local cn = U:StripWoWFormatting(U:SafeSpellName(sid) or ""):lower()
          if cn:find(token, 1, true) then return true end
        end
      end
      return false
    end

    local function offeredHasWantedQuality(off)
      if next(wantedQ) == nil then return true end
      if type(off) ~= 'table' then return false end
      for _, c in ipairs(off) do
        local q = tonumber(c and (c.quality or c.q))
        if q ~= nil and wantedQ[q] then return true end
      end
      return false
    end

    local function entryMatchesQuality()
      if next(wantedQ) == nil then return true end
      if not e or e.kind == 'error' then return false end

      if filter == 'picks' or filter == 'priority' then
        local _, _, pq = GetPickMeta(e)
        return wantedQ[tonumber(pq) or 0] == true
      elseif filter == 'offers' then
        if offeredHasWantedQuality(e and e.offered) then return true end
        for _, a in ipairs(e and e.attempts or {}) do
          if offeredHasWantedQuality(a and a.offered) then return true end
        end
        for _, st in ipairs(e and e.steps or {}) do
          if offeredHasWantedQuality(st and st.offered) then return true end
        end
        return false
      else
        local _, _, pq = GetPickMeta(e)
        if wantedQ[tonumber(pq) or 0] then return true end
        if offeredHasWantedQuality(e and e.offered) then return true end
        for _, a in ipairs(e and e.attempts or {}) do
          if offeredHasWantedQuality(a and a.offered) then return true end
        end
        for _, st in ipairs(e and e.steps or {}) do
          if offeredHasWantedQuality(st and st.offered) then return true end
        end
        return false
      end
    end

    if not entryMatchesQuality() then return false end
    if #textTokens == 0 then return true end

    local function tokenMatchesAnywhere(token)
      local n = U:StripWoWFormatting(entryName(e) or ""):lower()
      if n:find(token, 1, true) then return true end

      if e and e.kind == 'error' then
        local r = U:StripWoWFormatting(tostring(e.reason or "")):lower()
        if r:find(token, 1, true) then return true end
      end

      if scanOfferedText(e and e.offered, token) then return true end
      for _, a in ipairs(e and e.attempts or {}) do
        if scanOfferedText(a and a.offered, token) then return true end
      end
      for _, st in ipairs(e and e.steps or {}) do
        if scanOfferedText(st and st.offered, token) then return true end
      end

      return false
    end

    for _, tok in ipairs(textTokens) do
      if not tokenMatchesAnywhere(tok) then
        return false
      end
    end

    return true
  end


  local function CountRerollsUpTo(attempts, maxIdx)
    local n = 0
    if type(attempts) ~= 'table' then return 0 end
    maxIdx = tonumber(maxIdx) or #attempts
    if maxIdx < 1 then return 0 end
    if maxIdx > #attempts then maxIdx = #attempts end
    for i = 1, maxIdx do
      local a = attempts[i]
      if a and a.decision and a.decision.action == "reroll" then
        n = n + 1
      end
    end
    return n
  end

  local function MakeBanishRow(level, parentEntry, attempt, attemptIndex, isPending)
    local dec = (attempt and attempt.decision) or {}
    local sid = tonumber(dec.spellId or 0)
    if sid == 0 then sid = nil end

    local q = tonumber(dec.quality)
    if q == nil and dec.key then
      local _, qq = U:ParseKey(dec.key)
      q = tonumber(qq)
    end
    q = tonumber(q) or 0

    local name = nil
    if sid then
      name = U:SafeSpellName(sid)
    end
    if (not name or name == "") and type(attempt and attempt.offered) == 'table' then
      local bi = tonumber(dec.banishIndex)
      if bi ~= nil then
        local ev = attempt.offered[bi + 1]
        if ev then
          name = ev.name or (ev.spellId and U:SafeSpellName(ev.spellId)) or name
          if q == 0 and ev.quality ~= nil then q = tonumber(ev.quality) or q end
        end
      end
    end

    local rerU = CountRerollsUpTo(parentEntry and parentEntry.attempts, attemptIndex)

    return {
      kind = 'banish',
      ts = attempt and attempt.ts,
      t = attempt and attempt.t,
      level = level,
      subIndex = tonumber(attemptIndex) or 0,
      parent = parentEntry,
      offered = (attempt and attempt.offered) or (parentEntry and parentEntry.offered) or {},
      decision = dec,
      spellId = sid,
      quality = q,
      name = name or "",
      rerollsUsed = rerU,
      isPending = isPending == true,
    }
  end

  local function AppendBanishRowsFromEntry(e, isPending)
    if not e then return end
    local lvl = tonumber(e.level) or 0
    if lvl <= 0 then return end
    for i, a in ipairs(e.attempts or {}) do
      local d = a and a.decision or nil
      if d and d.action == 'banish' then
        local br = MakeBanishRow(lvl, e, a, i, isPending)
        if br and matchesSearch(br) then
          table.insert(out, br)
        end
      end
    end
  end

  local includeBanish = (filter == 'all' or filter == 'offers' or filter == 'banished')
  local includePicks = (filter ~= 'banished')

  if filter == 'errors' then
    for i = 1, #errors do
      local e = errors[i]
      if e and matchesSearch(e) then
        table.insert(out, e)
      end
    end
  else
    if includeBanish then
      for i = 1, #entries do
        local e = entries[i]
        if e then
          AppendBanishRowsFromEntry(e, false)
        end
      end

      local pending = h.pending or {}
      for lvl, pe in pairs(pending) do
        if type(pe) == 'table' then
          pe.level = tonumber(pe.level) or tonumber(lvl) or pe.level
          AppendBanishRowsFromEntry(pe, true)
        end
      end
    end

    if includePicks then
      for i = 1, #entries do
        local e = entries[i]
        if e and matchesSearch(e) then
          if filter == 'rolls' then
            if CountRerolls(e) > 0 then table.insert(out, e) end
          elseif filter == 'picks' or filter == 'offers' or filter == 'all' or filter == 'priority' then
            table.insert(out, e)
          else
            table.insert(out, e)
          end
        end
      end
    end
  end

  local sortKey, asc = Auto_GetSortState()
  if filter == 'priority' then
    sortKey = "priority"
    if EbonholdAutomationKitDB.uiAutoHistory and EbonholdAutomationKitDB.uiAutoHistory.sortKey ~= "priority" then
      asc = false
    end
  end
  table.sort(out, function(a, b)
    if a == b then return false end
    if not a then return false end
    if not b then return true end

    local al = tonumber(a.level) or 0
    local bl = tonumber(b.level) or 0
    local ar = (a and a.kind == 'error') and 0 or CountRerolls(a)
    local br = (b and b.kind == 'error') and 0 or CountRerolls(b)
    local an = U:StripWoWFormatting(entryName(a) or ""):lower()
    local bn = U:StripWoWFormatting(entryName(b) or ""):lower()
    local asub = (a and a.kind == 'banish') and (tonumber(a.subIndex) or 0) or 9999
    local bsub = (b and b.kind == 'banish') and (tonumber(b.subIndex) or 0) or 9999

    local function cmpStr(x, y, ascending)
      if x == y then return nil end
      if ascending then return x < y else return x > y end
    end
    local function cmpNum(x, y, ascending)
      if x == y then return nil end
      if ascending then return x < y else return x > y end
    end

    local function pickBaseWeight(e)
      if not e or e.kind == 'error' then return -1e18 end
      local fp = e.finalPick or {}
      local why = fp.why
      if type(why) == 'string' then
        local m = string.match(why, "base=([%-%d%.]+)")
        local n = tonumber(m)
        if n ~= nil then return n end
      end
      return tonumber(fp.score) or 0
    end

    local r
    if sortKey == "level" then
      r = cmpNum(al, bl, asc); if r ~= nil then return r end
      r = cmpNum(asub, bsub, true); if r ~= nil then return r end
      r = cmpStr(an, bn, true); if r ~= nil then return r end
      r = cmpNum(ar, br, true); if r ~= nil then return r end
      return tostring(a) < tostring(b)
    elseif sortKey == "name" then
      r = cmpStr(an, bn, asc); if r ~= nil then return r end
      r = cmpNum(al, bl, true); if r ~= nil then return r end
      r = cmpNum(asub, bsub, true); if r ~= nil then return r end
      r = cmpNum(ar, br, true); if r ~= nil then return r end
      return tostring(a) < tostring(b)
    elseif sortKey == "priority" then
      local ap = pickBaseWeight(a)
      local bp = pickBaseWeight(b)
      r = cmpNum(ap, bp, asc); if r ~= nil then return r end
      r = cmpNum(al, bl, true); if r ~= nil then return r end
      r = cmpNum(asub, bsub, true); if r ~= nil then return r end
      r = cmpStr(an, bn, true); if r ~= nil then return r end
      r = cmpNum(ar, br, true); if r ~= nil then return r end
      return tostring(a) < tostring(b)
    else
      r = cmpNum(ar, br, asc); if r ~= nil then return r end
      r = cmpNum(al, bl, true); if r ~= nil then return r end
      r = cmpNum(asub, bsub, true); if r ~= nil then return r end
      r = cmpStr(an, bn, true); if r ~= nil then return r end
      return tostring(a) < tostring(b)
    end
  end)

  return out
end

local function Auto_ExportText()
  local filter, search = Auto_GetViewState()
  local list = GetAutoDisplayList()
  local lines = {}
  table.insert(lines, "Ebonhold Automation Kit - Automation History Export")
  table.insert(lines, "Generated: " .. (U:NowStamp() or ""))
  table.insert(lines, "Filter: " .. tostring(filter) .. "    Search: " .. tostring(search or ""))
  table.insert(lines, "Count: " .. tostring(#list))
  table.insert(lines, "")

  for _, e in ipairs(list) do
    if e.kind == 'error' then
      local sid = tonumber(e.spellId)
      local nm = sid and U:SafeSpellName(sid) or "(unknown)"
      table.insert(lines, string.format("ERROR  Lv.%s  spell=%s (%s)", tostring(e.level or "?"), nm, tostring(sid or "?")))
      if e.txnId then table.insert(lines, "  txn=" .. tostring(e.txnId)) end
      if e.reason then table.insert(lines, "  reason=" .. tostring(e.reason)) end
      if e.retries or e.resendCount then
        table.insert(lines, "  retries=" .. tostring(e.retries or 0) .. "  resends=" .. tostring(e.resendCount or 0))
      end
      for i, st in ipairs(e.steps or {}) do
        local d = st.decision or {}
        local off = {}
        for _, o in ipairs(st.offered or {}) do
          table.insert(off, string.format("%s(%d)", o.name or U:SafeSpellName(o.spellId), tonumber(o.spellId) or 0))
        end
        table.insert(lines, string.format("  step %d: %s  txn=%s  offer=[%s]", i, tostring(d.action or "?"), tostring(d.txnId or ""), table.concat(off, ", ")))
      end
    elseif e.kind == 'banish' then
      local sid, nm, q = GetPickMeta(e)
      local rer = CountRerolls(e)
      table.insert(lines, string.format("Lv.%s  Banish=%s (%s)  q=%s  rerolls=%d", tostring(e.level or "?"), tostring(nm or "(none)"), tostring(sid or "?"), tostring(q or "?"), rer))
      local dec = e.decision or {}
      if dec.banishIndex ~= nil then
        table.insert(lines, "  slot=" .. tostring(tonumber(dec.banishIndex) + 1))
      end
      if dec.reason then table.insert(lines, "  reason=" .. tostring(dec.reason)) end
    else
      local sid, nm, q = GetPickMeta(e)
      table.insert(lines, string.format("Lv.%s  Pick=%s (%s)  q=%s  rerolls=%d", tostring(e.level or "?"), tostring(nm or "(none)"), tostring(sid or "?"), tostring(q or "?"), CountRerolls(e)))
      if e.finalPick and e.finalPick.txnId then
        table.insert(lines, "  txn=" .. tostring(e.finalPick.txnId))
      end
      for i, a in ipairs(e.attempts or {}) do
        local d = a.decision or {}
        local off = {}
        for _, o in ipairs(a.offered or {}) do
          table.insert(off, string.format("%s(%d)", o.name or U:SafeSpellName(o.spellId), tonumber(o.spellId) or 0))
        end
        local extra = ""
        if d.action == 'reroll' then
          extra = string.format("  streak=%s/%s  effRem=%s", tostring(d.streakUsedThisPick or "?"), tostring(d.streakCap or "?"), tostring(d.effectiveRerollsRemaining or d.rerollsRemaining or "?"))
        end
        table.insert(lines, string.format("  attempt %d: %s  txn=%s%s  offer=[%s]", i, tostring(d.action or "?"), tostring(d.txnId or ""), extra, table.concat(off, ", ")))
      end
    end
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

local function RenderAutoDetails(entry)
  if not entry then return "" end
  local lines = {}

  local filter = HU.auto.filter or "all"

  if entry.kind == 'banish' then
    local sid = tonumber(entry.spellId)
    local name = (entry.name and entry.name ~= "" and entry.name) or (sid and U:SafeSpellName(sid)) or "(unknown)"
    table.insert(lines, U:ColorText("BANISHED", 1, 0.3, 0.3) .. "  |cffaaaaaa" .. tostring(entry.ts or "") .. "|r")
    table.insert(lines, U:ColorText("Level:", 0.9,0.9,0.9) .. " " .. tostring(entry.level or ""))
    if sid then
      table.insert(lines, U:ColorText("Echo:", 0.9,0.9,0.9) .. " " .. name .. " ("..tostring(sid)..")")
    else
      table.insert(lines, U:ColorText("Echo:", 0.9,0.9,0.9) .. " " .. name)
    end
    local dec = entry.decision or {}
    if dec.banishIndex ~= nil then
      table.insert(lines, U:ColorText("Slot:", 0.9,0.9,0.9) .. " " .. tostring(tonumber(dec.banishIndex) + 1))
    elseif dec.banishIndex0 ~= nil then
      table.insert(lines, U:ColorText("Slot:", 0.9,0.9,0.9) .. " " .. tostring(tonumber(dec.banishIndex0) + 1))
    end
    if dec.banishesRemaining ~= nil then
      table.insert(lines, U:ColorText("Banishes remaining:", 0.9,0.9,0.9) .. " " .. tostring(dec.banishesRemaining))
    elseif entry.banishesRemaining ~= nil then
      table.insert(lines, U:ColorText("Banishes remaining:", 0.9,0.9,0.9) .. " " .. tostring(entry.banishesRemaining))
    end
    if dec.reason then
      table.insert(lines, U:ColorText("Reason:", 0.9,0.9,0.9) .. " " .. tostring(dec.reason))
    end
    table.insert(lines, "")
    table.insert(lines, U:ColorText("Offered:", 0.9,0.9,0.9))
    for _, o in ipairs(entry.offered or {}) do
      table.insert(lines, string.format("- %s (%d)  q=%d  score=%.1f  [%s]", o.name or "?", o.spellId or 0, o.quality or 0, tonumber(o.score or 0) or 0, o.why or ""))
    end
    return table.concat(lines, "\n")
  end

  if entry.kind == 'error' then
    table.insert(lines, U:ColorText("ERROR", 1, 0.3, 0.3) .. "  |cffaaaaaa" .. tostring(entry.ts or "") .. "|r")
    table.insert(lines, U:ColorText("Level:", 0.9,0.9,0.9) .. " " .. tostring(entry.level or ""))
    if entry.txnId then
      table.insert(lines, U:ColorText("Txn:", 0.9,0.9,0.9) .. " " .. tostring(entry.txnId))
    end
    if entry.spellId then
      table.insert(lines, U:ColorText("Attempted:", 0.9,0.9,0.9) .. " " .. U:SafeSpellName(entry.spellId) .. " ("..tostring(entry.spellId)..")")
    end
    if entry.reason then
      table.insert(lines, U:ColorText("Reason:", 0.9,0.9,0.9) .. " " .. tostring(entry.reason))
    end
    table.insert(lines, "")

    local steps = entry.steps or {}
    table.insert(lines, U:ColorText("Steps:", 0.9,0.9,0.9) .. " " .. tostring(#steps))
    table.insert(lines, "")

    for i, st in ipairs(steps) do
      local dec = st.decision or {}
      table.insert(lines, U:ColorText(string.format("Step %d", i), 0.7,0.85,1) .. (st.ts and ("  |cffaaaaaa"..tostring(st.ts).."|r") or ""))
      table.insert(lines, "Action: " .. tostring(dec.action or "?"))
      if dec.txnId then table.insert(lines, "Txn: " .. tostring(dec.txnId)) end
      if dec.reason then table.insert(lines, "Reason: " .. tostring(dec.reason)) end
      table.insert(lines, "")
      table.insert(lines, U:ColorText("Offered:", 0.9,0.9,0.9))
      for _, o in ipairs(st.offered or {}) do
        table.insert(lines, string.format("- %s (%d)  q=%d  score=%.1f  [%s]", o.name or "?", o.spellId or 0, o.quality or 0, tonumber(o.score or 0) or 0, o.why or ""))
      end
      table.insert(lines, "")
    end

    return table.concat(lines, "\n")
  end

  table.insert(lines, U:ColorText("Level:", 0.9,0.9,0.9) .. " " .. tostring(entry.level or ""))
  if entry.tsFirst then
    table.insert(lines, U:ColorText("First seen:", 0.9,0.9,0.9) .. " " .. tostring(entry.tsFirst))
  end
  if entry.tsFinal then
    table.insert(lines, U:ColorText("Final:", 0.9,0.9,0.9) .. " " .. tostring(entry.tsFinal))
  end
  table.insert(lines, "")

  local final = entry.finalPick
  if final and final.spellId then
    table.insert(lines, U:ColorText("Final Pick:", 1,0.82,0) .. " " .. U:SafeSpellName(final.spellId) .. " ("..tostring(final.spellId)..")")
    if final.txnId then
      table.insert(lines, "Txn: " .. tostring(final.txnId))
    end
    if final.score then
      table.insert(lines, "Final score: " .. string.format("%.1f", tonumber(final.score) or 0))
    end
    if final.why and final.why ~= "" then
      table.insert(lines, "Why: " .. tostring(final.why))
    end
    table.insert(lines, "")
  end

  local attempts = entry.attempts or {}
  table.insert(lines, U:ColorText("Attempts:", 0.9,0.9,0.9) .. " " .. tostring(#attempts) .. "   (Rerolls: " .. tostring(CountRerolls(entry)) .. ")")
  table.insert(lines, "")

  for i, a in ipairs(attempts) do
    local dec = a.decision or {}

    if filter == 'rolls' and dec.action ~= 'reroll' then
    elseif filter == 'picks' and dec.action ~= 'select' then
    else
    table.insert(lines, U:ColorText(string.format("Attempt %d", i), 0.7,0.85,1) .. (a.ts and ("  |cffaaaaaa"..tostring(a.ts).."|r") or ""))
    table.insert(lines, "Decision: " .. tostring(dec.action or "?"))

    if dec.txnId then
      table.insert(lines, "Txn: " .. tostring(dec.txnId))
    end

    if dec.action == "select" and dec.spellId then
      table.insert(lines, "Picked: " .. U:SafeSpellName(dec.spellId) .. " ("..tostring(dec.spellId)..")")
    end

    if dec.bestScore ~= nil then
      table.insert(lines, "Best score: " .. string.format("%.1f", tonumber(dec.bestScore) or 0))
    end
    if dec.bestWhy and dec.bestWhy ~= "" then
      table.insert(lines, "Why: " .. tostring(dec.bestWhy))
    end
    if dec.reason then
      table.insert(lines, "Reason: " .. tostring(dec.reason))
    end
    if dec.minScoreToKeep ~= nil then
      table.insert(lines, "Min score to keep: " .. tostring(dec.minScoreToKeep))
    end
    if dec.preferUnownedEnabled ~= nil then
      table.insert(lines, string.format("Single Echo Mode: %s (forced=%s)  ownedOnlyOffer=%s  bestOwnedStacks=%s", tostring(dec.preferUnownedEnabled), tostring(dec.preferUnownedForced), tostring(dec.ownedOnlyOffer), tostring(dec.bestOwnedStacks)))
    end
    if dec.effectiveRerollsRemaining ~= nil and dec.serverRerollsTotal ~= nil then
      table.insert(lines, string.format("Rerolls: effective %s   server %s/%s (used %s)", tostring(dec.effectiveRerollsRemaining), tostring(dec.serverRerollsRemaining or "?"), tostring(dec.serverRerollsTotal), tostring(dec.serverRerollsUsed or "?")))
    elseif dec.rerollsRemaining ~= nil and dec.rerollsTotal ~= nil then
      table.insert(lines, string.format("Rerolls: %s/%s (used %s)", tostring(dec.rerollsRemaining), tostring(dec.rerollsTotal), tostring(dec.rerollsUsed or "?")))
    end
    if dec.streakUsedThisPick ~= nil and dec.streakCap ~= nil then
      table.insert(lines, string.format("Roll streak: %s/%s (remaining %s)", tostring(dec.streakUsedThisPick), tostring(dec.streakCap), tostring(dec.streakRemaining or "?")))
    end
    if dec.rerollGateMinLevel ~= nil then
      table.insert(lines, string.format("Roll gate: Lv.%s+ (current pick Lv.%s)", tostring(dec.rerollGateMinLevel), tostring(dec.rerollGatePickLevel or "?")))
    end

    if filter == 'offers' or filter == 'all' or filter == 'rolls' or filter == 'picks' then
      table.insert(lines, "")
      table.insert(lines, U:ColorText("Offered:", 0.9,0.9,0.9))
      for _, o in ipairs(a.offered or {}) do
        table.insert(lines, string.format("- %s (%d)  q=%d  score=%.1f  [%s]", o.name or "?", o.spellId or 0, o.quality or 0, tonumber(o.score or 0) or 0, o.why or ""))
      end
      table.insert(lines, "")
    end
    end
  end

  return table.concat(lines, "\n")
end

function HU.auto:GetPopup()
  if self.popup and self.popup.editBox then
    return self.popup
  end

  local f = CreateFrame("Frame", "EAK_HistoryAutomationDetailsPopup", UIParent)
  f:SetSize(620, 430)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  f:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0, 0, 0, 0.85)
  f:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("Automation History Details")
  f.title = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)
  close:SetScript("OnClick", function() f:Hide() end)

  if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, f:GetName())
  end

  local sf = CreateFrame("ScrollFrame", "EAK_HistoryAutomationDetailsPopupScroll", f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 14, -40)
  sf:SetPoint("BOTTOMRIGHT", -30, 14)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  if eb.SetTextColor then eb:SetTextColor(1, 1, 1) end
  if eb.SetTextInsets then eb:SetTextInsets(8, 8, 8, 8) end
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  eb:SetText("")
  sf:SetScrollChild(eb)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(eb, { multiline = true })
  end

  sf:SetScript("OnSizeChanged", function()
    if sf:GetWidth() and sf:GetWidth() > 0 then
      eb:SetWidth(sf:GetWidth() - 30)
    end
  end)

  f.scroll = sf
  f.editBox = eb

  self.popup = f
  return f
end

function HU.auto:ShowDetails(entry)
  if not EnsureUtils() then return end
  local f = self:GetPopup()
  local text = RenderAutoDetails(entry)
  f.editBox:SetText(text or "")
  f.editBox:HighlightText(0, 0)
  f:Show()

  U:After(0, function()
    if f:IsShown() then
      f.editBox:HighlightText(0, 0)
    end
  end)
end

local function Auto_CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  local ROW_H = 30
  row:SetHeight(ROW_H)
  row:EnableMouse(true)

  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(row)
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(1, 1, 1, 0)
  row.bg = bg

  local levelText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  levelText:SetPoint("LEFT", 10, 0)
  levelText:SetWidth(64)
  levelText:SetJustifyH("LEFT")
  row.levelText = levelText

  local rerText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rerText:SetPoint("RIGHT", -10, 0)
  rerText:SetWidth(92)
  rerText:SetJustifyH("RIGHT")
  row.rerText = rerText

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", levelText, "RIGHT", 10, 0)
  row.iconTex = icon

  local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  nameText:SetPoint("RIGHT", rerText, "LEFT", -10, 0)
  nameText:SetJustifyH("LEFT")
  row.nameText = nameText

  local hover = CreateFrame("Button", nil, row)
  hover:EnableMouse(true)
  hover:SetPoint("LEFT", icon, "LEFT", -2, 0)
  hover:SetPoint("RIGHT", nameText, "RIGHT", 2, 0)
  hover:SetPoint("TOP", row, "TOP")
  hover:SetPoint("BOTTOM", row, "BOTTOM")
  hover:SetFrameLevel(row:GetFrameLevel() + 2)
  row.hover = hover

  local function ShowSpellTooltip(owner)
    if not row.entry then return end
    local sid = nil
    if row.entry.kind == 'error' then
      sid = row.entry.spellId
    elseif row.entry.kind == 'banish' then
      sid = row.entry.spellId
    else
      sid = row.entry.finalPick and row.entry.finalPick.spellId or nil
    end
    if not sid then return end
    GameTooltip:SetOwner(owner or row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
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
    GameTooltip:Show()
  end

  hover:SetScript("OnEnter", function(self)
    row.bg:SetVertexColor(1, 1, 1, 0.05)
    ShowSpellTooltip(self)
  end)
  hover:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if HU.auto.selectedIndex ~= row.index then
      row.bg:SetVertexColor(1, 1, 1, 0)
    end
  end)

  hover:SetScript("OnClick", function()
    local f = row:GetScript("OnClick")
    if f then f(row) end
  end)

  row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.05) end)
  row:SetScript("OnLeave", function(self)
    if HU.auto.selectedIndex ~= self.index then
      self.bg:SetVertexColor(1, 1, 1, 0)
    end
  end)

  row:SetScript("OnClick", function(self)
    HU.auto.selectedIndex = self.index
    HU.auto:Refresh()
    local e = HU.auto.display and HU.auto.display[self.index] or nil
    if e then
      HU.auto:ShowDetails(e)
    end
  end)

  return row
end

function HU.auto:Refresh()
  if not self.panel then return end
  if not EnsureUtils() then return end

  self.display = GetAutoDisplayList()
  local total = #self.display

  local ROW_H = 30
  FauxScrollFrame_Update(self.scroll, total, #self.rows, ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.scroll)

  for i = 1, #self.rows do
    local row = self.rows[i]
    local idx = i + offset
    row.index = idx

    local entry = self.display[idx]
    row.entry = entry

    if entry then
      row.levelText:SetText(string.format("Lv. %s", tostring(entry.level or "?")))

      if entry.kind == 'error' then
        local sid = tonumber(entry.spellId)
        local name = sid and U:SafeSpellName(sid) or "(unknown)"
        row.nameText:SetText("ERROR: " .. name)
        row.nameText:SetTextColor(1, 0.3, 0.3)
        if sid then
          local icon = select(3, GetSpellInfo(sid))
          if icon then
            row.iconTex:SetTexture(icon)
            row.iconTex:Show()
          else
            row.iconTex:Hide()
          end
        else
          row.iconTex:Hide()
        end
        row.rerText:SetText("ERROR")
        row.rerText:SetTextColor(1,0.3,0.3)
      elseif entry.kind == 'banish' then
        local sid = tonumber(entry.spellId)
        local name = (entry.name and entry.name ~= "" and entry.name) or (sid and U:SafeSpellName(sid)) or "(unknown)"
        row.nameText:SetText(name .. " - Banished")
        row.nameText:SetTextColor(1, 0.3, 0.3)
        row.rerText:SetTextColor(1,1,1)
        row.rerText:SetText("Rerolls: 0")

        if sid then
          local q = tonumber(entry.quality) or 0
          local icon = nil
          local echoDB = EAK:GetEchoDB() or {}
          local meta = echoDB[U:MakeKey(sid, q)]
          icon = (meta and meta.icon) or select(3, GetSpellInfo(sid))
          if icon then
            row.iconTex:SetTexture(icon)
            row.iconTex:Show()
          else
            row.iconTex:Hide()
          end
        else
          row.iconTex:Hide()
        end
      else
        local rer = CountRerolls(entry)
        local sid, pickName, q = GetPickMeta(entry)
        local r,g,b = U:RarityColor(q or 0)
        row.rerText:SetTextColor(1,1,1)

        if sid then
          row.nameText:SetText(pickName or "?")
          row.nameText:SetTextColor(r,g,b)

          local icon = nil
          local echoDB = EAK:GetEchoDB() or {}
          local meta = echoDB[U:MakeKey(sid, q or 0)]
          icon = (meta and meta.icon) or select(3, GetSpellInfo(sid))
          if icon then
            row.iconTex:SetTexture(icon)
            row.iconTex:Show()
          else
            row.iconTex:Hide()
          end
        else
          local last = entry.attempts and entry.attempts[#entry.attempts] or nil
          local act = last and last.decision and last.decision.action or ""
          local label = act ~= "" and ("["..act.."]") or ""
          row.nameText:SetText(label)
          row.nameText:SetTextColor(1,1,1)
          row.iconTex:Hide()
        end

        row.rerText:SetText(string.format("Rerolls: %d", rer))
      end
      row:Show()

      if idx == self.selectedIndex then
        row.bg:SetVertexColor(1,1,1,0.08)
      else
        row.bg:SetVertexColor(1,1,1,0)
      end
    else
      row.entry = nil
      row:Hide()
    end
  end

  if self.countText then
    local h = U:GetAutomationHistory()
    local picksN = #(h.entries or {})
    self.countText:SetText(string.format("Showing: %d - Picks: %d", total, picksN))
  end

  if self.filterDropDown then
    local f, _ = Auto_GetViewState()
    UIDropDownMenu_SetSelectedValue(self.filterDropDown, f)
    UIDropDownMenu_SetText(self.filterDropDown, Auto_FilterLabel(f))
  end

  if self.headerLevel and self.headerName and self.headerRer then
    local key, asc = Auto_GetSortState()
    local up = " |cffaaaaaa▲|r"
    local dn = " |cffaaaaaa▼|r"
    self.headerLevel:SetText("Level" .. ((key=="level") and (asc and up or dn) or ""))
    if key == "priority" then
      self.headerName:SetText("Echo (Weight)" .. (asc and up or dn))
    else
      self.headerName:SetText("Echo" .. ((key=="name") and (asc and up or dn) or ""))
    end
    self.headerRer:SetText("Rerolls" .. ((key=="rerolls") and (asc and up or dn) or ""))
  end
end

function HU.auto:CreatePanel(parentName)
  if self.panel then return end

  local panel = CreateFrame("Frame", "EAK_HistoryAutomationPanel", InterfaceOptionsFramePanelContainer)
  panel.name = "History - Automation"
  panel.parent = parentName
  self.panel = panel

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Automation History")

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  help:SetHeight(40)
  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")
  help:SetNonSpaceWrap(true)
  help:SetText("Records entries everytime the AddOn picks an Echo\nIf anything seems weird or if the pick seems off, check the log.")

  local searchRow = CreateFrame("Frame", nil, panel)
  searchRow:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
  searchRow:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  searchRow:SetHeight(22)

  local searchLabel = searchRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  searchLabel:SetPoint("LEFT", 0, 0)
  searchLabel:SetText("Search:")

  local search = CreateFrame("EditBox", nil, searchRow)
  search:SetSize(176, 20)
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
  search:SetScript("OnTextChanged", function(self)
    local t = self:GetText() or ""
    HU.auto.search = t
    Auto_SetSearch(t)
    HU.auto:Refresh()
  end)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(search)
  end
  self.searchBox = search

    local viewLabel = searchRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    viewLabel:SetPoint("LEFT", search, "RIGHT", 8, 0)
    viewLabel:SetText("View:")

    local dd = CreateFrame("Frame", "EAK_AutoHistoryFilterDropDown", searchRow, "UIDropDownMenuTemplate")
    dd:SetPoint("LEFT", viewLabel, "RIGHT", -6, -2)
    UIDropDownMenu_SetWidth(dd, 76)
    UIDropDownMenu_SetButtonWidth(dd, 86)
    UIDropDownMenu_JustifyText(dd, "LEFT")

    local function SetView(val, noRefresh)
      val = tostring(val or "all")
      HU.auto.filter = val
      Auto_SetFilter(val)
      if val == "priority" then
        Auto_SetSort("priority")
        EbonholdAutomationKitDB.uiAutoHistory = EbonholdAutomationKitDB.uiAutoHistory or {}
        EbonholdAutomationKitDB.uiAutoHistory.sortAsc = false
      end
      if dd then
        UIDropDownMenu_SetSelectedValue(dd, val)
        UIDropDownMenu_SetText(dd, Auto_FilterLabel(val))
      end
      if not noRefresh then
        HU.auto:Refresh()
      end
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
      local function add(text, value)
        local info = UIDropDownMenu_CreateInfo()
        info.text = text
        info.value = value
        info.func = function() SetView(value) end
        UIDropDownMenu_AddButton(info, level)
      end
      add("All", "all")
      add("Picks", "picks")
      add("Offers", "offers")
      add("Rolls", "rolls")
      add("Banished", "banished")
      add("Errors", "errors")
      add("Priority", "priority")
    end)

    self.filterDropDown = dd
    self.SetView = SetView
  local listContainer = CreateFrame("Frame", nil, panel)
  listContainer:SetPoint("TOPLEFT", searchRow, "BOTTOMLEFT", 0, -12)
  listContainer:SetPoint("TOPRIGHT", searchRow, "BOTTOMRIGHT", 0, -12)
  listContainer:SetHeight(280)
  listContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  listContainer:SetBackdropColor(0, 0, 0, 0.35)
  listContainer:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

  local header = CreateFrame("Frame", nil, listContainer)
  header:SetPoint("TOPLEFT", 4, -4)
  header:SetPoint("TOPRIGHT", -28, -4)
  header:SetHeight(22)

  local headerBG = header:CreateTexture(nil, "BACKGROUND")
  headerBG:SetAllPoints(header)
  headerBG:SetTexture("Interface\\Buttons\\WHITE8X8")
  headerBG:SetVertexColor(1, 1, 1, 0.06)

  local headerLevel = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerLevel:SetPoint("LEFT", 10, 0)
  headerLevel:SetText("Level")

  local headerRer = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerRer:SetPoint("RIGHT", -10, 0)
  headerRer:SetText("Rerolls")

  local headerName = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerName:SetPoint("LEFT", 90, 0)
  headerName:SetPoint("RIGHT", headerRer, "LEFT", -10, 0)
  headerName:SetJustifyH("LEFT")
  headerName:SetText("Echo")

  self.headerLevel = headerLevel
  self.headerName = headerName
  self.headerRer = headerRer

  local levelBtn = CreateFrame("Button", nil, header)
  levelBtn:SetAllPoints(headerLevel)
  levelBtn:SetScript("OnClick", function()
    Auto_SetSort("level")
    HU.auto:Refresh()
  end)

  local nameBtn = CreateFrame("Button", nil, header)
  nameBtn:SetAllPoints(headerName)
  nameBtn:SetScript("OnClick", function()
    Auto_SetSort("name")
    HU.auto:Refresh()
  end)

  local rerBtn = CreateFrame("Button", nil, header)
  rerBtn:SetAllPoints(headerRer)
  rerBtn:SetScript("OnClick", function()
    Auto_SetSort("rerolls")
    HU.auto:Refresh()
  end)

  local ROW_H = 30

  local listScroll = CreateFrame("ScrollFrame", "EAK_HistoryAutomationListScroll", listContainer, "FauxScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -26)
  listScroll:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 8)
  self.scroll = listScroll
  listScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() HU.auto:Refresh() end)
  end)

  local sb = _G[listScroll:GetName() .. "ScrollBar"]
  if sb and sb.ClearAllPoints then
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT",    listScroll, "TOPRIGHT",    0, 4)
    sb:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 0, 12)
  end

  local listContent = CreateFrame("Frame", nil, listContainer)
  listContent:SetPoint("TOPLEFT", 0, -26)
  listContent:SetPoint("BOTTOMRIGHT", -24, 8)

  listScroll:SetFrameLevel(listContainer:GetFrameLevel() + 1)
  listContent:SetFrameLevel(listScroll:GetFrameLevel() + 1)

  for i = 1, 8 do
    local row = Auto_CreateRow(listContent)
    row:SetFrameLevel(listContent:GetFrameLevel() + 1)
    row:SetPoint("TOPLEFT", 0, - (i-1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, - (i-1) * ROW_H)
    table.insert(self.rows, row)
  end
  local exportBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  exportBtn:SetSize(110, 22)
  exportBtn:SetPoint("TOPLEFT", listContainer, "BOTTOMLEFT", 0, -2)
  exportBtn:SetText("Export")
  exportBtn:SetScript("OnClick", function()
    HU:ShowTextPopup("Automation History Export", Auto_ExportText())
  end)

  local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  clearBtn:SetSize(100, 22)
  clearBtn:SetPoint("LEFT", exportBtn, "RIGHT", 8, 0)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    U:ClearAutomationHistory()
    HU.auto.selectedIndex = 1
    HU.auto:Refresh()
  end)

  local countText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  countText:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
  countText:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  countText:SetJustifyH("LEFT")
  countText:SetText("")
  self.countText = countText

  panel.refresh = function() HU.auto:Refresh() end
  panel:SetScript("OnShow", function()
    local f, q = Auto_GetViewState()
    HU.auto.filter = f
    HU.auto.search = q
    if HU.auto.SetView then
      HU.auto.SetView(f, true)
    elseif HU.auto.filterDropDown then
      UIDropDownMenu_SetSelectedValue(HU.auto.filterDropDown, f)
      UIDropDownMenu_SetText(HU.auto.filterDropDown, Auto_FilterLabel(f))
    end
    if HU.auto.searchBox and HU.auto.searchBox.GetText and (HU.auto.searchBox:GetText() or "") ~= (q or "") then
      HU.auto.searchBox:SetText(q or "")
    end
    if panel.refresh then panel.refresh() end
		if EnsureUtils() then
			U:After(0, function()
				if panel:IsShown() and panel.refresh then panel.refresh() end
			end)
		end
  end)

  InterfaceOptions_AddCategory(panel)
  self:Refresh()
end

local function Book_GetSortState()
  EbonholdAutomationKitDB.uiLogbook = EbonholdAutomationKitDB.uiLogbook or {}
  local ui = EbonholdAutomationKitDB.uiLogbook
  local key = ui.sortKey or HU.book.sortKey or "count"
  local asc = (ui.sortAsc == true)
  return key, asc
end

local function Book_SetSort(key)
  EbonholdAutomationKitDB.uiLogbook = EbonholdAutomationKitDB.uiLogbook or {}
  local ui = EbonholdAutomationKitDB.uiLogbook
  if ui.sortKey == key then
    ui.sortAsc = not (ui.sortAsc == true)
  else
    ui.sortKey = key
    if key == "name" then ui.sortAsc = true
    else ui.sortAsc = false end
  end
end

local function QualityName(q)
  q = tonumber(q) or 0
  if q == 1 then return "Uncommon" end
  if q == 2 then return "Rare" end
  if q == 3 then return "Epic" end
  if q == 4 then return "Legendary" end
  return "Common"
end

local function Book_ExportText()
  HU.book:BuildFiltered()
  local lb = U:GetLogbook()
  local totalSeen = tonumber(lb.totalSeen) or 0

  local function esc(s)
    s = tostring(s or "")
    s = s:gsub('"', '\\"')
    return s
  end

  local rs = lb.raritySeen or {}
  local tQ = { [0]=tonumber(rs[0]) or 0, [1]=tonumber(rs[1]) or 0, [2]=tonumber(rs[2]) or 0, [3]=tonumber(rs[3]) or 0, [4]=tonumber(rs[4]) or 0 }

  local function pct(part, whole)
    part = tonumber(part) or 0
    whole = tonumber(whole) or 0
    if whole <= 0 then return 0 end
    return (part / whole) * 100.0
  end

  local lines = {}
  table.insert(lines, "Ebonhold Automation Kit - Logbook Export")
  local unix = (type(time) == 'function') and time() or 0
  table.insert(lines, "Generated: " .. tostring(unix))
  table.insert(lines, "")

  table.insert(lines, string.format('TotalSeen="%d"', totalSeen))
  table.insert(lines, string.format('TotalCommon="%d"', tQ[0]))
  table.insert(lines, string.format('TotalUncommon="%d"', tQ[1]))
  table.insert(lines, string.format('TotalRare="%d"', tQ[2]))
  table.insert(lines, string.format('TotalEpic="%d"', tQ[3]))
  table.insert(lines, string.format('TotalLegendary="%d"', tQ[4]))
  table.insert(lines, "")

  table.insert(lines, string.format('ChanceCommon="%.1f%%"', pct(tQ[0], totalSeen)))
  table.insert(lines, string.format('ChanceUncommon="%.1f%%"', pct(tQ[1], totalSeen)))
  table.insert(lines, string.format('ChanceRare="%.1f%%"', pct(tQ[2], totalSeen)))
  table.insert(lines, string.format('ChanceEpic="%.1f%%"', pct(tQ[3], totalSeen)))
  table.insert(lines, string.format('ChanceLegendary="%.1f%%"', pct(tQ[4], totalSeen)))
  table.insert(lines, "")

  local echoDB = (EAK and EAK.GetEchoDB) and EAK:GetEchoDB() or {}

  local classNames = {
    WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest",
    DEATHKNIGHT="Death Knight", SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock", DRUID="Druid",
  }

  for _, it in ipairs(HU.book.filtered or {}) do
    local key = it.key
    local sid = tonumber(it.spellId or 0) or 0
    local q = tonumber(it.quality or 0) or 0
    local count = tonumber(it.count or 0) or 0

    local meta = (key and echoDB and echoDB[key]) or nil
    if (not meta or not meta.name or not meta.icon) and sid and sid > 0 then
      meta = U:EnsureSpellMeta(sid, q) or meta
    end
    local name = (it.name or (meta and meta.name) or "?")
    local qName = QualityName(q)

    local last = (lb.lastSeen and lb.lastSeen[key]) or (meta and (meta.lastSeenAt or meta.lastSeen)) or ""
    local first = (meta and (meta.firstSeenAt or meta.firstSeen)) or ""

    local chanceTotal = pct(count, totalSeen)
    local poolTotal = tQ[q] or 0
    local chancePool = pct(count, poolTotal)

    local classTag = ""
    if meta and type(meta.classes) == "table" then
      local tmp = {}
      for ck, cv in pairs(meta.classes) do
        if cv then
          table.insert(tmp, classNames[ck] or tostring(ck))
        end
      end
      table.sort(tmp)
      classTag = table.concat(tmp, ", ")
    end

    local poolLabel = qName
    table.insert(lines, string.format('Name="%s" SpellID="%d" Quality="%s" AmountSeen="%d" ChanceTotalPool="%.1f%%" Chance%sPool="%.1f%%" LastSeen="%s" FirstSeen="%s" ClassTag="%s"',
      esc(name), sid, esc(qName), count, chanceTotal, esc(poolLabel), chancePool, esc(last), esc(first), esc(classTag)))
  end

  return table.concat(lines, "\n")
end


local function Book_CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(30)
  row:EnableMouse(false)

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 8, 0)
  row.iconTex = icon

  local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  name:SetJustifyH("LEFT")
  row.nameText = name

  local seen = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  seen:SetPoint("RIGHT", -12, 0)
  seen:SetJustifyH("RIGHT")
  row.seenText = seen

  local rarity = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rarity:SetPoint("RIGHT", seen, "LEFT", -18, 0)
  rarity:SetJustifyH("RIGHT")
  row.rarityText = rarity

  name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  name:SetPoint("RIGHT", rarity, "LEFT", -10, 0)

  local hover = CreateFrame("Button", nil, row)
  hover:EnableMouse(true)
  hover:SetPoint("LEFT", icon, "LEFT", -2, 0)
  hover:SetPoint("RIGHT", rarity, "LEFT", -6, 0)
  hover:SetPoint("TOP", row, "TOP")
  hover:SetPoint("BOTTOM", row, "BOTTOM")
  hover:SetFrameLevel(row:GetFrameLevel() + 1)
  row.hover = hover

  local function ShowSpellTooltip(owner)
    if not row.data or not row.data.spellId then return end
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
    GameTooltip:Show()
  end
  hover:SetScript("OnEnter", function(self)
    if not EnsureUtils() then return end
    ShowSpellTooltip(self)
    if row.data and row.data.spellId then
      local sid = tonumber(row.data.spellId) or 0
      if sid > 0 then
        local q = tonumber(row.data.quality or 0) or 0
        local meta = U:EnsureSpellMeta(sid, q)
        if meta then
          row.data.name = meta.name or row.data.name
          row.data.icon = meta.icon or row.data.icon
          if row.iconTex and row.data.icon then
            row.iconTex:SetTexture(row.data.icon)
            row.iconTex:Show()
          end
          if row.nameText and row.data.name then
            row.nameText:SetText(row.data.name)
          end
        end
      end
    end
  end)
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
    if not EnsureUtils() then return end
    if U and U.TryInsertSpellLink and U:TryInsertSpellLink(row.data.spellId, row.data.quality, true) then
      GameTooltip:Hide()
    end
  end)

  return row
end

function HU.book:BuildFiltered()
  local lb = U:GetLogbook()
  local total = tonumber(lb.totalSeen) or 0
  local counts = lb.counts or {}
  local echoDB = EAK:GetEchoDB() or {}

  local q = tostring(self.search or "")
  q = string.lower(q)
  local out = {}

  for key, n in pairs(counts) do
    local sid, qFromKey = U:ParseKey(key)
    local meta = echoDB[key]
    if (not meta or not meta.name or not meta.icon) and sid then
      meta = U:EnsureSpellMeta(sid, qFromKey) or meta
    end
    local name = (meta and meta.name) or tostring(key)
    if q == "" or string.find(string.lower(name), q, 1, true) then
      local pct = (total > 0) and ((tonumber(n) or 0) * 100 / total) or 0
      table.insert(out, {
        key = key,
        spellId = (meta and meta.spellId) or sid,
        name = name,
        quality = (meta and meta.quality) or qFromKey or 0,
        icon = meta and meta.icon or nil,
        count = tonumber(n) or 0,
        pct = pct,
      })
    end
  end

  local sortKey, asc = Book_GetSortState()
  table.sort(out, function(a, b)
    if a == b then return false end
    if not a then return false end
    if not b then return true end

    local an = U:StripWoWFormatting(a.name or ""):lower()
    local bn = U:StripWoWFormatting(b.name or ""):lower()
    local ac = tonumber(a.count) or 0
    local bc = tonumber(b.count) or 0
    local aq = tonumber(a.quality) or 0
    local bq = tonumber(b.quality) or 0

    local function cmpStr(x, y, ascending)
      if x == y then return nil end
      if ascending then return x < y else return x > y end
    end

    local function cmpNum(x, y, ascending)
      if x == y then return nil end
      if ascending then return x < y else return x > y end
    end

    local r
    if sortKey == "count" then
      r = cmpNum(ac, bc, asc); if r ~= nil then return r end
      r = cmpStr(an, bn, true); if r ~= nil then return r end
      r = cmpNum(aq, bq, false); if r ~= nil then return r end
    elseif sortKey == "quality" then
      r = cmpNum(aq, bq, asc); if r ~= nil then return r end
      r = cmpStr(an, bn, true); if r ~= nil then return r end
      r = cmpNum(ac, bc, false); if r ~= nil then return r end
    else
      r = cmpStr(an, bn, asc); if r ~= nil then return r end
      r = cmpNum(ac, bc, false); if r ~= nil then return r end
      r = cmpNum(aq, bq, false); if r ~= nil then return r end
    end

    return tostring(a.key) < tostring(b.key)
  end)

  self.filtered = out
end

function HU.book:Refresh()
  if not self.panel then return end
  if not EnsureUtils() then return end

  self:BuildFiltered()
  local total = #self.filtered

  local ROW_H = 30
  FauxScrollFrame_Update(self.scroll, total, #self.rows, ROW_H)
  local offset = FauxScrollFrame_GetOffset(self.scroll)

  for i = 1, #self.rows do
    local row = self.rows[i]
    local idx = i + offset
    local item = self.filtered[idx]
    if item then
      row.data = item
      local r,g,b = U:RarityColor(item.quality or 0)
      row.nameText:SetText(item.name or "?")
      row.nameText:SetTextColor(r,g,b)
      if item.icon then
        row.iconTex:SetTexture(item.icon)
        row.iconTex:Show()
      else
        row.iconTex:Hide()
      end

      row.rarityText:SetText(QualityName(item.quality))
      row.rarityText:SetTextColor(r,g,b)
      row.seenText:SetText(string.format("%d (%.1f%%)", item.count or 0, tonumber(item.pct or 0) or 0))
      row:Show()
    else
      row.data = nil
      row:Hide()
    end
  end

  if self.totalText then
    local lb = U:GetLogbook()
    self.totalText:SetText("Total Echoes Seen: " .. tostring(tonumber(lb.totalSeen) or 0))
  end

  if self.rarityTotalsText then
    local lb = U:GetLogbook()
    local totalSeen = tonumber(lb.totalSeen) or 0
    local rs = lb.raritySeen or {}
    local function fmt(q, label)
      local n = tonumber(rs[q]) or 0
      local pct = (totalSeen > 0) and (n * 100 / totalSeen) or 0
      local r,g,b = U:RarityColor(q)
      local rr = math.floor((r or 1) * 255 + 0.5)
      local gg = math.floor((g or 1) * 255 + 0.5)
      local bb = math.floor((b or 1) * 255 + 0.5)
      return string.format("|cff%02x%02x%02x%s: %d (%.1f%%)|r", rr, gg, bb, label, n, pct)
    end
    self.rarityTotalsText:SetText(
      fmt(0, "Common") .. "\n" .. fmt(1, "Uncommon") .. "\n" .. fmt(2, "Rare") .. "\n" ..
      fmt(3, "Epic") .. "\n" .. fmt(4, "Legendary")
    )
  end

  if self.headerName and self.headerSeen and self.headerRarity then
    local key, asc = Book_GetSortState()
    local up = " |cffaaaaaa▲|r"
    local dn = " |cffaaaaaa▼|r"
    self.headerName:SetText("Echo" .. ((key=="name") and (asc and up or dn) or ""))
    self.headerRarity:SetText("Rarity" .. ((key=="quality") and (asc and up or dn) or ""))
    self.headerSeen:SetText("Seen" .. ((key=="count") and (asc and up or dn) or ""))
  end
end

function HU.book:CreatePanel(parentName)
  if self.panel then return end

  local panel = CreateFrame("Frame", "EAK_HistoryLogbookPanel", InterfaceOptionsFramePanelContainer)
  panel.name = "History - Logbook"
  panel.parent = parentName
  self.panel = panel

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Logbook")

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  help:SetHeight(20)
  help:SetJustifyH("LEFT")
  help:SetJustifyV("TOP")
  help:SetNonSpaceWrap(true)
  help:SetText("Data Collection for the amount of times any given Echo has been shown.")

  local rarityTotals = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  rarityTotals:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -6)
  rarityTotals:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  rarityTotals:SetJustifyH("LEFT")
  rarityTotals:SetJustifyV("TOP")
  rarityTotals:SetHeight(60)
  rarityTotals:SetText("")
  self.rarityTotalsText = rarityTotals

  local searchRow = CreateFrame("Frame", nil, panel)
  searchRow:SetPoint("TOPLEFT", rarityTotals, "BOTTOMLEFT", 0, -10)
  searchRow:SetPoint("TOPRIGHT", rarityTotals, "BOTTOMRIGHT", 0, -10)
  searchRow:SetHeight(22)

  local searchLabel = searchRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  searchLabel:SetPoint("LEFT", 0, 0)
  searchLabel:SetText("Search:")

  local search = CreateFrame("EditBox", nil, searchRow)
  search:SetSize(240, 20)
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
  search:SetScript("OnTextChanged", function(self)
    HU.book.search = self:GetText() or ""
    HU.book:Refresh()
  end)

  if U and U.EnhanceEditBox then
    U:EnhanceEditBox(search)
  end
  self.searchBox = search

  local listContainer = CreateFrame("Frame", nil, panel)
  listContainer:SetPoint("TOPLEFT", searchRow, "BOTTOMLEFT", 0, -12)
  listContainer:SetPoint("TOPRIGHT", searchRow, "BOTTOMRIGHT", 0, -12)
  listContainer:SetHeight(240)
  listContainer:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  listContainer:SetBackdropColor(0, 0, 0, 0.35)
  listContainer:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)

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
  headerName:SetText("Echo")

  local headerSeen = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerSeen:SetPoint("RIGHT", -10, 0)
  headerSeen:SetText("Seen")

  local headerRarity = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  headerRarity:SetPoint("RIGHT", headerSeen, "LEFT", -18, 0)
  headerRarity:SetText("Rarity")

  self.headerName = headerName
  self.headerSeen = headerSeen
  self.headerRarity = headerRarity

  local nameBtn = CreateFrame("Button", nil, header)
  nameBtn:SetAllPoints(headerName)
  nameBtn:SetScript("OnClick", function() Book_SetSort("name"); HU.book:Refresh() end)

  local rarityBtn = CreateFrame("Button", nil, header)
  rarityBtn:SetAllPoints(headerRarity)
  rarityBtn:SetScript("OnClick", function() Book_SetSort("quality"); HU.book:Refresh() end)

  local seenBtn = CreateFrame("Button", nil, header)
  seenBtn:SetAllPoints(headerSeen)
  seenBtn:SetScript("OnClick", function() Book_SetSort("count"); HU.book:Refresh() end)

  local ROW_H = 30

  local scrollList = CreateFrame("ScrollFrame", "EAK_HistoryLogbookScroll", listContainer, "FauxScrollFrameTemplate")
  scrollList:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, -26)
  scrollList:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 8)
  self.scroll = scrollList
  scrollList:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() HU.book:Refresh() end)
  end)

  local sb = _G[scrollList:GetName() .. "ScrollBar"]
  if sb and sb.ClearAllPoints then
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT", scrollList, "TOPRIGHT", 0, 4)
    sb:SetPoint("BOTTOMLEFT", scrollList, "BOTTOMRIGHT", 0, 12)
  end


  local contentList = CreateFrame("Frame", nil, listContainer)
  contentList:SetPoint("TOPLEFT", 0, -26)
  contentList:SetPoint("BOTTOMRIGHT", -24, 8)

  scrollList:SetFrameLevel(listContainer:GetFrameLevel() + 1)
  contentList:SetFrameLevel(scrollList:GetFrameLevel() + 1)

  for i = 1, 7 do
    local row = Book_CreateRow(contentList)
    row:SetFrameLevel(contentList:GetFrameLevel() + 1)
    row:SetPoint("TOPLEFT", 0, - (i-1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, - (i-1) * ROW_H)
    table.insert(self.rows, row)
  end

  panel.refresh = function() HU.book:Refresh() end
  panel:SetScript("OnShow", function()
    if panel.refresh then panel.refresh() end
		if EnsureUtils() then
			U:After(0, function()
				if panel:IsShown() and panel.refresh then panel.refresh() end
			end)
		end
  end)

  local statsRow = CreateFrame("Frame", nil, panel)
  statsRow:SetPoint("TOPLEFT", listContainer, "BOTTOMLEFT", 0, 0)
  statsRow:SetPoint("TOPRIGHT", listContainer, "BOTTOMRIGHT", 0, 0)
  statsRow:SetHeight(22)

  local totalText = statsRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  totalText:SetPoint("LEFT", 0, 0)
  totalText:SetText("Total Echoes Seen: 0")
  self.totalText = totalText
  local exportBtn = CreateFrame("Button", nil, statsRow, "UIPanelButtonTemplate")
  exportBtn:SetSize(80, 22)
  exportBtn:SetPoint("RIGHT", 0, 0)
  exportBtn:SetText("Export")
  exportBtn:SetScript("OnClick", function()
    HU:ShowTextPopup("Logbook Export", Book_ExportText())
  end)

  local resetBtn = CreateFrame("Button", nil, statsRow, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 22)
  resetBtn:SetPoint("RIGHT", exportBtn, "LEFT", -8, 0)
  resetBtn:SetText("Reset")
  resetBtn:SetScript("OnClick", function()
    U:ResetLogbook()
    HU.book:Refresh()
  end)

  totalText:SetPoint("RIGHT", resetBtn, "LEFT", -12, 0)

  InterfaceOptions_AddCategory(panel)
  self:Refresh()
end

function HU:CreatePanel(parentName)
  HU.auto:CreatePanel(parentName)
  HU.book:CreatePanel(parentName)
end
