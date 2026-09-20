local AnimationClipProvider = game:GetService("AnimationClipProvider")
local RunService = game:GetService("RunService")

return function(viewports, templates)
	local worlds, cameras, animators, tracks = {}, {}, {}, {}
	local restBounds, layoutConnections = {}, {}
	local paused = false
	local alive = true
	local function frame()
		local distance = 0
		for i, bounds in restBounds do
			local viewportSize = viewports[i].AbsoluteSize
			-- Layout can be zero-sized before the dock opens; its size signal retries.
			if viewportSize.X == 0 or viewportSize.Y == 0 then
				return
			end
			local tanHalfFov = math.tan(math.rad(cameras[i].FieldOfView / 2))
			local aspect = viewportSize.X / viewportSize.Y
			local fit = math.max(bounds.size.Y / 2 / tanHalfFov, bounds.size.X / 2 / (tanHalfFov * aspect))
			distance = math.max(distance, fit * 1.25 + bounds.size.Z / 2)
		end
		for i, bounds in restBounds do
			-- Frame each rig's body centre with one shared scale and motion margin.
			-- The stable rest centre avoids camera bobbing as the animation plays.
			cameras[i].CFrame = CFrame.lookAt(bounds.center + Vector3.new(0, 0, -distance), bounds.center)
		end
	end
	for _, viewport in viewports do
		table.insert(layoutConnections, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame))
	end
	local function clear()
		for _, track in tracks do
			track:Stop(0)
			track:Destroy()
		end
		for _, world in worlds do
			world:Destroy()
		end
		for _, camera in cameras do
			camera:Destroy()
		end
		table.clear(tracks)
		table.clear(animators)
		table.clear(worlds)
		table.clear(cameras)
		table.clear(restBounds)
	end
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if paused then
			return
		end
		for _, animator in animators do
			animator:StepAnimations(dt)
		end
	end)
	local function show(source, converted)
		clear()
		paused = false
		local ok, err = pcall(function()
			for i, name in { "R15", "R6" } do
				local world = Instance.new("WorldModel")
				world.Parent = viewports[i]
				table.insert(worlds, world)
				local rig = templates[name]:Clone()
				for _, item in rig:GetDescendants() do
					if item:IsA("BaseScript") then
						item:Destroy()
					elseif item:IsA("BasePart") then
						item.Anchored = item.Name == "HumanoidRootPart"
					end
				end
				rig:PivotTo(CFrame.identity)
				rig.Parent = world
				local controller = rig:FindFirstChildOfClass("Humanoid")
					or rig:FindFirstChildOfClass("AnimationController")
				-- Both bundled fixtures contain their animation controller.
				local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
				local camera = Instance.new("Camera")
				camera.FieldOfView = 40
				local bounds, size = rig:GetBoundingBox()
				table.insert(restBounds, { center = bounds.Position, size = size })
				camera.Parent = viewports[i]
				viewports[i].CurrentCamera = camera
				table.insert(cameras, camera)
				if source then
					local animation = Instance.new("Animation")
					animation.AnimationId =
						AnimationClipProvider:RegisterAnimationClip(if i == 1 then source else converted)
					local loaded, track = pcall(animator.LoadAnimation, animator, animation)
					animation:Destroy()
					assert(loaded, track)
					if not alive then
						track:Destroy()
						return
					end
					track.Looped = true
					table.insert(tracks, track)
					table.insert(animators, animator)
				end
			end
			frame()
			for _, track in tracks do
				track:Play(0)
			end
		end)
		if not ok then
			clear()
		end
		return ok, err
	end
	return {
		show = show,
		pause = function(value)
			paused = value
		end,
		seek = function(time)
			for i, track in tracks do
				track.TimePosition = time
				animators[i]:StepAnimations(0)
			end
		end,
		destroy = function()
			alive = false
			heartbeat:Disconnect()
			for _, connection in layoutConnections do
				connection:Disconnect()
			end
			clear()
		end,
	}
end
