local E, L, C = select(2, ...):unpack()

local P = CreateFrame("Frame")
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local runeforge_specID = E.runeforge_specID

P.spell_enabled = {}

function P:Enable()
	if self.enabled then
		return
	end

	self:RegisterEvent("UI_SCALE_CHANGED")
	self:RegisterEvent("CVAR_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
	self:RegisterEvent("GROUP_JOINED")
	self:SetScript("OnEvent", function(self, event, ...)
		self[event](self, ...)
	end)

	self.enabled = true

	E.Comms:InspectPlayer() -- [58]

	self:SetHooks()
	self:CreateExBars()
	self:Refresh(true)
end

function P:Disable()
	if not self.enabled then
		return
	end

	if self.test then
		self:Test()
	end
	self.disabledzone = true
	self:UnregisterAllEvents()
	self:ResetModule(true)

	self.enabled = false
end

function P:HideAllBars()
	self:HideBars()
	self:HideExBars()
end

function P:ResetModule(isModuleDisabled)
	if not isModuleDisabled then
		E.UnregisterEvents(self, self.zoneEvents.all)
	end
	E.Comms:Disable()
	E.Cooldowns:Disable()

	wipe(self.groupInfo)

	self.disabled = true
	self:HideAllBars()
end

function P:Refresh(full)
	if not self.enabled then
		return
	end

	local instanceType = self.zone or select(2, IsInInstance()) -- [59]
	local key = self.test and self.testZone or instanceType
	key = key == "none" and E.profile.Party.noneZoneSetting or (key == "scenario" and E.profile.Party.scenarioZoneSetting) or key
	E.db = E.profile.Party[key]

	if full then
		self:UpdateFontObj() -- shared frames still needs to be updated on every call
		self:UpdateTextureObj()
		self:PLAYER_ENTERING_WORLD(nil, nil, true)
	else
		E:SetActiveUnitFrameData()
		self:UpdatePositionValues()
		self:UpdateExPositionValues()
		self:UpdateBars()
		self:UpdatePosition()
		self:UpdateExPosition()
	end
end

function P:UpdateFontObj()
	local db_anchor = E.profile.General.fonts.anchor
	for i = 1, #self.bars do
		local f = self.bars[i]
		E.SetFontObj(f.anchor.text, db_anchor)
	end

	for i = 1, #self.unusedBars do
		local f = self.unusedBars[i]
		E.SetFontObj(f.anchor.text, db_anchor)
	end

	for _, f in pairs(self.extraBars) do
		E.SetFontObj(f.anchor.text, db_anchor)
		E.SetWidth(f.anchor)
	end

	self.TestMod:SetAnchor(self.testZone)

	local db_icon = E.profile.General.fonts.icon
	local db_statusBar = E.profile.General.fonts.statusBar
	for _, info in pairs(self.groupInfo) do
		local icons = info.spellIcons
		for _, icon in pairs(icons) do
			local statusBar = icon.statusBar
			if statusBar then
				E.SetFontObj(statusBar.Text, db_statusBar)
				E.SetFontObj(statusBar.CastingBar.Text, db_statusBar)
				E.SetFontObj(statusBar.CastingBar.Timer, db_statusBar)
			end
			E.SetFontObj(icon.Name, db_icon)
		end
	end

	for i = 1, #self.unusedIcons do
		local icon = self.unusedIcons[i]
		E.SetFontObj(icon.Name, db_icon)
	end

	for i = 1, #self.unusedStatusBars do
		local statusBar = self.unusedStatusBars[i]
		E.SetFontObj(statusBar.Text, db_statusBar)
		E.SetFontObj(statusBar.CastingBar.Text, db_statusBar)
		E.SetFontObj(statusBar.CastingBar.Timer, db_statusBar)
	end
end

function P:UpdateTextureObj()
	local texture = E.LSM:Fetch("statusbar", E.profile.General.textures.statusBar.bar)
	self:ConfigTextures()

	for i = 1, #self.unusedStatusBars do
		local statusBar = self.unusedStatusBars[i]
		statusBar.BG:SetTexture(texture)
		statusBar.CastingBar:SetStatusBarTexture(texture)
		statusBar.CastingBar.BG:SetTexture(E.LSM:Fetch("statusbar", E.profile.General.textures.statusBar.BG))
	end
end

function P:UpdatePositionValues()
	local db = E.db.position

	self.point = db.anchor
	self.relativePoint = db.attach

	local growLeft = string.find(self.point, "RIGHT")
	local growX = growLeft and -1 or 1

	self.anchorPoint = growLeft and "BOTTOMLEFT" or "BOTTOMRIGHT"
	self.containerOfsX = db.offsetX * growX
	self.containerOfsY = -db.offsetY
	self.columns = db.columns
	self.doubleRow = db.layout == "doubleRow"
	self.breakPoint = E.db.priority[db.breakPoint]
	self.displayInactive = db.displayInactive

	local growUpward = db.growUpward
	local growY = growUpward and 1 or -1
	local px = E.NumPixels / E.db.icons.scale
	if db.layout == "vertical" then
		self.point2 = growUpward and "BOTTOMRIGHT" or "TOPRIGHT"
		self.relativePoint2 = growUpward and "TOPRIGHT" or "BOTTOMRIGHT"
		self.ofsX = growX * (E.BASE_ICON_SIZE + db.paddingX  * px)
		self.ofsY = 0
		self.ofsX2 = 0
		self.ofsY2 = growY * db.paddingY * px
	else
		self.point2 = growLeft and "TOPRIGHT" or "TOPLEFT"
		self.relativePoint2 = growLeft and "TOPLEFT" or "TOPRIGHT"
		self.ofsX = 0
		self.ofsY = growY * (E.BASE_ICON_SIZE + db.paddingY * px)
		self.ofsX2 = growX * db.paddingX * px
		self.ofsY2 = 0
		--[[ xml
		if growUpward then
			self.point3 = growLeft and "BOTTOMRIGHT" or "BOTTOMLEFT"
		else
			self.point3 = self.point2
		end
		self.relativePoint3 = self.point2
		self.modRowOfsX = E.db.icons.modRowOfsX * growX
		self.modRowOfsY = growUpward and db.paddingY * px or -E.BASE_ICON_SIZE - db.paddingY * px
		self.ofsX4 = growX * db.paddingX * px / E.db.icons.modRowScale
		--]]
	end
end

function P:GetBuffDuration(unit, spellID)
	for i = 1, 40 do
		local _,_,_,_, duration, expTime,_,_,_, id = UnitBuff(unit, i)
		if not id then return end
		if id == spellID then
			return duration > 0 and expTime - GetTime()
		end
	end
end

function P:GetDebuffDuration(unit, spellID)
	for i = 1, 40 do
		local _,_,_,_, duration, expTime,_,_,_, id = UnitDebuff(unit, i)
		if not id then return end
		if id == spellID then
			return duration > 0 and expTime - GetTime()
		end
	end
end

function P:GetEffectiveNumGroupMembers()
	local size = GetNumGroupMembers()
	return size == 0 and self.test and 1 or size
end

function P:GetValueByType(v, guid, item2)
	if v then
		if type(v) == "table" then
			if item2 then
				return self.groupInfo[guid].invSlotData[item2] and v[item2] or v.default
			end
			return v[self.groupInfo[guid].spec] or v.default
		else
			return v
		end
	end
end

function P:IsTalent(talentID, guid)
	if not talentID then
		return true
	end

	local talent = self.groupInfo[guid].talentData[talentID]
	if not talent then
		return false
	end

	if talent == "PVP" then
		return self.isPvP
	elseif talent == "R" then
		local spec = runeforge_specID[talentID]
		return not spec and true or spec == self.groupInfo[guid].spec
	else
		return talent -- [60]
	end
end

function P:IsEquipped(itemID, guid, item2)
	if not itemID then
		return true
	end

	local invSlotData = self.groupInfo[guid].invSlotData
	if invSlotData[itemID] then
		return true
	end
	return invSlotData[item2]
end

function P.IsEnabledSpell(id, key)
	local db = key and E.profile.Party[key] or E.db
	id = tostring(id)
	return db.spells[id]
end

function P:IsDeBuffActive(unit, spellID)
	for i = 1, 40 do
		local _,_,_,_, duration, expTime,_,_,_, id = UnitDebuff(unit, i)
		if not id then return end
		if id == spellID then
			return true
		end
	end
end

function P:ConfirmReload(text, data, arg)
	local dialog = StaticPopup_Show("OMNICD_RELOADUI", text)
	dialog.data = data
	dialog.data2 = arg
	dialog:SetFrameStrata("TOOLTIP")
end

function P:UI_SCALE_CHANGED() -- [61]
	E:SetNumPixels()
	self:ConfigSize(nil, true)
	for key in pairs(self.extraBars) do
		self:ConfigExSize(key, true)
	end
end

E["Party"] = P
