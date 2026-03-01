local T, C, L = unpack(ShestakUI)

-- 3 columns for ObjectiveTracker: Campaign / Quests / Achievements
-- Put this file somewhere loaded after Blizzard ObjectiveTracker is available.

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	if not ObjectiveTrackerFrame or not ObjectiveTrackerFrame.MODULES then return end

	-- Create 3 anchors
	local parent = UIParent
	local baseX = -420   -- tweak: moves the whole block left/right
	local baseY = -220   -- tweak: moves the whole block up/down
	local colW  = 240    -- tweak: column width
	local gap   = 18     -- tweak: gap between columns

	local a1 = CreateFrame("Frame", "ShestakUI_OT_Col1", parent)
	local a2 = CreateFrame("Frame", "ShestakUI_OT_Col2", parent)
	local a3 = CreateFrame("Frame", "ShestakUI_OT_Col3", parent)

	for _, a in ipairs({a1,a2,a3}) do
		a:SetSize(colW, 600)
		a:SetFrameStrata("LOW")
	end

	-- Position columns (top-right area by default)
	a1:SetPoint("TOPRIGHT", parent, "TOPRIGHT", baseX, baseY)
	a2:SetPoint("TOPLEFT", a1, "TOPRIGHT", gap, 0)
	a3:SetPoint("TOPLEFT", a2, "TOPRIGHT", gap, 0)

	-- Try to identify modules (names differ a bit across expansions)
	local function isCampaignModule(m)
		return m == CAMPAIGN_QUEST_TRACKER_MODULE
			or (m.Header and m.Header.Text and m.Header.Text.GetText and (m.Header.Text:GetText() or ""):lower():find("camp"))
	end

	local function isQuestModule(m)
		return m == QUEST_TRACKER_MODULE
			or (m.Header and m.Header.Text and m.Header.Text.GetText and (m.Header.Text:GetText() or ""):lower():find("quête"))
			or (m.Header and m.Header.Text and m.Header.Text.GetText and (m.Header.Text:GetText() or ""):lower():find("quest"))
	end

	local function isAchievementModule(m)
		return m == ACHIEVEMENT_TRACKER_MODULE
			or (m.Header and m.Header.Text and m.Header.Text.GetText and (m.Header.Text:GetText() or ""):lower():find("haut"))
			or (m.Header and m.Header.Text and m.Header.Text.GetText and (m.Header.Text:GetText() or ""):lower():find("achiev"))
	end

	local function placeModule(m, anchor)
		if not m or not anchor then return end

		-- Most modules have a Header and a ContentsFrame / or just a frame itself
		local header = m.Header or m.header
		local frame  = m

		-- Some modules are tables with a .frame
		if m.frame and m.frame.SetPoint then
			frame = m.frame
		end

		if frame and frame.SetPoint then
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
			frame:SetWidth(colW)
		end

		-- Also constrain the blocks/contents width if we can find it
		local contents = m.ContentsFrame or m.contents or (frame and frame.ContentsFrame)
		if contents and contents.SetWidth then
			contents:SetWidth(colW)
		end

		if header and header.SetWidth then
			header:SetWidth(colW)
		end
	end

	-- Hook the tracker update: it will try to re-anchor modules constantly
	hooksecurefunc(ObjectiveTrackerFrame, "Update", function()
		if not ObjectiveTrackerFrame.MODULES then return end

		for _, m in ipairs(ObjectiveTrackerFrame.MODULES) do
			if isCampaignModule(m) then
				placeModule(m, a1)
			elseif isQuestModule(m) then
				placeModule(m, a2)
			elseif isAchievementModule(m) then
				placeModule(m, a3)
			end
		end
	end)

	-- Force one update
	if ObjectiveTrackerFrame.Update then
		ObjectiveTrackerFrame:Update()
	end
end)




C_Timer.After(1, function()
    if not ObjectiveTrackerFrame then return end

    ObjectiveTrackerFrame:ClearAllPoints()
    ObjectiveTrackerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -180)

    -- Largeur max forcée
    ObjectiveTrackerFrame:SetWidth(420)

    -- Empêche les modules d'élargir au-delà
    ObjectiveTrackerFrame:SetClampedToScreen(true)
end)


