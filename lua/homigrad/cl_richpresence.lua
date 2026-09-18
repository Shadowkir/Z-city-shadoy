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

		rpc_data["partySize"] = player.GetCount()
		rpc_data["partyMax"] = game.MaxPlayers()

		local mapname = game.GetMap()
		local prefix = string.find(mapname, "_")
		if prefix then
			mapname = string.sub(mapname, prefix + 1)
		end

		local roundName = (zb ~= nil and (isfunction(zb.GetRoundName) and zb.GetRoundName() or zb.GetRoundName)) or mapname
		local gm = (gmod.GetGamemode() and gmod.GetGamemode().Name or "Homigrad") .. " | " .. string.NiceName(tostring(roundName))

		rpc_data["details"] = gm
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

		local roundName = (zb ~= nil and (isfunction(zb.GetRoundName) and zb.GetRoundName() or zb.GetRoundName)) or mapname
		local gm = (gmod.GetGamemode() and gmod.GetGamemode().Name or "Homigrad") .. " | " .. string.NiceName(tostring(roundName))
		
		local ip = game.GetIPAddress()
		local showip = ip

		if ip == "loopback" then
			showip = "Local Server"
		end

		local updatedtext = gm

		if updatedtext and richtext ~= updatedtext then
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