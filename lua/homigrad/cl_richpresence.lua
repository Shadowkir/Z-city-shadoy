-- https://github.com/YuRaNnNzZZ/gmcl_steamrichpresencer/releases/tag/2023.07.20
-- https://github.com/fluffy-servers/gmod-discord-rpc/releases/tag/1.2.1

function StartDiscordPresence(arguments)
	if not util.IsBinaryModuleInstalled("gdiscord") then return end
	require("gdiscord")

	local image = "default"
	local discord_id = "1550446703092703233"
	local refresh_time = 30
	local discord_start = discord_start or -1

	function DiscordUpdate()
		local ply = LocalPlayer()

		local rpc_data = {}
		local ip = game.GetIPAddress()
		local showip = ip

		if ip == "loopback" then
			rpc_data["state"] = "Local Server"
			showip = "Local Server"
		--[[else
            rpc_data["state"] = string.Replace(ip, ":27015", "")

            rpc_data["buttonPrimaryLabel"] = "Join Server"
            rpc_data["buttonPrimaryUrl"] = "steam://connect/" .. ip]]
		end

		local playerCount = player.GetCount()
		local maxPlayers = game.MaxPlayers()

		rpc_data["partySize"] = playerCount
		rpc_data["partyMax"] = maxPlayers

		local mapname = game.GetMap()
		local prefix = string.find(mapname, "_")
		if prefix then
			mapname = string.sub(mapname, prefix + 1)
		end

		local roundName = mapname
		if zb ~= nil and zb.GetRoundName then
			local r = isfunction(zb.GetRoundName) and zb.GetRoundName() or zb.GetRoundName
			if r and r ~= "" then roundName = r end
		end

		local roundStr = string.lower(tostring(roundName))
		local isSandbox = (roundStr == "sandbox") or (roundStr == "песочница") or (string.find(roundStr, "sandbox") ~= nil) or (string.find(roundStr, "песочниц") ~= nil) or (engine.ActiveGamemode() == "sandbox")

		local baseText = "Zbox | " .. string.NiceName(tostring(roundName)) .. " (" .. playerCount .. "/" .. maxPlayers .. ")"
		local text = baseText

		if not isSandbox then
			text = baseText .. " | " .. (ply.exp or 0) .. " XP " .. math.Round(ply.skill or 0, 3) .. " Skill"
		end

		rpc_data["details"] = text
		rpc_data["startTimestamp"] = discord_start
		rpc_data["largeImageKey"] = image
		rpc_data["largeImageText"] = showip

		DiscordUpdateRPC(rpc_data)
	end

	timer.Simple(5, function()
		discord_start = os.time()

		DiscordRPCInitialize(discord_id)
		DiscordUpdate()

		if timer.Exists("UpdateDiscordRichPresence") then timer.Remove("UpdateDiscordRichPresence") end

		timer.Simple(0.5, function()
			if not timer.Exists("UpdateSteamRichPresence") then
				timer.Create("UpdateDiscordRichPresence", refresh_time, 0, DiscordUpdate)
			end
		end)
	end)
end

function StartSteamPresence(arguments)
	if not util.IsBinaryModuleInstalled("steamrichpresencer") then return end
	require("steamrichpresencer")

	local richtext = ""
	local refresh_time = 30

	local function SteamUpdate()
		local ply = LocalPlayer()

		local mapname = game.GetMap()
		local prefix = string.find(mapname, "_")
		if prefix then
			mapname = string.sub(mapname, prefix + 1)
		end

		local roundName = mapname
		if zb ~= nil and zb.GetRoundName then
			local r = isfunction(zb.GetRoundName) and zb.GetRoundName() or zb.GetRoundName
			if r and r ~= "" then roundName = r end
		end

		local playerCount = player.GetCount()
		local maxPlayers = game.MaxPlayers()

		local roundStr = string.lower(tostring(roundName))
		local isSandbox = (roundStr == "sandbox") or (roundStr == "песочница") or (string.find(roundStr, "sandbox") ~= nil) or (string.find(roundStr, "песочниц") ~= nil) or (engine.ActiveGamemode() == "sandbox")

		local baseText = "Zbox | " .. string.NiceName(tostring(roundName)) .. " (" .. playerCount .. "/" .. maxPlayers .. ")"
		local updatedtext = baseText

		if not isSandbox then
			updatedtext = baseText .. " | " .. (ply.exp or 0) .. " XP " .. math.Round(ply.skill or 0, 3) .. " Skill"
		end

		if richtext ~= updatedtext then
			richtext = updatedtext
			steamworks.SetRichPresence("generic", richtext)
		end
	end

	timer.Simple(5, function()
		SteamUpdate()

		if timer.Exists("UpdateSteamRichPresence") then timer.Remove("UpdateSteamRichPresence") end

		timer.Simple(0.5, function()
			if not timer.Exists("UpdateSteamRichPresence") then
				timer.Create("UpdateSteamRichPresence", refresh_time, 0, SteamUpdate)
			end
		end)
	end)
end

hook.Add("PostGamemodeLoaded", "UpdateDiscordStatus", function()
	StartDiscordPresence()
	StartSteamPresence()
end)