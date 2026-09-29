--[[
    Bird Attack
    npc_crow / npc_pigeon / npc_seagull dive at targets (players, NPCs, NextBots),
    deal damage on contact, bounce back, turn around and attack again.
    Birds never attack each other.

    The engine AI of the birds is frozen (SCHED_NPC_FREEZE); flight is driven entirely from Lua.
]]

AddCSLuaFile()

local CVAR_FLAGS = { FCVAR_ARCHIVE, FCVAR_REPLICATED }

local CVAR_DEFAULTS = {
    birdattack_enabled = "0",
    birdattack_damage  = "5",
    birdattack_speed   = "500",
    birdattack_health  = "10",
    birdattack_range   = "4000",
    birdattack_retreat = "1",
}

local function MakeConVar(name, help)
    return CreateConVar(name, CVAR_DEFAULTS[name], CVAR_FLAGS, help)
end

local cvEnabled = MakeConVar("birdattack_enabled", "Enable attacking birds")
local cvDamage  = MakeConVar("birdattack_damage", "Damage per hit")
local cvSpeed   = MakeConVar("birdattack_speed", "Dive speed (units per second)")
local cvHealth  = MakeConVar("birdattack_health", "Bird health (0 = leave default)")
local cvRange   = MakeConVar("birdattack_range", "Target search range")
local cvRetreat = MakeConVar("birdattack_retreat", "Seconds a bird flies away after a hit")

------------------------------------------------------------------------------
-- Client: settings panel (Q -> Utilities -> Bird Attack -> Settings)
------------------------------------------------------------------------------
if CLIENT then
    hook.Add("AddToolMenuCategories", "BirdAttack.MenuCategory", function()
        spawnmenu.AddToolCategory("Utilities", "BirdAttack", "Bird Attack")
    end)

    hook.Add("PopulateToolMenu", "BirdAttack.Menu", function()
        spawnmenu.AddToolMenuOption("Utilities", "BirdAttack", "BirdAttackSettings", "Settings", "", "", function(panel)
            panel:ClearControls()

            panel:Help("Crows, pigeons and seagulls dive at players, NPCs and NextBots, peck them and come back for more. Birds never attack each other.")
            panel:ControlHelp("Settings can only be changed by the host (singleplayer / listen server). On a dedicated server use the server console.")

            panel:CheckBox("Birds attack", "birdattack_enabled")
            panel:ControlHelp("When disabled, birds return to their normal behaviour.")

            panel:NumSlider("Damage per hit", "birdattack_damage", 0, 100, 0)
            panel:NumSlider("Dive speed", "birdattack_speed", 150, 1500, 0)

            panel:NumSlider("Bird health", "birdattack_health", 0, 500, 0)
            panel:ControlHelp("Applied to newly spawned birds. 0 = leave the default health.")

            panel:NumSlider("Target search range", "birdattack_range", 500, 16000, 0)

            panel:NumSlider("Retreat time (seconds)", "birdattack_retreat", 0.3, 4, 1)
            panel:ControlHelp("How long a bird flies away after a hit before attacking again.")

            local reset = panel:Button("Reset to defaults")
            reset.DoClick = function()
                for name, value in pairs(CVAR_DEFAULTS) do
                    RunConsoleCommand(name, value)
                end
            end
        end)
    end)

    return
end

------------------------------------------------------------------------------
-- Server
------------------------------------------------------------------------------
local BIRD_CLASSES = {
    npc_crow    = true,
    npc_pigeon  = true,
    npc_seagull = true,
}

local BIRD_SOUNDS = {
    npc_crow    = { "NPC_Crow.Alert", "NPC_Crow.Squawk" },
    npc_pigeon  = { "NPC_Pigeon.Idle" },
    npc_seagull = { "NPC_Seagull.Pain", "NPC_Seagull.Idle" },
}

local BIRD_DEATH_SOUNDS = {
    npc_crow    = "NPC_Crow.Die",
    npc_pigeon  = "NPC_Pigeon.Idle",
    npc_seagull = "NPC_Seagull.Pain",
}

-- Utility "NPCs" that are pointless to attack
local IGNORE_CLASSES = {
    npc_bullseye           = true,
    bullseye_strider_focus = true,
    npc_enemyfinder        = true,
    npc_furniture          = true,
    npc_launcher           = true,
    npc_grenade_frag       = true,
    npc_satchel            = true,
    npc_tripmine           = true,
    npc_heli_avoidsphere   = true,
    npc_heli_avoidbox      = true,
    npc_heli_nobomb        = true,
    generic_actor          = true,
    cycler_actor           = true,
}

local STATE_ATTACK  = 1
local STATE_RETREAT = 2

local COND_FREEZE   = (COND and COND.NPC_FREEZE) or 67
local COND_UNFREEZE = (COND and COND.NPC_UNFREEZE) or 68

local Birds = {} -- [npc] = flight data
local forcedTarget = nil -- Цель по нику

local cvIgnorePlayers = GetConVar("ai_ignoreplayers")
local cvAIDisabled    = GetConVar("ai_disabled")

local VEC_UP = Vector(0, 0, 1)

------------------------------------------------------------------------------
-- Targets
------------------------------------------------------------------------------
local function IsValidTarget(ent)
    if not IsValid(ent) or Birds[ent] then return false end

    if ent:IsPlayer() then
        if cvIgnorePlayers and cvIgnorePlayers:GetBool() then return false end
        return ent:Alive()
            and ent:GetObserverMode() == OBS_MODE_NONE
            and not ent:IsFlagSet(FL_NOTARGET)
    end

    local class = ent:GetClass()
    if BIRD_CLASSES[class] or IGNORE_CLASSES[class] then return false end

    if ent:IsNPC() then
        return ent:Health() > 0
    end

    if ent:IsNextBot() then
        return true
    end

    return false
end

local function GetAimPos(target)
    if target:IsPlayer() then
        return target:EyePos() - Vector(0, 0, 8) -- peck the head
    end
    return target:WorldSpaceCenter()
end

local targetCache = {}
local nextCacheUpdate = 0

local function GetTargets()
    local now = CurTime()
    if now < nextCacheUpdate then return targetCache end
    nextCacheUpdate = now + 0.5

    local list = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValidTarget(ent) then
            list[#list + 1] = ent
        end
    end

    targetCache = list
    return list
end

local function CanSee(from, target)
    local tr = util.TraceLine({
        start  = from,
        endpos = GetAimPos(target),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Fraction > 0.98
end

local function PickTarget(eye)
    if IsValid(forcedTarget) and IsValidTarget(forcedTarget) then
        return forcedTarget
    end

    local range = cvRange:GetFloat()
    local rangeSqr = range * range

    local bestVis, bestVisDist = nil, rangeSqr
    local bestAny, bestAnyDist = nil, rangeSqr

    for _, ent in ipairs(GetTargets()) do
        if IsValidTarget(ent) then
            local d = eye:DistToSqr(ent:WorldSpaceCenter())
            if d < bestAnyDist then
                bestAny, bestAnyDist = ent, d
            end
            if d < bestVisDist and CanSee(eye, ent) then
                bestVis, bestVisDist = ent, d
            end
        end
    end

    return bestVis or bestAny
end

------------------------------------------------------------------------------
-- Taking over / releasing a bird
------------------------------------------------------------------------------
local function BirdSound(npc)
    local sounds = BIRD_SOUNDS[npc:GetClass()]
    if sounds then
        npc:EmitSound(sounds[math.random(#sounds)])
    end
end

local function FreezeAI(npc)
    npc:SetCondition(COND_FREEZE)
    npc:SetSchedule(SCHED_NPC_FREEZE)
end

local function RegisterBird(npc)
    if not IsValid(npc) or Birds[npc] or npc.BirdAttackDead then return end
    if not BIRD_CLASSES[npc:GetClass()] or not npc:IsNPC() then return end
    if npc:Health() <= 0 then return end
    if not cvEnabled:GetBool() then return end

    local mins, maxs = npc:GetCollisionBounds()

    local flySeq = npc:SelectWeightedSequence(ACT_FLY)
    if not flySeq or flySeq < 0 then flySeq = npc:LookupSequence("fly01") end

    local b = {
        state        = STATE_ATTACK,
        stateEnd     = 0,
        attackStart  = CurTime(),
        vel          = npc:GetForward() * 50 + Vector(0, 0, 150),
        home         = npc:GetPos(),
        mins         = mins,
        maxs         = maxs,
        center       = npc:OBBCenter(),
        flySeq       = flySeq,
        oldGroup     = npc:GetCollisionGroup(),
        nextRetarget = 0,
        nextAnim     = 0,
        nextStuck    = CurTime() + 1.5,
        stuckPos     = npc:GetPos(),
        lastSeen     = 0,
    }
    Birds[npc] = b

    local hp = cvHealth:GetInt()
    if hp > 0 then
        npc:SetMaxHealth(hp)
        npc:SetHealth(hp)
    end

    for class in pairs(BIRD_CLASSES) do
        npc:AddRelationship(class .. " D_LI 99")
    end

    FreezeAI(npc)
    npc:SetMoveType(MOVETYPE_NONE)
    npc:AddFlags(FL_FLY)
    npc:SetGroundEntity(NULL)
    npc:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    npc:SetIdealActivity(ACT_FLY)
end

local function ReleaseBird(npc)
    local b = Birds[npc]
    Birds[npc] = nil

    if not b or not IsValid(npc) or npc:Health() <= 0 then return end

    npc:SetCondition(COND_UNFREEZE)
    npc:SetMoveType(MOVETYPE_STEP)
    npc:SetCollisionGroup(b.oldGroup)
end

local function RegisterAll()
    for class in pairs(BIRD_CLASSES) do
        for _, npc in ipairs(ents.FindByClass(class)) do
            RegisterBird(npc)
        end
    end
end

hook.Add("OnEntityCreated", "BirdAttack.Register", function(ent)
    if not IsValid(ent) or not BIRD_CLASSES[ent:GetClass()] then return end
    timer.Simple(0.1, function() RegisterBird(ent) end)
end)

hook.Add("EntityRemoved", "BirdAttack.Unregister", function(ent)
    Birds[ent] = nil
end)

------------------------------------------------------------------------------
-- Death
------------------------------------------------------------------------------
local function SpawnCorpse(npc, vel)
    local rag = ents.Create("prop_ragdoll")
    if not IsValid(rag) then return end

    rag:SetModel(npc:GetModel())
    rag:SetPos(npc:GetPos())
    rag:SetAngles(npc:GetAngles())
    rag:SetSkin(npc:GetSkin())
    rag:Spawn()
    if not IsValid(rag) then return end
    rag:Activate()

    local count = rag:GetPhysicsObjectCount()
    if count <= 0 then
        rag:Remove()
        return
    end

    rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    local origin = npc:GetPos()
    for i = 0, count - 1 do
        local phys = rag:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local bone = rag:TranslatePhysBoneToBone(i)
            local bpos, bang = npc:GetBonePosition(bone)
            if bpos and bang and bpos ~= origin then
                phys:SetPos(bpos)
                phys:SetAngles(bang)
            end
            phys:Wake()
            phys:SetVelocity(vel)
        end
    end

    SafeRemoveEntityDelayed(rag, 20)
end

local function KillBird(npc, attacker, inflictor)
    if npc.BirdAttackDead then return end
    npc.BirdAttackDead = true

    local b = Birds[npc]
    Birds[npc] = nil

    local vel = b and b.vel * 0.6 or Vector(0, 0, 0)

    timer.Simple(0, function()
        if not IsValid(npc) then return end
        if npc:IsFlagSet(FL_TRANSRAGDOLL) then return end

        if not npc.BirdAttackKillReported then
            npc.BirdAttackKillReported = true

            local snd = BIRD_DEATH_SOUNDS[npc:GetClass()]
            if snd then npc:EmitSound(snd) end

            if not IsValid(attacker) then attacker = game.GetWorld() end
            if not IsValid(inflictor) then inflictor = attacker end
            local ok, err = pcall(hook.Run, "OnNPCKilled", npc, attacker, inflictor)
            if not ok then ErrorNoHalt("[BirdAttack] OnNPCKilled: " .. tostring(err) .. "\n") end
        end

        local ok, err = pcall(SpawnCorpse, npc, vel)
        if not ok then ErrorNoHalt("[BirdAttack] corpse: " .. tostring(err) .. "\n") end

        if IsValid(npc) then npc:Remove() end
    end)
end

hook.Add("OnNPCKilled", "BirdAttack.Death", function(npc, attacker, inflictor)
    if not IsValid(npc) or not BIRD_CLASSES[npc:GetClass()] then return end
    npc.BirdAttackKillReported = true
    if Birds[npc] then KillBird(npc, attacker, inflictor) end
end)

hook.Add("PostEntityTakeDamage", "BirdAttack.Death", function(ent, dmginfo)
    if Birds[ent] and ent:Health() <= 0 then
        KillBird(ent, dmginfo:GetAttacker(), dmginfo:GetInflictor())
    end
end)

-- Успокаиваем птиц после смерти цели по нику
hook.Add("PlayerDeath", "BirdAttack.TargetDied", function(victim)
    if IsValid(forcedTarget) and victim == forcedTarget then
        forcedTarget = nil
        cvEnabled:SetBool(false)
    end
end)

-- Если выбранный игрок вышел с сервера
hook.Add("PlayerDisconnected", "BirdAttack.TargetDisconnected", function(ply)
    if IsValid(forcedTarget) and ply == forcedTarget then
        forcedTarget = nil
        cvEnabled:SetBool(false)
    end
end)

hook.Add("InitPostEntity", "BirdAttack.Init", RegisterAll)
hook.Add("PostCleanupMap", "BirdAttack.Cleanup", function() timer.Simple(0.2, RegisterAll) end)

------------------------------------------------------------------------------
-- Команда hg_birdattack
------------------------------------------------------------------------------
cvars.AddChangeCallback("birdattack_enabled", function(_, _, new)
    local enabled = tobool(new)
    if enabled then
        RegisterAll()
    else
        forcedTarget = nil
        for npc in pairs(Birds) do ReleaseBird(npc) end
    end
end, "BirdAttack")

local function PrintConsoleMsg(ply, msg)
    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, msg .. "\n")
    else
        print(msg)
    end
end

local function FindPlayerByName(name)
    name = string.lower(name)
    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), name, 1, true) then
            return ply
        end
    end
    return nil
end

concommand.Add("hg_birdattack", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then
        PrintConsoleMsg(ply, "[Bird Attack] У вас нет прав на использование этой команды.")
        return
    end

    local input = table.concat(args, " ")
    input = string.Trim(input)
    local lowerInput = string.lower(input)

    if lowerInput == "1" or lowerInput == "on" then
        forcedTarget = nil
        cvEnabled:SetBool(true)
        PrintConsoleMsg(ply, "hg_birdattack = 1")
    elseif lowerInput == "0" or lowerInput == "off" then
        forcedTarget = nil
        cvEnabled:SetBool(false)
        PrintConsoleMsg(ply, "hg_birdattack = 0")
    elseif input == "" then
        forcedTarget = nil
        local newState = not cvEnabled:GetBool()
        cvEnabled:SetBool(newState)
        PrintConsoleMsg(ply, "hg_birdattack = " .. (newState and "1" or "0"))
    else
        -- Поиск игрока по нику
        local targetPly = FindPlayerByName(input)
        if IsValid(targetPly) then
            forcedTarget = targetPly
            cvEnabled:SetBool(true)

            local now = CurTime()
            for npc, b in pairs(Birds) do
                b.target = targetPly
                b.attackStart = now
                b.lastSeen = now
                b.state = STATE_ATTACK
            end

            PrintConsoleMsg(ply, "[Bird Attack] Цель захвачена: " .. targetPly:Nick())
        else
            PrintConsoleMsg(ply, "[Bird Attack] Игрок '" .. input .. "' не найден!")
        end
    end
end, nil, "Управление атакой птиц (hg_birdattack [1/0/ник])")

------------------------------------------------------------------------------
-- Flight
------------------------------------------------------------------------------
local function SteerDir(cur, want, maxRad)
    local dot = math.Clamp(cur:Dot(want), -1, 1)
    local ang = math.acos(dot)
    if ang <= maxRad or ang < 0.001 then return want end

    if ang > 3.1 then
        want = want + cur:Cross(VEC_UP) * 0.3 + VEC_UP * 0.3
        want:Normalize()
        dot = math.Clamp(cur:Dot(want), -1, 1)
        ang = math.acos(dot)
    end

    local s = math.sin(ang)
    if s < 0.001 then return want end

    local t = maxRad / ang
    local out = cur * (math.sin((1 - t) * ang) / s) + want * (math.sin(t * ang) / s)
    out:Normalize()
    return out
end

local function BirdFilter(ent)
    return not Birds[ent] and not BIRD_CLASSES[ent:GetClass()]
end

local function MoveBird(b, pos, dt)
    local delta = b.vel * dt
    local hitEnt

    local trData = {
        start  = pos,
        endpos = pos + delta,
        mins   = b.mins,
        maxs   = b.maxs,
        mask   = MASK_SOLID,
        filter = BirdFilter,
    }

    local tr = util.TraceHull(trData)

    if tr.StartSolid then
        if IsValid(tr.Entity) then hitEnt = tr.Entity end

        trData.mask = MASK_SOLID_BRUSHONLY
        tr = util.TraceHull(trData)

        if tr.StartSolid then
            return pos + delta + Vector(0, 0, 40 * dt), hitEnt
        end
    end

    if tr.Hit then
        local n = tr.HitNormal
        if not hitEnt and IsValid(tr.Entity) then hitEnt = tr.Entity end

        b.vel = b.vel - n * b.vel:Dot(n)

        return tr.HitPos + n * 0.5, hitEnt
    end

    return tr.HitPos, hitEnt
end

local function StartRetreat(b, dir, duration)
    b.state = STATE_RETREAT
    b.stateEnd = CurTime() + duration
    b.retreatDir = dir
end

local function DoHit(npc, b, victim, pos)
    local center = pos + b.center
    local dmgAmount = cvDamage:GetFloat()
    local flyDir = b.vel:GetNormalized()

    if dmgAmount > 0 then
        local dmg = DamageInfo()
        dmg:SetDamage(dmgAmount)
        dmg:SetAttacker(npc)
        dmg:SetInflictor(npc)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(center)
        dmg:SetDamageForce(flyDir * 200)
        victim:TakeDamageInfo(dmg)
    end

    if not IsValid(npc) then return end

    if IsValid(victim) then
        victim:EmitSound("Flesh.ImpactSoft")
        if victim:IsNPC() and victim.UpdateEnemyMemory then
            victim:UpdateEnemyMemory(npc, pos)
        end
    end
    if math.random() < 0.6 then BirdSound(npc) end

    local away = IsValid(victim) and (center - victim:WorldSpaceCenter()) or -flyDir
    away.z = 0
    if away:LengthSqr() < 1 then
        away = -flyDir
        away.z = 0
    end
    if away:LengthSqr() < 0.01 then
        away = VectorRand()
        away.z = 0
    end
    away:Normalize()

    local side = away:Cross(VEC_UP) * math.Rand(-0.6, 0.6)
    local dir = away + side + Vector(0, 0, math.Rand(0.35, 0.8))
    dir:Normalize()

    b.vel = dir * (cvSpeed:GetFloat() * 0.85)
    StartRetreat(b, dir, cvRetreat:GetFloat() * math.Rand(0.8, 1.2))
end

local function OnNewTarget(npc, target)
    npc:AddEntityRelationship(target, D_HT, 99)

    if target:IsNPC() and target.AddEntityRelationship then
        target:AddEntityRelationship(npc, D_HT, 99)
    end

    if math.random() < 0.5 then BirdSound(npc) end
end

local function UpdateTarget(npc, b, eye, now)
    if IsValid(forcedTarget) then
        -- Если цель умерла или стала невалидной прямо во время полета
        if not IsValidTarget(forcedTarget) then
            forcedTarget = nil
            cvEnabled:SetBool(false)
            return nil
        end

        if b.target ~= forcedTarget then
            b.target = forcedTarget
            b.lastSeen = now
            b.attackStart = now
            OnNewTarget(npc, forcedTarget)
        end
        return forcedTarget
    end

    local target = b.target
    local valid = IsValidTarget(target)

    if valid and now < b.nextRetarget then return target end
    b.nextRetarget = now + math.Rand(0.8, 1.2)

    if valid then
        local range = cvRange:GetFloat() * 1.2
        if CanSee(eye, target) then b.lastSeen = now end
        if now - b.lastSeen < 5 and eye:DistToSqr(target:WorldSpaceCenter()) < range * range then
            return target
        end
    end

    local new = PickTarget(eye)
    if new ~= target then
        b.target = new
        b.lastSeen = now
        b.attackStart = now
        if IsValid(new) then OnNewTarget(npc, new) end
    end

    return new
end

local function UpdateBird(npc, b, dt, now)
    local pos = npc:GetPos()
    local eye = pos + b.center
    local speedMax = cvSpeed:GetFloat()

    local target = UpdateTarget(npc, b, eye, now)
    local hasTarget = IsValid(target)

    if b.state == STATE_RETREAT and now >= b.stateEnd then
        b.state = STATE_ATTACK
        b.attackStart = now
    end

    local wantDir, wantSpeed, turnRate

    if b.state == STATE_RETREAT then
        wantDir   = b.retreatDir
        wantSpeed = speedMax * 0.85
        turnRate  = 360
    elseif hasTarget then
        wantDir = GetAimPos(target) - eye
        wantDir:Normalize()
        wantSpeed = speedMax
        turnRate = math.min(200 + (now - b.attackStart) * 150, 720)
    else
        if not b.wanderGoal or now > b.wanderUntil or pos:DistToSqr(b.wanderGoal) < 40 * 40 then
            b.wanderGoal = b.home + Vector(math.Rand(-350, 350), math.Rand(-350, 350), math.Rand(80, 260))
            b.wanderUntil = now + 4
        end
        wantDir = b.wanderGoal - pos
        wantDir:Normalize()
        wantSpeed = math.min(200, speedMax)
        turnRate  = 120
    end

    local speed = b.vel:Length()
    local dir = speed > 1 and b.vel / speed or wantDir

    dir   = SteerDir(dir, wantDir, math.rad(turnRate) * dt)
    speed = math.Approach(speed, wantSpeed, speedMax * 2 * dt)
    b.vel = dir * speed

    local newPos, hitEnt = MoveBird(b, pos, dt)
    npc:SetPos(newPos)

    if b.vel:LengthSqr() > 1 then
        local want = b.vel:Angle()
        local cur = npc:GetAngles()
        want:Normalize()
        cur:Normalize()
        npc:SetAngles(Angle(
            math.ApproachAngle(cur.p, math.Clamp(want.p, -55, 55), 360 * dt),
            math.ApproachAngle(cur.y, want.y, 540 * dt),
            0
        ))
    end

    if b.state == STATE_ATTACK then
        local victim

        if hasTarget then
            local c = newPos + b.center
            if hitEnt == target
                or c:DistToSqr(target:NearestPoint(c)) <= 16 * 16
                or c:DistToSqr(GetAimPos(target)) <= 24 * 24 then
                victim = target
            end
        end

        if not victim and hitEnt and IsValidTarget(hitEnt) then
            victim = hitEnt
        end

        if victim then
            DoHit(npc, b, victim, newPos)
            return
        end
    end

    if now >= b.nextStuck then
        if b.state == STATE_ATTACK and hasTarget and newPos:DistToSqr(b.stuckPos) < 40 * 40 then
            local esc = VectorRand()
            esc.z = math.Rand(1, 2)
            esc:Normalize()
            b.vel = esc * (speedMax * 0.6)
            StartRetreat(b, esc, 0.8)
        end
        b.stuckPos = newPos
        b.nextStuck = now + 1.5
    end

    npc:SetPlaybackRate(1)

    if now >= b.nextAnim then
        b.nextAnim = now + 0.25

        if not npc:IsCurrentSchedule(SCHED_NPC_FREEZE) then
            FreezeAI(npc)
        end
        if npc:GetMoveType() ~= MOVETYPE_NONE then
            npc:SetMoveType(MOVETYPE_NONE)
        end

        local act = npc:GetSequenceActivity(npc:GetSequence())
        if act ~= ACT_FLY and act ~= ACT_GLIDE and b.flySeq and b.flySeq >= 0 then
            npc:ResetSequence(b.flySeq)
        end
    end
end

hook.Add("Tick", "BirdAttack.Think", function()
    if not next(Birds) then return end
    if cvAIDisabled and cvAIDisabled:GetBool() then return end

    local dt = engine.TickInterval()
    local now = CurTime()

    for npc, b in pairs(Birds) do
        if not IsValid(npc) then
            Birds[npc] = nil
        elseif npc:Health() <= 0 then
            KillBird(npc)
        else
            local ok, err = pcall(UpdateBird, npc, b, dt, now)
            if not ok then
                ErrorNoHalt("[BirdAttack] " .. tostring(err) .. "\n")
                ReleaseBird(npc)
            end
        end
    end
end)