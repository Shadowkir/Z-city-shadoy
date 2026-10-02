local CLASS_UA = player.RegClass("ukrainiansoldier")

function CLASS_UA.Off(self)
    if CLIENT then return end
end

local ukrainnames = {
    "Яків", "Федiр", "Добромисл", "Тімох", "Еміль",
    "Цвітан", "Світослав", "Явір", "Євлампій", "Георгій",
    "Світовид", "Світлогор", "Турбрід", "Юліан", "Юрій"
}

local models_ua = {
    "models/arty/halo7725/rusop/ukrosoldaten - ARC9.mdl",
}

function CLASS_UA.On(self)
    if CLIENT then return end

    if isfunction(ApplyAppearance) then
        ApplyAppearance(self, nil, nil, nil, true)
    end

    local Appearance = self.CurAppearance or (hg and hg.Appearance and hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance()) or {}

    self:SetPlayerColor(Color(90, 75, 0):ToVector())
    self:SetModel(models_ua[math.random(#models_ua)])
    self:SetNWString("PlayerName", ukrainnames[math.random(#ukrainnames)])

    local bgIndex = self:FindBodygroupByName("facewear")
    if bgIndex ~= -1 then
        self:SetBodygroup(bgIndex, math.random(0, self:GetBodygroupCount(bgIndex) - 1))
    end

    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    Appearance.ClothesStyle = ""
    Appearance.Attachmets = "none"
    self:SetNetVar("Accessories", "none")

    self:SetSubMaterial()
    self.CurAppearance = Appearance
end
-- а вы все москалі проклятые