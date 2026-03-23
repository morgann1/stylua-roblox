--!strict

local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local StudioService = game:GetService("StudioService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

assert(plugin, "This code must run inside of a plugin")

if game:GetService("RunService"):IsRunning() then
	return
end

type ConfigEntry = { DefaultValue: string | number | boolean, Options: string }

local ConfigInfo: { [string]: ConfigEntry } = {
	column_width = {
		DefaultValue = 120,
		Options = "<number>",
	},
	line_endings = {
		DefaultValue = "Unix",
		Options = "Unix,Windows",
	},
	indent_type = {
		DefaultValue = "Tabs",
		Options = "Tabs,Spaces",
	},
	indent_width = {
		DefaultValue = 4,
		Options = "<number>",
	},
	quote_style = {
		DefaultValue = "AutoPreferDouble",
		Options = "AutoPreferDouble, AutoPreferSingle, ForceDouble, ForceSingle",
	},
	call_parentheses = {
		DefaultValue = "Always",
		Options = "Always, NoSingleString, NoSingleTable, None, Input",
	},
	collapse_simple_statement = {
		DefaultValue = "Never",
		Options = "Never, FunctionOnly, ConditionalOnly, Always",
	},
	space_after_function_names = {
		DefaultValue = "Never",
		Options = "Never, Definitions, Calls, Always",
	},
	block_newline_gaps = {
		DefaultValue = "Never",
		Options = "Never, Preserve",
	},
	sort_requires = {
		DefaultValue = false,
		Options = "<boolean>",
	},
}

local function wrap(Value)
	if type(Value) == "string" then
		return '"' .. Value .. '"'
	else
		return tostring(Value)
	end
end

local function generateSettings()
	local Settings = plugin:GetSetting("StyLuaSettings")
	local Output = "-- StyLua Configuration\nreturn {\n\n"
	for CName, CValue in Settings do
		Output = Output
			.. "\t"
			.. CName
			.. " = "
			.. wrap(CValue)
			.. ",	--| "
			.. ConfigInfo[CName].Options
			.. " | "
			.. "\n"
	end

	Output = Output .. "\n}"

	return Output
end

local function validateSettings(Module: LuaSourceContainer): { [string]: string | number | boolean }?
	local source = ScriptEditorService:GetEditorSource(Module)
	local Settings: { [string]: string | number | boolean } = {}

	for line in source:gmatch("[^\n]+") do
		local key, value = line:match("^%s*(%w+)%s*=%s*(.-)%s*,")
		if key and value and ConfigInfo[key] then
			local info = ConfigInfo[key]
			if value:match('^"(.*)"$') then
				local str = value:match('^"(.*)"$') :: string
				if type(info.DefaultValue) ~= "string" then
					return nil
				end
				local Options = string.split(info.Options:gsub("%s+", ""), ",")
				if not table.find(Options, str) then
					return nil
				end
				Settings[key] = str
			elseif value == "true" or value == "false" then
				if type(info.DefaultValue) ~= "boolean" then
					return nil
				end
				Settings[key] = value == "true"
			else
				local num = tonumber(value)
				if not num or type(info.DefaultValue) ~= "number" then
					return nil
				end
				Settings[key] = num
			end
		end
	end

	if next(Settings) == nil then
		return nil
	end
	return Settings
end

local SettingsModule: ModuleScript? = nil

local Connection: RBXScriptConnection?
local function applySettings()
	assert(SettingsModule, "Settings module not created")
	Connection = ScriptEditorService.TextDocumentDidChange:Connect(function()
		local NewSetting = validateSettings(SettingsModule :: ModuleScript)
		if NewSetting then
			plugin:SetSetting("StyLuaSettings", NewSetting)
		end
	end)
end

local function openSettings()
	if not SettingsModule then
		local existing = workspace:FindFirstChild("StyLua_Settings")
		if existing and existing:IsA("ModuleScript") then
			SettingsModule = existing
		else
			local Module = Instance.new("ModuleScript")
			Module.Name = "StyLua_Settings"
			Module.Archivable = false
			Module.Parent = workspace
			SettingsModule = Module
		end
	end

	if not plugin:GetSetting("StyLuaSettings") then
		local ConfigTable = {}
		for ConfigName, ConfigData in ConfigInfo do
			ConfigTable[ConfigName] = ConfigData.DefaultValue
		end
		plugin:SetSetting("StyLuaSettings", ConfigTable)
	end

	ScriptEditorService:UpdateSourceAsync(SettingsModule :: ModuleScript, function()
		return generateSettings()
	end)
	if Connection == nil then
		applySettings()
	end
	ScriptEditorService:OpenScriptDocumentAsync(SettingsModule :: ModuleScript)
end

local function fetchSettings()
	local Config = {}

	-- Place Only Settings
	local PlaceSetting = ServerStorage:FindFirstChild("StyLua")
	if PlaceSetting and PlaceSetting:IsA("LuaSourceContainer") then
		local PlaceConfig = validateSettings(PlaceSetting)
		if PlaceConfig then
			for setting, value in PlaceConfig :: any do
				if value ~= ConfigInfo[setting].DefaultValue then
					Config[setting] = value
				end
			end
		end
		return Config
	end

	-- Global Settings
	for setting, value in plugin:GetSetting("StyLuaSettings") do
		if value ~= ConfigInfo[setting].DefaultValue then
			Config[setting] = value
		end
	end
	return Config
end

local function formatter(script: LuaSourceContainer)
	local ConfigJSON = fetchSettings()

	local recordingId = ChangeHistoryService:TryBeginRecording("StyLua Format")

	local success, result = pcall(HttpService.RequestAsync, HttpService, {
		Method = "POST" :: "POST",
		Url = `http://localhost:18259/stylua?Config={HttpService:JSONEncode(ConfigJSON)}`,
		Headers = {
			["Content-Type"] = "text/plain",
		},
		Body = ScriptEditorService:GetEditorSource(script),
		Compress = Enum.HttpCompression.None,
	})
	if not success then
		warn(`[StyLua] Connecting to server failed: {result}`)
		if recordingId then
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
		end
	elseif not result.Success then
		local body = result.Body :: any
		if body:match("<!DOCTYPE html>") then
			warn(`[StyLua] {body:match("<pre>(.-)</pre>"):gsub("&#39;", "'"):gsub("<br>", "\n"):sub(1, -1)}`)
		end
		if recordingId then
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
		end
	else
		if ScriptEditorService:GetEditorSource(script) == result.Body then
			if recordingId then
				ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Cancel)
			end
			return
		end
		ScriptEditorService:UpdateSourceAsync(script, function()
			return result.Body
		end)
		if recordingId then
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		end
	end
end

local function format()
	if StudioService.ActiveScript then
		formatter(StudioService.ActiveScript :: LuaSourceContainer)
		return
	end
	local Selected = Selection:Get()
	for _, Object in Selected do
		if Object:IsA("LuaSourceContainer") then
			formatter(Object)
		end
	end
end

local FormatAction =
	plugin:CreatePluginAction("StyLua Format", "Format", "Formats the code", "rbxassetid://15177733701", true)

local toolbar = plugin:CreateToolbar("StyLua")

local FormatButton = toolbar:CreateButton("StyLua", "Format Document", "rbxassetid://15177733701", "StyLua")
FormatButton.ClickableWhenViewportHidden = true

local SettingButton =
	toolbar:CreateButton("StyLuaSettings", "StyLua Settings", "rbxassetid://15177736312", "StyLua Settings")
SettingButton.ClickableWhenViewportHidden = true

FormatAction.Triggered:Connect(format)
FormatButton.Click:Connect(format)
SettingButton.Click:Connect(openSettings)
