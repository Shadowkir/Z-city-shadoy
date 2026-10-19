local classList = player.classList
local Player = FindMetaTable("Player")

function Player:SetPlayerClass(value, data)
	data = data or {}
	value = value or "none"

	local old = self.PlayerClassName
	self.PlayerClassNameOld = old
	old = classList[old]
	if old and old.Off then old.Off(self) end

	self.PlayerClassName = value
	self:SetNWString("Class", value)
	self:SetNWString("ClassOld", self.PlayerClassNameOld or "")

	if value ~= "none" and value ~= "" then
		self:SetSubMaterial()              
		self:SetNetVar("Accessories", "") 
	else
		if hg and hg.Appearance and hg.Appearance.ForceApplyAppearance and self.CachedAppearance then
			hg.Appearance.ForceApplyAppearance(self, self.CachedAppearance, false)
		end
	end

	self:PlayerClassEvent("On", data)

	net.Start("setupclass")
		net.WriteEntity(self)
		net.WriteString(value)
		net.WriteString(self.PlayerClassNameOld or "")
		net.WriteTable(data)
	net.Broadcast()
end

function Player:GiveSwep(list, mulClip1)
	if not list then return end
	local wep = self:Give(type(list) == "table" and list[math.random(#list)] or list)
	mulClip1 = mulClip1 or 3
	if IsValid(wep) then
		wep:SetClip1(wep:GetMaxClip1())
		self:GiveAmmo(wep:GetMaxClip1() * mulClip1, wep:GetPrimaryAmmoType())
	end
end

util.AddNetworkString("setupclass")
hook.Add("PlayerInitializeSpawn", "PlayerClass", function(plySend)
	for i, ply in player.Iterator() do
		local cls = ply.PlayerClassName
		if not cls or cls == "none" or cls == "" then continue end
		net.Start("setupclass")
		net.WriteEntity(ply)
		net.WriteString(cls)
		net.WriteString(ply.PlayerClassNameOld or "")
		net.WriteTable({})
		net.Send(plySend)
	end
end)

hook.Add("PostPostPlayerDeath", "PlayerClass", function(ply, ragdoll)
	ply:PlayerClassEvent("PlayerDeath")
	ply:SetPlayerClass("none")
end)

hook.Add("Player Think", "ClassPlyThink", function(ply, time, dtime)
	ply:PlayerClassEvent("Think", time, dtime)
end)

COMMANDS.playerclass = {
	function(ply, args)
		if not ply:IsAdmin() then return end
		local plya = #args > 1 and args[1] or ply:Name()
		local class = #args > 1 and args[2] or args[1]

		if #args < 2 then
			ply:SetPlayerClass(class)
			ply:ChatPrint(ply:Name())
		else
			for i, ply2 in pairs(player.GetListByName(plya)) do
				ply2:SetPlayerClass(class)
				ply2:ChatPrint(ply2:Name())
			end
		end
	end,
	0
}