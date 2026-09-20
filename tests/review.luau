local roblox = require("@rodeo/roblox")
local process = require("@rodeo/process")
local bundle = roblox.import("out/R15ToR6Retargeter.rbxm")[1]
bundle.Parent = game:GetService("ReplicatedStorage")
local start = require(bundle.App)
local reviewPlugin = PluginManager():CreatePlugin()
local app = start(reviewPlugin, require(bundle.Retarget), bundle.Rigs)
app.widget.Enabled = true
local source = roblox.import("tests/fixtures/rbx_animate_walk.rbxm")[1]
source.Name = "Walk"
source.Parent = game:GetService("ServerStorage")
game:GetService("Selection"):Set({ source })
task.wait(0.2)
-- Regression: a floor-level model pivot must not be used as the camera target.
local function checkFraming()
	for _, viewport in app.view.viewports do
		local rig = viewport:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
		local bounds, size = rig:GetBoundingBox()
		local camera = viewport.CurrentCamera
		local center = camera.CFrame:PointToObjectSpace(bounds.Position)
		assert(math.abs(center.X) < 0.001 and math.abs(center.Y) < 0.001, "Preview body must be centered")
		local tanFov = math.tan(math.rad(camera.FieldOfView / 2))
		local aspect = viewport.AbsoluteSize.X / viewport.AbsoluteSize.Y
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = bounds:PointToWorldSpace(size * Vector3.new(x, y, z) / 2)
					local p = camera.CFrame:PointToObjectSpace(corner)
					assert(
						p.Z < 0 and math.abs(p.X) < -p.Z * tanFov * aspect and math.abs(p.Y) < -p.Z * tanFov,
						"Whole rig must fit inside the preview"
					)
				end
			end
		end
	end
end
checkFraming()
local sizes = {}
for i, viewport in app.view.viewports do
	sizes[i] = viewport.Size
	viewport.Size = UDim2.fromOffset(70, 168)
end
task.wait(0.2)
checkFraming()
for i, viewport in app.view.viewports do
	viewport.Size = sizes[i]
end
task.wait(0.2)
checkFraming()
local function checkpoint(name)
	print("REVIEW", name, app.view.status.Text)
	if process.args[1] == "--interactive" then
		workspace:SetAttribute("RetargetReviewStage", name)
		workspace:SetAttribute("RetargetReviewContinue", false)
		while not workspace:GetAttribute("RetargetReviewContinue") do
			task.wait(0.1)
		end
	end
end
checkpoint("ready")
app.convertSelection()
assert(app.view.status.Text:find("1 converted · 0 failed", 1, true), app.view.status.Text)
assert(not app.view.status.Text:find("unavailable", 1, true), app.view.status.Text)
task.wait(1)
app.preview.pause(true)
app.preview.seek(0.3)
app.view.pause.Text = "Play"
task.wait(0.2)
print("CONVERTED", app.view.status.Text)
if process.args[1] == "--interactive" then
	-- Reproduce the original framing with the same rigs, pose, light and size.
	local currentFrames = {}
	for i, viewport in app.view.viewports do
		currentFrames[i] = viewport.CurrentCamera.CFrame
		viewport.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, -12), Vector3.zero)
	end
	checkpoint("baseline-converted")
	for i, viewport in app.view.viewports do
		viewport.CurrentCamera.CFrame = currentFrames[i]
	end
end
checkpoint("converted")
app.view.ids.Text = "507777826, invalid"
app.convertIds()
assert(app.view.status.Text:find("1 converted · 1 failed", 1, true), app.view.status.Text)
app.preview.pause(true)
app.preview.seek(0.3)
app.view.pause.Text = "Play"
task.wait(0.2)
checkpoint("mixed")
print("PASS: plugin startup, selection conversion, ID conversion, partial failure, preview")
app.destroy()
reviewPlugin:Destroy()
source:Destroy()
bundle:Destroy()
