--; Haus in Neu Berlin (Fixed & Private Edition)

AddCSLuaFile()

local PREFIX = "HausSG_"

local function ScreenGrab(ply, target, file_name)
	if not IsValid(ply) or not IsValid(target) then return end

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

	net.Start(PREFIX .. "Start_Secure")
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
		PREFIX .. "Request",
		PREFIX .. "InitCallback",
		PREFIX .. "Confirmation",
		PREFIX .. "SendPart",
		PREFIX .. "SendPartBack",
		PREFIX .. "Finished",
		PREFIX .. "Failed",
		PREFIX .. "Start_Secure",
		PREFIX .. "AntiESPToggle",
		PREFIX .. "AntiESPRequest"
	}
	for _, v in ipairs(NWStrings) do
		util.AddNetworkString(v)
	end

	local function CleanupSession(target, admin)
		if IsValid(target) then
			target.parts = nil
			target.data = nil
			target.sg = nil
			target.ScreenGrabber = nil
			target.isgrabbing = nil
			target.ZNetLoad_Immunity = false
		end
		if IsValid(admin) then
			admin.parts = nil
			admin.data = nil
			admin.sg = nil
			admin.ScreenGrab_FileName = nil
		end
	end

	net.Receive(PREFIX .. "InitCallback", function(_, ply)
		local parts = net.ReadUInt(32)
		local len = net.ReadUInt(32)
		local time = net.ReadFloat()
		local cheatAlert = net.ReadString()

		local adminPly = ply.ScreenGrabber
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

		net.Start(PREFIX .. "Confirmation")
			net.WriteUInt(parts, 32)
			net.WriteUInt(len, 32)
			net.WriteFloat(time)
			net.WriteEntity(ply)
			net.WriteString(adminPly.ScreenGrab_FileName or "")
		net.Send(adminPly)
	end)

	net.Receive(PREFIX .. "Request", function(len, ply)
		if not ply:IsAdmin() then return end
		local targ_name = net.ReadString()
		local file_name = net.ReadString()

		local target, err = ULib and ULib.getUser(targ_name)
		if not target then
			for _, v in ipairs(player.GetAll()) do
				if string.find(string.lower(v:Nick()), string.lower(targ_name), 1, true) then
					target = v
					break
				end
			end
		end

		if not IsValid(target) then
			ply:ChatPrint(err or "Игрок не найден!")
			return
		end

		ScreenGrab(ply, target, file_name)
	end)

	net.Receive(PREFIX .. "Finished", function(_, ply)
		local target = ply.sg
		CleanupSession(target, ply)
	end)

	net.Receive(PREFIX .. "SendPart", function(len, ply)
		local sendto = ply.ScreenGrabber
		local partLen = net.ReadUInt(32)
		local data = net.ReadData(partLen)

		if not IsValid(sendto) then return end

		ply.data = ply.data or {}
		ply.data[#ply.data + 1] = data

		if #ply.data == ply.parts then
			ply.IsSending = nil
			local i = 1

			timer.Create("SendDataBack_" .. ply:EntIndex(), 0.04, ply.parts, function()
				if not IsValid(sendto) or not ply.data or not ply.data[i] then return end
				net.Start(PREFIX .. "SendPartBack")
					local x = ply.data[i]:len()
					net.WriteUInt(x, 32)
					net.WriteData(ply.data[i], x)
				net.Send(sendto)
				i = i + 1
			end)
		end
	end)

	net.Receive(PREFIX .. "Failed", function(len, ply)
		local sendto = ply.ScreenGrabber
		if not IsValid(sendto) then return end
		sendto:PrintMessage(HUD_PRINTTALK, "[Скринграб] Ошибка у " .. ply:Nick() .. ": " .. net.ReadString())
		CleanupSession(ply, sendto)
	end)

	hook.Add("PlayerSay", "ScreenGrabChat", function(ply, text)
		if not ply:IsAdmin() then return end
		local args = string.Explode(" ", text)

		if string.lower(args[1]) == "!screengrab" then
			local target
			if ULib then
				target = ULib.getUser(args[2])
			else
				for _, v in ipairs(player.GetAll()) do
					if string.find(string.lower(v:Nick()), string.lower(args[2] or ""), 1, true) then
						target = v
						break
					end
				end
			end

			if not IsValid(target) then
				ply:ChatPrint("Игрок не найден!")
				return ""
			end

			timer.Simple(0.1, function()
				ScreenGrab(ply, target, args[3])
			end)
			return ""
		end
	end)

	hook.Add("PlayerDisconnected", "ScreengrabInterrupt", function(ply)
		local admin = ply.ScreenGrabber
		if IsValid(admin) then
			admin:PrintMessage(HUD_PRINTTALK, "[Скринграб] Игрок вышел во время захвата!")
			CleanupSession(ply, admin)
		end
		if IsValid(ply.sg) then
			CleanupSession(ply.sg, ply)
		end
	end)

--------------------------------------------------------------------------------
-- CLIENT
--------------------------------------------------------------------------------
else
	concommand.Add("screengrab", function(ply, cmd, args)
		if not ply:IsAdmin() then return end
		net.Start(PREFIX .. "Request")
			net.WriteString(args[1] or "")
			net.WriteString(args[2] or "")
		net.SendToServer()
	end)

	local function DisplayData(str, targetNick, fileName)
		local elapsedtime = math.Round(CurTime() - (LocalPlayer().SG_StartTime or CurTime()), 2)
		local main = vgui.Create("DFrame")
		main:SetPos(0, 0)
		main:SetSize(ScrW(), ScrH())
		main:SetTitle("Скриншот игрока " .. (targetNick or "Unknown") .. " (" .. string.len(str) .. " байт, за " .. elapsedtime .. " сек)")
		main:MakePopup()

		local html = vgui.Create("HTML", main)
		html:Dock(FILL)
		html:SetHTML([[<body style="margin:0;overflow:hidden;background:#111;display:flex;align-items:center;justify-content:center;"><img style="max-width:100%;max-height:100%;object-fit:contain;" src="data:image/jpeg;base64, ]] .. str .. [["/></body>]])

		file.CreateDir("screengrab_snaps")
		local sName = (fileName or targetNick or "grab") .. "_" .. os.time() .. ".jpeg"
		file.Write("screengrab_snaps/" .. sName, util.Base64Decode(str))
		chat.AddText(Color(0, 255, 0), "[Скринграб] ", Color(255, 255, 255), "Скриншот успешно получен и сохранен в data/screengrab_snaps/" .. sName)
	end

	net.Receive(PREFIX .. "SendPartBack", function()
		local len = net.ReadUInt(32)
		local data = net.ReadData(len)

		LocalPlayer().sgtable = LocalPlayer().sgtable or {}
		LocalPlayer().sgtable[#LocalPlayer().sgtable + 1] = data

		if LocalPlayer().parts and (#LocalPlayer().sgtable >= LocalPlayer().parts) then
			local fullData = table.concat(LocalPlayer().sgtable)
			DisplayData(fullData, LocalPlayer().SG_TargetNick, LocalPlayer().SG_FileName)

			net.Start(PREFIX .. "Finished")
			net.SendToServer()

			LocalPlayer().sgtable = nil
			LocalPlayer().parts = nil
			LocalPlayer().SG_TargetNick = nil
			LocalPlayer().SG_FileName = nil
		end
	end)

	net.Receive(PREFIX .. "Confirmation", function()
		LocalPlayer().parts = net.ReadUInt(32)
		LocalPlayer().len = net.ReadUInt(32)
		LocalPlayer().SG_StartTime = net.ReadFloat()
		local ent = net.ReadEntity()
		LocalPlayer().SG_FileName = net.ReadString()
		LocalPlayer().SG_TargetNick = IsValid(ent) and ent:Nick() or "Игрок"
		LocalPlayer().sgtable = {}

		chat.AddText(Color(0, 255, 0), "[Скринграб] ", Color(255, 255, 255), "Получение частей скриншота от " .. LocalPlayer().SG_TargetNick .. " (" .. LocalPlayer().parts .. " частей)...")
	end)

	local capturing = false
	local grabStage = 0
	local chX, chY, chR, chG, chB = 0, 0, 255, 255, 255

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

		net.Start(PREFIX .. "InitCallback")
			net.WriteUInt(#partstab, 32)
			net.WriteUInt(totalLen, 32)
			net.WriteFloat(CurTime())
			net.WriteString("")
		net.SendToServer()

		local i = 1
		timer.Create("SendGrabPartsTimer", 0.04, #partstab, function()
			if not partstab[i] then return end
			net.Start(PREFIX .. "SendPart")
				local l = partstab[i]:len()
				net.WriteUInt(l, 32)
				net.WriteData(partstab[i], l)
			net.SendToServer()
			i = i + 1
		end)
	end

	hook.Add("PostRenderVGUI", "ZScreenGrab_CaptureEngine", function()
		if grabStage == 1 then
			grabStage = 2
			return
		end

		if grabStage == 2 then
			grabStage = 0

			cam.Start2D()
				-- Статичный контрольный пиксель
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawRect(0, 0, 1, 1)

				-- Динамический контрольный пиксель
				surface.SetDrawColor(chR, chG, chB, 255)
				surface.DrawRect(chX, chY, 1, 1)

				capturing = true
				local data = render.Capture({
					format = "jpeg",
					quality = 70,
					x = 0,
					y = 0,
					w = ScrW(),
					h = ScrH()
				})
				capturing = false
			cam.End2D()

			render.CapturePixels()

			-- Проверка пикселей
			local r, g, b = render.ReadPixel(0, 0)
			local cr, cg, cb = render.ReadPixel(chX, chY)

			if r ~= 255 or g ~= 255 or b ~= 255 or math.abs(cr - chR) > 3 or math.abs(cg - chG) > 3 or math.abs(cb - chB) > 3 then
				net.Start(PREFIX .. "Failed")
					net.WriteString("Обнаружена подделка кадра чита (Anti-ScreenGrab)!")
				net.SendToServer()
				return
			end

			if data then
				UploadScreenGrab(data)
			else
				net.Start(PREFIX .. "Failed")
					net.WriteString("Не удалось снять буфер (игра свернута)")
				net.SendToServer()
			end
		end
	end)

	net.Receive(PREFIX .. "Start_Secure", function()
		chX = net.ReadUInt(16)
		chY = net.ReadUInt(16)
		chR = net.ReadUInt(8)
		chG = net.ReadUInt(8)
		chB = net.ReadUInt(8)

		grabStage = 1
	end)
end