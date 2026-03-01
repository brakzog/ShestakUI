local T, C, L = unpack(ShestakUI)
if C.chat.enable ~= true then return end


-- --------------------------------------------------------------------
-- HARD NUKE: Blizzard HelpTips about Voice/Speech/Narration (overlay tutorial)
-- --------------------------------------------------------------------
do
	-- 1) Disable tutorials globally (safe if CVar exists)
	pcall(SetCVar, "showTutorials", 0)

	-- 2) Block via global function (some builds use this)
	local orig_Show = _G.HelpTip_Show
	if type(orig_Show) == "function" then
		_G.HelpTip_Show = function(parent, info, relativeRegion, ...)
			if info and type(info.text) == "string" then
				local t = info.text:lower()
				if t:find("synthèse vocale", 1, true)
					or t:find("sous%-titres", 1, true)
					or t:find("canal vocal", 1, true)
					or t:find("speech", 1, true)
					or t:find("transcription", 1, true)
					or t:find("text to speech", 1, true)
				then
					return
				end
			end
			return orig_Show(parent, info, relativeRegion, ...)
		end
	end

	-- 3) Block via method (some builds bypass HelpTip_Show and call HelpTip:Show)
	if _G.HelpTip and type(_G.HelpTip.Show) == "function" then
		local orig_Method = _G.HelpTip.Show
		_G.HelpTip.Show = function(self, parent, info, relativeRegion, ...)
			if info and type(info.text) == "string" then
				local t = info.text:lower()
				if t:find("synthèse vocale", 1, true)
					or t:find("sous%-titres", 1, true)
					or t:find("canal vocal", 1, true)
					or t:find("speech", 1, true)
					or t:find("transcription", 1, true)
					or t:find("text to speech", 1, true)
				then
					return
				end
			end
			return orig_Method(self, parent, info, relativeRegion, ...)
		end
	end

	-- 4) Vacuum cleaner: if Blizzard spawns it anyway, delete it repeatedly for a few seconds
	local function HideAllTips()
		if _G.HelpTip and type(_G.HelpTip.HideAll) == "function" then
			_G.HelpTip:HideAll()
		elseif type(_G.HelpTipHideAll) == "function" then
			_G.HelpTipHideAll()
		end
	end

	C_Timer.After(0.5, HideAllTips)
	C_Timer.After(1.5, HideAllTips)
	C_Timer.After(3.0, HideAllTips)

	-- small ticker for the “it keeps coming back” case (stops after ~10s)
	local ticks = 0
	C_Timer.NewTicker(1.0, function()
		ticks = ticks + 1
		HideAllTips()
		if ticks >= 10 then
			-- ticker auto-stops by returning nil; WoW ticker stops when no ref kept
		end
	end, 10)
end


----------------------------------------------------------------------------------------
--	Narrator / Speech-to-text OFF + Block the Blizzard HelpTip overlay
----------------------------------------------------------------------------------------
local function KillNarrator()
	-- CVars (harmless if missing)
	pcall(SetCVar, "enableNarration", 0)
	pcall(SetCVar, "speechToText", 0)
	pcall(SetCVar, "voiceTranscription", 0)
	pcall(SetCVar, "textToSpeech", 0)
	pcall(SetCVar, "voiceChatTextToSpeech", 0)

	-- API (if present)
	if C_Accessibility then
		if C_Accessibility.SetNarratorEnabled then pcall(C_Accessibility.SetNarratorEnabled, false) end
		if C_Accessibility.SetSpeechToTextEnabled then pcall(C_Accessibility.SetSpeechToTextEnabled, false) end
		if C_Accessibility.SetTextToSpeechEnabled then pcall(C_Accessibility.SetTextToSpeechEnabled, false) end
	end

	-- Some builds show quick-start toasts
	if _G.NarratorQuickStartToast then
		_G.NarratorQuickStartToast:Hide()
		_G.NarratorQuickStartToast.Show = function() end
	end
	if _G.SpeechToTextToast then
		_G.SpeechToTextToast:Hide()
		_G.SpeechToTextToast.Show = function() end
	end
end

-- Run multiple times (Blizzard can re-enable when Accessibility UI loads)
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(_, event, addon)
		if event == "ADDON_LOADED" and addon ~= "Blizzard_AccessibilityUI" then return end
		C_Timer.After(0, KillNarrator)
		C_Timer.After(0.5, KillNarrator)
		C_Timer.After(2.0, KillNarrator)
	end)
end

-- Block the annoying overlay (this is NOT chat text; it’s a HelpTip)
do
	local orig = _G.HelpTip_Show
	if type(orig) == "function" then
		_G.HelpTip_Show = function(parent, info, relativeRegion, ...)
			if info and type(info.text) == "string" then
				local t = info.text:lower()
				if t:find("synthèse vocale", 1, true)
					or t:find("sous%-titres", 1, true)
					or t:find("canal vocal", 1, true)
					or t:find("speech", 1, true)
					or t:find("transcription", 1, true)
				then
					return
				end
			end
			return orig(parent, info, relativeRegion, ...)
		end
	end

	C_Timer.After(0.5, function()
		if HelpTip and HelpTip.HideAll then
			HelpTip:HideAll()
		end
	end)
end

-- (Optional) filter system lines that still slip into chat sometimes
local function FilterNarratorSpam(_, _, msg, ...)
	if type(msg) == "string" then
		if msg:find("La synthèse vocale vous permet", 1, true)
			or msg:find("sous%-titres à un canal vocal", 1, true)
			or msg:find("Speech to Text", 1, true)
			or msg:find("Text to Speech", 1, true)
		then
			return true
		end
	end
	return false, msg, ...
end
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterNarratorSpam)

----------------------------------------------------------------------------------------
--	Style chat frame(by Tukz and p3lim)
----------------------------------------------------------------------------------------
local origs = {}

local function Strip(info, name)
	return string.format("|Hplayer:%s|h[%s]|h", info, name:gsub("%-[^|]+", ""))
end

-- Function to rename channel and other stuff
local function AddMessage(self, text, ...)
	if type(text) == "string" and canaccessvalue(text) then
		text = text:gsub("|h%[(%d+)%. .-%]|h", "|h[%1]|h")
		text = text:gsub("|Hplayer:(.-)|h%[(.-)%]|h", Strip)
	end
	return origs[self](self, text, ...)
end

-- Kill channel and voice buttons
ChatFrameChannelButton:Kill()
ChatFrameToggleVoiceDeafenButton:Kill()
ChatFrameToggleVoiceMuteButton:Kill()

-- Set chat style
local function SetChatStyle(frame)
	local id = frame:GetID()
	local chat = frame:GetName()
	local editBox = _G[chat.."EditBox"]

	_G[chat]:SetFrameLevel(5)
	_G[chat]:SetClampedToScreen(false)
	_G[chat]:SetFading(false)

	-- Move the chat edit box
	editBox:ClearAllPoints()
	editBox:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -10, 23)
	editBox:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 11, 23)

	-- Hide textures
	for j = 1, #CHAT_FRAME_TEXTURES do
		_G[chat..CHAT_FRAME_TEXTURES[j]]:SetTexture(nil)
	end

	-- Removes Default ChatFrame Tabs texture
	_G[format("ChatFrame%sTab", id)].Left:Kill()
	_G[format("ChatFrame%sTab", id)].Middle:Kill()
	_G[format("ChatFrame%sTab", id)].Right:Kill()

	_G[format("ChatFrame%sTab", id)].ActiveLeft:Kill()
	_G[format("ChatFrame%sTab", id)].ActiveMiddle:Kill()
	_G[format("ChatFrame%sTab", id)].ActiveRight:Kill()

	_G[format("ChatFrame%sTab", id)].HighlightLeft:Kill()
	_G[format("ChatFrame%sTab", id)].HighlightMiddle:Kill()
	_G[format("ChatFrame%sTab", id)].HighlightRight:Kill()

	-- Killing off the new chat tab selected feature
	_G[format("ChatFrame%sButtonFrameMinimizeButton", id)]:Kill()
	_G[format("ChatFrame%sButtonFrame", id)]:Kill()

	-- Kills off the new circle around the editbox
	_G[format("ChatFrame%sEditBoxLeft", id)]:Kill()
	_G[format("ChatFrame%sEditBoxMid", id)]:Kill()
	_G[format("ChatFrame%sEditBoxRight", id)]:Kill()

	_G[format("ChatFrame%sEditBoxFocusLeft", id)]:SetTexture("")
	_G[format("ChatFrame%sEditBoxFocusMid", id)]:SetTexture("")
	_G[format("ChatFrame%sEditBoxFocusRight", id)]:SetTexture("")

	_G[format("ChatFrame%sTabGlow", id)]:Kill()

	-- Kill scroll bar
	frame.ScrollBar:Kill()
	frame.ScrollToBottomButton:Kill()

	-- Kill off editbox artwork
	local a, b, c = select(6, editBox:GetRegions())
	a:Kill() b:Kill() c:Kill()

	-- Kill bubble tex/glow
	if _G[chat.."Tab"].conversationIcon then _G[chat.."Tab"].conversationIcon:Kill() end

	-- Disable alt key usage
	editBox:SetAltArrowKeyMode(false)

	-- Hide editbox on login
	editBox:Hide()

	-- Script to hide editbox instead of fading editbox to 0.35 alpha via IM Style
	editBox:HookScript("OnEditFocusGained", function(self) self:Show() end)
	editBox:HookScript("OnEditFocusLost", function(self) if self:GetText() == "" then self:Hide() end end)

	-- Hide edit box every time we click on a tab
	_G[chat.."Tab"]:HookScript("OnClick", function() editBox:Hide() end)

	-- Create our own texture for edit box
	if C.chat.background == true and C.chat.tabs_mouseover ~= true then
		local EditBoxBackground = CreateFrame("Frame", "ChatEditBoxBackground", editBox)
		EditBoxBackground:CreatePanel("Transparent", 1, 1, "LEFT", editBox, "LEFT", 0, 0)
		EditBoxBackground:ClearAllPoints()
		EditBoxBackground:SetPoint("TOPLEFT", editBox, "TOPLEFT", 7, -5)
		EditBoxBackground:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -7, 4)
		EditBoxBackground:SetFrameStrata("LOW")
		EditBoxBackground:SetFrameLevel(1)

		local function colorize(r, g, b)
			EditBoxBackground:SetBackdropBorderColor(r, g, b)
		end

		hooksecurefunc(editBox, "UpdateHeader", function()
			local chatType = editBox:GetAttribute("chatType")
			if not chatType then return end

			local chanTarget = editBox:GetAttribute("channelTarget")
			local chanName = chanTarget and GetChannelName(chanTarget)
			if chanName and chatType == "CHANNEL" then
				if chanName == 0 then
					colorize(unpack(C.media.border_color))
				else
					colorize(ChatTypeInfo[chatType..chanName].r, ChatTypeInfo[chatType..chanName].g, ChatTypeInfo[chatType..chanName].b)
				end
			else
				colorize(ChatTypeInfo[chatType].r, ChatTypeInfo[chatType].g, ChatTypeInfo[chatType].b)
			end
		end)
	end

	-- Rename combat log tab
	if _G[chat] == _G["ChatFrame2"] then
		CombatLogQuickButtonFrame_Custom:StripTextures()
		CombatLogQuickButtonFrame_Custom:CreateBackdrop("Transparent")
		CombatLogQuickButtonFrame_Custom.backdrop:SetPoint("TOPLEFT", 1, -4)
		CombatLogQuickButtonFrame_Custom.backdrop:SetPoint("BOTTOMRIGHT", -22, 0)
		T.SkinCloseButton(CombatLogQuickButtonFrame_CustomAdditionalFilterButton, CombatLogQuickButtonFrame_Custom.backdrop, " ", true)
		CombatLogQuickButtonFrame_CustomAdditionalFilterButton:SetSize(12, 12)
		CombatLogQuickButtonFrame_CustomAdditionalFilterButton:SetHitRectInsets(0, 0, 0, 0)
		CombatLogQuickButtonFrame_CustomProgressBar:ClearAllPoints()
		CombatLogQuickButtonFrame_CustomProgressBar:SetPoint("TOPLEFT", CombatLogQuickButtonFrame_Custom.backdrop, 2, -2)
		CombatLogQuickButtonFrame_CustomProgressBar:SetPoint("BOTTOMRIGHT", CombatLogQuickButtonFrame_Custom.backdrop, -2, 2)
		CombatLogQuickButtonFrame_CustomProgressBar:SetStatusBarTexture(C.media.texture)
		CombatLogQuickButtonFrameButton1:SetPoint("BOTTOM", 0, 0)
	end

	if _G[chat] ~= _G["ChatFrame2"] then
		origs[_G[chat]] = _G[chat].AddMessage
		_G[chat].AddMessage = AddMessage

		local color = C.chat.custom_time_color and T.RGBToHex(unpack(C.chat.time_color)) or ""
		_G.TIMESTAMP_FORMAT_HHMM = color.."[%I:%M]|r "
		_G.TIMESTAMP_FORMAT_HHMMSS = color.."[%I:%M:%S]|r "
		_G.TIMESTAMP_FORMAT_HHMMSS_24HR = color.."[%H:%M:%S]|r "
		_G.TIMESTAMP_FORMAT_HHMMSS_AMPM = color.."[%I:%M:%S %p]|r "
		_G.TIMESTAMP_FORMAT_HHMM_24HR = color.."[%H:%M]|r "
		_G.TIMESTAMP_FORMAT_HHMM_AMPM = color.."[%I:%M %p]|r "
	end

	frame.skinned = true
end

-- Setup chatframes 1 to 10 on login
local function SetupChat()
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local frame = _G[format("ChatFrame%s", i)]
		SetChatStyle(frame)
	end

	-- Remember last channel
	local var = (C.chat.sticky == true) and 1 or 0
	ChatTypeInfo.SAY.sticky = var
	ChatTypeInfo.PARTY.sticky = var
	ChatTypeInfo.PARTY_LEADER.sticky = var
	ChatTypeInfo.GUILD.sticky = var
	ChatTypeInfo.OFFICER.sticky = var
	ChatTypeInfo.RAID.sticky = var
	ChatTypeInfo.RAID_WARNING.sticky = var
	ChatTypeInfo.INSTANCE_CHAT.sticky = var
	ChatTypeInfo.INSTANCE_CHAT_LEADER.sticky = var
	ChatTypeInfo.WHISPER.sticky = var
	ChatTypeInfo.BN_WHISPER.sticky = var
	ChatTypeInfo.CHANNEL.sticky = var
end

local function SetupChatPosAndFont()
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local chat = _G[format("ChatFrame%s", i)]
		local id = chat:GetID()
		local _, fontSize = FCF_GetChatWindowInfo(id)

		if fontSize < 11 then
			FCF_SetChatWindowFontSize(nil, chat, 11)
		else
			FCF_SetChatWindowFontSize(nil, chat, fontSize)
		end

		chat:SetFont(C.font.chat_font, fontSize, C.font.chat_font_style)
		chat:SetShadowOffset(C.font.chat_font_shadow and 1 or 0, C.font.chat_font_shadow and -1 or 0)

		if i == 1 then
			chat:ClearAllPoints()
			chat:SetSize(C.chat.width, C.chat.height)
			if C.chat.background == true then
				chat:SetPoint(C.position.chat[1], C.position.chat[2], C.position.chat[3], C.position.chat[4], C.position.chat[5] + 4)
			else
				chat:SetPoint(C.position.chat[1], C.position.chat[2], C.position.chat[3], C.position.chat[4], C.position.chat[5])
			end
			FCF_SavePositionAndDimensions(chat)
		elseif i == 2 then
			if C.chat.combatlog ~= true then
				FCF_DockFrame(chat)
				ChatFrame2Tab:EnableMouse(false)
				ChatFrame2Tab.Text:Hide()
				ChatFrame2Tab:SetWidth(0.001)
				ChatFrame2Tab.SetWidth = T.dummy
				FCF_DockUpdate()
			end
		end

		chat:SetScript("OnMouseWheel", FloatingChatFrame_OnMouseScroll)
	end

	QuickJoinToastButton:ClearAllPoints()
	QuickJoinToastButton:SetPoint("TOPLEFT", 0, 90)
	QuickJoinToastButton.ClearAllPoints = T.dummy
	QuickJoinToastButton.SetPoint = T.dummy

	QuickJoinToastButton.Toast:ClearAllPoints()
	QuickJoinToastButton.Toast:SetPoint(unpack(C.position.bn_popup))
	QuickJoinToastButton.Toast.Background:SetTexture("")
	QuickJoinToastButton.Toast:CreateBackdrop("Transparent")
	QuickJoinToastButton.Toast.backdrop:SetPoint("TOPLEFT", 0, 0)
	QuickJoinToastButton.Toast.backdrop:SetPoint("BOTTOMRIGHT", 0, 0)
	QuickJoinToastButton.Toast.backdrop:Hide()
	QuickJoinToastButton.Toast:SetWidth(C.chat.width + 7)
	QuickJoinToastButton.Toast.Text:SetWidth(C.chat.width - 20)

	hooksecurefunc(QuickJoinToastButton, "ShowToast", function() QuickJoinToastButton.Toast.backdrop:Show() end)
	hooksecurefunc(QuickJoinToastButton, "HideToast", function() QuickJoinToastButton.Toast.backdrop:Hide() end)

	BNToastFrame:ClearAllPoints()
	BNToastFrame:SetPoint(unpack(C.position.bn_popup))

	hooksecurefunc(BNToastFrame, "SetPoint", function(self, _, anchor)
		if anchor ~= C.position.bn_popup[2] then
			self:ClearAllPoints()
			self:SetPoint(unpack(C.position.bn_popup))
		end
	end)

	hooksecurefunc(BNToastFrame, "ShowToast", function(self)
		if not self.IsSkinned then
			T.SkinCloseButton(self.CloseButton, nil, "x")
			self.CloseButton:SetSize(16, 16)
			self.IsSkinned = true
		end
	end)
end

GeneralDockManagerOverflowButton:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 5)
hooksecurefunc(GeneralDockManagerScrollFrame, "SetPoint", function(self, point, anchor, attachTo, x, y)
	if anchor == GeneralDockManagerOverflowButton and x == 0 and y == 0 then
		self:SetPoint(point, anchor, attachTo, 0, -4)
	end
end)

local UIChat = CreateFrame("Frame")
UIChat:RegisterEvent("ADDON_LOADED")
UIChat:RegisterEvent("PLAYER_ENTERING_WORLD")
UIChat:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" then
		if addon == "Blizzard_CombatLog" then
			self:UnregisterEvent("ADDON_LOADED")
			SetupChat(self)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		SetupChatPosAndFont(self)
	end
end)

local function SetupTempChat()
	local frame = FCF_GetCurrentChatFrame()
	if frame.skinned then return end
	SetChatStyle(frame)
end
hooksecurefunc("FCF_OpenTemporaryWindow", SetupTempChat)

local old = FCFManager_GetNumDedicatedFrames
function FCFManager_GetNumDedicatedFrames(...)
	return select(1, ...) ~= "PET_BATTLE_COMBAT_LOG" and old(...) or 1
end

local function RemoveRealmName(_, _, msg, author, ...)
	local realm = string.gsub(T.realm, " ", "")
	if msg:find("-" .. realm) then
		return false, gsub(msg, "%-"..realm, ""), author, ...
	end
end
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", RemoveRealmName)

----------------------------------------------------------------------------------------
--	Save slash command typo
----------------------------------------------------------------------------------------
local function TypoHistory_Posthook_AddMessage(chat, text)
	if text and canaccessvalue(text) and strfind(text, HELP_TEXT_SIMPLE) then
		ChatFrameEditBoxMixin.AddHistory(chat.editBox)
	end
end

for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
	if i ~= 2 then
		hooksecurefunc(_G["ChatFrame"..i], "AddMessage", TypoHistory_Posthook_AddMessage)
	end
end

----------------------------------------------------------------------------------------
--	Loot icons
----------------------------------------------------------------------------------------
if C.chat.loot_icons == true then
	local function AddLootIcons(_, _, message, ...)
		local function Icon(link)
			local texture = C_Item.GetItemIconByID(link)
			return "\124T"..texture..":12:12:0:0:64:64:5:59:5:59\124t"..link
		end
		message = message:gsub("(\124c%x+\124Hitem:.-\124h\124r)", Icon)
		return false, message, ...
	end
	ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_LOOT", AddLootIcons)
end

----------------------------------------------------------------------------------------
--	Swith channels by Tab
----------------------------------------------------------------------------------------
local cycles = {
	{chatType = "SAY", use = function() return 1 end},
	{chatType = "PARTY", use = function() return not IsInRaid() and IsInGroup(LE_PARTY_CATEGORY_HOME) end},
	{chatType = "RAID", use = function() return IsInRaid(LE_PARTY_CATEGORY_HOME) end},
	{chatType = "INSTANCE_CHAT", use = function() return IsPartyLFG() or C_PartyInfo.IsPartyWalkIn() end},
	{chatType = "GUILD", use = function() return IsInGuild() end},
	{chatType = "SAY", use = function() return 1 end},
}

local function UpdateTabChannelSwitch(self)
	if strsub(tostring(self:GetText()), 1, 1) == "/" then return end
	local currChatType = self:GetAttribute("chatType")
	for i, curr in ipairs(cycles) do
		if curr.chatType == currChatType then
			local h, r, step = i + 1, #cycles, 1
			if IsShiftKeyDown() then h, r, step = i - 1, 1, -1 end
			for j = h, r, step do
				if cycles[j]:use(self, currChatType) then
					self:SetAttribute("chatType", cycles[j].chatType)
					ChatFrameEditBoxMixin.UpdateHeaderr(self)
					return
				end
			end
		end
	end
end
hooksecurefunc("ChatEdit_CustomTabPressed", UpdateTabChannelSwitch)

----------------------------------------------------------------------------------------
--	Role icons
----------------------------------------------------------------------------------------
if C.chat.role_icons == true then
	local chats = {
		CHAT_MSG_SAY = 1, CHAT_MSG_YELL = 1,
		CHAT_MSG_WHISPER = 1, CHAT_MSG_WHISPER_INFORM = 1,
		CHAT_MSG_PARTY = 1, CHAT_MSG_PARTY_LEADER = 1,
		CHAT_MSG_INSTANCE_CHAT = 1, CHAT_MSG_INSTANCE_CHAT_LEADER = 1,
		CHAT_MSG_RAID = 1, CHAT_MSG_RAID_LEADER = 1, CHAT_MSG_RAID_WARNING = 1,
	}

	local role_tex = {
		TANK = "\124T"..[[Interface\AddOns\ShestakUI\Media\Textures\Tank.tga]]..":12:12:0:0:64:64:5:59:5:59\124t",
		HEALER = "\124T"..[[Interface\AddOns\ShestakUI\Media\Textures\Healer.tga]]..":12:12:0:0:64:64:5:59:5:59\124t",
		DAMAGER = "\124T"..[[Interface\AddOns\ShestakUI\Media\Textures\Damager.tga]]..":12:12:0:0:64:64:5:59:5:59\124t",
	}

	local GetColoredName_orig = _G.GetColoredName
	local function GetColoredName_hook(event, arg1, arg2, ...)
		local ret = GetColoredName_orig(event, arg1, arg2, ...)
		if chats[event] then
			local role = UnitGroupRolesAssigned(arg2)
			if role == "NONE" and arg2:match(" *- *"..GetRealmName().."$") then
				role = UnitGroupRolesAssigned(arg2:gsub(" *-[^-]+$",""))
			end
			if role and role ~= "NONE" then
				ret = role_tex[role]..ret
			end
		end
		return ret
	end
	_G.GetColoredName = GetColoredName_hook
end


-- --------------------------------------------------------------------
-- Force ChatFrame3 tab (BUTIN) to stay on ChatBackgroundThird (Shestak)
-- --------------------------------------------------------------------
local function ForceThirdTab()
	if not _G.ChatFrame3 or not _G.ChatFrame3Tab or not _G.ChatBackgroundThird then return end

	local cf  = _G.ChatFrame3
	local tab = _G.ChatFrame3Tab
	local panel = _G.ChatBackgroundThird

	-- 1) Undock hard (sinon Blizzard le garde dans le dock manager)
	pcall(FCF_UnDockFrame, cf)
	pcall(FCF_DockUpdate)

	-- 2) Parent + points du TAB = comme tes autres headers
	tab:SetParent(panel)
	tab:ClearAllPoints()
	tab:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 0)
	tab:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 0)

	-- 3) Recaler le texte du tab (sinon il flotte / s’offset)
	if tab.Text then
		tab.Text:ClearAllPoints()
		tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -1)
		tab.Text:Show()
	end

	-- 4) Forcer visible (certains setups Shestak mettent alpha 0)
	tab:SetAlpha(1)
	tab:Show()
	tab:EnableMouse(true)
end


----------------------------------------------------------------------------------------
--	Prevent reposition ChatFrame
----------------------------------------------------------------------------------------
hooksecurefunc(ChatFrame1, "SetPoint", function(self, _, _, _, x)
	if MoverInfo and MoverInfo:IsShown() then return end
	local positionTable = T.CurrentProfile()
	if positionTable["ChatFrame1"] then
		local _, _, _, newx = unpack(positionTable["ChatFrame1"])
		if x ~= newx then
			self:ClearAllPoints()
			self:SetPoint(unpack(positionTable["ChatFrame1"]))
		end
	else
		if x ~= C.position.chat[4] then
			self:ClearAllPoints()
			self:SetSize(C.chat.width, C.chat.height)
			self.SetSize = T.dummy
			if C.chat.background == true then
				self:SetPoint(C.position.chat[1], C.position.chat[2], C.position.chat[3], C.position.chat[4], C.position.chat[5] + 4)
			else
				self:SetPoint(C.position.chat[1], C.position.chat[2], C.position.chat[3], C.position.chat[4], C.position.chat[5])
			end
		end
	end
end)

----------------------------------------------------------------------------------------
--  Right chat frame + THIRD chat (left) + hyperlinks fix
----------------------------------------------------------------------------------------
if not C.chat.second_frame then return end

----------------------------------------------------------------------------------------
--  RIGHT ANCHOR (ChatFrame4)
----------------------------------------------------------------------------------------
local rightAnchor = CreateFrame("Frame", "ChatFrameRightAnchor", UIParent)
rightAnchor:SetSize(C.chat.width, C.chat.height)
rightAnchor:EnableMouse(false)
rightAnchor:EnableMouseWheel(false)
rightAnchor:SetFrameStrata("BACKGROUND")
rightAnchor:SetFrameLevel(0)

if C.minimap.on_top then
	if C.chat.background == true then
		rightAnchor:SetPoint(C.position.chat_right[1], C.position.chat_right[2], C.position.chat_right[3], C.position.chat_right[4], C.position.chat_right[5] + 4)
	else
		rightAnchor:SetPoint(unpack(C.position.chat_right))
	end
else
	if C.chat.background == true then
		rightAnchor:SetPoint(C.position.chat_right[1], C.position.chat_right[2], C.position.chat_right[3], C.position.chat_right[4] - C.minimap.size - 23, C.position.chat_right[5] + 4)
	else
		rightAnchor:SetPoint(C.position.chat_right[1], C.position.chat_right[2], C.position.chat_right[3], C.position.chat_right[4] - C.minimap.size - 23, C.position.chat_right[5])
	end
end

hooksecurefunc(ChatFrame4, "SetPoint", function(self, _, _, _, x)
	if x ~= C.position.chat_right[4] then
		self:ClearAllPoints()
		self:SetSize(C.chat.width, C.chat.height)
		self:SetAllPoints(rightAnchor)
	end
end)

C_Timer.After(0.1, function()
	if not ChatFrame4 then
		FCF_OpenNewWindow(LOOT)
	end
	if ChatFrame4 then
		FCF_UnDockFrame(ChatFrame4)
		ChatFrame4:SetAllPoints(rightAnchor)

		ChatFrame4:SetFrameStrata("LOW")
		ChatFrame4:SetFrameLevel(50)
		ChatFrame4:EnableMouse(true)
		if ChatFrame4.SetHyperlinksEnabled then ChatFrame4:SetHyperlinksEnabled(true) end
		if ChatFrame4.FontStringContainer then
			ChatFrame4.FontStringContainer:EnableMouse(true)
			ChatFrame4.FontStringContainer:SetFrameStrata("LOW")
			ChatFrame4.FontStringContainer:SetFrameLevel(51)
		end

		FCF_SetTabPosition(ChatFrame4, 0)
		FCF_CheckShowChatFrame(ChatFrame4)
	end
end)

----------------------------------------------------------------------------------------
--  Helpers: do not let panels steal clicks
----------------------------------------------------------------------------------------
local function DisableMouseDeep(frame)
	if not frame then return end
	if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
	if frame.EnableMouseWheel then pcall(frame.EnableMouseWheel, frame, false) end
	if frame.SetScript then
		for _, s in ipairs({
			"OnMouseDown", "OnMouseUp", "OnClick",
			"OnEnter", "OnLeave", "OnMouseWheel"
		}) do
			pcall(frame.SetScript, frame, s, nil)
		end
	end
	local kids = { frame:GetChildren() }
	for i = 1, #kids do
		DisableMouseDeep(kids[i])
	end
end

----------------------------------------------------------------------------------------
--  THIRD CHAT (ChatFrame3 = BUTIN) - left of ChatFrame1, Shestak style, width dedicated
----------------------------------------------------------------------------------------
local GAP = 10
local BASE_W = tonumber(C.chat.width) or 420
local BASE_H = tonumber(C.chat.height) or 180

-- ✅ Réglage simple : largeur BUTIN (change ce ratio)
local LOOT_W = math.floor(BASE_W * 1.1)
local LOOT_H = BASE_H

local leftAnchor = CreateFrame("Frame", "ChatFrameLeftAnchor", UIParent)
leftAnchor:SetSize(LOOT_W, LOOT_H)
leftAnchor:EnableMouse(false)
leftAnchor:EnableMouseWheel(false)
leftAnchor:SetFrameStrata("BACKGROUND")
leftAnchor:SetFrameLevel(0)


local ChatBackgroundThird = CreateFrame("Frame", "ChatBackgroundThird", UIParent)
ChatBackgroundThird:EnableMouse(false)
ChatBackgroundThird:EnableMouseWheel(false)
ChatBackgroundThird:SetFrameStrata("BACKGROUND")
ChatBackgroundThird:SetFrameLevel(0)
ChatBackgroundThird:CreatePanel("Transparent", LOOT_W, LOOT_H, "BOTTOMLEFT", leftAnchor, "BOTTOMLEFT", 0, 0)



-- Run several times because Blizzard keeps reattaching tabs after login / world enter / dock updates
local thirdTabFixer = CreateFrame("Frame")
thirdTabFixer:RegisterEvent("PLAYER_LOGIN")
thirdTabFixer:RegisterEvent("PLAYER_ENTERING_WORLD")
thirdTabFixer:RegisterEvent("UPDATE_CHAT_WINDOWS")
thirdTabFixer:SetScript("OnEvent", function()
	C_Timer.After(0.1, ForceThirdTab)
	C_Timer.After(0.6, ForceThirdTab)
	C_Timer.After(1.5, ForceThirdTab)
end)

-- Also when chat docking refreshes
hooksecurefunc("FCF_DockUpdate", function()
	C_Timer.After(0, ForceThirdTab)
end)


local function SetupThirdChat()
	local cf = _G.ChatFrame3
	if not cf or not _G.ChatFrame1 then return end

	leftAnchor:ClearAllPoints()
	leftAnchor:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMLEFT", -GAP, 0)

	DisableMouseDeep(ChatBackgroundThird)

	pcall(FCF_UnDockFrame, cf)

	if not cf.skinned then
		SetChatStyle(cf)
	end

	-- Place inside panel
	cf:ClearAllPoints()
	cf:SetPoint("TOPLEFT", ChatBackgroundThird, "TOPLEFT", 5, -5)
	cf:SetPoint("BOTTOMRIGHT", ChatBackgroundThird, "BOTTOMRIGHT", -5, 5)

	-- Clickable + hyperlinks
	cf:SetFrameStrata("LOW")
	cf:SetFrameLevel(50)
	cf:EnableMouse(true)
	if cf.SetHyperlinksEnabled then pcall(cf.SetHyperlinksEnabled, cf, true) end

	if cf.FontStringContainer then
		cf.FontStringContainer:EnableMouse(true)
		cf.FontStringContainer:SetFrameStrata("LOW")
		cf.FontStringContainer:SetFrameLevel(51)
	end

	-- Wrap behavior to avoid “looks like overflow”
	if cf.SetIndentedWordWrap then pcall(cf.SetIndentedWordWrap, cf, true) end
	if cf.SetJustifyH then pcall(cf.SetJustifyH, cf, "LEFT") end


	pcall(FCF_SavePositionAndDimensions, cf)
	pcall(FCF_SetTabPosition, cf, 0)
	pcall(FCF_CheckShowChatFrame, cf)
	ForceThirdTab()
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function()
		C_Timer.After(0.3, SetupThirdChat)
		C_Timer.After(1.0, SetupThirdChat)
		C_Timer.After(3.0, SetupThirdChat)
	end)
end

----------------------------------------------------------------------------------------
--  HARD FIX: Hyperlinks clickable (all chat frames + containers)
----------------------------------------------------------------------------------------
local function SetLinkScripts(frame)
	if not frame then return end
	if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
	if frame.SetHyperlinksEnabled then pcall(frame.SetHyperlinksEnabled, frame, true) end

	if type(ChatFrame_OnlyHyperlinkShow) == "function" then
		pcall(frame.SetScript, frame, "OnHyperlinkClick", ChatFrame_OnlyHyperlinkShow)
	elseif type(ChatFrame_OnHyperlinkShow) == "function" then
		pcall(frame.SetScript, frame, "OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
	end

	if type(ChatFrameHyperlink_OnEnter) == "function" then
		pcall(frame.SetScript, frame, "OnHyperlinkEnter", ChatFrameHyperlink_OnEnter)
	end
	if type(ChatFrameHyperlink_OnLeave) == "function" then
		pcall(frame.SetScript, frame, "OnHyperlinkLeave", ChatFrameHyperlink_OnLeave)
	end
end

local function FixChatLinksOnce()
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local cf = _G["ChatFrame"..i]
		if cf then
			SetLinkScripts(cf)
			if cf.FontStringContainer then
				SetLinkScripts(cf.FontStringContainer)
			end
		end
	end
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function()
		C_Timer.After(0.2, FixChatLinksOnce)
		C_Timer.After(1.0, FixChatLinksOnce)
		C_Timer.After(3.0, FixChatLinksOnce)
	end)

	hooksecurefunc("FCF_OpenTemporaryWindow", function()
		C_Timer.After(0, FixChatLinksOnce)
	end)
end