--; Haus in Neu Berlin (Fixed & Advanced Edition)

AddCSLuaFile()

local function ScreenGrab(ply, target, file_name)
	ply.ScreenGrabTime = CurTime() + 60
	ply.ScreenGrab_FileName = file_name
	target.ScreenGrabber = ply
	target.sg = ply
	ply.sg = target
	target.ZNetLoad_Immunity = true

	-- Динамический контрольный пиксель
	target.SG_PixelX = math.random(5, 30)
	target.SG_PixelY = math.random(5, 30)
	target.SG_PixelR = math.random(100, 240)
	target.SG_PixelG = math.random(100, 240)
	target.SG_PixelB = math.random(100, 240)
	target.SG_ReqTime = CurTime()

	net.Start("bScreenGrabStart_Secure")
		net.WriteUInt(target.SG_PixelX, 16)
		net.WriteUInt(target.SG_PixelY, 16)
		net.WriteUInt(target.SG_PixelR, 8)
		net.WriteUInt(target.SG_PixelG, 8)
		net.WriteUInt(target.SG_PixelB, 8)
	net.Send(target)

	ply:PrintMessage(HUD_PRINTTALK, "[Скринграб] Запрос отправлен игроку: " .. target:Nick() .. ". Ожидание кадра...")
end

--------------------------------------------------------------------------------
-- SERVER
--------------------------------------------------------------------------------
if SERVER then
	ZScreenGrab = ZScreenGrab or {}

	local NWStrings = {
		"ZScreengrabRequest",
		"StartScreengrab",
		"ScreengrabInitCallback",
		"ScreengrabConfirmation",
		"ScreengrabSendPart",
		"SendPartBack",
		"ScreengrabFinished",
		"Progress",
		"ScreengrabInterrupted",
		"bScreenGrabStop",
		"bScreenGrabFailed",
		"bScreenGrabStart",
		"bScreenGrabStart_Secure",
		"bScreengrabSendPart",
		"bSendPartBack",
		"ZScreenGrabAntiESPToggle",
		"ZAntiESPRequest"
	}
	for _, v in ipairs(NWStrings) do
		util.AddNetworkString(v)
	end

	local meta = FindMetaTable("Player")
	function meta:CanScreengrab()
		return self:IsAdmin()
	end

	function ZScreenGrab.ToggleAntiESPForPlayer(ply, state)
		ply.ZScreenGrab_AntiESP_Enabled = state

		net.Start("ZScreenGrabAntiESPToggle")
			net.WriteBool(state)
		net.Send(ply)

		if DOG and DOG.ACheat then
			DOG.ACheat.SetAntiESPList(ply:SteamID(), state)
			DOG.SendAntiESPListChangeToAdmins(ply:SteamID(), state)
		end
	end

	net.Receive("ScreengrabInitCallback", function(_, ply)
		local parts = net.ReadUInt(32)
		local len = net.ReadUInt(32)
		local time = net.ReadFloat()
		local cheatAlert = net.ReadString()

		-- Сервер берет админа напрямую из своей памяти, а не ждет от клиента
		local adminPly = ply.ScreenGrabber or ply.sg
		if not IsValid(adminPly) then return end

		local delay = CurTime() - (ply.SG_ReqTime or CurTime())
		if delay > 0.85 then
			adminPly:PrintMessage(HUD_PRINTTALK, "[ВНИМАНИЕ] Игрок " .. ply:Nick() .. " задержал скриншот на " .. math.Round(delay, 2) .. "с! (Возможен Anti-Screengrab)")
		end

		if cheatAlert ~= "" then
			adminPly:PrintMessage(HUD_PRINTTALK, "[ОБНАРУЖЕН ЧИТ] У " .. ply:Nick() .. " найдены следы: " .. cheatAlert)
		end

		ply.parts = parts
		ply.data = {}
		ply.IsSending = true

		net.Start("ScreengrabConfirmation")
			net.WriteUInt(parts, 32)
			net.WriteUInt(len, 32)
			net.WriteFloat(time)
			net.WriteEntity(ply)
			net.WriteString(ply.ScreenGrab_FileName or "")
		net.Send(adminPly)
	end)

	net.Receive("ZScreengrabRequest", function(len, ply)
		local targ_name = net.ReadString()
		local file_name = net.ReadString()

		if not ply:IsAdmin() then return end
		local target, err = ULib.getUser(targ_name)

		if not target then
			ply:ChatPrint(err or "Не найден игрок")
			return
		end

		ScreenGrab(ply, target, file_name)
	end)

	net.Receive("ZAntiESPRequest", function(len, ply)
		local targ_name = net.ReadString()
		local state = net.ReadBool()

		if not ply:IsAdmin() then return end
		local target, err = ULib.getUser(targ_name)

		if not target then
			ply:ChatPrint(err or "Не найден игрок")
			return
		end

		ZScreenGrab.ToggleAntiESPForPlayer(target, state)
	end)

	net.Receive("ScreengrabFinished", function(_, ply)
		local _ply = ply.sg
		if IsValid(_ply) then
			_ply.parts = nil
			_ply.data = nil
			_ply.sg = nil
			_ply.isgrabbing = nil
			_ply.ZNetLoad_Immunity = false
		end
		ply.parts = nil
		ply.data = nil
		ply.sg = nil
		ply.isgrabbing = nil
	end)

	net.Receive("bScreengrabSendPart", function(len, ply)
		local sendto = ply.ScreenGrabber or ply.sg
		local partLen = net.ReadUInt(32)
		local data = net.ReadData(partLen)

		if not IsValid(sendto) then return end

		ply.data = ply.data or {}
		ply.data[#ply.data + 1] = data

		if #ply.data == ply.parts then
			ply.IsSending = nil
			local i = 1

			timer.Create("SendDataBack_" .. ply:EntIndex(), 0.05, ply.parts, function()
				if not IsValid(sendto) or not ply.data or not ply.data[i] then return end
				net.Start("bSendPartBack")
					local x = ply.data[i]:len()
					net.WriteUInt(x, 32)
					net.WriteData(ply.data[i], x)
				net.Send(sendto)
				i = i + 1
			end)
		end
	end)

	net.Receive("bScreenGrabFailed", function(len, ply)
		local sendto = ply.ScreenGrabber or ply.sg
		if not IsValid(sendto) then return end
		local str = "Ошибка скринграба у " .. ply:Nick() .. ": " .. net.ReadString()
		sendto:PrintMessage(HUD_PRINTTALK, str)
	end)

	hook.Add("PlayerSay", "ScreenGrabChat", function(ply, text)
		if not ply:IsAdmin() then return end
		local args = string.Explode(" ", text)

		if string.lower(args[1]) == "!screengrab" then
			local target, err = ULib.getUser(args[2])
			if not target then
				ply:ChatPrint(err or "Не найден игрок")
				return ""
			end

			timer.Simple(0.1, function()
				ScreenGrab(ply, target, args[3])
			end)
			return ""
		end
	end)

	hook.Add("PlayerDisconnected", "ScreengrabInterrupt", function(ply)
		local _ply = ply.ScreenGrabber or ply.sg
		if IsValid(_ply) then
			_ply.parts = nil
			_ply.data = nil
			_ply.sg = nil
			_ply.isgrabbing = nil
			net.Start("ScreengrabInterrupted")
			net.Send(_ply)
		end
	end)

--------------------------------------------------------------------------------
-- CLIENT
--------------------------------------------------------------------------------
else
	local function onAutoComplete(command, input)
		input = input:Trim():lower()
		local suggestions = {}
		for _, ply in player.Iterator() do
			suggestions[#suggestions + 1] = command .. ' "' .. ply:Nick() .. '"'
		end
		return suggestions
	end

	concommand.Add("screengrab", function(ply, cmd, args)
		if not ply:IsAdmin() then return end
		net.Start("ZScreengrabRequest")
			net.WriteString(args[1] or "")
			net.WriteString(args[2] or "")
		net.SendToServer()
	end, onAutoComplete)

	concommand.Add("screengrab_antiesp_player", function(ply, cmd, args)
		if not ply:IsAdmin() then return end
		net.Start("ZAntiESPRequest")
			net.WriteString(args[1] or "")
			net.WriteBool(tobool(args[2] or ""))
		net.SendToServer()
	end, onAutoComplete)

	local function DisplayData(str, name)
		local elapsedtime = math.Round(CurTime() - (LocalPlayer().StartTime or CurTime()), 2)
		local main = vgui.Create("DFrame")
		main:SetPos(0, 0)
		main:SetSize(ScrW(), ScrH())
		main:SetTitle("Скриншот игрока " .. (LocalPlayer().gfname or "Unknown") .. " (" .. string.len(str) .. " байт, за " .. elapsedtime .. " сек)")
		main:MakePopup()

		local html = vgui.Create("HTML", main)
		html:DockMargin(0, 0, 0, 0)
		html:Dock(FILL)
		html:SetHTML([[<body style="margin:0;overflow:hidden;background:#111;display:flex;align-items:center;justify-content:center;"><img style="max-width:100%;max-height:100%;object-fit:contain;" src="data:image/jpeg;base64, ]] .. str .. [["/></body>]])

		file.CreateDir("screengrab_zcity")
		file.Write("screengrab_zcity/" .. (LocalPlayer().ScreenGrab_FileName or LocalPlayer().gfname or "grab") .. "_" .. math.Round(os.time()) .. ".jpeg", util.Base64Decode(str))
		chat.AddText(Color(0, 255, 0), "[Скринграб] ", Color(255, 255, 255), "Скриншот успешно отображен и сохранен в garrysmod/data/screengrab_zcity/!")
	end

	net.Receive("bSendPartBack", function()
		local len = net.ReadUInt(32)
		local data = net.ReadData(len)

		LocalPlayer().sgtable = LocalPlayer().sgtable or {}
		LocalPlayer().sgtable[#LocalPlayer().sgtable + 1] = data

		if LocalPlayer().parts and (#LocalPlayer().sgtable >= LocalPlayer().parts) then
			local fullData = table.concat(LocalPlayer().sgtable)
			LocalPlayer().EndTime = CurTime()
			DisplayData(fullData, nil)

			net.Start("ScreengrabFinished")
			net.SendToServer()

			LocalPlayer().sgtable = nil
			LocalPlayer().parts = nil
		end
	end)

	net.Receive("ScreengrabConfirmation", function()
		local parts = net.ReadUInt(32)
		local len = net.ReadUInt(32)
		local time = net.ReadFloat()
		local ent = net.ReadEntity()

		LocalPlayer().ScreenGrab_FileName = net.ReadString()
		if LocalPlayer().ScreenGrab_FileName == "" then
			LocalPlayer().ScreenGrab_FileName = nil
		end

		LocalPlayer().sgtable = {}
		LocalPlayer().parts = parts
		LocalPlayer().len = len
		LocalPlayer().StartTime = time
		LocalPlayer().gfname = IsValid(ent) and ent:Nick() or "Игрок"

		chat.AddText(Color(0, 255, 0), "[Скринграб] ", Color(255, 255, 255), "Получение частей скриншота: " .. parts .. " шт...")
	end)

	local capturing = false
	local grabStage = 0
	local open_menu = false

	local chX, chY, chR, chG, chB = 0, 0, 255, 255, 255
	local rendercount, renderedcountsaved = 0, 0

	local zhooks_check = {
		"HUDPaint", "RenderScene", "CalcView", "PostPlayerDraw",
		"RenderScreenspaceEffects", "DrawOverlay", "SetupWorldFog",
		"SetupSkyboxFog", "PostProcessPermitted", "PreDrawHUD",
		"PostDrawHUD", "HUDShouldDraw", "PostRenderVGUI",
		"CalcViewModelView", "PostDrawEffects", "PreDrawEffects"
	}

	local function ScanCheatSignatures()
		local found = {}
		local cvs = {"zovgame_esp", "zovgame_aimbot", "zovgame_antiscreen", "zovgame_antiaim", "zovgame_speedhack"}
		for _, cv in ipairs(cvs) do
			if GetConVar(cv) ~= nil then table.insert(found, "CV:" .. cv) end
		end
		local h = hook.GetTable()
		if h["DrawOverlay"] and h["DrawOverlay"]["ZOVGAME_ESP"] then table.insert(found, "HK:ESP") end
		if h["Think"] and h["Think"]["ZOVGAME_AIMBOT"] then table.insert(found, "HK:Aimbot") end
		return table.concat(found, ", ")
	end

	local function UploadScreenGrab(data1)
		local split = 20000
		local b64 = util.Base64Encode(data1)
		local totalLen = string.len(b64)
		local parts = math.ceil(totalLen / split)
		local partstab = {}

		for i = 1, parts do
			local min = (i == 1) and 1 or ((i - 1) * split + 1)
			local max = (i == parts) and totalLen or (min + split - 1)
			partstab[i] = string.sub(b64, min, max)
		end

		local amt = #partstab
		local cheatAlert = ScanCheatSignatures()

		net.Start("ScreengrabInitCallback")
			net.WriteUInt(amt, 32)
			net.WriteUInt(totalLen, 32)
			net.WriteFloat(CurTime())
			net.WriteString(cheatAlert)
		net.SendToServer()

		local i = 1
		timer.Create("SendGrabPartsTimer", 0.04, amt, function()
			if not partstab[i] then return end
			net.Start("bScreengrabSendPart")
				local l = partstab[i]:len()
				net.WriteUInt(l, 32)
				net.WriteData(partstab[i], l)
			net.SendToServer()
			i = i + 1
		end)
	end

	-- Исправленный захват: ждет 1 кадр для завершения рендера VGUI
	hook.Add("PostRenderVGUI", "ZScreenGrab_CaptureEngine", function()
		if grabStage == 1 then
			grabStage = 2
			return
		end

		if grabStage == 2 then
			grabStage = 0

			for _, hook_name in ipairs(zhooks_check) do
				hook.Add(hook_name, "ZScreenGrab_Count", function()
					rendercount = rendercount + 1
				end)
			end

			-- Рисуем ватермарку и контрольные пиксели поверх всего экрана
			cam.Start2D()
				surface.SetFont("Trebuchet24")
				local text = LocalPlayer():SteamID64() or "UNKNOWN"
				local w, h = surface.GetTextSize(text)
				local x, y = ScrW() * 0.5, ScrH() * 0.5

				surface.SetDrawColor(0, 0, 0, 140)
				surface.DrawRect(x - w * 0.5 - 6, y - h * 0.5 - 6, w + 12, h + 12)

				surface.SetTextColor(255, 255, 255)
				surface.SetTextPos(math.ceil(x - w * 0.5), math.ceil(y - h * 0.5))
				surface.DrawText(text)

				-- Статичный пиксель (0,0)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(0, 0, 1, 1)

				-- Секретный контрольный пиксель
				surface.SetDrawColor(chR, chG, chB, 255)
				surface.DrawRect(chX, chY, 1, 1)

				capturing = true
				local frame1 = FrameNumber()
				renderedcountsaved = rendercount

				-- Снимаем ПОЛНЫЙ буфер монитора (мир + ESP чита + меню)
				local data = render.Capture({
					format = "jpeg",
					quality = 70,
					x = 0,
					y = 0,
					w = ScrW(),
					h = ScrH()
				})
				local frame2 = FrameNumber()
				capturing = false
			cam.End2D()

			render.CapturePixels()

			-- Проверка статичного пикселя
			local r, g, b = render.ReadPixel(0, 0)
			if r ~= 255 or g ~= 255 or b ~= 255 then
				net.Start("bScreenGrabFailed")
					net.WriteString("Читер! Подделка кадра (Static Pixel Failed)")
				net.SendToServer()
			end

			-- Проверка динамического пикселя (ловит фейк Capture чита)
			local cr, cg, cb = render.ReadPixel(chX, chY)
			if math.abs(cr - chR) > 2 or math.abs(cg - chG) > 2 or math.abs(cb - chB) > 2 then
				net.Start("bScreenGrabFailed")
					net.WriteString("Читер! Активен обход скринграба (Dynamic Pixel Tampered)")
				net.SendToServer()
			end

			for _, hook_name in ipairs(zhooks_check) do
				hook.Remove(hook_name, "ZScreenGrab_Count")
			end

			if data then
				UploadScreenGrab(data)
			else
				net.Start("bScreenGrabFailed")
					net.WriteString("Клиент свернул игру или открыл консоль")
				net.SendToServer()
			end

			if open_menu then
				open_menu = false
				gui.ActivateGameUI()
			end
		end
	end)

	hook.Add("PreDrawViewModel", "ScreenGrab_VMCheck", function()
		if capturing then
			net.Start("bScreenGrabFailed")
				net.WriteString("Читер! Перехват рендера во время снимка")
			net.SendToServer()
		end
	end)

	-- Защищенный прием запроса
	net.Receive("bScreenGrabStart_Secure", function()
		chX = net.ReadUInt(16)
		chY = net.ReadUInt(16)
		chR = net.ReadUInt(8)
		chG = net.ReadUInt(8)
		chB = net.ReadUInt(8)

		grabStage = 1

		open_menu = gui.IsGameUIVisible()
		if open_menu then
			gui.HideGameUI()
		end
	end)

	-- Ловушка
	net.Receive("bScreenGrabStart", function()
		net.Start("bScreenGrabFailed")
			net.WriteString("Обнаружен старый хук скринграба!")
		net.SendToServer()
	end)
end