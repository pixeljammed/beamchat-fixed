-- module for chatting, text rendering, etc.
-- @unrooot

local chatModule = {}

-- user & emoji searching
chatModule.chatbarToggle = false
chatModule.searching = nil
chatModule.emojiSearch = {}

-- chat history
chatModule.chatHistory = {}
chatModule.historyPosition = 0
chatModule.chatCache = ""

-- used for hovering effects
chatModule.inContainer = false

-- table of locally muted players
chatModule.muted = {}

-- services
local deb = game:GetService("Debris")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local txt = game:GetService("TextService")
local textChatService = game:GetService("TextChatService")

-- initialization
local beamchatRS = rs:WaitForChild("beamchat")
local modules = beamchatRS:WaitForChild("modules")
local remotes = beamchatRS:WaitForChild("remotes")

local effects = require(modules.effects)
local emoji = require(modules.emoji)
local emotes = require(modules.emotes)
local colors = require(modules.chatColors)
local config = require(modules.clientConfig)
local textRenderer = require(modules.textRenderer)
local statusIcons = require(modules.statusIcons)
local bubbleChat = require(modules.bubbleChat)

local c3 = Color3.fromRGB
local c3w = c3(255, 255, 255)
local u2 = UDim2.new
local v2 = Vector2.new

local sub = string.sub
local gsub = string.gsub
local gmatch = string.gmatch
local len = string.len
local find = string.find
local lower = string.lower

local plr = players.LocalPlayer
local beamchat = plr:WaitForChild("PlayerGui"):WaitForChild("beamchat2"):WaitForChild("main")
local chatbar, chatbox = beamchat:WaitForChild("chatbar"), beamchat:WaitForChild("chatbox")

-- Generate the frame for any possible search results.
function chatModule.generateResults()
	local results = Instance.new("Frame")
	results.Name = "results"
	results.BackgroundTransparency = 1
	results.Size = u2(1, 0, 0, 0)
	results.Position = u2(0, 0, 1, 0)
	results.Parent = chatbar

	local highlight = Instance.new("Frame")
	highlight.Name = "highlight"
	highlight.BackgroundColor3 = c3w
	highlight.BackgroundTransparency = 0.9
	highlight.BorderSizePixel = 0
	highlight.Size = u2(1, 0, 0, 26)
	highlight.Position = u2(0, 0, 0, 0)
	highlight.Parent = results

	local entries = Instance.new("Frame")
	entries.Name = "entries"
	entries.BackgroundTransparency = 1
	entries.Size = u2(1, 0, 1, 0)
	entries.Parent = results

	return results
end

-- Get the last word of a string.
function chatModule.getLastWord(str)
	local lastWord = ""
	local words = {}

	for word in gmatch(str, "%S+") do
		table.insert(words, word)
	end

	if #words > 0 then
		lastWord = words[#words]
	end

	return lastWord
end

-- Clear the search results.
function chatModule.clearResults()
	if chatModule.searching then
		local res = chatbar:FindFirstChild("results")
		if res then
			res:TweenSize(u2(0, res.Size.X.Offset, 0, 0), "Out", "Quart", 0.25, true)
			wait(0.25)
			res:Destroy()
		end

		chatModule.searching = nil
	end
end

-- Correct the chatbar bounds.
function chatModule.correctBounds(reset)
	if reset then
		chatbar.Size = u2(1, 0, 0, 32)
		return
	end

	local input = chatbar.input
	local label = chatbar.label

	if input.Text == "" then
		chatbar.Size = u2(1, 0, 0, 32)
	else
		local textSize = txt:GetTextSize(input.Text, 18, Enum.Font.SourceSans, v2(chatbar.AbsoluteSize.X, 1000))
		chatbar.Size = u2(1, 0, 0, textSize.Y + 16)
	end
end

-- Fade out the chat.
function chatModule.fadeOut()
	if not chatModule.inContainer and not chatbar.input:IsFocused() then
		effects.fade(chatbox, 0.25, {BackgroundTransparency = 1, ScrollBarImageTransparency = 1})
		effects.fade(chatbar, 0.25, {BackgroundTransparency = 1})
		effects.fade(chatbar.label, 0.25, {TextTransparency = 0.5, TextStrokeTransparency = 0.85})
	end
end

function chatModule.sanitize(str)
	local sanitized = string.gsub(str, "%s+", " ")
	if sanitized ~= nil and sanitized ~= "" and sanitized ~= " " then
		-- strip starting and trailing spaces
		if sub(sanitized, 0, 1) == " " then
			sanitized = sub(sanitized, 2, len(sanitized))
		end

		if sub(sanitized, len(sanitized)) == " " then
			sanitized = sub(sanitized, 0, len(sanitized)-1)
		end

		return sanitized
	else
		return nil
	end
end

-- Toggle the chatbar & message sending.
-- @param {boolean} sending - Whether or not the message will be sent.
function chatModule.chatbar(sending)
	if chatModule.canChat then
		if not chatModule.chatbarToggle then
			chatModule.correctBounds()
			chatModule.chatbarToggle = true

			-- chatbar effects
			effects.fade(chatbox, 0.25, {BackgroundTransparency = 0.5})
			effects.fade(chatbar, 0.25, {BackgroundTransparency = 0.3})
			effects.fade(chatbar.input, 0.25, {TextTransparency = 0, Active = true, Visible = true})
			effects.fade(chatbar.label, 0.25, {TextTransparency = 1, TextStrokeTransparency = 1, Active = false, Visible = false})
			chatbar.label:TweenPosition(u2(0.1, 0, 0, -10), "Out", "Quart", 0.25, true)

			-- why doesn't it take the renderstepped wait pls?????????
			wait()
			chatbar.input:CaptureFocus()
		
			chatModule.chatbarToggle = false
			-- capture user input
			local msg = chatbar.input.Text

			-- reset chatbar properties
			effects.fade(chatbox, 0.25, {BackgroundTransparency = 1})
			effects.fade(chatbar, 0.25, {BackgroundTransparency = 1})
			effects.fade(chatbar.input, 0.25, {TextTransparency = 1, Active = false, Visible = false})
			effects.fade(chatbar.label, 0.25, {TextTransparency = 0, TextStrokeTransparency = 0.85, Active = true, Visible = true})
			chatbar.label:TweenPosition(u2(0, 0, 0, -10), "Out", "Quart", 0.25, true)

			chatModule.searching = nil

			if sending then
				-- reset input if sending
				chatbar.input.Text = ""
				local sanitized = chatModule.sanitize(msg)

				if sanitized ~= nil then
					-- she's good to go!!!!
					table.insert(chatModule.chatHistory, sanitized)

					chatModule.historyPosition = 0
					chatModule.chatCache = ""

					local lowerS = lower(sanitized)

					-- local chat commands!
					-- todo: migrate to be module based
					if sub(sanitized, 0, 3) == "/e " then
						local emoteName = lower(sub(sanitized, 4))

						-- lowercase emote map
						local emoteTable = {}
						local desc = plr.Character.Humanoid:FindFirstChildOfClass("HumanoidDescription")

						for x,_ in pairs(desc:GetEmotes()) do
							emoteTable[lower(x)] = x
						end

						-- try playing animation
						pcall(function()
							plr.Character.Animate.PlayEmote:Invoke(emoteName)
							plr.Character.Humanoid:PlayEmote(emoteTable[emoteName])
						end)
					elseif sub(lowerS, 0, 5) == "/mute" then
						local target = chatModule.sanitize(sub(lowerS, 7))

						if target == "[system]" then
							chatModule.newSystemMessage("no 👺")
						else
							if target ~= lower(plr.Name) and len(target) >= 3 then
								local found
								for _,v in pairs(players:GetPlayers()) do
									if find(lower(v.Name), target) then
										found = v.Name
									end
								end

								if found and not table.find(chatModule.muted, lower(found)) then
									table.insert(chatModule.muted, lower(found))
									chatModule.newSystemMessage(("Muted %s."):format(found))
								else
									chatModule.newSystemMessage("Player not found.")
								end
							elseif target == lower(plr.Name) then
								chatModule.newSystemMessage("You can't mute yourself, silly.")
							else
								chatModule.newSystemMessage("Player invalid.")
							end
						end
					elseif sub(lowerS, 0, 7) == "/unmute" then
						local target = sub(lowerS, 9)
						local inTable = table.find(chatModule.muted, target)

						if inTable then
							table.remove(chatModule.muted, inTable)
							chatModule.newSystemMessage("Player unmuted.")
						else
							chatModule.newSystemMessage("You do not have that player muted.")
						end
					elseif sub(lowerS, 0, 2) == "/?" or sub(lowerS, 0, 5) == "/help" then
						-- todo: move this to be ui based?
						chatModule.newSystemMessage(config.helpMessage)
					elseif sub(lowerS, 0, 7) == "/emotes" then
						local emoteList = ""

						for name,_ in pairs(emotes) do
							emoteList = emoteList .. ":" .. name .. ": "
						end

						chatModule.newSystemMessage("Here are the currently enabled emotes (hover to see names): " .. emoteList)
					elseif sub(lowerS, 0, 7) == "/modern" then
						config.chatAnimation = "modern"
					elseif sub(lowerS, 0, 8) == "/classic" then
						config.chatAnimation = "classic"
					else
						if lowerS == "/shrug" then
							sanitized = "¯\\_(ツ)_/¯"
						end

						textChatService.TextChannels.RBXGeneral:SendAsync(sanitized)
					end
				end
			end

			local res = chatbar:FindFirstChild("results")
			if res then
				res:TweenSize(u2(0, res.Size.X.Offset, 0, 0), "Out", "Quart", 0.25, true)
				wait(0.25)
				res:Destroy()
			end

			chatbar.input:ReleaseFocus()
		end
	end
end

-- Correct the chat entry sizes if the user resizes their screen.
function chatModule.correctSize(message)
	assert(message.ClassName == "Frame", "[chatModule] [correctSize] parameter message must be a frame.")

	-- get the new size of the message and resize accordingly
	local contents = message:WaitForChild("message").Text
	local msgSize = txt:GetTextSize(contents, 18, Enum.Font.SourceSansBold, v2(chatbox.AbsoluteSize.X, 1000))
	message.Size = u2(1, 20, 0, msgSize.Y == 18 and 22 or msgSize.Y+2)
end

-- Re-align all of the messages when the client resizes their screen.
function chatModule.alignMessages()
	local sum = 0
	for i = 1, (#chatbox:GetChildren() - 1) do
		local label = chatbox[tostring(i)]
		if i ~= 1 then
			label.Position = u2(0, 0, 1, -sum)
		end

		sum = sum + label.AbsoluteSize.Y + 8
	end

	chatbox.CanvasSize = u2(0, 0, 0, sum + 8)
	chatbox.CanvasPosition = v2(0, chatbox.CanvasSize.Y.Offset)
end

-- Create a new message in the chatbox.
-- @param {table} chatData
-- {
-- 		user = [string] user, -- the user that sent the message
--		message = [string] message, -- the filtered contents of the user's message.
--		type = [string] type, -- the type of message (can be general or whisper)
-- 		(optional) target = [string] target -- the person who is receiving the whisper.
-- }

function chatModule.newMessage(chatData)
	local user = chatData.user
	local msg = chatData.message
	local type = chatData.type

	local muted = false
	for _,v in pairs(chatModule.muted) do
		if v == lower(user) then
			muted = true
		end
	end

	if not muted then
		local player = players:FindFirstChild(user)
		if player then
			bubbleChat.newBubble(player.UserId, msg)
		end

		local label = Instance.new("TextLabel")
		label.Name = "1"
		label.BackgroundTransparency = 1
		label.AnchorPoint = v2(0, 1)
		label.Size = u2(1, 0, 0, 22)
		label.Font = Enum.Font.SourceSansBold
		label.TextColor3 = c3w
		label.TextSize = 16
		label.TextTransparency = 1
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Parent = chatbox

		if player then
			label.TextColor3 = colors.getTextColor(player.UserId)
		end

		if find(lower(msg), lower(plr.Name)) then
			local highlight = Instance.new("Frame")
			highlight.Size = u2(1, 10, 1, 8)
			highlight.Position = u2(0, -5, 0, -4)
			highlight.BorderSizePixel = 0
			highlight.BackgroundColor3 = c3w
			highlight.BackgroundTransparency = 0.85
			highlight.Name = "highlight"
			highlight.Parent = label
		end

		local posY = Instance.new("NumberValue")
		posY.Name = "posY"
		posY.Parent = label

		local preText = ""
		if type == "whisper" then
			local formatting
			local target = chatData.target

			if target == plr.Name then
				formatting = "{whisper from} " .. user
			else
				formatting = "{whisper to} " .. target
			end

			preText = ("{%s}{b}%s %s{}{} "):format(colors.getColor(user), formatting, user)
		
			local iconTag = ""

			if player then
				local iconId = statusIcons:fetchStatusIcon(player.UserId)
				if iconId and iconId ~= "" then
					iconTag = string.format("{%s} ", iconId)
				end
			end

			local specialTags = ""
			for _,v in pairs(chatData.specialTags) do
				specialTags = specialTags .. v
			end

			local nameTag = ("{%s}{b}%s:{}"):format(colors.getColor(user), user)
			preText = iconTag .. specialTags .. nameTag .. "  "
		elseif type == "system" then
			preText = "{#8ba4b3}{b}[{b}{b}{#65a4f1}system{b}{b}{#8ba4b3}]:{b}{}  "
		end

		label.Text = preText

		-- text formatting (thanks adrian <3)
		local cleanText = gsub(msg, "{", "\\{")
		-- cleanText = string.gsub(cleanText, "%*%*..-%*%*", function(a) return "{i}"..string.sub(a, 3, #a-2).."{}" end) -- italic
		-- local formatted = string.gsub(cleanText, "%*..-%*", function(a) return "{b}"..string.sub(a, 3, #a-2).."{}" end) -- bold

		-- append formatted text to final string
		label.Text = label.Text .. cleanText

		-- do da magic
		textRenderer.renderText(label)

		for _,v in pairs(chatbox:GetChildren()) do
			if v:IsA("TextLabel") and v ~= label then
				v.posY.Value = v.posY.Value - label.Size.Y.Offset - 8
				v.Name = tonumber(v.Name) + 1

				if config.chatAnimation == "modern" then
					v:TweenPosition(u2(0, 0, 1, (v.posY and v.posY.Value or (v.Position.Y.Offset - label.Size.Y.Offset) - 8)), "Out", "Quart", 0.25, true)
				elseif config.chatAnimation == "classic" then
					v.Position = u2(0, 0, 1, (v.posY and v.posY.Value or (v.Position.Y.Offset - label.Size.Y.Offset) - 8))
				end

				if tonumber(v.Name) > config.chatLimit then
					for _,x in pairs(v:GetDescendants()) do
						if x:IsA("TextLabel") then
							effects.fade(x, 0.25, {TextTransparency = 1, TextStrokeTransparency = 1})
						elseif x:IsA("ImageLabel") then
							effects.fade(x, 0.25, {ImageTransparency = 1})
						end
					end

					deb:AddItem(v, 1)
				end
			end
		end

		label.Position = u2(0, 0, 1, label.Size.Y.Offset)
		label.Visible  = true

		for _,v in pairs(label:GetDescendants()) do
			if v:IsA("TextLabel") and not v.Parent:IsA("Frame") then
				effects.fade(v, 0.25, {TextTransparency = 0, TextStrokeTransparency = 0.7})
			elseif v:IsA("ImageLabel") then
				effects.fade(v, 0.25, {ImageTransparency = 0})
			end
		end

		if config.chatAnimation == "modern" then
			label:TweenPosition(u2(0, 0, 1, 0), "Out", "Quart", 0.25, true)
		elseif config.chatAnimation == "classic" then
			label.Position = u2(0, 0, 1, 0)
		end

		local heightSum = 0
		for _,v in pairs(chatbox:GetChildren()) do
			if v:IsA("TextLabel") then
				heightSum = heightSum + v.AbsoluteSize.Y + 8
			end
		end

		chatbox.CanvasSize = u2(0, 0, 0, heightSum + 8)

		if not chatModule.inContainer then
			chatbox.CanvasPosition = v2(0, chatbox.CanvasSize.Y.Offset)
		end
	end
end

-- Create a new system message.
-- @param {string} - The contents of the system's message.
function chatModule.newSystemMessage(contents)
	chatModule.newMessage({user = "[system]", message = contents, type = "system"})
end

return chatModule
