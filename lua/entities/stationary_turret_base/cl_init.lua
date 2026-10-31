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

surface.CreateFont("StationaryGun_AmmoFont", {font = "Bahnschrift", size = ScreenScale(15), weight = 500})

local function DrawBar(x, y, w, h, frac)
	surface.SetDrawColor(255, 255, math.Clamp(frac, 0, 1) * 255)
	surface.DrawRect(x, y + h * (1 - frac), w, h * frac)
	surface.DrawOutlinedRect(x - 5, y - 5, w + 10, h + 10)
end

hook.Add("HUDPaint", "StationaryGun_HUD", function()
	local ply = LocalPlayer()
	local gun = ply:GetNWEntity("ActiveStationaryGun")
	if not IsValid(gun) or gun.EnableHUD == false then return end

	local cap, clip = gun.MaxAmmo or 100, gun:GetAmmoCount()
	local ammo = gun:GetGunnerAmmo(ply)
	local mags = math.ceil(ammo / cap)
	local visMags = math.min(mags, 3)

	local w, h = math.Round(ScrW() * 0.024), math.Round(ScrH() * 0.1)
	local subW, subH = math.Round(w * 0.55), math.Round(h * 0.55)
	local posX, posY = ScrW() - ScrW() * 0.25, ScrH() - ScrH() * 0.166
	local subY = posY + (h - subH)

	local bgW = w + 10 + (visMags > 0 and (visMags * (subW + 20) + (mags > 3 and 35 or 0)) or 0)
	draw.RoundedBox(4, posX - 15, posY - 15, bgW + 20, h + 30, Color(0, 0, 0, 160))

	DrawBar(posX, posY, w, h, clip / cap)

	local curX = posX + w + 15
	for i = 1, visMags do
		local boxAmmo = math.min(cap, ammo - (i - 1) * cap)
		DrawBar(curX + 5, subY, subW, subH, boxAmmo / cap)
		curX = curX + subW + 20
	end

	if mags > 3 then
		draw.SimpleText("+" .. (mags - 3), "StationaryGun_AmmoFont", curX, subY + subH * 0.5, color_white, 0, 1)
	end
end)