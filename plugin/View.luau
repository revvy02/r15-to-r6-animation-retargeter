local C = {
	background = Color3.fromRGB(30, 33, 39),
	panel = Color3.fromRGB(43, 47, 55),
	text = Color3.fromRGB(235, 238, 244),
	muted = Color3.fromRGB(167, 176, 190),
	accent = Color3.fromRGB(83, 132, 245),
}

return function(parent)
	local root = Instance.new("ScrollingFrame")
	root.Name = "Retargeter"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = C.background
	root.BorderSizePixel = 0
	root.ScrollBarThickness = 4
	root.CanvasSize = UDim2.new()
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y
	root.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root
	local order = 0
	local function append(instance)
		order += 1
		instance.LayoutOrder = order
		instance.Parent = root
		return instance
	end
	local function text(value, size, muted)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -4, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.SourceSans
		label.TextSize = size or 16
		label.TextColor3 = if muted then C.muted else C.text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Text = value
		return append(label)
	end
	local function round(instance)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = instance
	end
	local function button(name, value, primary)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.new(1, -4, 0, 34)
		button.BackgroundColor3 = if primary then C.accent else C.panel
		button.BorderSizePixel = 0
		button.TextColor3 = C.text
		button.Font = Enum.Font.SourceSansSemibold
		button.TextSize = 16
		button.Text = value
		round(button)
		return button
	end
	local title = text("R15 → R6", 26)
	title.Font = Enum.Font.SourceSansSemibold
	text("Convert animations for classic rigs.", 16, true)
	text("ANIMATION IDS", 12, true)
	local ids = Instance.new("TextBox")
	ids.Name = "AnimationIds"
	ids.Size = UDim2.new(1, -4, 0, 76)
	ids.BackgroundColor3 = C.panel
	ids.BorderSizePixel = 0
	ids.TextColor3 = C.text
	ids.PlaceholderColor3 = C.muted
	ids.Font = Enum.Font.SourceSans
	ids.TextSize = 16
	ids.TextXAlignment = Enum.TextXAlignment.Left
	ids.TextYAlignment = Enum.TextYAlignment.Top
	ids.TextWrapped = true
	ids.MultiLine = true
	ids.ClearTextOnFocus = false
	ids.Text = ""
	ids.PlaceholderText = "Paste IDs or Roblox asset URLs\nSeparate with spaces, commas, or new lines"
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 10)
	inset.PaddingLeft = UDim.new(0, 10)
	inset.PaddingRight = UDim.new(0, 10)
	inset.Parent = ids
	round(ids)
	append(ids)
	local convertIds = append(button("ConvertIds", "Convert IDs", true))
	local selectionLabel = text("Select Animation or KeyframeSequence instances in Explorer.", 14, true)
	selectionLabel.Name = "SelectionStatus"
	local convertSelection = append(button("ConvertSelection", "Convert selection", false))
	local option = append(button("CounterWaist", "☐  Hold legs against waist swing", false))
	text("Use this when unanimated legs should stay planted as the waist bends.", 14, true)
	local status = text("Ready. Results appear in ServerStorage / RetargetedR6.", 15)
	status.Name = "Status"
	local previewLabel = text("PREVIEW", 12, true)
	previewLabel.Name = "PreviewLabel"
	local pair = Instance.new("Frame")
	pair.Name = "Comparison"
	pair.Size = UDim2.new(1, -4, 0, 192)
	pair.BackgroundTransparency = 1
	append(pair)
	local viewports = {}
	for i, label in { "R15 · source", "R6 · converted" } do
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = if i == 1 then "R15" else "R6"
		viewport.Size = UDim2.new(0.5, -4, 1, -24)
		viewport.Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 4, 0, 24)
		viewport.BackgroundColor3 = Color3.fromRGB(23, 26, 31)
		viewport.BorderSizePixel = 0
		viewport.Ambient = Color3.fromRGB(180, 185, 200)
		viewport.LightColor = Color3.fromRGB(255, 245, 231)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = pair
		round(viewport)
		local caption = Instance.new("TextLabel")
		caption.Size = UDim2.new(0.5, -4, 0, 20)
		caption.Position = UDim2.fromScale((i - 1) * 0.5, 0)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.SourceSans
		caption.TextSize = 14
		caption.TextColor3 = C.muted
		caption.Text = label
		caption.Parent = pair
		table.insert(viewports, viewport)
	end
	local controls = Instance.new("Frame")
	controls.Size = UDim2.new(1, -4, 0, 32)
	controls.BackgroundTransparency = 1
	append(controls)
	local controlsButtons = {}
	for i, value in { "Previous", "Pause", "Next" } do
		local control = button(value, value, false)
		control.Size = UDim2.new(1 / 3, -4, 1, 0)
		control.Position = UDim2.new((i - 1) / 3, 0, 0, 0)
		control.Parent = controls
		controlsButtons[i] = control
	end
	text(
		"Preview uses the bundled reference rigs. Conversion keeps the source intact; inserted sequences can be undone with Studio Undo.",
		14,
		true
	)
	return {
		root = root,
		ids = ids,
		convertIds = convertIds,
		convertSelection = convertSelection,
		option = option,
		status = status,
		selectionLabel = selectionLabel,
		previewLabel = previewLabel,
		viewports = viewports,
		previous = controlsButtons[1],
		pause = controlsButtons[2],
		next = controlsButtons[3],
	}
end
