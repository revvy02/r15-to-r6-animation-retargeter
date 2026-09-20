local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local Inputs = require(script.Parent.Inputs)
local Batch = require(script.Parent.Batch)
local makeView = require(script.Parent.View)
local makePreview = require(script.Parent.Preview)

return function(plugin, convert, rigs)
	local toolbar = plugin:CreateToolbar("R15 → R6")
	local toggle = toolbar:CreateButton("R15ToR6", "Convert R15 animations to R6", "", "Retarget")
	toggle.ClickableWhenViewportHidden = true
	local widget = plugin:CreateDockWidgetPluginGuiAsync(
		"R15ToR6Retargeter.v1",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 400, 760, 320, 480)
	)
	widget.Title = "R15 → R6 Retargeter"
	local view = makeView(widget)
	local preview = makePreview(view.viewports, rigs)
	local connections = {}
	local alive, busy, previewing, paused, counterWaist = true, false, false, false, false
	local results = {}
	local selected = 0
	local function connect(signal, fn)
		table.insert(connections, signal:Connect(fn))
	end
	local function clearResults()
		for _, result in results do
			result.source:Destroy()
			result.preview:Destroy()
		end
		table.clear(results)
	end
	local function selectionChanged()
		local inputs = Inputs.fromSelection(Selection:Get())
		view.selectionLabel.Text = if #inputs == 0
			then "Select Animation or KeyframeSequence instances in Explorer."
			else `{#inputs} animation{if #inputs == 1 then "" else "s"} selected in Explorer.`
	end
	local function setBusy(value)
		busy = value
		for _, button in { view.convertIds, view.convertSelection, view.option } do
			button.Interactable = not value
			button.TextTransparency = if value then 0.5 else 0
		end
	end
	local function show(index)
		if previewing or #results == 0 then
			return
		end
		previewing = true
		selected = (index - 1) % #results + 1
		local result = results[selected]
		view.previewLabel.Text = `PREVIEW · {selected}/{#results} · {result.name}`
		local ok, err = preview.show(result.source, result.preview)
		previewing = false
		paused = false
		preview.pause(not widget.Enabled)
		view.pause.Text = "Pause"
		if not ok and alive then
			view.status.Text ..= `\nPreview unavailable: {tostring(err)}`
		end
	end
	local function run(inputs, inputErrors)
		if busy or previewing or not alive then
			return
		end
		if RunService:IsRunning() then
			view.status.Text = "Stop play mode before converting animations."
			return
		end
		if #inputs == 0 then
			view.status.Text = if #inputErrors > 0
				then table.concat(inputErrors, "\n")
				else "Enter animation IDs or select animations in Explorer first."
			return
		end
		setBusy(true)
		local converted = {}
		local inserted = false
		local ok, err = pcall(function()
			local errors
			converted, errors = Batch.convert(
				inputs,
				convert,
				{ counterWaistSwingOnLegs = counterWaist },
				function(index, count, name)
					view.status.Text = `Converting {index}/{count} · {name}…`
				end,
				function()
					return not alive
				end
			)
			if not alive then
				return
			end
			for _, message in errors do
				table.insert(inputErrors, message)
			end
			if #converted > 0 then
				for _, result in converted do
					result.preview = result.output:Clone()
				end
				Batch.insert(converted)
				inserted = true
				clearResults()
				results = converted
			end
			view.status.Text = `{#converted} converted · {#inputErrors} failed`
			if #converted > 0 then
				view.status.Text ..= "\nSaved to ServerStorage / RetargetedR6."
			end
			if #inputErrors > 0 then
				view.status.Text ..= "\n" .. table.concat(inputErrors, "\n")
			end
			if #converted > 0 then
				show(1)
			end
		end)
		if not inserted then
			for _, result in converted do
				result.source:Destroy()
				result.output:Destroy()
				if result.preview then
					result.preview:Destroy()
				end
			end
		end
		if alive then
			if not ok then
				view.status.Text = `Conversion failed: {tostring(err)}`
			end
			setBusy(false)
		end
	end
	local function convertIds()
		run(Inputs.fromText(view.ids.Text))
	end
	local function convertSelection()
		run(Inputs.fromSelection(Selection:Get()))
	end
	local function destroy()
		if not alive then
			return
		end
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		preview.destroy()
		clearResults()
		widget:Destroy()
		toolbar:Destroy()
	end
	connect(toggle.Click, function()
		widget.Enabled = not widget.Enabled
	end)
	connect(widget:GetPropertyChangedSignal("Enabled"), function()
		toggle:SetActive(widget.Enabled)
		preview.pause(paused or not widget.Enabled)
	end)
	connect(view.convertIds.Activated, convertIds)
	connect(view.convertSelection.Activated, convertSelection)
	connect(view.option.Activated, function()
		counterWaist = not counterWaist
		view.option.Text = `{if counterWaist then "☑" else "☐"}  Hold legs against waist swing`
	end)
	connect(view.previous.Activated, function()
		if not busy then
			show(selected - 1)
		end
	end)
	connect(view.next.Activated, function()
		if not busy then
			show(selected + 1)
		end
	end)
	connect(view.pause.Activated, function()
		paused = not paused
		preview.pause(paused or not widget.Enabled)
		view.pause.Text = if paused then "Play" else "Pause"
	end)
	connect(Selection.SelectionChanged, selectionChanged)
	connect(plugin.Unloading, destroy)
	selectionChanged()
	toggle:SetActive(widget.Enabled)
	local ok, err = preview.show(nil, nil)
	preview.pause(not widget.Enabled)
	if not ok then
		view.status.Text = `Preview unavailable: {tostring(err)}`
	end
	return {
		widget = widget,
		view = view,
		preview = preview,
		convertIds = convertIds,
		convertSelection = convertSelection,
		destroy = destroy,
	}
end
