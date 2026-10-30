include("shared.lua")

hg_shelles = hg_shelles or {}
hg_trails = hg_trails or {}

local Shell50Cal = {
	m = "models/shells/fhell_50cal.mdl",
	s = {
		"weapons/shells/m249_link_concrete_01.wav",
		"weapons/shells/m249_link_concrete_02.wav",
		"weapons/shells/m249_link_concrete_03.wav",
		"weapons/shells/m249_link_concrete_04.wav",
		"weapons/shells/m249_link_concrete_05.wav",
		"weapons/shells/m249_link_concrete_06.wav",
		"weapons/shells/m249_link_concrete_07.wav",
		"weapons/shells/m249_link_concrete_08.wav"
	}
}

local function PlayDistSound(gun, shootPos)
	local lply = LocalPlayer()
	if not IsValid(lply) then return end

	if IsValid(gun) and (gun:GetGunner() == lply or lply:GetNWEntity("ActiveStationaryGun") == gun) then
		return
	end

	local view = render.GetViewSetup(true)
	local viewOrigin = (view and view.origin) or lply:EyePos()
	local dist = shootPos:Distance(viewOrigin)
	if dist < 850 then return end

	local soundDelay = dist / 17836
	timer.Simple(soundDelay, function()
		if not IsValid(gun) then return end
		if gun:GetGunner() == lply or lply:GetNWEntity("ActiveStationaryGun") == gun then return end

		local bRoom = util.IsSkyboxVisibleFromPoint and util.IsSkyboxVisibleFromPoint(shootPos + Vector(0, 0, 72))
		local roomMultiplier = (bRoom == nil or bRoom) and 1.0 or 0.65
		local finalVolume = 100 * roomMultiplier
		local farPitch = math.Clamp(100 - (dist / 1000), 75, 95)

		gun:EmitSound(gun.SoundDistFar or "m249/m249_dist.wav", finalVolume, 90, 1, CHAN_STATIC)
		if dist > 1200 then
			gun:EmitSound(gun.SoundDistFar or "m249/m249_dist.wav", finalVolume * 1.15, farPitch, 1, CHAN_STATIC)
		end
	end)
end

local physvec = Vector(0.5, 0.2, 0.5)
local function SpawnShell(gun)
	if not IsValid(gun) then return end

	local pos = gun:LocalToWorld(gun.ShellEjectOffset or Vector(-1, 9, 25))
	local ang = gun:GetAngles()
	local vel = (gun:GetRight() * -140 + gun:GetUp() * 75 + VectorRand() * 15)

	local ent = ClientsideModel(gun.ShellModel or Shell50Cal.m, RENDERGROUP_BOTH)
	if not IsValid(ent) then return end

	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:PhysicsInitBox(-physvec, physvec, "gmod_silent")
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	table.insert(hg_shelles, ent)

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMaterial("gmod_silent")
		phys:SetMass(12)
		phys:SetVelocity(vel)
		phys:SetAngleVelocity(VectorRand() * 200 - ang:Forward() * math.random(1500, 3000))
	end

	if #hg_trails < 8 then
		local eff = ent:CreateParticleEffect("smoke_trail_wild", 1, {PATTACH_ABSORIGIN_FOLLOW, ent, ent:GetPos()})
		table.insert(hg_trails, eff)
		if IsValid(eff) then
			eff:StartEmission()
			timer.Simple(2.5, function() if IsValid(eff) then eff:StopEmission() end end)
			timer.Simple(4, function()
				if IsValid(eff) then
					eff:StopEmissionAndDestroyImmediately()
					table.RemoveByValue(hg_trails, eff)
				end
			end)
		end
	end

	ent:AddCallback("PhysicsCollide", function(entSelf, data)
		if data.Speed > 45 then
			local sounds = gun.ShellSounds or Shell50Cal.s
			entSelf:EmitSound(sounds[math.random(#sounds)], 62, math.random(95, 105))
		end
	end)

	timer.Simple(12, function()
		if IsValid(ent) then SafeRemoveEntity(ent) end
	end)
end

net.Receive("StationaryGun_Punch", function()
	local ang = net.ReadAngle()
	local ply = LocalPlayer()
	if IsValid(ply) and ply.ViewPunch then
		ply:ViewPunch(ang)
	end
end)

net.Receive("StationaryGun_ShootFX", function()
	local gun = net.ReadEntity()
	local shootPos = net.ReadVector()
	if not IsValid(gun) then return end

	gun.LastShootTime = CurTime()

	local muzzleAtt = gun:LookupAttachment("muzzle")
	if muzzleAtt <= 0 then muzzleAtt = gun:LookupAttachment("muzzle_1") end
	if muzzleAtt <= 0 then muzzleAtt = 1 end

	local att = gun:GetAttachment(muzzleAtt)
	local pos = att and att.Pos or (shootPos or gun:LocalToWorld(Vector(65, 0, 16)))
	local ang = att and att.Ang or gun:GetAngles()

	local fx = EffectData()
	fx:SetOrigin(pos)
	fx:SetAngles(ang)
	fx:SetScale(gun.MuzzleScale or 1.4)
	util.Effect("MuzzleEffect", fx)

	SpawnShell(gun)
	PlayDistSound(gun, pos)
end)

function ENT:Draw()
	self:DrawModel()
end

function ENT:Think()
	local gunner = self:GetGunner()
	if IsValid(gunner) then
		self:UpdateTurretPose(gunner)
	end
	self:SetNextClientThink(CurTime())
	return true
end

hook.Add("CalcView", "StationaryGun_MountedView", function(ply, pos, angles, fov)
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if not IsValid(gun) then return end

	local attView = gun:GetAttachment(gun:LookupAttachment("view"))
	local sightPos = attView and attView.Pos or gun:LocalToWorld(gun.SightOffset or Vector(-10, 0, 18))
	local plyAngles = ply:EyeAngles()

	local view = {}
	view.angles = plyAngles

	if ply:KeyDown(IN_ATTACK2) then
		view.origin = sightPos
		view.fov = 55
	else
		view.origin = sightPos - plyAngles:Forward() * 18 + Vector(0, 0, 4)
		view.fov = fov
	end

	local shootTime = gun.LastShootTime or 0
	local shootDiff = CurTime() - shootTime
	if shootDiff < 0.18 then
		local factor = 1 - (shootDiff / 0.18)
		view.origin = view.origin - plyAngles:Forward() * (factor * (gun.ViewKickBack or 3.5))
		view.angles.p = view.angles.p - factor * (gun.ViewKickPitch or 1.6)
	end

	return view
end)

surface.CreateFont("StationaryGunAmmoFont", {
	font = "Bahnschrift",
	size = ScreenScale(16),
	extended = true,
	weight = 500,
	antialias = true
})

local function DrawBullet(matIcon, x, y, size, cColor)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)
	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	surface.SetDrawColor(cColor)
	surface.SetMaterial(matIcon)
	surface.DrawTexturedRect(x - size * 0.5, y - size, size, size)
	render.PopFilterMag()
	render.PopFilterMin()
end

local LerpFT_Local = function(speed, from, to)
	return Lerp(math.Clamp(FrameTime() * speed * 30, 0, 1), from, to)
end

local lastShoot, lastShootFor, ammoCheck, ammoLongCheck, lerpAmmoCheck = 0, 0, 0, 0, 0
local WhiteColor = Color(200, 200, 200, 255)
local color_bg = Color(0, 0, 0, 150)
local coloruse = Color(255, 255, 255, 255)

hook.Add("HUDPaint", "StationaryGun_HUD", function()
	local ply = LocalPlayer()
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if not IsValid(gun) then return end
	if gun.EnableHUD == false then return end

	local scrW, scrH = ScrW(), ScrH()
	local clipsize = gun.MaxAmmo
	local clip = gun:GetAmmoCount()
	local shootTime = gun.LastShootTime or 0
	local shoot = CurTime() - shootTime

	local ammo = gun:GetGunnerAmmo(ply)
	local magCount = math.ceil(ammo / clipsize)

	local posX = scrW * 0.75
	local posX2 = scrW * 0.8
	local HudHPos = 0.8

	local dynamicMags = ConVarExists("hg_dynamic_mags") and GetConVar("hg_dynamic_mags"):GetBool() or false

	lastShoot = LerpFT_Local(0.5, lastShoot, (shoot >= 0 and shoot < 0.4) and 1 or 0)
	lastShootFor = lastShoot

	local reloadingKey = ply:KeyDown(IN_RELOAD) or gun:GetIsReloading()

	if (clip < clipsize / 3 and lastShoot < 0.9 and dynamicMags) or reloadingKey then
		ammoCheck = CurTime() + 1
	end

	ammoLongCheck = LerpFT_Local(0.025, ammoLongCheck, reloadingKey and 5 or 0)

	if ammoLongCheck > 4 then
		local text = (
			(clip >= clipsize - 1) and "Full" or
			(clip <= clipsize and clip > clipsize / 1.5) and "~ Full" or
			(clip <= clipsize / 1.5 and clip > clipsize / 3.5) and "~ Half" or
			(clip <= clipsize / 3.5 and clip > 0) and "~ Almost Empty" or
			(clip == 0 and "Empty")
		)

		coloruse.a = 210 * math.max(ammoLongCheck - 4, 0)
		coloruse.r, coloruse.g, coloruse.b = 0, 0, 0
		draw.SimpleText(text, "StationaryGunAmmoFont", scrW * 0.8 + 2, scrH * HudHPos + scrH * 0.05 + 2, coloruse, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		coloruse.r, coloruse.g, coloruse.b = 255, 255, 255
		draw.SimpleText(text, "StationaryGunAmmoFont", scrW * 0.8, scrH * HudHPos + scrH * 0.05, coloruse, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	lerpAmmoCheck = LerpFT_Local((ammoCheck > CurTime()) and 0.2 or 0.1, lerpAmmoCheck, ammoCheck > CurTime() and 1 or 0)
	local Yellow = ((clipsize / math.max(clip, 1)) - 1) / (clipsize / 5)

	color_bg.r = 55 * Yellow
	color_bg.a = (250 * lastShoot) * lerpAmmoCheck
	WhiteColor.a = (150 * lastShoot) * lerpAmmoCheck

	local PosLerp = Lerp(math.ease.OutExpo(lerpAmmoCheck), 150, 0)
	gun.CachedMatIcon = gun.CachedMatIcon or Material(gun.HUD_AmmoIcon or "vgui/hud/127108.png", "smooth")
	local texture = gun.CachedMatIcon

	if clip > 0 then
		DrawBullet(texture, posX - (scrH * 0.16) + (scrH * 0.08) * (1 + lastShoot) + 2 + PosLerp, scrH * HudHPos + 2, scrH * 0.08, color_bg)
		DrawBullet(texture, posX - (scrH * 0.16) + (scrH * 0.08) * (1 + lastShoot) + PosLerp, scrH * HudHPos, scrH * 0.08, WhiteColor)
	end

	local maxBullets = math.min(clip, 7)
	for i = 2, maxBullets do
		local idx = i - 1
		local PosAdjust = math.max(PosLerp - idx * 15, 0)
		if idx < 2 then
			DrawBullet(texture, posX + 2 + PosAdjust, scrH * (HudHPos + idx * (0.026 * lastShoot)) + 2, scrH * 0.08, color_bg)
			DrawBullet(texture, posX + PosAdjust, scrH * (HudHPos + idx * (0.026 * lastShoot)), scrH * 0.08, WhiteColor)
		else
			color_bg.a = (210 - (20 * idx)) * lerpAmmoCheck
			WhiteColor.a = (210 - (20 * idx)) * lerpAmmoCheck
			DrawBullet(texture, posX + 2 + PosAdjust, scrH * ((HudHPos - 0.026) + idx * 0.026 + (0.026 * lastShootFor)) + 2, scrH * 0.08, color_bg)
			DrawBullet(texture, posX + PosAdjust, scrH * ((HudHPos - 0.026) + idx * 0.026 + (0.026 * lastShootFor)), scrH * 0.08, WhiteColor)
		end
	end

	if magCount > 0 then
		coloruse.a = 210 * lerpAmmoCheck
		coloruse.r, coloruse.g, coloruse.b = 0, 0, 0
		draw.SimpleText("+" .. magCount, "StationaryGunAmmoFont", posX2 + 2, scrH * HudHPos + 2, coloruse, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		coloruse.r, coloruse.g, coloruse.b = 255, 255, 255
		draw.SimpleText("+" .. magCount, "StationaryGunAmmoFont", posX2, scrH * HudHPos, coloruse, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end)