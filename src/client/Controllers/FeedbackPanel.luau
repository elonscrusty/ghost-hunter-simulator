--!strict
-- FEEDBACK: players send a bug report or an idea (Settings → SEND FEEDBACK). The server filters
-- and stores it; the owner reads them in the DEV panel (FeedbackInbox).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)

local FeedbackPanel = {}

local panel: Kit.Panel
local box: TextBox
local counter: TextLabel
local kindButtons: { [string]: TextButton } = {}
local kind = "Bug"
local busy = false

local function setKind(k: string)
	kind = k
	for id, b in kindButtons do
		b:SetAttribute("Color", if id == k then (if id == "Bug" then "Red" else "Blue") else "Gray")
	end
	box.PlaceholderText = if k == "Bug"
		then "What went wrong? Where were you and what did you do?"
		else "What would make the game more fun?"
end

local function send()
	if busy then
		return
	end
	local text = box.Text
	if #text < Config.Feedback.MinLength then
		Kit.Toast("Tell us a bit more!", "Bad")
		return
	end
	busy = true
	local res = State.Request("Feedback", kind, text)
	busy = false
	if res.ok then
		box.Text = ""
		panel:Close()
		Kit.Toast("Thanks! Your " .. (if kind == "Bug" then "bug report" else "idea") .. " was sent 💚", "Good")
	else
		Kit.Toast(res.err or "Couldn't send", "Bad")
	end
end

function FeedbackPanel.Init()
	panel = Kit.Panel("Feedback", "💬 FEEDBACK", Vector2.new(520, 360), "Blue")
	local body = panel.Body
	local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, ZIndex = 61, Parent = body })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = row })
	for _, k in { "Bug", "Idea" } do
		kindButtons[k] = Kit.Button(row, {
			Text = if k == "Bug" then "🐞 BUG" else "💡 IDEA",
			Color = "Gray",
			Size = UDim2.fromOffset(150, 40),
			TextStyle = "Body",
			ZIndex = 62,
			OnClick = function()
				setKind(k)
			end,
		})
	end
	local frame: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 1, -128), Position = UDim2.fromOffset(0, 58), BackgroundColor3 = Theme.Bg, ZIndex = 61, Parent = body })
	Kit.Corner(frame, UDim.new(0, 12))
	Kit.Stroke(frame, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	box = Kit.new("TextBox", {
		Size = UDim2.new(1, -20, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Body,
		TextSize = Theme.Type.Body,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		Text = "",
		ZIndex = 62,
		Parent = frame,
	})
	counter = Kit.Label(body, "0 / " .. Config.Feedback.MaxLength, { Size = UDim2.fromOffset(110, 18), Position = UDim2.new(1, 0, 1, -66), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = Theme.Muted, Style = "Tiny", Stroke = 0, ZIndex = 62 })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Config.Feedback.MaxLength then
			box.Text = box.Text:sub(1, Config.Feedback.MaxLength)
		end
		counter.Text = #box.Text .. " / " .. Config.Feedback.MaxLength
	end)
	local sendButton = Kit.Button(body, {
		Text = "SEND",
		Color = "Green",
		Size = UDim2.fromOffset(220, 46),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = send,
	})
	panel.Primary = sendButton
	setKind("Bug")
	Hud.RegisterPanel("Feedback", function()
		panel:Toggle()
	end)
end

return FeedbackPanel
