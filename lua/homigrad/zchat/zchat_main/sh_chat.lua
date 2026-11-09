-- ЭТО ПЕРЕДЕЛКА ЧАТА ЭТО САЛАТА, ДА ТУТ ЕСТЬ ЧУТ ЧУТ ИИ ПОТОМУ ЧТО РЕНЧ ТУПОЙ В ПРОГРАМИРОВАНИИ
local maxLength = CreateConVar("zchat_maxmessagelength", "256", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Maximum message length allowed")

if CLIENT then
	zchat = zchat or {}

	function zchat.RichText(text)
		return {
			__zchatRichText = true,
			text = tostring(text or "")
		}
	end

	local fontSize = CreateClientConVar("zchat_fontsize", 7, true, false, "Self explanatory", 3, 10)
	local fontName = CreateClientConVar("zchat_font", "Bahnschrift", true, false, "Self explanatory, should be available to GMod")
	local fontAA = CreateClientConVar("zchat_fontaa", 1, true, false, "Font anti-aliasing", 0, 1)
	local fontWeight = CreateClientConVar("zchat_fontweight", 1000, true, false, "Font weight", 0, 1000)

	local function CreateChat()
		if (IsValid(hg.chat)) then
			hg.chat:Remove()
		end

		hg.chat = vgui.Create("zChatbox")
	end

	hook.Add("InitPostEntity", "ZChat", function()
		CreateChat()
	end)

	local adminShow = ConVarExists("zb_admin_show_voicechat") and GetConVar("zb_admin_show_voicechat") or CreateClientConVar("zb_admin_show_voicechat","0",false,false,"Show voicechat panels for admins",0,1)
	hook.Add("PlayerStartVoice","RemoveVoicePanles",function(ply)
		if !IsValid(ply) then return end
		local lply = LocalPlayer()
		if IsValid(lply) and lply:IsAdmin() and adminShow:GetBool() then return end

		local other_alive = (ply:Alive() and LocalPlayer() != ply) or (ply.organism and (ply.organism.otrub or (ply.organism.brain and ply.organism.brain > 0.05)))

		return other_alive or nil
	end)

	hook.Add("PlayerBindPress", "ZChat", function(client, bind, pressed)
		bind = bind:lower()

		if (bind:find("messagemode") and pressed) then
			hg.chat:SetActive(true)

			return true
		end
	end)

	hook.Add("OnShowZCityPause", "ZChat", function()
		if !hg.chat:GetActive() then return end
		hg.chat:SetActive(false)

		return false
	end)

	hook.Add("HUDShouldDraw", "ZChat", function(name)
		if (name == "CHudChat") then
			return false
		end
	end)

	net.Receive("zChatMessage", function(len)
		local speaker = net.ReadEntity()
		local text = net.ReadString()
		local bWhisper = net.ReadBool()

		if !IsValid(speaker) then return end

		speaker.ChatWhisper = bWhisper

		CHAT_SPEAKER = speaker

		local supressed = hook.Run("OnPlayerChat", speaker, text, false, speaker:Alive(), bWhisper)
		if !supressed then
			chat.AddText(speaker, ": ", zchat.RichText(text))
		end

		CHAT_SPEAKER = nil
	end)

	net.Receive("zChatGlobalMessage", function(len)
		local buffer = net.ReadTable()

		chat.AddText(unpack(buffer))
	end)

	hook.Add("ChatText", "ZChat", function(index, name, text, messageType)
		if (IsValid(hg.chat)) then
			hg.chat:AddMessage(text)
		end
	end)

	function chat.AddText(...)
		if (IsValid(hg.chat)) then
			hg.chat:AddMessage(...)
		end

		-- логи скачат
		local text = {}

		for _, v in ipairs({...}) do
			if (istable(v) and v.__zchatRichText) then
				text[#text + 1] = v.text
			elseif (istable(v) or isstring(v)) then
				text[#text + 1] = v
			elseif (isentity(v) and v:IsPlayer()) then
				text[#text + 1] = team.GetColor(v:Team())
				text[#text + 1] = v:Name()
			elseif (type(v) != "IMaterial") then
				text[#text + 1] = tostring(v)
			end
		end

		text[#text + 1] = "\n"
		MsgC(unpack(text))
	end

	function chat.Open()
		if IsValid(hg.chat) then hg.chat:SetActive(true) end
	end

	function chat.Close()
		if IsValid(hg.chat) then hg.chat:SetActive(false) end
	end

	function chat.GetChatBoxPos()
		if !IsValid(hg.chat) then return 0, 0 end
		return hg.chat:GetPos()
	end

	function chat.GetChatBoxSize()
		if !IsValid(hg.chat) then return 0, 0 end
		return hg.chat:GetSize()
	end

	local function LoadFonts()
		local size = fontSize:GetFloat()
		local font = fontName:GetString()
		local fontAntiAliasing = fontAA:GetBool()
		local fontW = fontWeight:GetFloat()

		surface.CreateFont("zChatFont", {
			font = font,
			size = ScreenScale(size),
			extended = true,
			weight = fontW,
			antialias = fontAntiAliasing
		})

		surface.CreateFont("zChatFontSmall", {
			font = font,
			size = ScreenScale(4),
			extended = true,
			weight = fontW,
			antialias = fontAntiAliasing
		})

		surface.CreateFont("ZB_ProotOSChat", {
			font = "Ari-W9500",
			size = ScreenScale(size),
			extended = true,
			weight = fontW,
			antialias = fontAntiAliasing
		})

		surface.CreateFont("BerserkChatFont", {
			font = "Who asks Satan",
			size = ScreenScale(size + 3),
			extended = true,
			weight = 0,
			antialias = fontAntiAliasing
		})
	end

	local function RefreshChatFonts()
		LoadFonts()

		if !IsValid(hg.chat) then return end

		if IsValid(hg.chat.entry) then
			hg.chat.entry:SetFont("zChatFont")
		end

		for _, panel in ipairs(hg.chat.entries or {}) do
			if IsValid(panel) then
				panel:SetMarkup(panel.text)
			end
		end

		hg.chat:InvalidateLayout(true)
	end

	cvars.AddChangeCallback("zchat_fontsize", function()
		RefreshChatFonts()
	end)

	cvars.AddChangeCallback("zchat_font", function()
		RefreshChatFonts()
	end)

	cvars.AddChangeCallback("zchat_fontaa", function()
		RefreshChatFonts()
	end)

	cvars.AddChangeCallback("zchat_fontweight", function()
		RefreshChatFonts()
	end)

	concommand.Add("zchat_reload", function()
		include("homigrad/chat/zchat_main/derma/cl_zchat.lua")
		LoadFonts()
		CreateChat()
	end)

	LoadFonts()

	hook.Add("ModifyMessageBuffer", "ChatFont", function(buffer, speaker)
		if !IsValid(speaker) or !speaker:IsPlayer() then return end

		if speaker.PlayerClassName == "furry" then
			buffer[#buffer + 1] = "<font=ZB_ProotOSChat>"
		elseif speaker:IsBerserk() then
			buffer[#buffer + 1] = "<font=BerserkChatFont>"
		end
	end)

	hook.Add("StartChat", "TypingBool", function()
		net.Start("zChatTyping")
			net.WriteBool(true)
		net.SendToServer()
	end)

	hook.Add("FinishChat", "TypingBool", function()
		net.Start("zChatTyping")
			net.WriteBool(false)
		net.SendToServer()
	end)

	local META = FindMetaTable("Player")

	function META:IsTyping()
		return self:GetNetVar("bIsTyping")
	end

	local ghost = Color(118, 159, 255)
	local dead = Color(255, 0, 0)
	hook.Add("OnPlayerChat", "ZChatDead", function(ply, text, bTeam, bDead, bWhisper)
		if ( ply:IsPlayer() and !ply:Alive() ) then
			chat.AddText( dead, "*DEAD* ", ghost, ply:Nick(), ghost, ": ", zchat.RichText(text) )
			return true
		end
	end)
else
	util.AddNetworkString("zChatMessage")
	util.AddNetworkString("zChatGlobalMessage")
	util.AddNetworkString("zChatTyping")

	local customEmojiResources = {
		"fiyy.png",
		"grr.png",
		"joe.png",
		"joe1.png",
		"joe2.png",
		"joe3.png",
		"pluv.png",
		"pluvnerd.png",
		"pluvomg.png",
		"pluvsad.png",
		"pluvsnooze.png",
		"scared.png",
		"steamhappy.png"
	}

	local atlasEmojiResources = {
		"228.png",
		"almaz.png",
		"gaben.png",
		"garry.png",
		"overrustle.png"
	}

	for _, fileName in ipairs(customEmojiResources) do
		local baseName = string.StripExtension(fileName)
		resource.AddFile("materials/icon16/" .. fileName)
		resource.AddFile("materials/icon16/" .. baseName .. ".vtf")
		resource.AddFile("materials/icon16/" .. baseName .. ".vmt")
	end

	for _, fileName in ipairs(atlasEmojiResources) do
		resource.AddFile("materials/atlaschat/emoticons/" .. fileName)
	end


	net.Receive("zChatMessage", function(len, ply)
		-- без лимита спам этим сообщением гоняет все PlayerSay-хуки (команды, ulx) без задержки
		if (ply.zChatNext or 0) > CurTime() then return end
		ply.zChatNext = CurTime() + 0.4

		local text = net.ReadString()

		local maxLen = maxLength:GetInt()

		if (text:utf8len() > maxLen) then
			text = text:utf8sub(0, maxLen)
		end

		hook.Run("PlayerSay", ply, text)
	end)

	hook.Add("PlayerSay", "ZChat", function(ply, text)
		-- ULX mute / gimp-mute: наш хук идёт раньше ULXGimpCheck (HOOK_LOW)
		if IsValid(ply) and (ply:GetNWBool("ulx_muted", false) or (ID_MUTE and ply.gimp == ID_MUTE)) then return "" end

		local otsositi = string.Trim(string.lower(text)) == "!skip"
 		local txtTbl = {text}
		hook.Run("HG_PlayerSay", ply, txtTbl, text) // our shit gets called later
		text = isstring(txtTbl[1]) and txtTbl[1] or text // checks to see if shit hits the ceiling

		if otsositi then
			text = "Я тупой говноед пришедший с ОТСО-СИТИ, у меня СДВГ И ПОЭТОМУ ЭТО НАДО СКИПНУТЬ!"
		end

		if text == "" then return end

		if ply:Alive() and ply.organism and ply.organism.otrub then return end

		ply.ChatWhisper = ply:Alive() and ply.ChatWhisper or false

		local rf = RecipientFilter()
		-- пизда моча
		for i, plya in player.Iterator() do
			if plya:Alive() and plya.organism and plya.organism.otrub then continue end
			if plya:Alive() and !ply:Alive() then continue end

			if (hook.Run("PlayerCanSeePlayersChat", text, false, plya, ply)) then
				rf:AddPlayer(plya)
			end
		end
		
		net.Start("zChatMessage")
			net.WriteEntity(ply)
			net.WriteString(text)
			net.WriteBool(ply.ChatWhisper)
		net.Send(rf)
		local textConsole = {}

		textConsole[#textConsole + 1] = ply:GetPlayerColor():ToColor()
		textConsole[#textConsole + 1] = ply:GetNWString("PlayerName", ply:Nick())
		textConsole[#textConsole + 1] = color_white
		textConsole[#textConsole + 1] = ": " .. text

		textConsole[#textConsole + 1] = "\n"

		MsgC(unpack(textConsole))

		hook.Run("PostPlayerSay", client, chatType, text)
		return ""
	end)

	net.Receive("zChatTyping", function(len, ply)
		local typing = net.ReadBool()
		-- "перестал печатать" не режем, иначе индикатор залипнет
		if typing and (ply.zChatTypingNext or 0) > CurTime() then return end
		ply.zChatTypingNext = CurTime() + 0.2
		ply:SetNetVar("bIsTyping", typing)
	end)

	local META = FindMetaTable("Player")

	function META:IsTyping()
		return self:GetNetVar("bIsTyping")
	end

	function META:zChatPrint(...)
		net.Start("zChatGlobalMessage")
			net.WriteTable({...})
		net.Send(self)
	end

	function zChatPrint(...)
		net.Start("zChatGlobalMessage")
			net.WriteTable({...})
		net.Broadcast()
	end
end
