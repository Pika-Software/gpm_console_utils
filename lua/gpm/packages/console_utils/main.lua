SV_COLOR = Color( 136, 221, 255, 255 )
CL_COLOR = Color( 255, 221, 102, 255 )

console = console or {}

local history = {}
local textColor = Color(230, 220, 220)

function console.getHistory()
    return history
end

local table_insert = table.insert
local hook_Add = hook.Add
local os_date = os.date
local assert = assert
local unpack = unpack
local ipairs = ipairs
local type = type

do

    local IsColor = IsColor
    function console.setColor( color )
        assert( IsColor( color ), "bad argument #1 (color expected)" )
        textColor = color
    end

end

function console.getColor()
    return textColor
end

do

    local space = " "

    if SERVER then

        local RunConsoleCommand = RunConsoleCommand
        function console.run( str )
            table_insert( history, { os_date( "%X" ), str } )
            RunConsoleCommand( unpack( str:Split( space ) ) )
        end

        function console.color()
            return SV_COLOR
        end

    else

        local Ply = NULL
        hook_Add("PlayerInitialized", "Console.Run", function( ply )
            Ply = ply
        end)

        do
            local IsValid = IsValid
            function console.run( str )
                if game_ready.isReady() and IsValid( Ply ) then
                    table_insert( history, { os_date( "%X" ), str } )
                    Ply:ConCommand( str )
                else
                    wait( console.run, str )
                end
            end
        end

        function console.color()
            return CL_COLOR
        end

    end

end

--[[-------------------------------------------------------------------------
    Logs
---------------------------------------------------------------------------]]

do

    local log = {}
    log["__index"] = log
    debug.getregistry().ConsoleLog = log

    function log:setTag( tag )
        self["__tag"] = tag
        return self
    end

    log["__split"] = nil
    function log:setSeparator( any )
        self["__split"] = any
        return self
    end


    function log:onlyDevelopers( bool )
        self["__dev"] = (bool == true) and true or false
        return self
    end

    function log:isDevLog()
        return self["__dev"] or false
    end

    local timer_Simple = timer.Simple
    local setmetatable = setmetatable
    local hook_Run = hook.Run
    local MsgC = MsgC

    local developer = ((GetConVar( "developer" ):GetInt() or 0) > 0) or SERVER
    cvars.AddChangeCallback( "developer", function( name, old, new )
        developer = (tonumber( new ) > 0) or SERVER
    end, "Console Utils")

    function console.log( ... )
        local new = setmetatable( {["__args"] = {...}}, log)

        timer_Simple(0, function()
            if new:isDevLog() and (developer == false) then
                return
            end

            local args = new["__args"]
            if ( type( new["__split"] ) == "string" ) then
                local len = #args
                for num, var in ipairs( args ) do
                    if (type( var ) == "string") and (num < len) then
                        args[num] = var .. new["__split"]
                    end
                end
            end

            table_insert( args, "\n" )
            hook_Run( new:isDevLog() and "Console.DevLog" or "Console.Log", console.color(), "[", os_date( "%H:%M" ), " -> ", new["__tag"] or "Console Logs", "] ", textColor, unpack( args ) )
        end)

        return new
    end

    hook_Add( "Console.Log", "game.Console", function( ... )
        MsgC( ... )
    end)

    hook_Add( "Console.DevLog", "game.Console", function( ... )
        MsgC( " </> ", ... )
    end)

    function console.devLog( ... )
        return console.log( ... ):onlyDevelopers( true )
    end

    local getmetatable = getmetatable
    function isConsoleLog( any )
        return getmetatable( any ) == log
    end

end

--[[-------------------------------------------------------------------------
	Normal ConCommand's
---------------------------------------------------------------------------]]

if (SERVER) then

    do

        util.AddNetworkString("Console.ConCommand")

        local net_WriteString = net.WriteString
        local net_Start = net.Start
        local net_Send = net.Send

        local PLAYER = FindMetaTable("Player")
        function PLAYER:ConCommand( cmd )
            if type( cmd ) == "string" then
                net_Start( "Console.ConCommand" )
                    net_WriteString( cmd )
                net_Send( self )
            end
        end
    end

    do

        local cmd_starts = CreateConVar("chat_command_symbols", "/ !", FCVAR_ARCHIVE, " - List of chat commands start symbols"):GetString()
        if (cmd_starts != nil) then
            cmd_starts = "/ !"
        end

        local start_symbols = cmd_starts:Split( " " )
        hook.Add("PlayerSay", "ChatCommands", function( ply, text, teamChat )
            for num, start in ipairs( start_symbols ) do
                if text:StartWith( start ) then
                    local cmd = text:Replace( start, "" )
                    local splited = cmd:Split( " " )

                    local args = {}
                    for num, str in ipairs( splited ) do
                        if (num == 1) then
                            continue
                        end

                        table_insert( args, str )
                    end

                    return hook.Run( "ChatCommand", ply, splited[1], args, teamChat )
                end
            end
        end)

    end

else
    local net_ReadString = net.ReadString
    local net_Receive = net.Receive

    hook_Add("PlayerInitialized", "Console.ConCommand", function( ply )
    	net_Receive("Console.ConCommand", function()
            ply:ConCommand( net_ReadString() )
        end)
    end)
end