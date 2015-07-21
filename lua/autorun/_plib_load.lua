local luaroot = "plib"
local name = "PLib"

--Shared modules
local files = file.Find( luaroot .."/sh/*.lua", "LUA" )
table.sort( files )
if #files > 0 then
	for _, file in pairs( files ) do
		Msg( "["..name.."] Loading SHARED file: " .. file .. "\n" )
		include( luaroot .."/sh/" .. file )
		if SERVER then
			AddCSLuaFile( luaroot .."/sh/" .. file )
		end
	end
end

if SERVER then
	AddCSLuaFile( )
	local folder = luaroot .. "/sh"
	local files = file.Find( folder .. "/" .. "*.lua", "LUA" )
	for _, file in ipairs( files ) do
		AddCSLuaFile( folder .. "/" .. file )
	end

	folder = luaroot .."/cl"
	files = file.Find( folder .. "/" .. "*.lua", "LUA" )
	for _, file in ipairs( files ) do
		AddCSLuaFile( folder .. "/" .. file )
	end

	--Server modules
	local files = file.Find( luaroot .."/sv/*.lua", "LUA" )
	if #files > 0 then
		for _, file in ipairs( files ) do
			Msg( "["..name.."] Loading SERVER file: " .. file .. "\n" )
			include( luaroot .."/sv/" .. file )
		end
	end
		
	MsgN( name.." by Phoenixf129 loaded" )
end

if CLIENT then
	--Client modules
	local files = file.Find( luaroot .."/cl/*.lua", "LUA" )
	if #files > 0 then
		for _, file in ipairs( files ) do
			Msg( "["..name.."] Loading CLIENT file: " .. file .. "\n" )
			include( luaroot .."/cl/" .. file )
		end
	end
	MsgN( name.." by Phoenixf129 loaded" )
end