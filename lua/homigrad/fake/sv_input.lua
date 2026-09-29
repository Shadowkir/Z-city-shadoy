local cooldown = 0.5

local blocked_models = {
	["models/shadowkir/shadowkir/shadowkir.mdl"] = true,
	--[""] = true,
}

local function IsBlockedModel(ply)
	if not IsValid(ply) then return false end
	local mdl = ply:GetModel()
	if not mdl then return false end
	return blocked_models[string.lower(mdl)] == true
end

hook.Add("Initialize", "BlockFakeForShadowkir", function()
	if hg and hg.Fake then
		local oldFake = hg.Fake
		hg.Fake = function(ply, ...)
			if IsBlockedModel(ply) then return end
			return oldFake(ply, ...)
		end
	end
end)

concommand.Add("fake", function(ply)
	if not ply:Alive() then return end
	if ply.fakecd and ply.fakecd > CurTime() then return end
	if ply:IsFlagSet( FL_FROZEN ) then return end
	
	if IsBlockedModel(ply) then return end

	--ply.fakecd = CurTime() + cooldown
	if not IsValid(ply.FakeRagdoll) then
		hg.Fake(ply)
	else
		hg.FakeUp(ply)
	end
end)

hook.Add("PlayerInitialSpawn", "PlayerColideCallback", function(ply) 
	ply:AddCallback("PhysicsCollide", function(phys, data) 
		hook.Run("PlayerCollide", ply, data.HitEntity, data) 
	end) 
end)

hook.Add("PlayerCollide", "Fake", function(ply, ent, data)
	if IsBlockedModel(ply) then return end

	if (not ent:IsPlayerHolding()) and data.Speed > math.max(700 - ent:GetPhysicsObject():GetMass(), 200) and ent:GetPhysicsObject():GetMass() > 20 and ent:GetClass() ~= "prop_ragdoll" and ent:GetPhysicsObject():GetVelocity():Length() > 50 then
		timer.Simple(0, function()
			hg.LightStunPlayer(ply, 2)
		end)
	end
end)

hook.Add("OnPlayerHitGround", "fallStun", function(ply, inwater, onfloater, speed)
	if IsValid(ply.FakeRagdoll) then return true end
	if IsBlockedModel(ply) then return end

	local tr = {}
	tr.start = ply:GetPos()
	tr.endpos = ply:GetPos() - vector_up * 2
	tr.filter = ply
	local bottom, top = ply:GetHull()
	bottom[3] = bottom[3] - 5
	tr.mins = bottom
	tr.maxs = top

	tr = util.TraceHull(tr)

	if ply:IsBerserk() then
		return
	end

	if ply.GetPlayerClass and ply:GetPlayerClass() and ply:GetPlayerClass().FallDmgFunc then
		ply:PlayerClassEvent("FallDmgFunc", speed, tr)
		return
	end

	if (ply.PlayerClassName == "furry" and speed > 350 or speed > 250) and tr.Entity:IsPlayer() then
		if not IsBlockedModel(tr.Entity) then
			hg.drop(tr.Entity)
			hg.LightStunPlayer(tr.Entity, 2)
		end
	end

	if speed > 600 then
		hg.LightStunPlayer(ply, 2)
	end
end)

concommand.Add("force_fake", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	local target = Player(tonumber(args[1]))
	if not IsValid(target) then return end
	
	if IsBlockedModel(target) then return end

	if not IsValid(target.FakeRagdoll) then
		hg.Fake(target)
	else
		hg.FakeUp(target)
	end
end)