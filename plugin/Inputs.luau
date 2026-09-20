-- Input handling belongs to Studio; the package only accepts sequences.
local Inputs = {}

function Inputs.assetId(value: string): string?
	local value = value:match("^%s*(.-)%s*$") :: string
	local digits = value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
	if not digits then
		local host, path = value:match("^https?://([^/]+)(/.*)$")
		if host == "roblox.com" or host == "www.roblox.com" or host == "create.roblox.com" then
			digits = path:match("[?&]id=(%d+)")
				or path:match("^/library/(%d+)")
				or path:match("^/catalog/(%d+)")
				or path:match("^/store/asset/(%d+)")
		end
	end
	if not digits or not digits:find("[1-9]") then
		return nil
	end
	-- Keep IDs as strings to avoid rounding large integers.
	return "rbxassetid://" .. (digits:gsub("^0+", ""))
end

function Inputs.fromText(text: string)
	local inputs, errors, seen = {}, {}, {}
	for token in text:gmatch("[^%s,;]+") do
		local id = Inputs.assetId(token)
		if not id then
			table.insert(errors, `Invalid animation ID: {token}`)
		elseif not seen[id] then
			seen[id] = true
			table.insert(inputs, { name = id:sub(14), id = id })
		end
	end
	return inputs, errors
end

function Inputs.fromSelection(selection: { Instance })
	local inputs, errors = {}, {}
	for _, instance in selection do
		if instance:IsA("KeyframeSequence") then
			table.insert(inputs, { name = instance.Name, sequence = instance })
		elseif instance:IsA("Animation") then
			local id = Inputs.assetId(instance.AnimationId)
			if id then
				table.insert(inputs, { name = instance.Name, id = id })
			else
				table.insert(errors, `{instance.Name}: AnimationId is empty or invalid`)
			end
		else
			table.insert(errors, `{instance.Name}: select an Animation or KeyframeSequence`)
		end
	end
	return inputs, errors
end

return Inputs
