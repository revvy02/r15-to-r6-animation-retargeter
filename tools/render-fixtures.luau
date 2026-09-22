-- Deterministic frame capture in an isolated Studio; driven by videos.py.
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")
local process = require("@rodeo/process")
local roblox = require("@rodeo/roblox")
local convert = require("../package/src")
local RunService = game:GetService("RunService")
local AnimationClipProvider = game:GetService("AnimationClipProvider")
local configPath = assert(process.args[1], "Expected capture configuration")
local handle = fs.open(configPath)
local config = game:GetService("HttpService"):JSONDecode(stream.read(handle))
stream.close(handle)

local lighting = game:GetService("Lighting")
lighting:ClearAllChildren()
lighting.Ambient = Color3.fromRGB(180, 185, 200)
lighting.OutdoorAmbient = lighting.Ambient
lighting.Brightness = 1.5
lighting.ClockTime = 14
lighting.GlobalShadows = false
lighting.EnvironmentDiffuseScale = 0
lighting.EnvironmentSpecularScale = 0
settings().Rendering.QualityLevel = Enum.QualityLevel.Level21
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
local backdrop = Instance.new("Part")
backdrop.Name = "CaptureBackdrop"
backdrop.Anchored = true
backdrop.Size = Vector3.new(200, 200, 1)
backdrop.CFrame = CFrame.new(0, 30, 30)
backdrop.Color = Color3.fromRGB(26, 30, 38)
backdrop.Material = Enum.Material.SmoothPlastic
backdrop.Parent = workspace
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 35

local function prepareRig(name, x, sequence)
	local rig = roblox.import(`assets/{name}.rbxm`)[1]
	for _, item in rig:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
		end
	end
	rig:PivotTo(CFrame.new(x, 0, 0))
	rig.Parent = workspace
	local controller = rig:FindFirstChildOfClass("Humanoid") or rig:FindFirstChildOfClass("AnimationController")
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	local animation = Instance.new("Animation")
	animation.AnimationId = AnimationClipProvider:RegisterAnimationClip(sequence)
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	track.Looped = true
	track:Play(0, 1, 0)
	return { rig = rig, animator = animator, track = track }
end

local results = {}
for _, fixture in config.fixtures do
	local source = roblox.import(fixture.path)[1]
	assert(source:IsA("KeyframeSequence"), `Fixture {fixture.name} must contain a KeyframeSequence`)
	local converted = convert(source, { counterWaistSwingOnLegs = config.counterWaist })
	if not converted then
		table.insert(results, { name = fixture.name, skipped = "No R15 body poses (negative fixture)" })
		source:Destroy()
		print(`SKIP {fixture.name}: not an R15 fixture`)
		continue
	end
	local length = 0
	for _, keyframe in source:GetKeyframes() do
		length = math.max(length, keyframe.Time)
	end
	assert(length > 0, `Fixture {fixture.name} has no animation duration`)
	local count = math.ceil(math.max(config.seconds, length * config.cycles) * config.fps)
	-- This front-facing camera looks along +Z, so positive X is screen-left.
	local rigs = { prepareRig("r15", 3.8, source), prepareRig("r6", -3.8, converted) }
	local function pose(time)
		for _, entry in rigs do
			entry.track.TimePosition = time
			entry.animator:StepAnimations(0)
		end
		-- Joint transforms are applied by the render pipeline after StepAnimations.
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
	end
	pose(0)
	task.wait(0.2)
	for _, entry in rigs do
		assert(entry.track.Length > 0, `Failed to load {fixture.name}`)
	end

	-- Sample the complete recorded motion before fixing the camera. A rest-pose
	-- bound cannot guarantee that raised arms, root motion, or jumps fit later.
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	print(`FRAMING {fixture.name}: sampling {count} poses`)
	for index = 0, count - 1 do
		pose((index / config.fps) % length)
		for _, entry in rigs do
			local bounds, size = entry.rig:GetBoundingBox()
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = bounds:PointToWorldSpace(size * Vector3.new(x, y, z) / 2)
						low = low:Min(point)
						high = high:Max(point)
					end
				end
			end
		end
	end
	local center = (low + high) / 2
	-- Keep the two lanes symmetric even if a pose extends further on one rig.
	center = Vector3.new(0, center.Y, center.Z)
	local halfWidth = math.max(math.abs(low.X), math.abs(high.X))
	local tanHalfFov = math.tan(math.rad(camera.FieldOfView / 2))
	local aspect = math.min(16 / 9, camera.ViewportSize.X / camera.ViewportSize.Y)
	local distance = math.max((high.Y - low.Y) / 2 / tanHalfFov, halfWidth / (tanHalfFov * aspect)) * 1.3
		+ (high.Z - low.Z) / 2
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, -distance), center)
	local cameraFrame = camera.CFrame
	local viewportSize = camera.ViewportSize
	local directory = `{config.frames}/{fixture.name}`
	fs.mkdir(directory)
	print(`CAPTURE {fixture.name}: {count} frames at {config.fps} fps; clip {length}s`)
	for index = 0, count - 1 do
		pose((index / config.fps) % length)
		assert(camera.ViewportSize == viewportSize, "Viewport resized during capture; rerun for consistent frames")
		roblox.capture(
			`{directory}/{string.format("%05d", index)}.png`,
			{ cframe = cameraFrame, fov = camera.FieldOfView, settle = 0 }
		)
		if index % config.fps == 0 then
			print(`FRAME {fixture.name} {index + 1}/{count}`)
		end
	end
	table.insert(results, {
		name = fixture.name,
		clipSeconds = length,
		frames = count,
		fps = config.fps,
		seconds = count / config.fps,
		sourceLooped = source.Loop,
		camera = { cameraFrame:GetComponents() },
		fov = camera.FieldOfView,
		viewport = { viewportSize.X, viewportSize.Y },
	})
	for _, entry in rigs do
		entry.track:Destroy()
		entry.rig:Destroy()
	end
	source:Destroy()
	converted:Destroy()
end
return results
