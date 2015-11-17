-- Made by Phoenixf129. This system is designed for one MySQL connection only. NOT MULTIPLE!

-- DBModule now supports either MySQLOO or TMySQL4. Found in your config file!
-- TMySQL4 can be found at: http://facepunch.com/showthread.php?t=1442438
-- MySQLOO can be found at: http://facepunch.com/showthread.php?t=1357773

PLib = PLib or {
	Host = "xxx", -- Hostname or IP Address to connect to
	User = "xxx", -- Username to connect with
	Pass = "xxx", -- Password to connect with
	DBName = "xxx", -- Database to select
	Port = 3306, -- Port to connect through. Default 3306.
	DBModule = "mysqloo", -- tmysql4 is also supported.
}

file.CreateDir("plib")
if !file.Exists("plib/config.txt", "DATA") then
	file.Write("plib/config.txt", util.TableToJSON(PLib, true))
	Msg("[PLib] No config file was detected. Default values have been applied and file has been created.\n")
else
	local config = util.JSONToTable(file.Read("plib/config.txt", "DATA"))
	PLib = config
	
	PLib.MySQL = PLib.MySQL or {}
	PLib.QueryQueue = PLib.QueryQueue or {}
	
	PLib.DBModule = config.DBModule or "mysqloo"
	
	PLib.MySQLActive = PLib.MySQLActive or false -- Don't touch this. PLib Changes this when mysql is connected.
	PLib.DebugMode = PLib.DebugMode or false -- Problems? Turn this on to see the Queries being executed in your console.
	
	Msg("[PLib] Config file found and loaded!\n")
end

function PLib:Init()
	MsgN( "[PLib] Connecting to database.." )

	require(self.DBModule)
	
	if self.DBModule == "mysqloo" then

		MsgN( "[PLib] MySQLOO Mode Detected!" )
		self.MySQL = mysqloo.connect( self.Host, self.User, self.Pass, self.DBName, self.Port )

		function self.MySQL:onConnected()
			MsgN( "[PLib] Connection established!" )
			PLib.MySQLActive = true

			for i = 1, #PLib.QueryQueue do
				MsgN( "[PLib] Running queued query.." )
				self:RunPreparedQuery( self.QueryQueue[ i ] )
			end

			PLib.QueryQueue = {}
			
			hook.Call( "PLib_DatabaseConnected", nil, self )
		end

		function self.MySQL:onConnectionFailed( e, sql )
			MsgN( "[PLib] Connection FAILED:" .. e )
		end
			
		-- Start the connection process
		self.MySQL:connect()
	elseif self.DBModule == "tmysql4" then

		MsgN( "[PLib] TMySQL4 Mode Detected!" )
		self.MySQL, self.DBError = tmysql.initialize( self.Host, self.User, self.Pass, self.DBName, self.Port )

		if self.MySQL then
			for i = 1, #self.QueryQueue do
				if self.DebugMode then
					MsgN( "[PLib] Running queued query" )
				end
				self:RunPreparedQuery( self.QueryQueue[ i ] )
			end
			
			self:RunPreparedQuery( { sql = "SELECT 1", 
				callback = function( data )

					PLib.MySQLActive = true
					
					self.QueryQueue = {}

					hook.Call( "PLib_DatabaseConnected", nil, self )
					MsgN( "[PLib] Connection established!" )
				end }
			)

		elseif self.DBError then
			MsgN("[PLib] Connection failed: "..self.DBError)
		end
		
	end
	
	if ( RealTime() < 30 ) then
		RunConsoleCommand( "bot" )
	end
	
	timer.Create( "MySQL KeepAlive", 60, 0, function()
		self:QuickQuery( "SELECT 1" )
	end )
	
end

gameevent.Listen( "player_connect" )
local function PlayerConnect( data )
	if not ( data.networkid == "BOT" ) then return end
	
	hook.Remove( "player_connect", "PLib PlayerConnect" )
	
	game.ConsoleCommand( string.format( "kickid %d %s\n", data.userid, "Goodbye Bot, thanks for the MySQL wakeup!" ) )
end
hook.Add( "player_connect", "PLib PlayerConnect", PlayerConnect )

function PLib:RunPreparedQuery( q )
	
	if self.DBModule == "mysqloo" then
	
		if istable( self.MySQL ) then
			table.insert( self.QueryQueue, q )

			return false
		end

		local query = self.MySQL:query( q.sql )
		query:setOption( mysqloo.OPTION_NUMERIC_FIELDS, true )
		query:setOption( mysqloo.OPTION_NAMED_FIELDS, false )

		function query:onSuccess( data )
			if string.Left( q.sql, 6 ) == "INSERT" then
				data = self:lastInsert()
			end

			if self.DebugMode then
				MsgN( "[PLib] Query Successful!\nQuery: " .. q.sql )
			end
			
			if q.callback and isfunction( q.callback ) then
				q.callback( data, unpack( q.vargs or {} ) )
			end
		end

		function query:onError( e, sql )
			MsgN( "[PLib] Query Failed!\nQuery: " .. sql .. "\nError: " .. e )
		
			local stat = self.MySQL:status()
			if stat != mysqloo.DATABASE_CONNECTED then
				table.insert( self.QueryQueue, q )
				
				self.MySQL:connect()
				
				if stat != mysqloo.DATABASE_CONNECTED then
					ErrorNoHalt( "[PLib] Re-connection to database server failed!" )
				end
			end
		end

		function query:onAborted()
			ErrorNoHalt( "[PLib] Query aborted!" )
		end

		query:start()

	elseif self.DBModule == "tmysql4" then

		if !self.MySQL then
			table.insert( self.QueryQueue, q )
			
			return false
		end
			
		self.MySQL:Query( q.sql, queryOnCompleted, 0, q )
		
		function queryOnCompleted( q, results, status, error )
			
			if q.callback and isfunction( q.callback ) then
				q.callback( results, unpack( q.vargs or {} ) )
			end
			
			if status == true then
				if self.DebugMode then
					MsgN( "[PLib] Query Successful!\nQuery: " .. q.sql )
				end
			else
				ErrorNoHalt( error )
			end
			
		end
		
	end
	
end

function PLib:QuickQuery( sql )
	PLib:RunPreparedQuery( { sql = sql } )
end

function PLib:escape( txt )
	
	if self.DBModule == "mysqloo" then
		if type( txt ) != "string" then
			txt = tostring( txt )
		end
	elseif self.DBModule == "tmysql4" then
		txt = tmysql.escape( txt )
	end
	
	return txt
end

hook.Add( "InitPostEntity", "InitPostEntity.InitMySQL", function( p )
	PLib:Init()
end )
