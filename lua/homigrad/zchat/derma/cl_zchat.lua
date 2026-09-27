--made by mrrp :3

local maxLength = GetConVar("zchat_maxmessagelength")

local NoDrop = CreateClientConVar("zchat_dropcharacters", 1, true, false, "Play the character dropping animation when erasing text", 0, 1)
local ShowTextBoxInactive = CreateClientConVar("zchat_showtextboxinactive", 1, true, false, "Showing your text in textbox while chat is turned off", 0, 1)
local ShowTimestamps = CreateClientConVar("zchat_showtimestamps", 0, true, false, "Show the time before every chat message", 0, 1)
local avatar = CreateClientConVar("zchat_avatar", 0, true, false, "Show player avatars next to chat messages", 0, 1)
local kerambit_gradientR = CreateClientConVar("zchat_accent_r", 247, true, false, "Chat accent red", 0, 255)
local kerambit_gradientG = CreateClientConVar("zchat_accent_g", 67, true, false, "Chat accent green", 0, 255)
local kerambit_gradientB = CreateClientConVar("zchat_accent_b", 67, true, false, "Chat accent blue", 0, 255)
local kerambit_gradientAlpha = CreateClientConVar("zchat_accent_alpha", 100, true, false, "Chat accent opacity", 0, 255)
local zadniyfonAlpha = CreateClientConVar("zchat_background_alpha", 200, true, false, "Chat background opacity", 0, 255)

local CHAT_POS_X_COOKIE = "zchat_position_x"
local CHAT_POS_Y_COOKIE = "zchat_position_y"

local function Getkerambit_gradient()
	return kerambit_gradientR:GetInt(), kerambit_gradientG:GetInt(), kerambit_gradientB:GetInt()
end

local stemava_razmer = 24
local stemava = 4

local INLINE_EMOJIS = {
	{"smile", "icon16/emoticon_smile.png"},
	{"grin", "icon16/emoticon_grin.png"},
	{"tongue", "icon16/emoticon_tongue.png"},
	{"cute", "icon16/emoticon_waii.png"},
	{"heart", "icon16/heart.png"},
	{"star", "icon16/star.png"},
	{"yes", "icon16/accept.png"},
	{"no", "icon16/cancel.png"},
	{"fire", "icon16/lightning.png"},
	{"bomb", "icon16/bomb.png"},
	{"bug", "icon16/bug.png"},
	{"rainbow", "icon16/rainbow.png"},
	{"yuuri1", "sticker/yuuri1.png"},
}

local EMOJI_MATERIALS = {}
for _, emoji in ipairs(INLINE_EMOJIS) do
	EMOJI_MATERIALS[emoji[1]] = emoji[2]
end

local function EscapeMarkup(text)
	return tostring(text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function NormalizeSteamID(value)
	value = string.Trim(tostring(value or ""))

	if value:match("^STEAM_%d:%d:%d+$") then
		value = util.SteamIDTo64(value)
	end

	if value and value:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") then
		return value
	end
end

local function HexColor(value)
	value = tostring(value or ""):gsub("^#", "")
	if !value:match("^%x%x%x%x%x%x$") then return end

	return tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
end

local function GradientMarkup(text, fromHex, toHex)
	local r1, g1, b1 = HexColor(fromHex)
	local r2, g2, b2 = HexColor(toHex)
	if !r1 or !r2 then return EscapeMarkup(text) end

	local length = math.max(string.utf8len(text), 1)
	local result = {}
	for i = 1, length do
		local fraction = length == 1 and 0 or (i - 1) / (length - 1)
		local char = string.utf8sub(text, i, i)
		local r = math.Round(Lerp(fraction, r1, r2))
		local g = math.Round(Lerp(fraction, g1, g2))
		local b = math.Round(Lerp(fraction, b1, b2))
		result[#result + 1] = string.format("<color=%d,%d,%d>%s</color>", r, g, b, EscapeMarkup(char))
	end

	return table.concat(result)
end
local function BuildRichMarkup(text)
	local replacements = {}
	local avatarCount = 0

	local function Placeholder(markup)
		replacements[#replacements + 1] = markup
		return "\1ZCHAT" .. #replacements .. "\2"
	end

	-- Paired formatting is expanded first. Contents remain plain text, which
	-- prevents nested user markup from escaping the allow-list.
	text = tostring(text or ""):gsub("<gradient%s*=%s*(#?%x%x%x%x%x%x)%s*,%s*(#?%x%x%x%x%x%x)%s*>(.-)</gradient>", function(fromHex, toHex, contents)
		return Placeholder(GradientMarkup(contents, fromHex, toHex))
	end)

	for _, effect in ipairs({"spoiler", "pulse", "rainbow"}) do
		local openTag = "<" .. effect .. ">"
		local closeTag = "</" .. effect .. ">"
		text = text:gsub(openTag .. "(.-)" .. closeTag, function(contents)
			return Placeholder(openTag .. EscapeMarkup(contents) .. closeTag)
		end)
	end

	text = text:gsub("<avatar%s*=%s*([^>]+)>", function(value)
		local steamID = NormalizeSteamID(value)
		if !steamID or avatarCount >= stemava then
			return "<avatar=" .. value .. ">"
		end

		avatarCount = avatarCount + 1
		return Placeholder(string.format("<avatar=%s,%dx%d>", steamID, stemava_razmer, stemava_razmer))
	end)

	text = text:gsub(":([%w_+-]+):", function(name)
		local material = EMOJI_MATERIALS[string.lower(name)]
		if !material then return ":" .. name .. ":" end

		return Placeholder(string.format("<img=%s,18x18>", material))
	end)

	text = EscapeMarkup(text)
	text = text:gsub("\1ZCHAT(%d+)\2", function(index)
		return replacements[tonumber(index)] or ""
	end)

	return text
end

surface.CreateFont("zChatSettingsButtonFont", {
	font = "Segoe UI Symbol",
	size = 18,
	weight = 500,
	extended = true,
	antialias = true
})

local function CallbackBind(self, callback)
	return function(_, ...)
		return callback(self, ...)
	end
end

local function InsertEntryText(entry, text)
	local oldText = entry:GetText()
	local caret = entry:GetCaretPos()
	local newText = string.utf8sub(oldText, 1, caret) .. text .. string.utf8sub(oldText, caret + 1)

	entry:SetText(newText)
	entry:SetCaretPos(caret + string.utf8len(text))
	entry:OnTextChanged()
end

local function SetEntryText(entry, text)
	entry:SetText(text)
	entry:SetCaretPos(string.utf8len(text))
	entry:OnTextChanged()
end

local function GetStyledSource(text)
	text = tostring(text or "")
	local source = text:match("^<gradient%s*=%s*#?%x%x%x%x%x%x%s*,%s*#?%x%x%x%x%x%x%s*>(.-)</gradient>$")
	if source then return source end

	for _, effect in ipairs({"spoiler", "pulse", "rainbow"}) do
		source = text:match("^<" .. effect .. ">(.-)</" .. effect .. ">$" )
		if source then return source end
	end

	return source or text
end

local function GetGradientPreview(entry)
	local text = GetStyledSource(entry:GetText())
	text = text:gsub("<avatar%s*=%s*[^>]+>", "[AVATAR]")
	text = text:gsub("[%c\r\n]+", " ")
	text = string.Trim(text)

	if text == "" then text = "TEST" end
	if string.utf8len(text) > 28 then
		text = string.utf8sub(text, 1, 27) .. "…"
	end

	return text
end


local function PaintGradientButton(button, w, h, entry, fromHex, toHex)
	local hovered = button:IsHovered()
	surface.SetDrawColor(hovered and 38 or 24, hovered and 38 or 24, hovered and 38 or 24, 235)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(hovered and 210 or 95, hovered and 70 or 70, hovered and 70 or 70, 220)
	surface.DrawOutlinedRect(0, 0, w, h)

	local r1, g1, b1 = HexColor(fromHex)
	local r2, g2, b2 = HexColor(toHex)
	local text = GetGradientPreview(entry)
	local length = string.utf8len(text)
	local widths = {}
	local totalWidth = 0

	surface.SetFont("zChatFont")
	for index = 1, length do
		local char = string.utf8sub(text, index, index)
		local charWidth = surface.GetTextSize(char)
		widths[index] = charWidth
		totalWidth = totalWidth + charWidth
	end

	local x = math.max((w - totalWidth) * 0.5, 6)
	local y = h * 0.5
	for index = 1, length do
		local fraction = length == 1 and 0 or (index - 1) / (length - 1)
		local char = string.utf8sub(text, index, index)
		local color = Color(
			math.Round(Lerp(fraction, r1, r2)),
			math.Round(Lerp(fraction, g1, g2)),
			math.Round(Lerp(fraction, b1, b2))
		)

		draw.SimpleText(char, "zChatFont", x + 1, y + 1, Color(0, 0, 0, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(char, "zChatFont", x, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		x = x + widths[index]
	end
end

local function PaintTextEffectButton(button, w, h, entry, effect)
	local hovered = button:IsHovered()
	surface.SetDrawColor(hovered and 38 or 24, hovered and 38 or 24, hovered and 38 or 24, 235)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(hovered and 210 or 95, hovered and 70 or 70, hovered and 70 or 70, 220)
	surface.DrawOutlinedRect(0, 0, w, h)

	local text = GetGradientPreview(entry)
	surface.SetFont("zChatFont")
	local textWidth, textHeight = surface.GetTextSize(text)
	local x = w * 0.5
	local y = h * 0.5

	if effect == "spoiler" and !hovered then
		local left = math.max((w - textWidth) * 0.5, 6)
		surface.SetDrawColor(7, 7, 7, 255)
		surface.DrawRect(left, y - textHeight * 0.5, math.min(textWidth, w - 12), textHeight)
		surface.SetDrawColor(75, 75, 75, 220)
		surface.DrawOutlinedRect(left, y - textHeight * 0.5, math.min(textWidth, w - 12), textHeight)
		return
	end

	if effect == "rainbow" then
		local drawX = math.max((w - textWidth) * 0.5, 6)
		local length = string.utf8len(text)
		for index = 1, length do
			local char = string.utf8sub(text, index, index)
			local charWidth = surface.GetTextSize(char)
			local rainbow = HSVToColor((CurTime() * 100 + index * 24) % 360, 0.85, 1)
			draw.SimpleText(char, "zChatFont", drawX + 1, y + 1, Color(0, 0, 0, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(char, "zChatFont", drawX, y, rainbow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			drawX = drawX + charWidth
		end
		return
	end

	local alpha = effect == "pulse" and math.Round(140 + math.sin(CurTime() * 5) * 115) or 255
	draw.SimpleText(text, "zChatFont", x + 1, y + 1, Color(0, 0, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "zChatFont", x, y, Color(245, 245, 245, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function ApplyGradientToEntry(entry, fromHex, toHex)
	local source = string.Trim(GetStyledSource(entry:GetText()))
	if source == "" then source = "TEST" end

	local prefix = string.format("<gradient=%s,%s>", fromHex, toHex)
	local suffix = "</gradient>"
	local maxContentLength = math.max(maxLength:GetInt() - string.utf8len(prefix) - string.utf8len(suffix), 1)
	if string.utf8len(source) > maxContentLength then
		source = string.utf8sub(source, 1, maxContentLength)
	end

	SetEntryText(entry, prefix .. source .. suffix)
end

local function ApplyTextEffectToEntry(entry, effect)
	local source = string.Trim(GetStyledSource(entry:GetText()))
	if source == "" then source = "TEST" end

	local prefix = "<" .. effect .. ">"
	local suffix = "</" .. effect .. ">"
	local maxContentLength = math.max(maxLength:GetInt() - string.utf8len(prefix) - string.utf8len(suffix), 1)
	if string.utf8len(source) > maxContentLength then
		source = string.utf8sub(source, 1, maxContentLength)
	end

	SetEntryText(entry, prefix .. source .. suffix)
end

local function PaintMarkupOverride(panel, text, font, x, y, color, alignX, alignY, alpha, block)
	alpha = alpha or 255
	local effect = block and block.effect

	if effect == "spoiler" then
		surface.SetFont(font)
		local textWidth, textHeight = surface.GetTextSize(text)

		if !panel.spoilerHovered then
			surface.SetDrawColor(12, 12, 12, math.min(alpha, 245))
			surface.DrawRect(x, y + 1, math.max(textWidth, 8), math.max(textHeight - 2, 4))
			surface.SetDrawColor(70, 70, 70, math.min(alpha, 180))
			surface.DrawOutlinedRect(x, y + 1, math.max(textWidth, 8), math.max(textHeight - 2, 4))
			return
		end
	elseif effect == "pulse" then
		alpha = math.Clamp(alpha * (0.55 + math.sin(CurTime() * 5) * 0.45), 20, 255)
	elseif effect == "rainbow" then
		surface.SetFont(font)
		local drawX = x
		local length = string.utf8len(text)

		for index = 1, length do
			local char = string.utf8sub(text, index, index)
			local charWidth = surface.GetTextSize(char)
			local rainbow = HSVToColor((CurTime() * 100 + index * 24) % 360, 0.85, 1)

			surface.SetTextPos(drawX + 1, y + 1)
			surface.SetTextColor(0, 0, 0, alpha)
			surface.DrawText(char)
			surface.SetTextPos(drawX, y)
			surface.SetTextColor(rainbow.r, rainbow.g, rainbow.b, alpha)
			surface.DrawText(char)
			drawX = drawX + charWidth
		end

		return
	end

	-- background for easier reading
	surface.SetTextPos(x + 1, y + 1)
	surface.SetTextColor(0, 0, 0, alpha)
	surface.SetFont(font)
	surface.DrawText(text)

	surface.SetTextPos(x, y)
	surface.SetTextColor(color.r, color.g, color.b, alpha)
	surface.SetFont(font)
	surface.DrawText(text)
end

local PANEL = {}

function PANEL:Init()
	self.text = ""
	self.textOffset = 0
	self.alpha = 0
	self.fadeDelay = 15
	self.fadeDuration = 5
	self.yAnimDuration = 1

	self.yAnim = 5
	self.inlineAvatars = {}
end

function PANEL:ClearInlineAvatars()
	for _, avatar in ipairs(self.inlineAvatars or {}) do
		if IsValid(avatar) then avatar:Remove() end
	end

	self.inlineAvatars = {}
end

function PANEL:CreateInlineAvatars()
	local avatarIndex = 0
	for _, block in ipairs(self.markup.blocks or {}) do
		if !block.steamID then continue end
		avatarIndex = avatarIndex + 1

		local avatar = self.inlineAvatars[avatarIndex]
		if !IsValid(avatar) then
			avatar = self:Add("AvatarImage")
			avatar:SetMouseInputEnabled(false)
			self.inlineAvatars[avatarIndex] = avatar
		end

		if avatar.zChatSteamID != block.steamID then
			avatar:SetSteamID(block.steamID, 32)
			avatar.zChatSteamID = block.steamID
		end

		if avatar:GetWide() != block.w or avatar:GetTall() != block.h then
			avatar:SetSize(block.w, block.h)
		end

		avatar.zChatBlock = block
	end

	for index = #self.inlineAvatars, avatarIndex + 1, -1 do
		local avatar = self.inlineAvatars[index]
		if IsValid(avatar) then avatar:Remove() end
		table.remove(self.inlineAvatars, index)
	end
end

local function CanShowSpeakerAvatar(speaker)
	if engine.ActiveGamemode() == "sandbox" then return true end

	return IsValid(speaker) and speaker:IsPlayer() and !speaker:Alive()
end

function PANEL:SetSpeaker(speaker)
	self.speaker = speaker
	self.textOffset = 0

	if IsValid(self.avatar) then
		self.avatar:Remove()
	end

	if !avatar:GetBool() or !IsValid(speaker) or !speaker:IsPlayer() or !CanShowSpeakerAvatar(speaker) then
		self:InvalidateLayout(true)
		return
	end

	self.avatar = self:Add("AvatarImage")
	self.avatar:SetSize(24, 24)
	self.avatar:SetPlayer(speaker, 32)
	self.avatar:SetMouseInputEnabled(false)
	self.avatar.PaintOver = function(avatar, w, h)
		local alpha = avatar:GetAlpha()
		local teamColor = IsValid(speaker) and team.GetColor(speaker:Team()) or color_white

		surface.SetDrawColor(0, 0, 0, alpha)
		surface.DrawOutlinedRect(0, 0, w, h)
		surface.SetDrawColor(teamColor.r, teamColor.g, teamColor.b, alpha)
		surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
	end
	self.textOffset = 30

	self:InvalidateLayout(true)
end

function PANEL:GetMarkupWidth(width)
	return math.max(width - self.textOffset, 1)
end

function PANEL:UpdateHeight()
	local avatarHeight = IsValid(self.avatar) and 24 or 0
	self:SetTall(math.max(self.markup:GetHeight(), avatarHeight))
end

function PANEL:SetMarkup(text)
	self.text = text

	self.markup = hg.markup.Parse(self.text, self:GetMarkupWidth(self:GetWide()))
	self.markup.onDrawText = function(...)
		PaintMarkupOverride(self, ...)
	end
	self:CreateInlineAvatars()

	self:UpdateHeight()

	timer.Simple(self.fadeDelay, function()
		if (!IsValid(self)) then
			return
		end

		self:CreateAnimation(self.fadeDuration, {
			index = 3,
			target = {alpha = 0}
		})
	end)

	self:CreateAnimation(self.yAnimDuration, {
		index = 4,
		target = {yAnim = 0},
		easing = "outQuint"
	})

	self:CreateAnimation(0.5, {
		index = 3,
		target = {alpha = 255},
	})
end

function PANEL:PerformLayout(width, height)
	if IsValid(self.avatar) then
		self.avatar:SetPos(0, 0)
	end

	self.markup = hg.markup.Parse(self.text, self:GetMarkupWidth(width))
	self.markup.onDrawText = function(...)
		PaintMarkupOverride(self, ...)
	end
	self:CreateInlineAvatars()

	self:UpdateHeight()
end

function PANEL:UpdateSpoilerHover()
	self.spoilerHovered = false
	if !IsValid(hg.chat) or !hg.chat:GetActive() then return end

	local mouseX, mouseY = gui.MousePos()
	mouseX, mouseY = self:ScreenToLocal(mouseX, mouseY)

	for _, block in ipairs(self.markup.blocks or {}) do
		if block.effect != "spoiler" or !block.text then continue end

		local x = self.textOffset + block.offset.x
		local y = self.yAnim + (block.height - block.thisY) + block.offset.y
		if mouseX >= x and mouseX <= x + block.thisX
			and mouseY >= y and mouseY <= y + block.thisY then
			self.spoilerHovered = true
			return
		end
	end
end

function PANEL:Paint(width, height)
	local newAlpha

	if (hg.chat:GetActive()) then
		newAlpha = math.max(hg.chat.alpha, self.alpha)
	else
		newAlpha = self.alpha - (255 - hg.chat.realAlpha)
	end

	self:UpdateSpoilerHover()

	if IsValid(self.avatar) then
		self.avatar:SetAlpha(math.Clamp(newAlpha, 0, 255))
	end

	for _, avatar in ipairs(self.inlineAvatars or {}) do
		if !IsValid(avatar) then continue end
		local block = avatar.zChatBlock
		avatar:SetPos(self.textOffset + block.offset.x, self.yAnim + block.offset.y)
		avatar:SetAlpha(math.Clamp(newAlpha, 0, 255))
	end

	DisableClipping(true)
		local chatboxX, chatboxY = hg.chat:GetPos()
		local wide, tall = hg.chat:GetSize()

		render.SetScissorRect(chatboxX, chatboxY, chatboxX + wide, chatboxY + tall, true)
			self.markup:draw(self.textOffset, self.yAnim, nil, nil, newAlpha)
		render.SetScissorRect(0, 0, 0, 0, false)
	DisableClipping(false)
end

vgui.Register("zChatMessage", PANEL, "Panel")

PANEL = {}

DEFINE_BASECLASS("DTextEntry")

function PANEL:Init()
	self:SetFont("zChatFont")
	self:SetUpdateOnType(true)
	self:SetHistoryEnabled(true)

	self.History = hg.chat.messageHistory
	self.droppedCharacters = {}

	self.prevText = ""

	self:SetTextColor(color_white)

	self:SetPaintBackground(false)

	self.m_bLoseFocusOnClickAway = false
end

function PANEL:AllowInput(newCharacter)
	local text = self:GetText()
	local maxLen = maxLength:GetInt()

	-- we can't check for the proper length using utf-8 since AllowInput is called for single bytes instead of full characters
	if (string.len(text .. newCharacter) > maxLen) then
		surface.PlaySound("common/talk.wav")
		return true
	end
end

function PANEL:Think()
	local text = self:GetText()
	local maxLen = maxLength:GetInt()

	if (text:utf8len() > maxLen) then
		local newText = text:utf8sub(0, maxLen)

		self:SetText(newText)
		self:SetCaretPos(newText:utf8len())
	end
end

local gradient_l = Material("vgui/gradient-l")

function PANEL:Paint(w, h)
	local accentR, accentG, accentB = Getkerambit_gradient()
	surface.SetDrawColor(accentR * 0.2, accentG * 0.2, accentB * 0.2, 110)
	surface.DrawRect(0, 0, w, h)

	-- surface.SetDrawColor(137, 137, 137, 150)
	-- surface.SetMaterial(gradient_l)
	-- surface.DrawTexturedRect(0, 0, w * 0.9, h)

	for k, v in ipairs(self.droppedCharacters) do
		local text = v.text

		v.velocityY = v.velocityY + (5 * FrameTime())
		v.y = v.y + v.velocityY

		v.x = v.x + v.velocityX

		v.alpha = v.alpha - FrameTime() * 750

		DisableClipping(true)
			surface.SetTextColor(150, 150, 150, v.alpha)
			surface.SetTextPos(v.x, v.y)
			surface.SetFont("zChatFont")
			surface.DrawText(text)
		DisableClipping(false)

		if v.alpha <= 0 then
			table.remove(self.droppedCharacters, k)
		end
	end

	if ShowTextBoxInactive:GetBool() and !hg.chat:GetActive() and self.prevText != "" then
		DisableClipping(true)
		surface.SetAlphaMultiplier(1)
			surface.SetTextColor(150, 150, 150, 55)
			surface.SetTextPos(0, 0)
			surface.SetFont("zChatFont")
			surface.DrawText(self.prevText)
		surface.SetAlphaMultiplier(0)
		DisableClipping(false)
	end

	BaseClass.Paint(self, w, h)
end

function PANEL:OnValueChange(text)
	local prevText = self.prevText

	if NoDrop:GetBool() then
		local len1, len2 = string.utf8len(prevText), string.utf8len(text)

		if len1 > len2 then
			local droppedText = string.utf8sub(prevText, self:GetCaretPos() + 1, self:GetCaretPos() + (len1 - len2))

			local droppedChars = string.Explode(utf8.charpattern, droppedText)
			for k, v in ipairs(droppedChars) do
				local data = {}
				data.text = v

				surface.SetFont("zChatFont")
				-- local tw1 = surface.GetTextSize(text)
				local tw2 = surface.GetTextSize(v)

				data.x = tw2 * (self:GetCaretPos())

				-- local panelWide = self:GetWide()

				-- if data.x > panelWide then
				-- 	data.x = data.x - (data.x - panelWide)
				-- end

				data.y = 8

				data.velocityX = math.Rand(-0.1, 0.1)
				data.velocityY = -1

				data.alpha = 255

				table.insert(self.droppedCharacters, data)
			end
		end
	end

	self.prevText = text
end

vgui.Register("zChatboxEntry", PANEL, "DTextEntry")

PANEL = {}

AccessorFunc(PANEL, "bActive", "Active", FORCE_BOOL)
AccessorFunc(PANEL, "realAlpha", "RealAlpha", FORCE_BOOL)

function PANEL:Init()
	hg.chat = self

	self.entries = {}
	self.messageHistory = {}

	self.alpha = 255
	self.realAlpha = 255

	self:SetSize(ScrW() * 0.3, ScrH() * 0.25)

	local defaultX, defaultY = ScrW() * 0.02, ScrH() * 0.67
	local savedX = cookie.GetNumber(CHAT_POS_X_COOKIE, defaultX)
	local savedY = cookie.GetNumber(CHAT_POS_Y_COOKIE, defaultY)

	self:SetPos(
		math.Clamp(savedX, 0, ScrW() - self:GetWide()),
		math.Clamp(savedY, 0, ScrH() - self:GetTall())
	)

	local titleBar = self:Add("Panel")
	titleBar:SetZPos(2)
	titleBar:SetTall(24)
	titleBar:Dock(TOP)
	titleBar:SetMouseInputEnabled(true)
	titleBar:SetCursor("sizeall")
	titleBar.Paint = function(_, w, h)
		local accentR, accentG, accentB = Getkerambit_gradient()
		surface.SetDrawColor(accentR * 0.14, accentG * 0.14, accentB * 0.14, 165)
		surface.DrawRect(0, 0, w, h)
	end
	titleBar.OnMousePressed = function(_, mouseCode)
		if mouseCode != MOUSE_LEFT then return end

		local mouseX, mouseY = gui.MousePos()
		local panelX, panelY = self:GetPos()

		self.dragOffsetX = mouseX - panelX
		self.dragOffsetY = mouseY - panelY
		self.dragging = true
	end

	self.settingsButton = titleBar:Add("DButton")
	self.settingsButton:Dock(RIGHT)
	self.settingsButton:SetWide(30)
	self.settingsButton:SetText("")
	self.settingsButton:SetCursor("hand")
	self.settingsButton.Paint = function(button, w, h)
		local alpha = button:IsHovered() and 190 or 125

		surface.SetDrawColor(25, 25, 25, alpha)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("•••", "zChatSettingsButtonFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	self.settingsButton.DoClick = function()
		self:OpenSettings()
	end

	local entryPanel = self:Add("Panel")
	entryPanel:SetZPos(1)
	entryPanel:Dock(BOTTOM)
	entryPanel:DockMargin(4, 0, 4, 4)

	self.entry = entryPanel:Add("zChatboxEntry")
	self.entry:SetZPos(1)
	self.entry:Dock(FILL)
	-- self.entry.OnValueChange = ix.util.Bind(self, self.OnTextChanged)
	-- self.entry.OnKeyCodeTyped = ix.util.Bind(self, self.OnKeyCodeTyped)
	self.entry.OnEnter = CallbackBind(self, self.OnMessageSent)

	local toolsButton = entryPanel:Add("DButton")
	toolsButton:SetZPos(0)
	toolsButton:Dock(RIGHT)
	toolsButton:DockMargin(2, 0, 0, 0)
	toolsButton:SetWide(28)
	toolsButton:SetText("")
	toolsButton.Paint = function(button, w, h)
		local alpha = button:IsHovered() and 190 or 115
		local accentR, accentG, accentB = Getkerambit_gradient()
		surface.SetDrawColor(accentR * 0.2, accentG * 0.2, accentB * 0.2, alpha)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("☺", "zChatSettingsButtonFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	toolsButton.DoClick = function()
		self:OpenToolsMenu(toolsButton)
	end

	self.history = self:Add("DScrollPanel")
	self.history:Dock(FILL)
	self.history:DockMargin(4, 2, 4, 4)

	self:SetActive(false)
end

function PANEL:OpenToolsMenu(anchor)
	if IsValid(self.toolsFrame) then
		self.toolsFrame:Remove()
		return
	end

	local frame = vgui.Create("DFrame")
	self.toolsFrame = frame
	frame:SetSize(360, 390)
	frame:SetTitle("Chat features")
	frame:SetDeleteOnClose(true)
	frame:SetSizable(false)
	frame:ShowCloseButton(true)

	local anchorX, anchorY = anchor:LocalToScreen(anchor:GetWide(), 0)
	frame:SetPos(
		math.Clamp(anchorX - frame:GetWide(), 0, ScrW() - frame:GetWide()),
		math.Clamp(anchorY - frame:GetTall() - 6, 0, ScrH() - frame:GetTall())
	)
	frame:MakePopup()

	frame.OnRemove = function()
		if IsValid(self) and self:GetActive() then
			self.entry:RequestFocus()
		end
	end

	local tabs = frame:Add("DPropertySheet")
	tabs:Dock(FILL)
	tabs:DockMargin(6, 6, 6, 6)

	local emojiPanel = vgui.Create("DScrollPanel", tabs)
	local emojiGrid = emojiPanel:Add("DIconLayout")
	emojiGrid:Dock(TOP)
	emojiGrid:SetTall(300)
	emojiGrid:DockMargin(8, 8, 8, 8)
	emojiGrid:SetSpaceX(8)
	emojiGrid:SetSpaceY(8)

	for _, emoji in ipairs(INLINE_EMOJIS) do
		local name, material = emoji[1], emoji[2]
		local button = emojiGrid:Add("DImageButton")
		button:SetSize(38, 38)
		button:SetImage(material)
		button.DoClick = function()
			if !IsValid(self) then return end
			InsertEntryText(self.entry, ":" .. name .. ":")
			self.entry:RequestFocus()
		end
	end

	-- The local player's Steam avatar behaves like another emoji tile.
	local avatarButton = emojiGrid:Add("DButton")
	avatarButton:SetSize(38, 38)
	avatarButton:SetText("")
	avatarButton:SetCursor("hand")

	local avatarImage = avatarButton:Add("AvatarImage")
	avatarImage:Dock(FILL)
	avatarImage:DockMargin(3, 3, 3, 3)
	avatarImage:SetMouseInputEnabled(false)
	avatarImage:SetPlayer(LocalPlayer(), 32)

	avatarButton.Paint = function(button, w, h)
		surface.SetDrawColor(button:IsHovered() and 210 or 90, 60, 60, 230)
		surface.DrawRect(0, 0, w, h)
	end
	avatarButton.DoClick = function()
		if !IsValid(self) or !IsValid(LocalPlayer()) then return end

		InsertEntryText(self.entry, "<avatar=" .. LocalPlayer():SteamID64() .. ">")
		self.entry:RequestFocus()
	end

	tabs:AddSheet("Emojis", emojiPanel, "icon16/emoticon_smile.png")

	local gradientPanel = vgui.Create("DScrollPanel", tabs)
	gradientPanel:GetCanvas():DockPadding(8, 8, 8, 8)

	local textScrollBar = gradientPanel:GetVBar()
	textScrollBar:SetWide(12)
	textScrollBar:SetHideButtons(true)
	textScrollBar.Paint = function(_, w, h)
		surface.SetDrawColor(12, 12, 12, 210)
		surface.DrawRect(2, 0, w - 4, h)
	end
	textScrollBar.btnGrip.Paint = function(_, w, h)
		local accentR, accentG, accentB = Getkerambit_gradient()
		draw.RoundedBox(3, 2, 0, w - 4, h, Color(accentR, accentG, accentB, 230))
	end

	local textDescription = gradientPanel:Add("DLabel")
	textDescription:Dock(TOP)
	textDescription:DockMargin(0, 0, 0, 8)
	textDescription:SetTall(42)
	textDescription:SetWrap(true)
	textDescription:SetText("The buttons preview your current message. Click an effect to apply it to the entire line.")

	local gradients = {
		{"#FF3D3D", "#FFD93D"},
		{"#00E5FF", "#C000FF"},
		{"#43E97B", "#38F9D7"},
		{"#FF5F6D", "#FFC371"},
		{"#4FACFE", "#E0C3FC"}
	}

	for _, gradient in ipairs(gradients) do
		local fromHex = gradient[1]
		local toHex = gradient[2]
		local button = gradientPanel:Add("DButton")
		button:Dock(TOP)
		button:DockMargin(0, 0, 0, 7)
		button:SetTall(42)
		button:SetText("")
		button.Paint = function(button, w, h)
			PaintGradientButton(button, w, h, self.entry, fromHex, toHex)
		end
		button.DoClick = function()
			if !IsValid(self) then return end
			ApplyGradientToEntry(self.entry, fromHex, toHex)
			self.entry:RequestFocus()
		end
	end

	local effects = {
		"spoiler",
		"pulse",
		"rainbow"
	}

	for _, effect in ipairs(effects) do
		local button = gradientPanel:Add("DButton")
		button:Dock(TOP)
		button:DockMargin(0, 0, 0, 7)
		button:SetTall(42)
		button:SetText("")
		button.Paint = function(button, w, h)
			PaintTextEffectButton(button, w, h, self.entry, effect)
		end
		button.DoClick = function()
			if !IsValid(self) then return end
			ApplyTextEffectToEntry(self.entry, effect)
			self.entry:RequestFocus()
		end
	end

	tabs:AddSheet("Text", gradientPanel, "icon16/color_wheel.png")
end

function PANEL:SavePosition()
	local x, y = self:GetPos()

	cookie.Set(CHAT_POS_X_COOKIE, tostring(math.floor(x)))
	cookie.Set(CHAT_POS_Y_COOKIE, tostring(math.floor(y)))
end

function PANEL:ResetPosition()
	self:SetPos(ScrW() * 0.02, ScrH() * 0.67)
	self:SavePosition()
end

function PANEL:Think()
	if !self.dragging then return end

	if !input.IsMouseDown(MOUSE_LEFT) then
		self.dragging = false
		self:SavePosition()
		return
	end

	local mouseX, mouseY = gui.MousePos()
	local x = math.Clamp(mouseX - self.dragOffsetX, 0, ScrW() - self:GetWide())
	local y = math.Clamp(mouseY - self.dragOffsetY, 0, ScrH() - self:GetTall())

	self:SetPos(x, y)
end

function PANEL:OpenSettings()
	if IsValid(self.settingsFrame) then
		self.settingsFrame:MakePopup()
		self.settingsFrame:MoveToFront()
		return
	end

	local frame = vgui.Create("DFrame")
	self.settingsFrame = frame

	frame:SetSize(430, math.min(650, ScrH() - 80))
	frame:Center()
	frame:SetTitle("Settings")
	frame:SetDeleteOnClose(true)
	frame:MakePopup()

	frame.OnRemove = function()
		if IsValid(self) and self:GetActive() then
			self.entry:RequestFocus()
		end
	end

	local form = frame:Add("DForm")
	form:Dock(FILL)
	form:DockMargin(8, 8, 8, 8)
	form:SetName("")
	form:SetHeaderHeight(0)
	form.Header:SetVisible(false)
	form:NumSlider("Font size", "zchat_fontsize", 3, 10, 0)
	form:TextEntry("Font name", "zchat_font")
	form:NumSlider("Font weight", "zchat_fontweight", 0, 1000, 0)
	form:CheckBox("Font antialiasing", "zchat_fontaa")
	form:CheckBox("Animation for deleted characters", "zchat_dropcharacters")
	form:CheckBox("Show typed text when chat is closed", "zchat_showtextboxinactive")
	form:CheckBox("Show message timestamps", "zchat_showtimestamps")
	form:CheckBox("Show player avatars", "zchat_avatar")
	form:Help("Chat window appearance")

	local colorMixer = vgui.Create("DColorMixer")
	colorMixer:SetTall(150)
	colorMixer:SetPalette(true)
	colorMixer:SetAlphaBar(false)
	colorMixer:SetWangs(true)
	colorMixer:SetColor(Color(kerambit_gradientR:GetInt(), kerambit_gradientG:GetInt(), kerambit_gradientB:GetInt()))
	colorMixer.ValueChanged = function(_, color)
		RunConsoleCommand("zchat_accent_r", tostring(math.Round(color.r)))
		RunConsoleCommand("zchat_accent_g", tostring(math.Round(color.g)))
		RunConsoleCommand("zchat_accent_b", tostring(math.Round(color.b)))
	end
	form:AddItem(colorMixer)

	form:NumSlider("Accent opacity", "zchat_accent_alpha", 0, 255, 0)
	form:NumSlider("Background opacity", "zchat_background_alpha", 0, 255, 0)

	local resetAppearance = form:Button("Reset chat appearance")
	resetAppearance.DoClick = function()
		RunConsoleCommand("zchat_accent_r", "247")
		RunConsoleCommand("zchat_accent_g", "67")
		RunConsoleCommand("zchat_accent_b", "67")
		RunConsoleCommand("zchat_accent_alpha", "100")
		RunConsoleCommand("zchat_background_alpha", "200")
		colorMixer:SetColor(Color(247, 67, 67))
	end

	local resetButton = form:Button("Reset window position")
	resetButton.DoClick = function()
		if IsValid(self) then
			self:ResetPosition()
		end
	end
end

local gradient_d = Material("vgui/gradient-d")
local gray = Color(255, 255, 255, 100)
local black = Color(0, 0, 0, 200)

function PANEL:Paint(w, h)
	local accentR, accentG, accentB = Getkerambit_gradient()
	local accentAlpha = math.Clamp(kerambit_gradientAlpha:GetInt() + math.sin(CurTime()) * 30, 0, 255)
	surface.SetDrawColor(accentR, accentG, accentB, accentAlpha)
	surface.SetMaterial(gradient_d)
	surface.DrawTexturedRect(0, h * 0.5, w, h * 0.5)

	surface.SetDrawColor(0, 0, 0, zadniyfonAlpha:GetInt())
	surface.DrawRect(0, 0, w, h)

	surface.SetAlphaMultiplier(1)
		self.history:PaintManual()
		local bar = self.history:GetVBar()
		bar:SetAlpha(self:GetAlpha())
	surface.SetAlphaMultiplier(self:GetAlpha() / 255)

	DisableClipping(true)
		draw.SimpleText("Hold left ALT and press ENTER to whisper", "zChatFontSmall", 5, h * 1.01 + 1, black)
		draw.SimpleText("Hold left ALT and press ENTER to whisper", "zChatFontSmall", 4, h * 1.01, gray)

		if LocalPlayer().organism and LocalPlayer().organism.otrub  then
			draw.SimpleText("Your messages are currently not visible to anyone.", "zChatFontSmall", ScrW() * 0.3 + 1, h * 1.01 + 1, black, TEXT_ALIGN_RIGHT)
			draw.SimpleText("Your messages are currently not visible to anyone.", "zChatFontSmall", ScrW() * 0.3, h * 1.01, gray, TEXT_ALIGN_RIGHT)
		end
	DisableClipping(false)

	if self.bActive then
		self:SetAlpha(self.alpha - (255 - self.realAlpha))
	end
end

function PANEL:SetActive(bActive, bRemovePrev)
	if (bActive) then
		self:SetAlpha(255)
		self:MakePopup()
		self.entry:RequestFocus()

		input.SetCursorPos(self:LocalToScreen(10, self:GetTall() + 10))

		hook.Run("StartChat")
	else
		if IsValid(self.toolsFrame) then
			self.toolsFrame:Remove()
		end

		self:SetAlpha(0)
		self:SetMouseInputEnabled(false)
		self:SetKeyboardInputEnabled(false)

		if bRemovePrev then
			self.entry:SetText("")
			self.entry.prevText = ""
		end

		gui.EnableScreenClicker(false)

		hook.Run("FinishChat")
	end

	self.bActive = bActive

	local bar = self.history:GetVBar()
	bar:SetScroll(bar.CanvasSize)
end

function PANEL:AnimateAlpha(newAlpha)
	self:CreateAnimation(1, {
		index = 1,
		target = {alpha = newAlpha},
	})
end

function PANEL:AnimateRealAlpha(newAlpha)
	self:CreateAnimation(1, {
		index = 2,
		target = {realAlpha = newAlpha},
	})
end

function PANEL:SetRealAlpha(alpha)
	self.realAlpha = alpha
end

function PANEL:OnMessageSent()
	local text = self.entry:GetText()

	if (text:find("%S")) then
		local lastEntry = hg.chat.messageHistory[#hg.chat.messageHistory]

		-- only add line to textentry history if it isn't the same message
		if (lastEntry != text) then
			if (#hg.chat.messageHistory >= 20) then
				table.remove(hg.chat.messageHistory, 1)
			end

			hg.chat.messageHistory[#hg.chat.messageHistory + 1] = text
		end

		net.Start("zChatMessage")
			net.WriteString(text)
		net.SendToServer()
	end

	self:SetActive(false, true)
end

function PANEL:AddLine(elements)
	local buffer = {
		"<font=zChatFont>"
	}

	if ShowTimestamps:GetBool() then
		buffer[#buffer + 1] = "<color=140,180,220>" .. os.date("%H:%M:%S") .. "</color> - "
	end

	buffer = hook.Run("ModifyMessageBuffer", buffer, CHAT_SPEAKER) or buffer

	for index, v in ipairs(elements) do
		if (istable(v) and v.__zchatRichText) then
			buffer[#buffer + 1] = BuildRichMarkup(v.text)
		elseif (isstring(v) and index == #elements and IsValid(CHAT_SPEAKER)) then
			-- Compatibility with OnPlayerChat hooks that print the player message
			-- themselves instead of passing zchat.RichText.
			buffer[#buffer + 1] = BuildRichMarkup(v)
		elseif (type(v) == "IMaterial") then
			local texture = v:GetName()

			if (texture) then
				buffer[#buffer + 1] = string.format("<img=%s,%dx%d> ", texture, v:Width(), v:Height())
			end
		elseif (istable(v) and v.r and v.g and v.b) then
			buffer[#buffer + 1] = string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
		elseif (type(v) == "Player") then
			local color = team.GetColor(v:Team())

			buffer[#buffer + 1] = string.format("<color=%d,%d,%d>%s", color.r, color.g, color.b,
				v:GetName():gsub("<", "&lt;"):gsub(">", "&gt;"))
		else
			buffer[#buffer + 1] = tostring(v):gsub("<", "&lt;"):gsub(">", "&gt;")
		end
	end

	local panel = self.history:Add("zChatMessage")
	panel:Dock(TOP)
	panel:InvalidateParent(true)
	panel:SetSpeaker(CHAT_SPEAKER)
	panel:SetMarkup(table.concat(buffer))

	if (#self.entries >= 100) then
		local oldPanel = table.remove(self.entries, 1)

		if (IsValid(oldPanel)) then
			oldPanel:Remove()
		end
	end

	local bar = self.history:GetVBar()
	local bScroll = !self:GetActive() or bar.Scroll == bar.CanvasSize -- only scroll when we're not at the bottom/inactive

	if bScroll then
		bar:SetScroll(bar.CanvasSize)
	end

	self.entries[#self.entries + 1] = panel
	return panel
end

function PANEL:AddMessage(...)
	self:AddLine({...})

	chat.PlaySound()
end

vgui.Register("zChatbox", PANEL, "EditablePanel")

cvars.AddChangeCallback("zchat_avatar", function()
	if !IsValid(hg.chat) then return end

	for _, panel in ipairs(hg.chat.entries or {}) do
		if IsValid(panel) then
			panel:SetSpeaker(panel.speaker)
		end
	end
end, "ZChatAvatarVisibility")
