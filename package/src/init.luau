--[[
    Precision R15 to R6 Retargeting (Full Root Correction)
    -------------------------------------------------------
    Uses exact joint definitions (C0/C1) to mathematically map
    R15 motion to R6 axes for BOTH Limbs and Torso.
]]

-- =================================================================================
-- 1. DATA DEFINITIONS (Using your provided values)
-- =================================================================================

-- Calibrated from the actual R15 rig's AnimationConstraint attachments (Att0 =
-- C0 in parent-part space, Att1 = C1 in child-part space). All rotations are
-- identity, so these are pure translations; only positions matter to the chain
-- forward-kinematics (orientation deltas are rotation-only and frame-agnostic).
-- Measured values reproduce the real rig's hand/foot positions, eliminating the
-- idealized-data drift that read "too far out / too low" on crossed poses.
local R15_DATA = {
	["LowerTorso"] = { C0 = CFrame.new(0, -1, 0), C1 = CFrame.new(0, -0.2, 0) },
	["UpperTorso"] = { C0 = CFrame.new(0, 0.2, 0), C1 = CFrame.new(0, -0.8, 0) },
	["LeftUpperArm"] = { C0 = CFrame.new(-1, 0.563, 0), C1 = CFrame.new(0.5, 0.3943, 0) },
	["LeftLowerArm"] = { C0 = CFrame.new(0, -0.3341, 0), C1 = CFrame.new(0, 0.2587, 0) },
	["LeftHand"] = { C0 = CFrame.new(0, -0.5009, 0), C1 = CFrame.new(0, 0.125, 0) },
	["RightUpperArm"] = { C0 = CFrame.new(1, 0.563, 0), C1 = CFrame.new(-0.5, 0.3943, 0) },
	["RightLowerArm"] = { C0 = CFrame.new(0, -0.3342, 0), C1 = CFrame.new(0, 0.2586, 0) },
	["RightHand"] = { C0 = CFrame.new(0, -0.5009, 0), C1 = CFrame.new(0, 0.125, 0) },
	["LeftUpperLeg"] = { C0 = CFrame.new(-0.5, -0.2, 0), C1 = CFrame.new(0, 0.4208, 0) },
	["LeftLowerLeg"] = { C0 = CFrame.new(0, -0.4011, 0), C1 = CFrame.new(0, 0.379, 0) },
	["LeftFoot"] = { C0 = CFrame.new(0, -0.5472, 0), C1 = CFrame.new(0, 0.1019, 0) },
	["RightUpperLeg"] = { C0 = CFrame.new(0.5, -0.2, 0), C1 = CFrame.new(0, 0.4208, 0) },
	["RightLowerLeg"] = { C0 = CFrame.new(0, -0.4009, 0), C1 = CFrame.new(0, 0.3792, 0) },
	["RightFoot"] = { C0 = CFrame.new(0, -0.5472, 0), C1 = CFrame.new(0, 0.1019, 0) },
	["Head"] = { C0 = CFrame.new(0, 0.8, 0), C1 = CFrame.new(0, -0.586, 0) },
}

local R6_DATA = {
	["Torso"] = { C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	["Left Arm"] = { C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	["Right Arm"] = { C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Left Leg"] = { C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	["Right Leg"] = { C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	["Head"] = { C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
}

-- =================================================================================

local R15_MARKERS = {
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local LIMB_CHAINS = {
	["Left Arm"] = { upper = "LeftUpperArm", lower = "LeftLowerArm", terminal = "LeftHand" },
	["Right Arm"] = { upper = "RightUpperArm", lower = "RightLowerArm", terminal = "RightHand" },
	["Left Leg"] = { upper = "LeftUpperLeg", lower = "LeftLowerLeg", terminal = "LeftFoot", isLeg = true },
	["Right Leg"] = { upper = "RightUpperLeg", lower = "RightLowerLeg", terminal = "RightFoot", isLeg = true },
}

local EPSILON = 1e-5

-- Cache for math corrections
local CORRECTION_CACHE = {}

-- Calculates the "Adapter" matrix that converts R15 joint space to R6 joint space
local function calculateCorrections()
	-- 1. Helper to calculate Pre/Post for a single joint pair
	local function cacheJoint(r6Name, r6Data, r15Data)
		if not r6Data or not r15Data then
			return
		end

		local c0_r15 = r15Data.C0.Rotation
		local c1_r15 = r15Data.C1.Rotation
		local c0_r6 = r6Data.C0.Rotation
		local c1_r6 = r6Data.C1.Rotation

		-- The Matrix Formula: C0_R6^-1 * C0_R15 * ANIM * C1_R15^-1 * C1_R6
		local pre = c0_r6:Inverse() * c0_r15
		local post = c1_r15:Inverse() * c1_r6

		CORRECTION_CACHE[r6Name] = { Pre = pre, Post = post }
	end

	-- 2. Cache Limbs
	local map = {
		["Head"] = "Head",
		["Left Arm"] = "LeftUpperArm",
		["Right Arm"] = "RightUpperArm",
		["Left Leg"] = "LeftUpperLeg",
		["Right Leg"] = "RightUpperLeg",
	}

	for r6Name, r15Name in pairs(map) do
		cacheJoint(r6Name, R6_DATA[r6Name], R15_DATA[r15Name])
	end

	-- 3. Cache Torso (Crucial Fix!)
	-- We map R15 LowerTorso (Root) to R6 Torso (Root)
	cacheJoint("Torso", R6_DATA["Torso"], R15_DATA["LowerTorso"])
end

calculateCorrections() -- Initialize on load

local function buildPoseLookup(keyframe)
	local lookup = {}
	local function collectPoses(pose)
		lookup[pose.Name] = pose
		for _, child in pairs(pose:GetSubPoses()) do
			collectPoses(child)
		end
	end
	for _, pose in pairs(keyframe:GetPoses()) do
		collectPoses(pose)
	end
	return lookup
end

local function makePoseSample(time, cframe, weight, easingStyle, easingDirection)
	return {
		Time = time,
		CFrame = cframe,
		Weight = weight,
		EasingStyle = easingStyle,
		EasingDirection = easingDirection,
	}
end

local function easeAlpha(alpha, easingStyle, easingDirection)
	alpha = math.clamp(alpha, 0, 1)

	if easingStyle == Enum.PoseEasingStyle.Constant then
		return 0
	end

	if easingStyle == Enum.PoseEasingStyle.Cubic then
		if easingDirection == Enum.PoseEasingDirection.In then
			return alpha ^ 3
		elseif easingDirection == Enum.PoseEasingDirection.InOut then
			if alpha < 0.5 then
				return 4 * (alpha ^ 3)
			end
			return 1 - ((-2 * alpha + 2) ^ 3) * 0.5
		end
		return 1 - ((1 - alpha) ^ 3)
	end

	return alpha
end

local function insertPoseSample(samples, sample)
	for index, existing in ipairs(samples) do
		if math.abs(existing.Time - sample.Time) < EPSILON then
			samples[index] = sample
			return
		elseif sample.Time < existing.Time then
			table.insert(samples, index, sample)
			return
		end
	end

	table.insert(samples, sample)
end

local function buildPoseTracks(keyframes)
	local firstTime = if keyframes[1] then keyframes[1].Time else 0
	local tracks = {}

	for name in pairs(R15_DATA) do
		tracks[name] = {
			Authored = false,
			Samples = {
				makePoseSample(firstTime, CFrame.identity, 1, Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.Out),
			},
		}
	end

	for _, keyframe in ipairs(keyframes) do
		local lookup = buildPoseLookup(keyframe)
		for name, pose in pairs(lookup) do
			local track = tracks[name]
			if track and pose.Weight > 0 then
				track.Authored = true
				insertPoseSample(track.Samples, makePoseSample(keyframe.Time, pose.CFrame, pose.Weight, pose.EasingStyle, pose.EasingDirection))
			end
		end
	end

	return tracks
end

local function hasAuthoredPose(tracks, name)
	local track = tracks[name]
	return track and track.Authored == true
end

local function samplePoseAtTime(tracks, name, time)
	local track = tracks[name]
	if not track then
		return nil
	end

	local samples = track.Samples
	if #samples == 0 then
		return nil
	end

	if time <= samples[1].Time + EPSILON then
		return samples[1]
	end

	for index = 1, #samples - 1 do
		local left = samples[index]
		local right = samples[index + 1]

		if time <= right.Time + EPSILON then
			local duration = right.Time - left.Time
			if duration < EPSILON then
				return right
			end

			local alpha = easeAlpha((time - left.Time) / duration, left.EasingStyle, left.EasingDirection)
			return makePoseSample(
				time,
				left.CFrame:Lerp(right.CFrame, alpha),
				math.lerp(left.Weight, right.Weight, alpha),
				left.EasingStyle,
				left.EasingDirection
			)
		end
	end

	return samples[#samples]
end

local function getChainNames(chain)
	return { chain.upper, chain.lower, chain.terminal }
end

local function getMaxSampleWeight(tracks, names, time)
	local weight = 0
	for _, name in ipairs(names) do
		if hasAuthoredPose(tracks, name) then
			local sample = samplePoseAtTime(tracks, name, time)
			if sample then
				weight = math.max(weight, sample.Weight)
			end
		end
	end
	return weight
end

local function getSampleEaseSource(tracks, names, time)
	for _, name in ipairs(names) do
		if hasAuthoredPose(tracks, name) then
			local sample = samplePoseAtTime(tracks, name, time)
			if sample then
				return sample
			end
		end
	end
	return nil
end

local function composeChainPartCFrame(names, getCF)
	local partCFrame = CFrame.identity
	for _, name in ipairs(names) do
		local data = R15_DATA[name]
		partCFrame = partCFrame * data.C0 * getCF(name) * data.C1:Inverse()
	end
	return partCFrame
end

local function composeRestChainPartCFrame(names)
	local partCFrame = CFrame.identity
	for _, name in ipairs(names) do
		local data = R15_DATA[name]
		partCFrame = partCFrame * data.C0 * data.C1:Inverse()
	end
	return partCFrame
end

local function applyCorrection(r6Name, animatedCF)
	local correction = CORRECTION_CACHE[r6Name]
	if correction then
		return correction.Pre * animatedCF * correction.Post
	end
	return animatedCF
end

-- Solve the joint Transform that places the limb at a desired part CFrame
-- (rotation + position) in the joint's parent frame:
--   partCF = C0 * Transform * C1:Inverse()  ⇒  Transform = C0⁻¹ * partCF * C1
local function solveJointTransform(jointData, desiredPartCFrame)
	return jointData.C0:Inverse() * desiredPartCFrame * jointData.C1
end

-- The R6 limb parts are all 1×2×1 with their long axis on local Y and rest
-- rotation identity, so the foot/hand end of the limb sits one stud below the
-- part centre in part-local space. Forcing this point onto the R15 terminal
-- position plants the R6 limb's tip where R15's hand/foot lands.
local LIMB_TIP_LOCAL = Vector3.new(0, -1, 0)

-- The R15 hand/foot parts are 1×0.3×1, so their actual end (sole / fingertip)
-- sits 0.15 below the part centre along the part's local -Y. We match that end
-- to the R6 limb's bottom tip; using the centre would read 0.15 too high, and
-- since the offset rotates with the hand/foot it also skews the displacement
-- whenever the terminal rotates.
local TERMINAL_TIP_LOCAL = CFrame.new(0, -0.15, 0)

-- Full R15 joint chains from the HumanoidRootPart out to each limb, used to
-- evaluate limb pose in HRP/world space rather than relative to the limb's
-- parent. This is what makes the collapse correct when the torso bends: R15
-- bends at two torso joints (Root→LowerTorso, Waist→UpperTorso) and the arms
-- hang off UpperTorso, whereas R6 has a single Torso. Evaluating in world space
-- and converting into the R6 Torso part frame reconciles that structural gap
-- (and, since legs chain only through LowerTorso, drops the waist swing from
-- them automatically — no separate leg cancel needed).
local FULL_CHAIN_CACHE = {}
local function fullChains(chain)
	local cached = FULL_CHAIN_CACHE[chain]
	if not cached then
		local function chainFrom(prefix, parts)
			local names = table.clone(prefix)
			for _, name in ipairs(parts) do
				table.insert(names, name)
			end
			return names
		end
		-- Arms hang off UpperTorso; legs off LowerTorso.
		local prefix = if chain.isLeg then { "LowerTorso" } else { "LowerTorso", "UpperTorso" }
		cached = {
			orientation = chainFrom(prefix, { chain.upper, chain.lower }),
			terminal = chainFrom(prefix, { chain.upper, chain.lower, chain.terminal }),
		}
		FULL_CHAIN_CACHE[chain] = cached
	end
	return cached
end

-- Collapse an R15 limb chain onto the rigid R6 limb in two parts, both evaluated
-- in HRP/world space then brought into the R6 Torso part frame (r6TorsoPartCF):
--   • orientation — align to the R15 lower segment (forearm / shin) by
--     transferring its world rest→pose rotation *delta* onto the R6 limb's rest.
--     The lower segment is the dominant visual cue ("where the arm points"); a
--     rotation delta is singularity-free for folded / overhead / crossed poses,
--     and degrades to the upper segment when the elbow is straight.
--   • position — move the R6 limb's tip by the R15 terminal tip's (sole /
--     fingertip) world displacement from its own rest. The R6 joint stretches
--     from its socket to reach, so the extremity tracks where R15 puts it. A
--     displacement (not an absolute target) keeps rest exactly natural.
local function buildCollapsedLimbCFrame(r6Name, tracks, time, chain, r6TorsoPartCF)
	local function posed(name)
		local sample = samplePoseAtTime(tracks, name, time)
		return if sample then sample.CFrame else CFrame.identity
	end

	local chains = fullChains(chain)
	local r6Data = R6_DATA[r6Name]
	local r6RestPartCF = r6Data.C0 * r6Data.C1:Inverse() -- R6 limb rest, in Torso part frame (= world at rest torso)

	-- Orientation: R15 lower-segment world rest→pose delta onto the R6 rest,
	-- then expressed in the (posed) R6 Torso part frame.
	local worldLowerPosed = composeChainPartCFrame(chains.orientation, posed).Rotation
	local worldLowerRest = composeRestChainPartCFrame(chains.orientation).Rotation
	local worldDelta = worldLowerPosed * worldLowerRest:Inverse()
	local desiredWorldRotation = worldDelta * r6RestPartCF.Rotation
	local desiredRotation = r6TorsoPartCF.Rotation:Inverse() * desiredWorldRotation

	-- Position: R15 terminal tip world displacement from rest, planted onto the
	-- R6 limb's rest tip, then expressed in the (posed) R6 Torso part frame.
	local posedTipWorld = (composeChainPartCFrame(chains.terminal, posed) * TERMINAL_TIP_LOCAL).Position
	local restTipWorld = (composeRestChainPartCFrame(chains.terminal) * TERMINAL_TIP_LOCAL).Position
	local displacement = posedTipWorld - restTipWorld
	local desiredTipWorld = r6RestPartCF:PointToWorldSpace(LIMB_TIP_LOCAL) + displacement
	local desiredTip = r6TorsoPartCF:PointToObjectSpace(desiredTipWorld)

	local position = desiredTip - desiredRotation * LIMB_TIP_LOCAL
	local desiredPartCFrame = CFrame.fromMatrix(position, desiredRotation.XVector, desiredRotation.YVector, desiredRotation.ZVector)

	return solveJointTransform(r6Data, desiredPartCFrame)
end

local function isR15Animation(keyframeSequence)
	local keyframes = keyframeSequence:GetKeyframes()
	if #keyframes == 0 then
		return false
	end

	for _, keyframe in ipairs(keyframes) do
		local lookup = buildPoseLookup(keyframe)
		for _, marker in pairs(R15_MARKERS) do
			if lookup[marker] then
				return true
			end
		end
	end
	return false
end

local function createR6Poses(keyframe, lookup, tracks, counterWaistSwingOnLegs)
	-- Clear existing poses
	for _, pose in pairs(keyframe:GetPoses()) do
		pose:Destroy()
	end
	local time = keyframe.Time

	-- 1. ROOT (HumanoidRootPart)
	local rootPose = Instance.new("Pose")
	rootPose.Name = "HumanoidRootPart"
	rootPose.Weight = 1
	local rootSource = lookup["HumanoidRootPart"]
	if rootSource then
		rootPose.CFrame = rootSource.CFrame
		rootPose.Weight = rootSource.Weight
		rootPose.EasingStyle = rootSource.EasingStyle
		rootPose.EasingDirection = rootSource.EasingDirection
	end

	-- 2. TORSO (Composite + Correction)
	local torsoPose = Instance.new("Pose")
	torsoPose.Name = "Torso"
	local lowerTorso = samplePoseAtTime(tracks, "LowerTorso", time)
	local upperTorso = samplePoseAtTime(tracks, "UpperTorso", time)
	local lowerAuthored = hasAuthoredPose(tracks, "LowerTorso")
	local upperAuthored = hasAuthoredPose(tracks, "UpperTorso")

	-- The R6 Torso is a composite of two independently-weighted R15 joints
	-- (LowerTorso = root bend, UpperTorso = waist swing). Compose only the
	-- active components and weight by the max:
	--   - both weight-0 (inert facial/finger-only frames) → identity, weight 0
	--     (avoids the every-other-frame snap-to-rest "spaz")
	--   - swing driven by UpperTorso alone (e.g. grenade throw) with LowerTorso
	--     left weight-0 → still included, so the swing isn't dropped
	local lowerWeight = if lowerAuthored and lowerTorso then lowerTorso.Weight else 0
	local upperWeight = if upperAuthored and upperTorso then upperTorso.Weight else 0

	local lowerCF = if lowerWeight > 0 then lowerTorso.CFrame else CFrame.identity
	local upperCF = if upperWeight > 0 then upperTorso.CFrame else CFrame.identity
	local combinedTorso = lowerCF * upperCF

	-- Apply the FULL correction matrix to the Torso (Root Joint)
	local torsoCorrect = CORRECTION_CACHE["Torso"]
	if torsoCorrect then
		combinedTorso = torsoCorrect.Pre * combinedTorso * torsoCorrect.Post
	end

	local easeSource = (lowerWeight > 0 and lowerTorso) or (upperWeight > 0 and upperTorso) or nil

	-- Position the single R6 Torso in world (rel HRP) by tracking the R15
	-- UpperTorso (chest) centre's displacement from rest. R15 bends at two torso
	-- joints, so its chest leads forward/down — carrying the head and shoulders —
	-- whereas an R6 Torso left to just rotate about the root sits too far back and
	-- high (e.g. crawling). Orientation stays the composited rotation; only the
	-- position is world-anchored, and rest stays natural (zero displacement).
	-- Limbs re-plant off this moved torso automatically, so they stay correct.
	local torsoC0 = R6_DATA["Torso"].C0
	local torsoC1 = R6_DATA["Torso"].C1
	local function sampleCF(name)
		local sample = samplePoseAtTime(tracks, name, time)
		return if sample then sample.CFrame else CFrame.identity
	end
	local chestChain = { "LowerTorso", "UpperTorso" }
	local chestDisplacement = composeChainPartCFrame(chestChain, sampleCF).Position
		- composeRestChainPartCFrame(chestChain).Position
	local rotatedTorsoPartCF = torsoC0 * combinedTorso * torsoC1:Inverse()
	local restTorsoPartCF = torsoC0 * torsoC1:Inverse()
	local r6TorsoPartCF = CFrame.fromMatrix(
		restTorsoPartCF.Position + chestDisplacement,
		rotatedTorsoPartCF.XVector,
		rotatedTorsoPartCF.YVector,
		rotatedTorsoPartCF.ZVector
	)

	torsoPose.CFrame = torsoC0:Inverse() * r6TorsoPartCF * torsoC1
	torsoPose.Weight = math.max(lowerWeight, upperWeight)
	torsoPose.EasingStyle = if easeSource then easeSource.EasingStyle else Enum.PoseEasingStyle.Linear
	torsoPose.EasingDirection = if easeSource then easeSource.EasingDirection else Enum.PoseEasingDirection.Out
	torsoPose.Parent = rootPose

	-- 3. HEAD
	local function addSimplePose(r6Name, r15Name)
		if not hasAuthoredPose(tracks, r15Name) then
			return
		end

		local source = samplePoseAtTime(tracks, r15Name, time)
		if not source then
			return
		end

		local newPose = Instance.new("Pose")
		newPose.Name = r6Name
		newPose.Weight = source.Weight
		newPose.EasingStyle = source.EasingStyle
		newPose.EasingDirection = source.EasingDirection

		newPose.CFrame = applyCorrection(r6Name, source.CFrame.Rotation)

		newPose.Parent = torsoPose
	end

	-- 4. LIMBS
	-- Collapse each R15 limb chain into one R6 rigid limb. Each limb is evaluated
	-- in HRP/world space (via the full R15 chain through the torso joints) and
	-- brought into the R6 Torso's part frame (r6TorsoPartCF, computed above), so
	-- the single-R6-torso vs two-R15-torso structure is reconciled even when the
	-- body bends (e.g. crawl).
	local function addCollapsedLimb(r6Name, chain)
		local chainNames = getChainNames(chain)
		local weight = getMaxSampleWeight(tracks, chainNames, time)

		-- A leg hangs off LowerTorso in R15 and never sees the waist swing, but the
		-- R6 Torso (its parent) folds that swing in. With counterWaistSwingOnLegs,
		-- emit the leg pose whenever the waist is active even if the leg itself
		-- isn't animated, so it holds position instead of riding the swing
		-- (buildCollapsedLimbCFrame produces the counter from zero displacement +
		-- the swung torso). The pose must carry the swing's weight to apply.
		local easeSource = getSampleEaseSource(tracks, chainNames, time)
		if chain.isLeg and counterWaistSwingOnLegs and upperWeight > weight then
			weight = upperWeight
			easeSource = easeSource or upperTorso
		end

		if weight <= 0 then
			return
		end

		local poseCFrame = buildCollapsedLimbCFrame(r6Name, tracks, time, chain, r6TorsoPartCF)

		local newPose = Instance.new("Pose")
		newPose.Name = r6Name
		newPose.Weight = weight
		newPose.EasingStyle = if easeSource then easeSource.EasingStyle else Enum.PoseEasingStyle.Linear
		newPose.EasingDirection = if easeSource then easeSource.EasingDirection else Enum.PoseEasingDirection.Out
		newPose.CFrame = poseCFrame
		newPose.Parent = torsoPose
	end

	addSimplePose("Head", "Head")
	addCollapsedLimb("Left Arm", LIMB_CHAINS["Left Arm"])
	addCollapsedLimb("Right Arm", LIMB_CHAINS["Right Arm"])
	addCollapsedLimb("Left Leg", LIMB_CHAINS["Left Leg"])
	addCollapsedLimb("Right Leg", LIMB_CHAINS["Right Leg"])

	rootPose.Parent = keyframe
end

-- options:
--   counterWaistSwingOnLegs (default false) — hold an unanimated leg in place
--     when the torso's waist swing is active, instead of letting it ride the
--     R6 Torso's combined swing (R15 legs hang off LowerTorso and never see it).
local function retargetR15ToR6(keyframeSequence, options)
	if not isR15Animation(keyframeSequence) then
		return nil
	end

	local counterWaistSwingOnLegs = options ~= nil and options.counterWaistSwingOnLegs == true

	local result = keyframeSequence:Clone()
	result.Name = result.Name .. "_Precise"

	local keyframes = result:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)

	local tracks = buildPoseTracks(keyframes)
	for _, keyframe in keyframes do
		local lookup = buildPoseLookup(keyframe)
		createR6Poses(keyframe, lookup, tracks, counterWaistSwingOnLegs)
	end

	return result
end

return retargetR15ToR6
