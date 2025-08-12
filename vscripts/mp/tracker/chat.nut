																						//~mkos
global function Chat_Init
global function Chat_RegisterPlayerData

global function Chat_ToggleMuteForAll
global function Chat_InMutedList

global function Chat_GlobalMuteEnabled
global function Chat_CheckGlobalMute

global function Chat_GetMutedReason
global function Chat_FindMuteReasonInArgs
global function Chat_ReadableUnmuteTime

global function Chat_GetAllEffects
global function Chat_FindEffect

#if DEVELOPER
	global function DEV_PrintAllChatEffects
	global function DEV_PrintOffenceArray
#endif

//CHAT EFFECTS
global struct Chat 
{
	table<string,string> effects = 
	{
	
		["THUMBSUP"] = "󰉥",
		["SKULL"] = "󰆿",
		["PISTOL"] = "󰉅",
		["ROOK"] = "󰈭",
		["YELLOW_SKULL"] = "󰈫",
		["NO_WEP"] = "󰈝",
		["HEALTHKIT"] = "󰈘",
		["PHOENIX"] = "󰈖",
		["LOCKED"] = "󰈎",
		["EYE"] = "󰇊",
		["FRIEND"] = "󰆾",
		["LAG"] = "󰆼",
		["CONNECTING"] = "󰆺",
		["CELL"] = "󰈚",
		["BATTERY"] = "󰈙",
		["APEX"] = "󰅡",
		["FIVE"] = "󰆗",
		["CIRCLE"] = "󰆉",
		["BLUEPEX"] = "󰅠",
		["WRAITH_BANNER"] = "󰄒",
		["BIG_WHITE_CROWN"] = "󰄈",
		["WHITE_CROWN"] = "󰄇",
		["BLUE_CROWN"] = "󰄄",
		["TREE"] = "󰃻",
		["SUS"] = "󰃴",
		["RED_SQUARE"] = "󰃭"
	}
}

global Chat chat

typedef OffenceTiers array< int > 

const string YES = "1"
const bool PRINT_TIME_STRING_ARGS = false


struct 
{
	table< string, int > mutedPlayers //uid -> unix unmute time	
	table< string, int > offenceLevel
	OffenceTiers offensePenaltyTiers
	bool bOffenceTierTblGenerated
	int offencePenaltyTierCount
	bool offenceTiersEnabled
	int functionref( entity, int ) DetermineTimeOut
	
	bool bGlobalMuteEnabled = true
	bool opt_in_spam_mute	= true
	float chatInterval
	int timeoutAmount
	int chatThreshhold
	
	float chatMutePenaltyDecayTime
	int chatMutePenaltyDecayAmount
	
	bool chatCommandsEnabled
	
} file

////////////////
/// Register //////////////////////////////////////////////////////////////////////////////////////////
////////////////

void function RegisterAllChatCommands() //if chat commands enabled.
{
	// We want to assert out, incase this gets init somewhere else and gamemode is exposed.
	mAssert( GetCurrentPlaylistVarBool( "enable_chat_commands", true ), FUNC_NAME() + "() was called but enable_chat_commands is set to false" )
	
	//common
	Commands_Register( "!id", cmd_id, [ "/id", "\\id" ] )
	Commands_Register( "!aa", cmd_aa, [ "/aa", "\\aa" ] )
	Commands_Register( "!inputs", cmd_inputs, [ "/inputs", "\\inputs" ] )
	
	if( Flowstate_EnableReporting() )
		Commands_Register( "!cringe", cmd_cringe, ["/cringe", "\\cringe", "!report", "/report", "\\report" ] )
	
	//game varient
	switch( Playlist() )
	{
		case ePlaylists.fs_scenarios:
		
			Commands_Register( "!rest", cmd_rest, [ "/rest", "\\rest" ] )
			break 
			
		case ePlaylists.fs_1v1:
		case ePlaylists.fs_lgduels_1v1:
		case ePlaylists.fs_vamp_1v1:
			
			Commands_Register( "!wait", cmd_wait, [ "/wait", "\\wait" ] )
			Commands_Register( "!rest", cmd_rest, [ "/rest", "\\rest" ] )
			Commands_Register( "!info", cmd_info, [ "/info", "\\info" ] )
			
			if( GetCurrentPlaylistVarBool( "enable_challenges", true ) )
			{
					Commands_Register( "!chal", cmd_chal, [ "/chal", "\\chal", "!challenge", "/challenge", "\\challenge" ] )
					Commands_Register( "!accept", cmd_accept, [ "/accept", "\\accept" ] )
					Commands_Register( "!list", cmd_list, [ "/list", "\\list" ] )
					Commands_Register( "!end", cmd_end, [ "/end", "\\end" ] )
					Commands_Register( "!remove", cmd_remove, [ "/remove", "\\remove" ] )
					Commands_Register( "!clear", cmd_clear, [ "/clear", "\\clear" ] )
					Commands_Register( "!revoke", cmd_revoke, [ "/revoke", "\\revoke" ] )
					Commands_Register( "!cycle", cmd_cycle, [ "/cycle", "\\cycle" ] )
					Commands_Register( "!swap", cmd_swap, [ "/swap", "\\swap" ] )
					Commands_Register( "!legend", cmd_legend, [ "/legend", "\\legend" ] )
					Commands_Register( "!outlist", cmd_outlist, [ "/outlist", "\\outlist" ] )
			}
			break 
	}
}

///////////////////////////////
/// Define Command Handlers //////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////

const MAX_REPORTS_ALLOWED_PER_MAP = 5 
void function cmd_cringe( string tag, array<string> args, entity activator )
{
	activator.p.submitCringeCount++	
	
	if( activator.p.submitCringeCount >= MAX_REPORTS_ALLOWED_PER_MAP )
	{
		Message( activator, "Too many reports", "Please limit reports per match to as needed." )
		return
	}
	
	entity previousPlayer = activator.p.lastOpponent	
	if( IsValid( previousPlayer ) ) // && ( previousPlayer.p.lastOpponent == activator ) ) //we may want to omit opposition check ( the && expression #2), could be an exploit where enemy quickly finishes next player during the /cringe, and by this time the check would fail if opposition was fast enough in their next fight.
	{
		string argReason
		if( args.len() > 1 )
		{
			args.remove( 0 ) //the command "cringe" 
			argReason = args.join( " " ) //the rest of the string after the command
			
			string regex = "^[A-Za-z0-9_ \\[\\]\\(\\):;,\\'\\\"*&^%$#@!+=?.|]*$"
			if( !IsSafeString( argReason, 255, regex ) )
			{
				printt( "Unsafe reason string by: ", activator )
				argReason = "emptied"
			}
		}
		
		CringeReport cringe
		cringe.cringedOID = previousPlayer.p.UID
		cringe.cringedName = previousPlayer.p.name 
		cringe.reason = argReason

		previousPlayer.p.cringedCount++
		activator.p.cringeDataReports.append( cringe )
		
		Message( activator, "Thanks, Report Receieved", "We receieved your report as: \n\n" + argReason )
	}
	else 
	{
		Message( activator, "Opponent Left" )
	}
}


void function cmd_wait( string tag, array<string> args, entity activator )
{
	args.remove( 0 )
	ClientCommand_mkos_IBMM_wait( activator, args )
}

void function cmd_rest( string tag, array<string> args, entity activator )
{
	if( !g_bRestEnabled() )
		return
		
	switch( Playlist() )// only two varients use rest, as it was a 1v1 feature originally.
	{
		case ePlaylists.fs_scenarios:
			
			FS_Scenarios_ClientCommand_Rest( activator, args )
			break
			
		case ePlaylists.fs_1v1:
		case ePlaylists.fs_lgduels_1v1:
		case ePlaylists.fs_vamp_1v1:
		
			ClientCommand_Maki_SoloModeRest( activator, args )	
			break
	}
}

void function cmd_info( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "player"
	
	if( args.len() < 2 )
		args.append( activator.p.name )
	
	ClientCommand_mkos_return_data( activator, args )
}

void function cmd_id( string tag, array<string> args, entity activator )
{
	ClientCommand_mkos_return_data( activator, [ "id" ] )
}

void function cmd_aa( string tag, array<string> args, entity activator )
{
	ClientCommand_mkos_return_data( activator, [ "aa" ] )
}

void function cmd_inputs( string tag, array<string> args, entity activator )
{
	ClientCommand_mkos_return_data( activator, [ "inputs" ] )
}

void function cmd_chal( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "chal" //set client command to chal switch arg
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_accept( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "accept"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_list( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "list"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_end( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "end"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_remove( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "remove"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_clear( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "clear"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_revoke( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "revoke"
	ClientCommand_mkos_challenge( activator, args )	
}

void function cmd_cycle( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "cycle"
	ClientCommand_mkos_challenge( activator, args )	
}

void function cmd_swap( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "swap"	
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_legend( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "legend"
	ClientCommand_mkos_challenge( activator, args )
}

void function cmd_outlist( string tag, array<string> args, entity activator )
{
	args[ 0 ] = "outlist"
	ClientCommand_mkos_challenge( activator, args )
}


/////////////
/// Chat  //////////////////////////////////////////////////////////////////////////////////////////
/////////////

void function Chat_Init()
{
	if( GetCurrentPlaylistVarBool( "disable_chat_monitor", false ) )
		return
	
	//Init options first
	file.chatInterval 				= GetCurrentPlaylistVarFloat( "chat_interval", 12 )
	file.chatThreshhold 			= GetCurrentPlaylistVarInt( "chat_threshhold", 5 )
	file.bGlobalMuteEnabled 		= GetCurrentPlaylistVarBool( "opt_in_global_mute", true )
	file.opt_in_spam_mute 			= GetCurrentPlaylistVarBool( "opt_in_spam_mute", true )
	file.chatMutePenaltyDecayTime 	= GetCurrentPlaylistVarFloat( "textmute_offence_decay_time", 45.0 )
	file.chatMutePenaltyDecayAmount	= GetCurrentPlaylistVarInt( "textmute_offence_decay_amount", 1 )
	file.chatCommandsEnabled		= GetCurrentPlaylistVarBool( "enable_chat_commands", true )
	
	//Signals 
	RegisterSignal( "MuteStateChanged" )
	
	//Callbacks
	//AddClientCommandCallback( "FS_TT", SetRelayChallenge )
	AddClientCommandCallbackNew( "say", ChatWatchdog )
	AddCallback_OnClientConnected( CheckForTextMute )
	
	//Commands
	Commands_SetupArg( "-r", [ "r", "-reason", "reason" ] )
	
	if( file.chatCommandsEnabled )
	{
		RegisterAllChatCommands()
		AddClientCommandCallbackNew( "say", ClientCommand_ParseSay )
	
		if( file.opt_in_spam_mute )
		{		
			file.offensePenaltyTiers = CheckAndGenerateOffenceTierArray()
				
			array<string> args = []
			string timeString
			
			if( Chat_OffenceTiersEnabled() )//must contain one item
			{
				file.timeoutAmount = GetOffenceArray()[ 0 ]
				file.DetermineTimeOut = DetermineTimeOutFunction_Steps
				AddCallback_OnClientConnected( SetupForTiers )
			}
			else 
			{
				timeString = GetCurrentPlaylistVarString( "chat_timeout", "" )
				file.DetermineTimeOut = DetermineTimeOutFunction_Common
				
				if( !empty( timeString ) )
				{
					args = split( timeString, " " )
					file.timeoutAmount = ParseTimeString( args )
					
					if( file.timeoutAmount == -1 )
						mAssert( false, "Timeout was set to -1. Was the timeout string correctly formatted in playlists? Use 0 for infinite." )
				}
			}
			
			if( file.chatThreshhold <= 0 )
				mAssert( false, "Opt in mute was enabled, but threshold was " + string( file.chatThreshhold ) + ". must be greater than 0" ) //let host know: config error
			else
				AddCallback_OnClientConnected( Chat_SpamCheck_StartThread )
		}
	}
}

void function Chat_RegisterPlayerData()
{
	#if TRACKER && HAS_TRACKER_DLL
		AddCallback_PlayerData( "unmuteTime", SetUnmuteTime ) //must be before muted
		AddCallback_PlayerData( "muted", MuteFromPersistence )
		AddCallback_PlayerData( "muted_reason" )
	#endif
}

bool function Chat_InMutedList( string uid )
{
	return ( uid in GetMutedList() )
}

bool function Chat_OffenceTiersEnabled()
{
	#if DEVELOPER
		mAssert( file.bOffenceTierTblGenerated, "Tried to call " + FUNC_NAME() + "() in " + FUNC_NAME(1) + "() before first CheckAndGenerateOffenceTierArray()" )
	#endif
	
	return file.offenceTiersEnabled
}

bool function Chat_GlobalMuteEnabled()
{
	return file.bGlobalMuteEnabled
}

void function Chat_CheckGlobalMute( entity player )
{
	bool globalMute = GetPlayerStatBool( player.GetPlatformUID(), "globally_muted" )
	
	if( globalMute )
	{
		LocalMsg( player, "#FS_SPAM_MUTE", "", eMsgUI.DEFAULT, 5, "", "GLOBAL" )
		MuteFromPersistence( player, YES )
	}
}

bool function Chat_ToggleMuteForAll( entity player, bool toggle = true, bool cmdLine = false, array<string> cmdStringArgs = [], int timeoutAmount = 0, string uid = "" )
{
	int eHandle
	bool bSyncToPlayers = true
	
	if( IsValid( player ) )
	{
		eHandle = player.p.handle	
		uid = player.p.UID
	}
	else if( !empty( uid ) )
		bSyncToPlayers = false //attempt list update only
	else 
		return false
	
	if ( toggle ) //mute
	{
		int timestamp = -1

		if( cmdLine )
		{
			if( timeoutAmount > 0 ) //-1
			{
				timestamp = GetUnixTimestamp() + timeoutAmount
			}
			else
			{
				int determinedTime = ParseTimeString( cmdStringArgs )
				
				if( determinedTime > 0 )
					timestamp = GetUnixTimestamp() + determinedTime
				else 
					timestamp = determinedTime
			}
			
			#if TRACKER
				table<string, string> settings //todo:_typed
				
				string reason = Chat_FindMuteReasonInArgs( cmdStringArgs )	 	

				settings[ "muted_reason" ] 	<- reason
				settings[ "unmuteTime" ] 	<- timestamp.tostring()
				settings[ "muted" ] 		<- "1"
				
				tracker.SavePlayerData( uid, settings, !bSyncToPlayers )
			#endif
			
			if( IsTimeInSameMatch( timestamp ) )
				thread AutoUnmuteAtTime( player, timestamp, uid )
				
			if( bSyncToPlayers )
				SetUnmuteTime_Raw( player, timestamp )
		}
		else if( bSyncToPlayers )
			timestamp = GetEntityUnmuteTimestamp( player )
		else 
			timestamp = MutedList_GetUnmuteTime( uid )
			
		MutedList_Update( uid, timestamp )
	}
	else //unmute
	{		
		int timeToWait = ParseTimeString( cmdStringArgs )
		int unmuteTime = GetUnixTimestamp() + timeToWait
		
		if( timeToWait > 0 && IsTimeInSameMatch( unmuteTime ) )
		{
			MutedList_Update( uid, unmuteTime )
			thread AutoUnmuteAtTime( player, unmuteTime, uid )	
			return false
		}	
		
		if( cmdLine )
		{
			#if TRACKER
				table<string, string> settings
				
				string reason = Chat_FindMuteReasonInArgs( cmdStringArgs )	 	
				if( reason != "{none}" )
					if( reason != Tracker_FetchPlayerData( uid, "muted_reason" ) )
						settings[ "muted_reason" ] <- reason //ship reason as new unmute reason
				
				settings[ "muted" ] <- "0"
				settings[ "unmuteTime" ] <- "NA"
				
				tracker.SavePlayerData( uid, settings, !bSyncToPlayers )
			#endif
		}
		else 
		{
			Tracker_SavePlayerData( uid, "muted", "0" ) //save for endgame update
		}
			
		MutedList_Remove( uid )
	}
	
	if( bSyncToPlayers )
	{
		ToggleMute( player, toggle )
		
		if( !cmdLine && toggle )
		{
			string reason = Tracker_FetchPlayerData( player.p.UID, "muted_reason" )
			LocalMsg( player, "#FS_SPAM_MUTE", "", eMsgUI.DEFAULT, 5, "", reason )
		}					//Token name is misleading..just trust.
		
		foreach ( s_player in GetPlayerArray() )
		{
			if( !IsValid( s_player ) || player == s_player )
				continue
				
			Remote_CallFunction_NonReplay( s_player, "FS_Silence", toggle, eHandle )
		}
	}
	
	return true
}

string function Chat_GetMutedReason( string uid = "", entity player = null )
{
	string reason
	
	if( !empty( uid ) )
		reason = Tracker_FetchPlayerData( uid, "muted_reason" )
	else if( IsValid( player ) )
		reason = Tracker_FetchPlayerData( player.p.UID, "muted_reason" )	
		#if DEVELOPER
	else 
			printw( "No valid uid or player entity provided." )
		#endif 
		
	return reason
}

void function Chat_SpamCheck_StartThread( entity player )
{
	thread 
	(
		void function() : ( player )
		{
			//check again since this was threaded off 
			if( !IsValid( player ) )
				return 
				
			player.EndSignal( "OnDestroy", "OnDisconnected" )
			
			for( ; ; )
			{
				wait file.chatInterval
				
				int msgCount = player.p.msg 			
				player.p.msg = maxint( 0, ( msgCount - file.chatThreshhold ) )
			}
		}
	)()
	
	if( Chat_OffenceTiersEnabled() )
	{
		thread 
		(
			void function() : ( player )
			{
				//check again since this was threaded off 
				if( !IsValid( player ) )
					return 
					
				player.EndSignal( "OnDestroy", "OnDisconnected" )
				
				for( ; ; )
				{
					wait file.chatMutePenaltyDecayTime
					__OffenceArray_DecrementCount( player, file.chatMutePenaltyDecayAmount )
				}
			}
		)()
	}
}

const array<string> SINGLE_ARGS =
[
	"-1",
	"0",
	"forever",
	"infinite"
]
const string TEXT_MUTE_REASON_ARG = "-r"
string function Chat_FindMuteReasonInArgs( array<string> args ) 
{
	int i = 0
	
	while ( i < args.len() ) 
	{
        string arg = args[ i ]  

		if ( i + 1 < args.len() ) 
		{
            string value = args[ i + 1 ]
			if ( Commands_ArgAliasPointsTo( arg, TEXT_MUTE_REASON_ARG ) )
                return value
			
			int nextIndex = 2
			
			if( SINGLE_ARGS.contains( arg ) )
				--nextIndex
		
            i += nextIndex //continue
		} 
		else 
		{
			#if DEVELOPER && PRINT_TIME_STRING_ARGS
				printw( "Error: Missing value for command", "\"" + arg + "\"" )
			#endif
			break
		}
	}
	
	return "{none}"
}

void function __Commands( entity player, array<string> args )
{	
	// #if DEVELOPER
		// print_string_array( args )
	// #endif 
	
	string userCmd = args[ 0 ]
	string baseCmd = Commands_ReturnBaseCmdForAlias( userCmd )
	
	if( empty( baseCmd ) )
		return 
	
	if( Commands_RequiresPlayersCommandsEnabled( baseCmd ) )
	{
		if( !IsCommandsEnabled( player ) )
			return
	}
	
	CommandCallback handler = Commands_GetCommandHandler( baseCmd )
	handler( baseCmd, args, player )
}

/////////////////////
/// Chat Offences //////////////////////////////////////////////////////////////////////////////////////////
/////////////////////

// Chat_OffenceTiersEnabled()

OffenceTiers function GetOffenceArray()
{
	return file.offensePenaltyTiers
}

int function __OffenceArray_GetOffenceCount()
{
	return file.offencePenaltyTierCount
}

int function __OffenceArray_GetOffenceLevel( entity player )
{
	return file.offenceLevel[ player.p.UID ]
}

bool function __OffenceArray_IsPlayerSetup( entity player )
{
	return ( player.p.UID in file.offenceLevel )
}

bool function __OffenceArray_IsUidSetup( string uid )
{
	return ( uid in file.offenceLevel )
}

void function __OffenceArray_IncrementCount( entity player )
{
	if( !__OffenceArray_IsPlayerSetup( player ) )
	{
		mAssert( false, "Tried to increment offence count without first initializing player's offence slot." )
		return
	}
		
	int offenceLevel = __OffenceArray_GetOffenceLevel( player )	
	offenceLevel = minint( file.offencePenaltyTierCount, offenceLevel + 1 )
	
	__OffenceArray_SetOffenceLevel( player, offenceLevel )
}

void function __OffenceArray_DecrementCount( entity player, int steps = 1 )
{
	if( !__OffenceArray_IsPlayerSetup( player ) )
	{
		mAssert( false, "Tried to decrement offence count without first initializing player's offence slot." )
		return
	}
		
	int offenceLevel = __OffenceArray_GetOffenceLevel( player )	
	offenceLevel = maxint( 0, offenceLevel - steps )
	
	__OffenceArray_SetOffenceLevel( player, offenceLevel )
}

void function __OffenceArray_SetOffenceLevel( entity player, int level )
{
	file.offenceLevel[ player.p.UID ] = level
}

OffenceTiers function CheckAndGenerateOffenceTierArray()
{
	if( file.bOffenceTierTblGenerated )
		mAssert( false, "Tried to generate offence tier table more than once." )
	
	OffenceTiers offenceArray = []
	
	string playlistString = GetCurrentPlaylistVarString( "textmute_offence_tiers", "" )
	
	if( !empty( playlistString ) )
	{
		array<string> playlistOffenceTiers
		
		try
		{
			playlistOffenceTiers = StringToArray( playlistString, 1000 )
		
			foreach( string timeString in playlistOffenceTiers )
			{
				array< string > args = StringToArray( timeString )
				int timeInt = ParseTimeString( args )
				
				if( timeInt == -1 )
					continue 
					
				offenceArray.append( timeInt )		
			}
		}
		catch( e )
		{
			sqerror( "Error: " + e )
		}
	}
	
	file.offencePenaltyTierCount = offenceArray.len()
	if( file.offencePenaltyTierCount )
		file.offenceTiersEnabled = true
		
	file.bOffenceTierTblGenerated = true 
	return offenceArray
}



////////////////////
/// Chat Effects //////////////////////////////////////////////////////////////////////////////////////////
////////////////////

table <string,string> function Chat_GetAllEffects()
{
	return chat.effects
}

string function Chat_FindEffect( string key )
{
	if( key in chat.effects )
		return chat.effects[ key ]
	
	string query = key.tolower()
	
	foreach( effectKey, chatValue in chat.effects )
	{
		if ( effectKey.tolower() == query )
			return chatValue
	}
	
	return "Not found.";
}

#if DEVELOPER
	void function DEV_PrintAllChatEffects()
	{
		string print_effects = format( "\n\n --- Chat Effects --- \n\n" )
		
		foreach( key, value in chat.effects )
			print_effects += format( "%s \n", key ) 
		
		sqprint( print_effects )
	}
#endif

///////////////////
// chat utility //////////////////////////////////////////////////////////////////////////////////////////
///////////////////

table<string,int> function GetMutedList()
{
	return file.mutedPlayers
}

int function ParseTimeString( array<string> args )
{
	int argLen = args.len()
	
	if( argLen < 1 )
		return -1
		
	#if DEVELOPER && PRINT_TIME_STRING_ARGS
		string printout
		{
			string space = "\n== Parse Time String Args ==\n"
			for( int j = 0; j < args.len(); j++ )
			{
				space = j == 0 ? "" : " "
				printout += space + args[ j ]
			}
			
			printw( printout )
		}
	#endif
	
	int startIndex = 0
	string param = args[ 0 ]
	
	//compatibility hack for usage in admin cc
	switch( param )
	{
		case "mute":
		case "unmute":
		
			if( argLen >= 4 )
				startIndex = 2
	
		break 
		
		case "-1":
		case "0":
		
			--startIndex
		
		break
	}
	
	int addTime = 0
	for ( int i = startIndex; i < args.len(); i += 2 )
	{
		if ( i >= args.len() )
			return -1
			
		if( !IsNumeric( args[ i ] ) )
			continue 
		
		if( Commands_AllArgAliasesContains( args[ i ] ) )
			continue
		
		int timeAmount = 0
		try
		{
			timeAmount = args[ i ].tointeger()
		} 
		catch( e )
		{
			#if DEVELOPER 
				printw( "Warning:", e )
			#endif 
		}
		
		if ( i + 1 >= args.len() )
			return -1
		
		string timeUnit = args[ i + 1 ].tolower()
		
		if( Commands_AllArgAliasesContains( timeUnit ) )
		{
			--i
			continue
		}
			
		switch ( timeUnit ) 
		{
			case "year":
			case "years":
				addTime += ( timeAmount * 31557600 )
				break 
				
			case "month":
			case "months":
				addTime += ( timeAmount * 2629800 ) //avg
				break
				
			case "day":
			case "days":
				addTime += ( timeAmount * 86400 )
				break
				
			case "hour":
			case "hours":
				addTime += ( timeAmount * 3600 )
				break
				
			case "min":
			case "mins":
			case "minute":
			case "minutes":
				addTime += ( timeAmount * 60 )
				break
				
			case "sec":
			case "secs":
			case "second":
			case "seconds":
				addTime += ( timeAmount * 1 )
				break
			
			default:
				#if DEVELOPER 
					printw( "Invalid time unit used:", "\"" + timeUnit + "\""  )
				#endif
				return -1
		}
		
		#if DEVELOPER && PRINT_TIME_STRING_ARGS
			printt( "addtime =", addTime )
		#endif
	}
	
	return addTime
}

string function Chat_ReadableUnmuteTime( int unmuteTime )
{
	int currentTime = GetUnixTimestamp()	
	int diff = unmuteTime - currentTime

	if ( diff <= 0 )
		return "Already unmuted " + diff + " seconds ago."

	int years = diff / 31557600
	diff %= 31557600

	int months = diff / 2629800
	diff %= 2629800

	int days = diff / 86400
	diff %= 86400

	int hours = diff / 3600
	diff %= 3600

	int minutes = diff / 60
	int seconds = diff % 60

	array<string> result = []

	if ( years > 0 ) 
		result.append( years + " " + ( years == 1 ? "year" : "years" ) )

	if ( months > 0 ) 
		result.append( months + " " + ( months == 1 ? "month" : "months" ) )

	if ( days > 0 ) 
		result.append( days + " " + ( days == 1 ? "day" : "days" ) )

	if ( hours > 0 ) 
		result.append( hours + " " + ( hours == 1 ? "hour" : "hours" ) )

	if ( minutes > 0 ) 
		result.append( minutes + " " + ( minutes == 1 ? "minute" : "minutes" ) )

	if ( seconds > 0 ) 
		result.append( seconds + " " + ( seconds == 1 ? "second" : "seconds" ) )

	int rLen = result.len()
	
	if ( rLen == 1 )
		return result[ 0 ]
	else if ( rLen > 1 )
		return result.slice( 0, rLen - 1 ).join( ", " ) + " and " + result[ rLen - 1 ]

	return "Less than a second"
}


const array<int> INFINITE_MUTE_TIMES =
[
	0,
	-1
]
void function AutoUnmuteAtTime( entity player, int unmuteTime, string uid )
{
	if( !IsValid( player ) )
		return
		
	player.Signal( "MuteStateChanged" )
	EndSignal( player, "OnDestroy", "OnDisconnected", "MuteStateChanged" )
	
	if( INFINITE_MUTE_TIMES.contains( unmuteTime ) )
		return 
	
	int currentTime = GetUnixTimestamp() 
	if( unmuteTime > currentTime )
		wait ( unmuteTime - currentTime )
	else 
	{
		#if DEVELOPER 
			printw( "Invalid unmute time? unmuteTime:", unmuteTime, "currentTime:", currentTime )
		#endif 
		
		return
	}
	
	for( ; ; )
	{
		if( !Chat_InMutedList( uid ) ) //maybe a manual unmute occurred
			return
		
		int currentTimeStamp = GetUnixTimestamp()
		int newUnmuteTime = MutedList_GetUnmuteTime( uid )
		
		if( newUnmuteTime > 0 && newUnmuteTime > currentTimeStamp )
		{
			#if DEVELOPER 
				printw( "New muted time", MutedList_GetUnmuteTime( uid ), " is less thhan current time", currentTimeStamp, "for player", player )
			#endif
			
			wait newUnmuteTime - currentTimeStamp
			continue
		}
		else 
		{
			if( newUnmuteTime <= 0 )
				return //infinite mute time change applied
			else //(newUnmuteTime < currentTimeStamp)
				break //break and unmute
		}
	}
	
	//recheck from wait.
	if( IsValid( player ) )
	{
		Chat_ToggleMuteForAll( player, false ) //saves player data in process for endgame update.
		LocalMsg( player, "#FS_AUTO_UNMUTED" )
	}
	else
	{
		MutedList_Remove( uid ) //Todo(mk): verify this
		Tracker_SavePlayerData( uid, "muted", false, true ) //player disconnected. Save it and ship now.
	}
	
	#if DEVELOPER 
		printw( "player was auto unmuted:", player )
	#endif 
}

void function MuteFromPersistence( entity player, string setting )
{
	if( !IsValid( player ) ) 
		return 
	
	string uid = player.p.UID
	
	if( setting == YES )
	{
		if ( !Chat_InMutedList( uid ) )
			MutedList_Update( uid, GetEntityUnmuteTimestamp( player ) )
		
		CheckForTextMute( player )
	}
}

void function CheckForTextMute( entity player )
{
	if( !IsValid( player ) )
		return
	
	string uid = player.p.UID
	if( Chat_InMutedList( uid ) )
	{
		int unmuteTime = GetEntityUnmuteTimestamp( player )	
		
		if( unmuteTime > 0 )
		{
			if( GetUnixTimestamp() > unmuteTime )
			{
				Chat_ToggleMuteForAll( player, false )
				return
			}
			else if( IsTimeInSameMatch( unmuteTime ) )
			{
				thread AutoUnmuteAtTime( player, unmuteTime, uid )
			}
		}
	
		Chat_ToggleMuteForAll( player )
	}
}

#if TRACKER && HAS_TRACKER_DLL
void function SetUnmuteTime( entity player, string potentialTimestamp )
{
	int timestamp = -1
	
	if( !IsNumeric( potentialTimestamp ) )
		return
	
	try
	{
		timestamp = potentialTimestamp.tointeger() //Todo(mk): server-based persistence vars need typed like global stats.
	}
	catch( e )
	{
		#if DEVELOPER 
			printw( "Warning, tried to set timestamp", e )
		#endif 
	}
	
	player.p.unmuteTime = timestamp
}
#endif

void function SetUnmuteTime_Raw( entity player, int timestamp )
{	
	player.p.unmuteTime = timestamp
}

bool function IsTimeInSameMatch( int timestamp )
{
	if( ( Tracker_GetStartUnixTime() + ( FlowState_RoundTime() * Flowstate_AutoChangeLevelRounds() ) ) > timestamp )
		return true
		
	return false
}

int function GetEntityUnmuteTimestamp( entity player )
{
	int potentiallyUpdatedTime = -1
	
	if( Chat_InMutedList( player.p.UID ) )
		potentiallyUpdatedTime = MutedList_GetUnmuteTime( player.p.UID )
		
	return maxint( player.p.unmuteTime, potentiallyUpdatedTime )
}

void function SetupForTiers( entity player )
{
	if( !__OffenceArray_IsPlayerSetup( player ) )
		file.offenceLevel[ player.p.UID ] <- 0
	else 
		file.offenceLevel[ player.p.UID ] = 0
}

// bool function SetRelayChallenge( entity player, array<string> args )
// {
	// if( !IsValid( player ) )
		// return false
	
	// if( args.len() < 1 )
		// return true
	
	// string challengeCode = args[0]
	
	// if( !IsNumeric( challengeCode, 10000000, 99999999 ) )
		// return true
	
	// if( challengeCode.len() != 8 )
		// return true
	
	// int compCode = -1
	
	// try
	// {
		// compCode = challengeCode.tointeger()
	// }
	// catch(e){ return true }
	
	// if( compCode != player.p.relayChallengeCode )
	// {
		// return true 
	// }
	// else
	// {
		// player.p.bRelayChallengeState = true
		// player.Signal( "ChallengeReceived" )
	// }
	
	// return true
// }

void function ChatWatchdog( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return
		
	int wordCount = args.len()
		
	if( player.p.bTextmute && wordCount )
	{
		KickPlayerById( player.GetPlatformUID(), "Attempted to bypass chat mute" )
		return
	}
	
	if( wordCount && !GetServerVar( "batch_fetch_complete" ) )
		Chat_ToggleMuteForAll( player, true, true, [ "-reason", "Attempting to bypass precheck" ], 30 )
	
	if( file.chatCommandsEnabled && file.opt_in_spam_mute && wordCount > 0 )
	{
		player.p.msg++
		
		if( TooManyMessages( player ) )
		{
			int newTime = file.DetermineTimeOut( player, file.timeoutAmount )
			
			Chat_ToggleMuteForAll( player, true, true, [ "-reason", "AutoMute: Spam" ], newTime )
			__OffenceArray_IncrementCount( player )
			
			LocalMsg( player, "#FS_SPAM_MUTE", "#FS_SPAM_MUTE_DESC", eMsgUI.DEFAULT, 5.0, "", string( newTime ) )
			
			#if DEVELOPER
				printw( "player textmuted for spam: ", player, " msgcount:", player.p.msg, "penalty of:", newTime )
			#endif 
		}
	}
}

int function DetermineTimeOutFunction_Common( entity player, int textmuteTimeoutAmount )
{
	return textmuteTimeoutAmount
}

int function DetermineTimeOutFunction_Steps( entity player, int textmuteTimeoutAmount )
{
	return GetOffenceArray()[ __OffenceArray_GetOffenceLevel( player ) ]
}

bool function TooManyMessages( entity player )
{
	return player.p.msg > file.chatThreshhold
}

//chat commands
void function ClientCommand_ParseSay( entity player, array<string> args )
{		
    if ( !IsValid( player ) || args.len() == 0 )
		return
	
	__Commands( player, args )
}

#if DEVELOPER 
	void function DEV_PrintOffenceArray()
	{
		foreach( int idx, int timeAmount in GetOffenceArray() )
		{
			printt( idx, "=", timeAmount )
		}
		
		printt( "count:", GetOffenceArray().len() )
	}
#endif 

void function MutedList_Update( string uid, int timestamp = -1 )
{
	if( Chat_InMutedList( uid ) && timestamp != -1 )
		file.mutedPlayers[ uid ] = timestamp 
	else 
		file.mutedPlayers[ uid ] <- timestamp
}

int function MutedList_GetUnmuteTime( string uid )
{
	if( Chat_InMutedList( uid ) )
		return GetMutedList()[ uid ]
		
	return 0
}

void function MutedList_Remove( string uid )
{
	if( Chat_InMutedList( uid ) )
		delete GetMutedList()[ uid ]
}