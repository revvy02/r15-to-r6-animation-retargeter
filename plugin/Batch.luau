local AnimationClipProvider = game:GetService("AnimationClipProvider")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Batch = {}

function Batch.convert(inputs, convert, options, progress, cancelled)
	local results, errors = {}, {}
	for index, input in inputs do
		if cancelled() then
			break
		end
		progress(index, #inputs, input.name)
		local source, output
		local ok, err = pcall(function()
			-- The provider may return a cached clip. Own a clone so cleanup cannot
			-- destroy the provider's source and break subsequent conversions.
			source = (if input.sequence then input.sequence else AnimationClipProvider:GetAnimationClipAsync(input.id)):Clone()
			if not source then
				error("The selected sequence must be Archivable", 0)
			end
			if not source:IsA("KeyframeSequence") then
				error("CurveAnimation is not supported; use a KeyframeSequence", 0)
			end
			output = convert(source, options)
			if not output then
				error("No R15 body poses found (empty or non-R15 animation)", 0)
			end
			output.Name = input.name .. "_R6"
			if input.id then
				output:SetAttribute("SourceAnimationId", input.id)
			end
		end)
		if ok then
			table.insert(results, { name = input.name, source = source, output = output })
		else
			if source then
				source:Destroy()
			end
			if output then
				output:Destroy()
			end
			table.insert(errors, `{input.name}: {tostring(err)}`)
		end
	end
	return results, errors
end

function Batch.insert(results)
	assert(#results > 0, "No converted sequences to insert")
	-- All yielding work is complete before recording mutations to the place.
	local recording = ChangeHistoryService:TryBeginRecording("R15ToR6.Convert", "Convert R15 animations to R6")
	assert(recording, "Cannot record undo right now. Stop play mode or finish the active Studio operation, then retry.")
	local folder = Instance.new("Folder")
	folder.Name = "RetargetedR6"
	local outputs = {}
	local ok, err = pcall(function()
		folder.Parent = game:GetService("ServerStorage")
		for _, result in results do
			result.output.Parent = folder
			table.insert(outputs, result.output)
		end
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
	if not ok then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		folder:Destroy()
		error(err, 0)
	end
	Selection:Set(outputs)
	return folder
end

return Batch
