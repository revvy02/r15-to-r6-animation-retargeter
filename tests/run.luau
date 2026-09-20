local roblox = require("@rodeo/roblox")
local bundle = roblox.import("out/R15ToR6Retargeter.rbxm")[1]
bundle.Parent = game:GetService("ReplicatedStorage")
local convert = require(bundle.Retarget)
local Inputs = require(bundle.Inputs)
local Batch = require(bundle.Batch)
local Selection = game:GetService("Selection")
local history = game:GetService("ChangeHistoryService")
local checks = 0
local function check(value, message)
	assert(value, message)
	checks += 1
end

local function pose(parent, name, cf, weight)
	local p = Instance.new("Pose")
	p.Name, p.CFrame, p.Weight = name, cf or CFrame.identity, weight or 1
	p.Parent = parent
	return p
end

local function sequence()
	local source = Instance.new("KeyframeSequence")
	source.Name = "SparseWaist"
	source.Loop = true
	source.Priority = Enum.AnimationPriority.Action
	source:SetAttribute("Fixture", "preserved")
	for i = 0, 2 do
		local key = Instance.new("Keyframe")
		key.Name, key.Time = `Frame{i}`, i / 2
		key.Parent = source
		local root = pose(key, "HumanoidRootPart")
		local lower = pose(root, "LowerTorso")
		local upper = pose(lower, "UpperTorso", CFrame.Angles(i * 0.2, 0, i * 0.1))
		pose(upper, "Head")
		if i == 1 then
			local marker = Instance.new("KeyframeMarker")
			marker.Name, marker.Value = "Footstep", "left"
			marker.Parent = key
		end
	end
	return source
end

for _, value in
	{
		"507777826",
		"rbxassetid://507777826",
		"https://www.roblox.com/asset/?id=507777826",
		"https://create.roblox.com/store/asset/507777826/walk",
	}
do
	check(Inputs.assetId(value) == "rbxassetid://507777826", `ID parsing: {value}`)
end
for _, value in { "", "0", "-1", "12.5", "rbxassetid://no", "https://example.com/asset/?id=123" } do
	check(Inputs.assetId(value) == nil, `Reject invalid ID: {value}`)
end
local ids, invalid = Inputs.fromText("507777826, rbxassetid://507777826; bad\n507765000")
check(#ids == 2 and #invalid == 1, "Deduplicate IDs and retain input errors")

local source = sequence()
source.Parent = game:GetService("ServerStorage")
local output = convert(source)
check(output ~= source and output.Parent == nil, "Conversion returns a detached copy")
check(output.Name == "SparseWaist_Precise", "Preserve the existing function contract")
check(output.Loop == source.Loop and output.Priority == source.Priority, "Preserve loop and priority")
check(output:GetAttribute("Fixture") == "preserved", "Preserve attributes")
local allowed = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}
local markers = 0
for _, item in output:GetDescendants() do
	if item:IsA("Pose") then
		check(allowed[item.Name], `R6 pose name: {item.Name}`)
		for _, number in { item.CFrame:GetComponents() } do
			check(number == number and math.abs(number) < math.huge, "Finite transforms")
		end
	elseif item:IsA("KeyframeMarker") then
		markers += 1
		check(item.Name == "Footstep" and item.Value == "left", "Preserve event marker")
	end
end
check(markers == 1 and #output:GetKeyframes() == 3, "Preserve keyframes and markers")
check(
	source:FindFirstChild("UpperTorso", true) ~= nil and source:FindFirstChild("Torso", true) == nil,
	"Do not mutate source"
)
local held = convert(source, { counterWaistSwingOnLegs = true })
check(output:FindFirstChild("Left Leg", true) == nil, "Default leaves unauthored legs alone")
check(held:FindFirstChild("Left Leg", true) ~= nil, "Option counters waist swing on unauthored legs")
local empty = Instance.new("KeyframeSequence")
check(convert(empty) == nil, "Empty sequence returns nil")
empty:Destroy()

for _, name in { "rbx_animate_walk", "rbx_animate_dance", "rbx_animate_jump", "r6_animate_idle1" } do
	local input = roblox.import(`tests/fixtures/{name}.rbxm`)[1]
	local result = convert(input)
	check((result ~= nil) == (name ~= "r6_animate_idle1"), `Fixture rig detection: {name}`)
	if result then
		check(#result:GetKeyframes() == #input:GetKeyframes(), `Fixture frame count: {name}`)
		result:Destroy()
	end
	input:Destroy()
end

local animation = Instance.new("Animation")
animation.Name, animation.AnimationId = "OnlineWalk", "rbxassetid://507777826"
local wrong = Instance.new("Folder")
local inputs, errors = Inputs.fromSelection({ source, animation, wrong })
check(#inputs == 2 and #errors == 1, "Mixed selection accepts both input types")
local results, failures = Batch.convert(inputs, convert, {}, function() end, function()
	return false
end)
check(#results == 2 and #failures == 0, "Convert local selection and real online Animation ID")
check(results[2].output:GetAttribute("SourceAnimationId") == animation.AnimationId, "Record source ID")
history:SetWaypoint("Retargeter test setup")
local folder = Batch.insert(results)
check(folder.Parent == game.ServerStorage and #folder:GetChildren() == 2, "Insert all outputs into ServerStorage")
check(#Selection:Get() == 2, "Select inserted results")
check(history:GetCanUndo(), "Conversion creates an undo record")
history:Undo()
task.wait()
check(folder.Parent == nil, "Undo removes the whole conversion batch")
check(source.Parent == game.ServerStorage, "Undo preserves source")
history:Redo()
task.wait()
check(folder.Parent == game.ServerStorage and #folder:GetChildren() == 2, "Redo restores the batch")
for _, result in results do
	result.source:Destroy()
end
folder:Destroy()
local repeated, repeatErrors = Batch.convert({ inputs[2] }, convert, {}, function() end, function()
	return false
end)
check(#repeated == 1 and #repeatErrors == 0, "Online clips survive cleanup and can be loaded again")
for _, result in repeated do
	result.source:Destroy()
	result.output:Destroy()
end

local curve = Instance.new("CurveAnimation")
local unarchivable = sequence()
unarchivable.Archivable = false
local mixed, mixedErrors = Batch.convert(
	{
		{ name = "Curve", sequence = curve },
		{ name = "Unarchivable", sequence = unarchivable },
		{ name = source.Name, sequence = source },
	},
	convert,
	{},
	function() end,
	function()
		return false
	end
)
check(#mixed == 1 and #mixedErrors == 2, "One failure does not abort the remaining batch")
for _, result in mixed do
	result.source:Destroy()
	result.output:Destroy()
end
local cancelled = Batch.convert(inputs, convert, {}, function() end, function()
	return true
end)
check(#cancelled == 0, "Cancellation prevents conversion")
for _, item in { source, output, held, animation, wrong, curve, unarchivable, bundle } do
	item:Destroy()
end
print(
	`PASS: {checks} assertions; fixtures, metadata, both options, all inputs, online fetch, mixed failures, undo/redo`
)
