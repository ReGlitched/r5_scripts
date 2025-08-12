// flowstate spawn system														//mkos

global function Flowstate_SpawnSystem_Init
global function Flowstate_SpawnSystem_InitGamemodeOptions //gamemode must call

global function SpawnSystem_ReturnAllSpawnLocations
global function SpawnSystem_SortSpawnsByMetaData
global LocPair &g_waitingRoomPanelLocation

global function SetCallback_FlowstateSpawnsOffset
global function AddCallback_FlowstateSpawnsSettings
global function AddCallback_FlowstateSpawnsPostInit

global function SpawnSystem_SetCustomPak
global function SpawnSystem_SetCustomPlaylist
global function SpawnSystem_SetPreferredPak
global function SpawnSystem_SetRunCallbacks
global function SpawnSystem_SetPanelLocation
global function SpawnSystem_SetMetaDataHandler

global function SpawnSystem_GetCurrentSpawnSet
global function SpawnSystem_GetCurrentSpawnAsset
global function SpawnSystem_CreateSpawnObject
global function SpawnSystem_CreateSpawnObjectArray
global function SpawnSystem_FindBaseMapForPak
global function SpawnSystem_GenerateRandomSpawns

global function SpawnSystem_SetValidateSpawnsOnLoad
global function SpawnSystem_CreateLocPairObject
global function SpawnSystem_GetPakInfoForKey

#if DEVELOPER
	global function DEV_SpawnType
	global function DEV_AddSpawn
	global function DEV_PrintSpawns
	global function DEV_DeleteSpawn
	global function DEV_DeleteLast
	global function DEV_ClearSpawns
	global function DEV_TeleportToSpawn
	global function DEV_WriteSpawnFile
	global function DEV_SpawnHelp
	global function DEV_SetTeamCount
	global function DEV_TeleportToPanels
	global function DEV_LoadPak
	global function DEV_HighlightAll
	global function DEV_Highlight
	global function DEV_KeepHighlight
	global function DEV_PanelInfo
	global function DEV_ReloadInfo
	global function DEV_InfoPanelOffset
	global function DEV_RotateInfoPanels
	global function DEV_ShowCenter
	global function DEV_ValidateSpawn
	global function DEV_AutoDeleteInvalid
	global function DEV_GetSpawn
	global function DEV_SimulateRing
	global function DEV_KillRing
	global function DEV_SetRingSettings
	global function DEV_RingSettings
	global function DEV_RingInfo
	global function DEV_AutoSimulateRing
	global function DEV_SetAutoSave
	global function DEV_PrintSettings
	global function DEV_AutoSetInfo
	global function DEV_SetSpawnInfo
	global function DEV_SpawnsPlaylist
	global function DEV_SpawnsBaseMap
	
	const float HIGHLIGHT_SPAWN_DELAY 	= 7.0
	const int SPAWN_POSITIONS_BUDGET 	= 210
	const float DOOR_SCAN_RADIUS		= 100
	const bool DEBUG_SPAWN_TRACE		= true
	const int MAX_SPAWN_INFO_LENGTH	= 255
	const string FILE_NAME_REGEX		= "^[A-Za-z0-9._\\-]+$"
	
	const bool REMOVE 	= true 
	const bool LOAD 		= false
#endif 

	global struct LocPairData
	{
		array<LocPair> spawns
		LocPair ornull waitingRoom = null
		LocPair ornull panels = null
		bool bOverrideSpawns = false
		array<table> metaData
	}
	
	global struct SpawnData
	{
		LocPair& 		spawn
		string 			info
		int				id = -1
	}
	
	const int MASTER_PANEL_ORIGIN_OFFSET = 400
	const int MAX_GENERATE_RANDOM_ATTEMPTS = 2000
	const bool OVERIDE_VERIFY_SPAWNS = false //set this to always skip hullcheck fails for all spawns not just ones marked as "OOB"
	
	struct
	{
		array<LocPairData functionref()> onSpawnInitCallbacks
		array<void functionref()> spawnSettingsCallbacks
		LocPair functionref() mapGamemodeBasedOffsetFunc = null
		void functionref( SpawnData ) PakMetaDataHandler = null
		
		table<string,string> pakData = {}
		int preferredSpawnPak 	= 1
		string currentSpawnPak 	= ""
		string customSpawnpak 	= ""
		string customPlaylist 	= ""
		int iTeamCount 			= 2
		bool bOverrideSpawns 	= false	
		bool bSpawnsInitialized = false
		bool bRunCallbacks 		= true
		bool bValidateSpawns	= true
		
		#if DEVELOPER
			LocPair &panelsloc
			array<string> dev_positions = []
			string dev_positions_type = ""
			array<string> validPosTypes = ["sq","csv"]
			array<LocPair> dev_positions_LocPair = []
			bool bHighlightToggleAll = false
			bool bHighlightPersistent = true
			table<int,entity> allBeamEntities = {}
			bool bSpawnInfoPanels = true
			array< table<vector, string> > savedSpawnInfosExtendedArray
			vector infoPanelOffset = ZERO_VECTOR
			vector infoPanelOffsetAngles = ZERO_VECTOR
			bool bInfoPanelsAreReloading = false
			table signalDummy
			bool bValidatorRunning = false
			int iValidatorTracker = 1
			bool bAutoDelInvalid = false
			int maxIndentNeeded = 93 //auto generated on script init. 
			entity dummyEnt
			bool autoSimulateRing = false
			bool bAutoSave = false
			bool bFirstTimeUse = true
			string spawnSetName = ""
			string spawnsPlaylist = ""
			string spawnsMap = ""
			array<int> deleteEventsQueue
			
			table<string,string> DEV_POS_COMMANDS = 
			{
					[" script DEV_SpawnHelp()"] = "Prints this help msg...",
					[" script DEV_PrintSettings()"] = "Prints all current settings.",
					[" script DEV_PrintSpawns()"] = "Prints the current made spawn positions array [ called automatically for most operations ]",
					[".................."] = "",
					["...."] = "",
					[" ==== SETTINGS ===="] = "",
					["....."] = "",
					[" script DEV_SpawnsPlaylist( string playlist = \"\" ) "] = "Sets the playlist this spawn pak should load for. This will also automatically apply the values saved in the playlists_r5_patch.txt for the specified playlisst.",
					[" script DEV_SetAutoSave( bool value = true )"] = "Disabled by default. Make sure folder 'output' in r5reloaded/platform exists",
					[" script DEV_LoadPak( string pak = \"\", string playlist = \"\" )"] = "Loads spawn pak specifying rpak asset and playlist. If none provided, loads current pak. If custom spawns are wrote into the script test function, it loads those instead.",
					[" script DEV_SpawnType( string setToType = \"\" )"] = "Params: \"csv\" or \"sq\" Sets/Converts the current array of print outs to specified type, and further additions are added as the specified type. Returns the current type if no parameters are provided. ( call with printt() )",
					[" script DEV_SetTeamCount( int size )"] = "Sets the count of teams per spawn set formatting the PrintSpawns() array",
					[" script DEV_PanelInfo( bool setting = true )"] = "true/false, sets whether info panels show or not. On by default.",
					[" script DEV_InfoPanelOffset( vector offset = <0, 0, 600>, vector anglesOffset = <0, 0, 0> )"] = "Modify the offset of info panels. Call with no parameters to raise into sky by 600. Reloads all info panels.",
					[" script DEV_AutoDeleteInvalid( bool setting = true )"] = "Set spawn tool to auto delete bad spawns on creation. Disavled by default",
					[" script DEV_AutoSetInfo( string info = \"\" )"] = "Defines a custom spawn set name or info to automatically use when creating spawns if not specified during DEV_AddSpawn(). Call with nothing to empty/disable. System automatically names spawns based on index otherwise.",
					[" script DEV_KeepHighlight( bool setting = true )"] = "Sets whether spawn highlight stays after adding spawn.",
					[" script DEV_SpawnsBaseMap( string baseMap = \"\", bool bIgnoreInvalid = false )"] = "Sets the base map the spawn system will use for coordinate data ( is set automatically based on loaded map )",
					["......"] = "",
					["......."] = "",
					[" ==== MAIN SPAWN FUNCTIONS ===="] = "",
					["........"] = "",
					[" script DEV_AddSpawn( string pid, string info = \"\", int replace = -1 )"] = "Pass a player name/uid to have the current origin/angles of player appended to spawns array. Give spawn meta data, uses provided DEV_AutoSetInfo() if none specified. If replace is specified, replaces the given index with new spawn, otherwise, the operation is append.",
					[" script DEV_SetSpawnInfo( int index, string info = \"\" )"] = "Set spawn info on an already present spawn by index.",
					[" script DEV_DeleteSpawn( int index )"] = "Deletes a spawn from array by index",
					[" script DEV_DeleteLast()"] = "Deletes last placed spawn",
					[" script DEV_ClearSpawns( bool clearHighlights = true )"] = "Deletes all saved spawns. If passed false, does not remove highlights on map",
					["........"] = "",
					["........."] = "",
					[" ==== UTILITY ===="] = "",
					[".........."] = "",
					[" script DEV_TeleportToSpawn( string pid, int index )"] = "Teleport specified player by name/uid to a saved spawn by index",
					[" script DEV_TeleportToPanels( playerName/uid )"] = "Teleports player to panel locations",
					[" script DEV_ValidateSpawn( int index = -1, bool remove = false, player = null )"] = "Validates a given spawn or all if -1 is passed. Removes each invalid if true passed. Optionally pass a player to check mins/maxes",
					[" script DEV_RotateInfoPanels( string direction = \"clockwise\" )"] = "Rotate info panels in the event ids are not clearly visible. Reloads panels.",
					[" script DEV_ReloadInfo()"] = "Manually reload all info panels.",
					[" script DEV_HighlightAll()"] = "Shows/Removes beams of light on all spawns in the PosArray",
					[" script DEV_Highlight( int index, bool persistent = false )"] = "Highlight a single spawn by spawn index. Called automatically on spawn add. If persistent is not provided beam destroys after " + HIGHLIGHT_SPAWN_DELAY + " seconds. Set with DEV_KeepHighlight()",
					[" script DEV_GetSpawn( int index )"] = "Returns lockpair object for given spawn. Indexed into with .origin and .angles such as script printt( DEV_GetSpawn(0).origin )",
					[" script DEV_ShowCenter( int set )"] = "Shows the calculated center of a set that would be calculated automatically in a game mode based on teams per spawn set.",
					["..........."] = "",
					["............"] = "",
					[" ==== GENERATE FILE ===="] = "",
					["............."] = "",
					[" script DEV_WriteSpawnFile( type = \"\" )"] = "Write current locations to file in the current format or specified format ( csv || sq ), use printt( DEV_SpawnType() ) to see current type.",
					[".............."] = "",
					["..............."] = "",
					["................"] = "",
					[" ==== RING SIMULATOR ===="] = "",
					["................."] = "",
					[" script DEV_RingSettings()"] = "Call to see available settings for ring simulation",
					[" script DEV_SetRingSettings( table<string, float> settings )"] = "Set test settings for ring brhavior. Use { setting = value, setting2 = value }. Call DEV_RingSettings() for available settings.",
					[" script DEV_AutoSimulateRing( bool ornull bSetting = null )"] = "Auto simulate ring on spawn set creation. Calling empty returns current setting",
					[" script DEV_SimulateRing( int spawnSet, bool loop = false )"] = "Start ring simulation for given spawnset. Optional enable looping passing true as second paramater.",
					[" script DEV_KillRing( int spawnSet = -1, bool instantly = true, bool keepLooping = false )"] = "Kills ring simulation by spawnSet or -1 for all, optionally let ring complete, and keep looping",
					[" script DEV_RingInfo( bool bActiveOnly = true )"] = "Print active/all available ring struct info to console."
			}
		#endif

	} file 
	
	struct 
	{
		table<string,bool> spawnOptions = {}
		bool bOptionsAreSet = false
		
	} settings
	
	#if DEVELOPER 
	struct RingInfo
	{
		string identifier	= "_invalid"
		entity ringEnt		= null
		int spawnSet 		= -1
		bool loopSetting 		= false
		vector center 		= ZERO_VECTOR
		float radius
		float closeMaxTime
	}
	#endif 

void function Flowstate_SpawnSystem_Init()
{
	#if DEVELOPER 
		RegisterSignal( "DelayedHighlightActivate" )
		RegisterSignal( "RunValidatorIfWaiting" )
		RegisterSignal( "IsSpawnValidStatus" )
		RegisterSignal( "EventDeleteQueued" )
		
		CalculateMaxIndent()
		InitClonedSettings()
		AutoSetupSettings()
		thread __DeleteThread()
		
		SpawnSystem_SetValidateSpawnsOnLoad( false )
	#endif
}

void function AddCallback_FlowstateSpawnsSettings( void functionref() callbackFunc )
{
	mAssert( !file.spawnSettingsCallbacks.contains( callbackFunc ), "Tried to add callback Func " + string( callbackFunc ) + "() with " + FUNC_NAME() + " but was already added" )
	mAssert( !settings.bOptionsAreSet, "Tried to add callbackFunc " + string( callbackFunc ) + "() but options were already loaded in " + FILE_NAME() )
	
	file.spawnSettingsCallbacks.append( callbackFunc )
}

void function Flowstate_SpawnSystem_InitGamemodeOptions()
{
	mAssert( !settings.bOptionsAreSet, "Flowstate_SpawnSystem_InitGamemodeOptions() was called more than once." )
	
	bool use_sets 				= GetCurrentPlaylistVarBool( "spawnpaks_use_sets", false )
	bool use_random 			= GetCurrentPlaylistVarBool( "spawnpaks_use_random", false )
	bool prefer 				= GetCurrentPlaylistVarBool( "spawnpaks_prefer", false )
	bool use_custom_playlist 	= GetCurrentPlaylistVarBool( "spawnpaks_playlist_override", false )
	int preferred 				= GetCurrentPlaylistVarInt( "spawnpaks_preferred_pak", 1 )
	string customRpak 			= GetCurrentPlaylistVarString( "custom_spawnpak", "" )
	string customSpawnPlaylist	= GetCurrentPlaylistVarString( "custom_playlist_spawnpak", "" )
	
	settings.spawnOptions[ "use_sets" ] 			<- use_sets
	settings.spawnOptions[ "use_random" ] 			<- use_random
	settings.spawnOptions[ "prefer" ] 				<- prefer
	settings.spawnOptions[ "use_custom_rpak" ] 		<- SpawnSystem_SetCustomPak( customRpak ) //returns 0 on failed rpak
	settings.spawnOptions[ "use_custom_playlist" ] 	<- use_custom_playlist
	
	if( use_custom_playlist && !empty( customSpawnPlaylist ) )
		SpawnSystem_SetCustomPlaylist( customSpawnPlaylist )
	
	if( preferred > 1 )
	{
		SpawnSystem_SetPreferredPak( preferred )
		#if DEVELOPER
			printt( "Preferred spawnpak set to:", preferred )
		#endif 
	}
	
	foreach ( callbackFunc in file.spawnSettingsCallbacks )
		callbackFunc()
	
	settings.bOptionsAreSet = true
}

array<SpawnData> function SpawnSystem_ReturnAllSpawnLocations( int eMap, table<string,bool> options = {} )
{
	mAssert( settings.bOptionsAreSet, "Tried to fetch spawns without first running Flowstate_SpawnSystem_InitGamemodeOptions()" )
	
	if( !ValidateOptions( options ) )
	{
		options = settings.spawnOptions
		
		#if DEVELOPER
			foreach( setting, value in options )
			{
				printt( "Setting:", setting, " Value:", value )
			}
		#endif
	}
		
	string defaultpak = "_set_1";
	string spawnSet = defaultpak
	string customRpak = "";
	
	if ( options.len() >= 5 && ValidateOptions( options ) )
	{
		if( options.use_custom_rpak )
		{
			customRpak = file.customSpawnpak
		}
		else 
		{
			if( options.use_sets )
			{
				string mapSpawnString = "spawnsets_" + AllMapsArray()[ MapName() ]
				string currentMapSpawnSets = GetCurrentPlaylistVarString( mapSpawnString, "" )
				
				array<string> setpaks = []
				bool success = false
				
				if( empty( currentMapSpawnSets ) )
				{
					Warning( "options.use_sets was set but no paks were specified for \"" + mapSpawnString + "\" in playlist. Using default pak instead" )
					spawnSet = defaultpak
					success = false
				}
				else 
				{
					try
					{
						setpaks = StringToArray( currentMapSpawnSets )
						for( int i = 0; i < setpaks.len(); i++ )
						{
							if( !IsNumeric( setpaks[i] ) )
							{
								throw " error: " + setpaks[i] + " is not numeric..";
							}
							setpaks[i] = "_set_" + setpaks[i];
						}
						success = true
					}
					catch(e)
					{
						Warning( "Warning: " + e )
						
						spawnSet = defaultpak
						success = false
					}
				}
				
				if( success )
				{
					string prefferred = "_set_" + string ( file.preferredSpawnPak )
					if( options.prefer && setpaks.contains( prefferred ) )
					{
						int j = setpaks.find( prefferred )			
						if( j == -1 )
						{
							Warning( "Preferred spawnpak: " + prefferred + " not found!" )
							spawnSet = defaultpak
						}
						else
						{
							spawnSet = setpaks[j]
						}	
					}
					else if( options.use_random )
					{
						spawnSet = setpaks.getrandom()
					}
					else 
					{
						printt( "spawnpaks: Use sets was enabeld with no valid options in playlists" )
					}
				}
			}
		} //custom rpak override
	}
	else 
	{
		mAssert( false, "Spawn options were incorrectly configured" )
	}
	
	return FetchReturnAllLocations( eMap, spawnSet, customRpak, file.customPlaylist )
}

LocPairData function SpawnSystem_CreateLocPairObject( array<LocPair> spawns, bool bOverrideSpawns = false, LocPair ornull waitingRoom = null, LocPair ornull panels = null, array<table> ornull propertiesOrNull = null )
{
	LocPairData data
	
	data.spawns = spawns
	data.bOverrideSpawns = bOverrideSpawns
	
	if( bOverrideSpawns && spawns.len() == 0 )
		mAssert( false, "Cannot override spawns with empty array of spawns" )
	
	if( propertiesOrNull != null )
		data.metaData = expect array<table> ( propertiesOrNull )

	if ( waitingRoom != null )
	{
		#if DEVELOPER
			Warning( "LocPairData object set to override waitingroom location in " + FUNC_NAME() + "()" )
		#endif
		
		LocPair varWaitingRoom = expect LocPair ( waitingRoom )
		data.waitingRoom = varWaitingRoom
	}
	
	if( panels != null )
	{
		#if DEVELOPER 
			Warning( "LocPairData object set to override panel location in " + FUNC_NAME() + "()" )
		#endif 
		
		LocPair varPanels = expect LocPair ( panels )
		data.panels = varPanels
	}
	
	return data
}

void function AddCallback_FlowstateSpawnsPostInit( LocPairData functionref() callbackFunc )
{
	if( file.onSpawnInitCallbacks.contains( callbackFunc ) )
	{
		Warning("Tried to add callbackk with " + FUNC_NAME() + " but function " + string( callbackFunc ) + " already exists in [onSpawnInitCallbacks]")
		return
	}
	
	mAssert( !file.bSpawnsInitialized, "Tried to add spawns init function " + string( callbackFunc ) + " but spawns are already initialized " )
	
	file.onSpawnInitCallbacks.append( callbackFunc )
}


///////////////////////////////////////////////////////////////mkos///////
//																		//
//	All spawn locations are contained in their 							//
//	appropriate paks designated by playlist, mapname, and set.			//
//																		//
// set = a string that differentiates between sets of spawns. _set_#	//
// ( host can cycle spawnsets or choose a static set to always use )	//
//																		//
// The string for a pak should look like:								//
//__________________________________________________________			//
// prefix   | playlist     | map name            |set number|			//
//			|			   |					 |			|			//
// fs_spawns_fs_lgduels_1v1_mp_rr_arena_composite_set_1.rpak|			//
//```````````````````````````````````````````````````````````			//
// 																		//
//////////////////////////////////////////////////////////////////////////

array<SpawnData> function GenerateCustomSpawns( int eMap, int coreSpawnsLen = -1 )
														//waiting room + extra spawns
{														//ideally only default waiting
	array<SpawnData> customSpawns = []					// rooms are saved here. use :
														// AddCallback_FlowstateSpawnsPostInit()
														// to create custom spawns for your gamemode 
	LocPair defaultWaitingRoom
	
	switch( eMap )
	{
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_aqueduct:
			
			defaultWaitingRoom = NewLocPair( < 705, -5895, 432 >, < 0, 90, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
			
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_arena_composite:
		
			defaultWaitingRoom = NewLocPair( < -2.46021, 291.152, 129.574 >, < 0, 90, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom, <0,0,-5> )
			
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_canyonlands_64k_x_64k:
		
			defaultWaitingRoom = NewLocPair( < -906.22, 20306.5, 4570.03 >, < 0, 45, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_canyonlands_staging: 
		
			defaultWaitingRoom = NewLocPair( < 3477.69, -8364.02, -10252 >, < 356.203, 269.459, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_party_crasher:
		
			defaultWaitingRoom = NewLocPair( < 1881.75, -4210.87, 626.106 >, < 359.047, 104.246, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom, ZERO_VECTOR, 300 )		
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////	
		case eMaps.mp_rr_arena_phase_runner:
		
			defaultWaitingRoom = NewLocPair( < 31969, 17534, -884 >, < 360, 178, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
			
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////	
		case eMaps.mp_rr_arena_skygarden:
		
			defaultWaitingRoom = NewLocPair( < -7.8126, -1320.75, 2877.51 >, < 359.849, 270.32, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_olympus_mu1:

			defaultWaitingRoom = NewLocPair( < 318.434906, -19474.4141, -4947.88867 > , < 0, 32.8506927, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )	
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_desertlands_64k_x_64k:

			defaultWaitingRoom = NewLocPair( < -19830.3633, 14081.7314, -3759.98901 >, < 0, -83.0441132, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )	
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		case eMaps.mp_rr_canyonlands_mu2:
		
			defaultWaitingRoom = NewLocPair( < -915.356, 20298.4, 4570.03 >, < 3.22824, 44.1054, 0 > )
			g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////
		
		default:
		
			entity spawnstart = GetEnt( "info_player_start" )
			
			if( IsValid( spawnstart ) )
			{
				#if DEVELOPER
					Warning( "Warning: No default spawn provided. Setting initial player spawn from map's info_player_start ent" )
				#endif
				
				defaultWaitingRoom = NewLocPair( spawnstart.GetOrigin(), spawnstart.GetAngles() )
				g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( defaultWaitingRoom )
			}
			else 
			{
				mAssert( false, "No valid player start spawn detected \n If this is intentional disable this Assert." )
				Warning( "No valid player start spawn detected" )
			}
		
		break ////////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////////////		
	}//: Switch (eMap)
	
	#if DEVELOPER //for timing tests
		printt(" --- CALLING CUSTOM SPAWN CALLBACKS --- ")
	#endif
	//add with AddCallback_FlowstateSpawnsPostInit( functionref ) 
	//  function ref should return a LocPairData data object
	if( file.bRunCallbacks )
	{
		foreach( callbackFunc in file.onSpawnInitCallbacks )
		{
			LocPairData data = callbackFunc()
			
			if ( data.spawns.len() > 0 )
			{
				if( data.bOverrideSpawns )
				{
					#if DEVELOPER 
						Warning("Spawns overriden with custom spawns - count: [" + string( data.spawns.len() ) + "]" )
					#endif 
					
					customSpawns = SpawnSystem_CreateSpawnObjectArray( data.spawns, data.metaData )
					file.bOverrideSpawns = true
				}
				else 
				{
					#if DEVELOPER 
						Warning("Spawns extended with custom spawns - count: [" + string( data.spawns.len() ) + "]" )
					#endif 
					
					customSpawns.extend( SpawnSystem_CreateSpawnObjectArray( data.spawns, data.metaData, coreSpawnsLen ) )
				}	
			}
				
			if( data.waitingRoom != null )
			{
				LocPair varWaitingRoom = expect LocPair( data.waitingRoom )
				g_waitingRoomPanelLocation = SetWaitingRoomAndGeneratePanelLocs( varWaitingRoom )
			}
			
			if( data.panels != null )
			{
				LocPair varPanels = expect LocPair( data.panels )
				g_waitingRoomPanelLocation = NewLocPair( varPanels.origin, varPanels.angles )
			}
		}
	}
	
	file.bSpawnsInitialized = true
	
	return customSpawns
}


LocPair function SetWaitingRoomAndGeneratePanelLocs( LocPair defaultWaitingRoom, vector panelOffset = <0,0,0>, int panelDistance = MASTER_PANEL_ORIGIN_OFFSET, vector originOffset = <0,0,0>, vector anglesOffset = <0,0,0> )
{
	LocPair defaultPanels
	
	vector panelsOffset = < defaultWaitingRoom.origin.x, defaultWaitingRoom.origin.y, defaultWaitingRoom.origin.z > + panelOffset
	vector endPos = defaultWaitingRoom.origin + ( AnglesToForward( defaultWaitingRoom.angles ) * panelDistance ) //ty zee
	
	defaultPanels = NewLocPair( <endPos.x, endPos.y, panelsOffset.z >, defaultWaitingRoom.angles )
	
	#if DEVELOPER
		file.panelsloc = defaultPanels
	#endif
	
	getWaitingRoomLocation().origin = defaultWaitingRoom.origin + originOffset
	getWaitingRoomLocation().angles = defaultWaitingRoom.angles + anglesOffset
	
	return defaultPanels
}

void function SetCallback_FlowstateSpawnsOffset( LocPair functionref() callbackFunc )
{
	mAssert( file.mapGamemodeBasedOffsetFunc == null, "Tried to set " + string( callbackFunc ) + " in mapGamemodeBasedOffsetFunc but func was already set to " + string( file.mapGamemodeBasedOffsetFunc ) + " in " + FUNC_NAME(2) + "()" )
	file.mapGamemodeBasedOffsetFunc = callbackFunc 
}

LocPair function GenerateMapGamemodeBasedOffset()
{
	if( file.mapGamemodeBasedOffsetFunc != null )
		return file.mapGamemodeBasedOffsetFunc()
	
	return NewLocPair( ZERO_VECTOR, ZERO_VECTOR )
}

string function GenerateAssetStringForMapAndGamemode( int eMap, string set, string customRpak = "", string playlistOverride = "" )
{
	string spawnset = ""
	
	if ( !empty( customRpak ) )
	{
		#if DEVELOPER 
			printt("Custom spawns rpak is defined and set to be used: ", customRpak )
		#endif 
		spawnset = customRpak
	}
	else 
	{
		string dtbl_MapRef 			= AllMapsArray()[ eMap ]
		string dtbl_PlaylistRef 	= AllPlaylistsArray()[ Playlist() ]
		
		//pre conditionals
		if ( !empty( playlistOverride ) )
		{
			#if DEVELOPER 
				printt( "Using playlist override ref", playlistOverride, "to load spawn set." )
			#endif 
			dtbl_PlaylistRef = playlistOverride
		}
		
		// set spawnset
		spawnset 					= "datatable/fs_spawns_" + dtbl_PlaylistRef + "_" + dtbl_MapRef + set + ".rpak"		
	}
	
	file.currentSpawnPak = spawnset
	return spawnset
}

array<SpawnData> function FetchReturnAllLocations( int eMap, string set = "_set_1", string customRpak = "", string customPlaylist = "" )
{
	array<SpawnData> allSoloLocations
	
	try
	{
		string spawnset 	= GenerateAssetStringForMapAndGamemode( eMap, set, customRpak, customPlaylist )
		
		LocPair offsets 	= GenerateMapGamemodeBasedOffset()
		vector originOffset = offsets.origin
		vector anglesOffset = offsets.angles
		
		asset fetchasset 	= CastStringToAsset( spawnset )
		var datatable 		= GetDataTable( fetchasset )	
		
		int spawnsCount 	= GetDatatableRowCount( datatable )
		int originCol 		= GetDataTableColumnByName( datatable, "origin" )
		int anglesCol 		= GetDataTableColumnByName( datatable, "angles" )
		int nameCol			= GetDataTableColumnByName( datatable, "name" )
		int infoCol			= GetDataTableColumnByName( datatable, "info" )
		
		
		bool verify = 
		(
			originCol != -1 && 
			anglesCol != -1
		)
		
		mAssert( verify, "Loaded spawn rpak is an invalid format." )
		
		#if DEVELOPER
			string print_data = "\n\n spawnset: " + spawnset + "\n--- LOCATIONS ---\n\n"
		#endif
		
		int classCol = infoCol != -1 ? infoCol : nameCol	
		for ( int i = 0; i < spawnsCount; i++ )
		{		
			string info   = GetDataTableString( datatable, i, classCol )
			
			if( info.find( "pakData." ) != -1 )
			{
				if( info.find( ":" ) != -1 )
				{
					__ResolveAndSetPakData( info )
					continue
				}
			}
			
			vector origin = GetDataTableVector( datatable, i, originCol ) + originOffset
			vector angles = GetDataTableVector( datatable, i, anglesCol ) + anglesOffset
			
			#if DEVELOPER
				print_data += "Found origin: " + VectorToString( origin ) + " angles: " + VectorToString( angles ) + " SpawnInfo: " + info + "\n"	
			#endif
			
			
			if( OVERIDE_VERIFY_SPAWNS || file.bValidateSpawns && info != "OOB" && !CheckSpawn( origin ) )
				mAssert( false, "OOB spawn at origin " + VectorToString( origin ) + " index: " + ( allSoloLocations.len() - 1 ) )
			
			SpawnData spawnInfo = SpawnSystem_CreateSpawnObject( NewLocPair( origin, angles ), info, i )
			allSoloLocations.append( spawnInfo )
			
			//gamemode sets with SpawnSystem_SetMetaDataHandler
			if( file.PakMetaDataHandler != null )
				file.PakMetaDataHandler( spawnInfo )
		}
		#if DEVELOPER 
			printt( print_data )
			printt("Unpacked [",allSoloLocations.len()," ] spawn locations from locations asset.")
		#endif 
	}
	catch(e)
	{
		sqerror( "Error: " + e )
	}
	
	array<SpawnData> extraSpawnLocations = GenerateCustomSpawns( eMap, allSoloLocations.len() )
	
	if( extraSpawnLocations.len() > 0 )
	{
		if( file.bOverrideSpawns )
		{
			allSoloLocations = extraSpawnLocations
		}
		else 
		{
			allSoloLocations.extend( extraSpawnLocations )
			#if DEVELOPER
				printt("Added: [",extraSpawnLocations.len(),"] locations from custom spawns.")
			#endif 
		}
		
		#if DEVELOPER
			string print_sdata = ""
				foreach( spawnInfo in extraSpawnLocations )
				{
					print_sdata += "Found origin: " + VectorToString( spawnInfo.spawn.origin ) + " angles: " + VectorToString( spawnInfo.spawn.angles ) + " Info: " + spawnInfo.info + "\n"	
				}
			printt( "\n\n" + print_sdata )
		#endif
	}
	
	return allSoloLocations
}

//util

SpawnData function SpawnSystem_CreateSpawnObject( LocPair spawn, string info, int id = -1 )
{
	SpawnData spawnInfo
	
	spawnInfo.spawn = spawn
	spawnInfo.info 	= info
	
	if( id != -1 )
		spawnInfo.id = id
	
	return spawnInfo
}

array<SpawnData> function SpawnSystem_CreateSpawnObjectArray( array<LocPair> spawns, array<table> ornull propertiesOrNull = null, int coreSpawnsLen = -1 )
{
	bool bGenDefault = true
	table properties = {}
	array<table> propertiesArray = []
	int spawnsLen = spawns.len()
	
	bool bStartFromCoreLength = ( coreSpawnsLen > 0 )
	
	if( propertiesOrNull != null && expect array<table> ( propertiesOrNull ).len() > 0 )
	{
		propertiesArray = expect array<table> ( propertiesOrNull )	
		int propertiesArrayLen = propertiesArray.len()
			
		mAssert( propertiesArrayLen == 0 || spawnsLen == propertiesArrayLen, "Tried to create a spawn object array but specified properties table does not match the number of elements passed in the LocPair array." )
	}
	else
	{
		for( int i = 0; i < spawnsLen; i++ )
			propertiesArray.append( {} )
			
		mAssert( spawnsLen == propertiesArray.len(), "spawnsLen != propertiesArray" )
	}
	
	array<SpawnData> spawnInfoArray = []

	int iter = 0
	foreach( tableData in propertiesArray )
	{	
		if( tableData.len() == 0 )
			tableData = GenerateDefaultSpawnData()
		
		SpawnData spawnInfo
		
		spawnInfo.spawn = spawns[ iter ]
		spawnInfo.id	= bStartFromCoreLength ? coreSpawnsLen + iter : iter
		
		if( "info" in tableData ) //before "name" for backwards compat.
		{
			if( tableData[ "info" ] != null )
				spawnInfo.info = expect string( tableData[ "info" ] )
		} 
		else if( "name" in tableData )
		{
			if( tableData[ "name" ] != null )
				spawnInfo.info = expect string( tableData[ "name" ] )
		}	
		
		spawnInfoArray.append( spawnInfo )
		
		iter++
	}
	
	return spawnInfoArray
}

table function GenerateDefaultSpawnData()
{
	return { info = "spawn" }
}

bool function ValidateOptions( table<string,bool> options )
{
	return ( 
		"use_sets" 				in options &&
		"use_random" 			in options &&
		"prefer"				in options &&
		"use_custom_rpak"		in options &&
		"use_custom_playlist" 	in options
	)
}

void function SpawnSystem_SetPreferredPak( int preference )
{
	mAssert( preference > 0, "Invalid spawn pak preference" )
		file.preferredSpawnPak = preference
}

bool function SpawnSystem_SetCustomPak( string custom_rpak )
{
	bool success = false
	
	if( !empty( custom_rpak ) )
	{
		try 
		{
			asset test = CastStringToAsset( custom_rpak )
			GetDataTable( test )
			success = true
		}
		catch(e)
		{
			Warning( "Custom Rpak Error: " + e )
			Warning( "Skipping custom spawn rpak" )
		}
		
		if( success )
		{
			file.customSpawnpak = custom_rpak
			settings.spawnOptions[ "use_custom_rpak" ] = true
		}
	}
	
	return success
}

void function SpawnSystem_SetCustomPlaylist( string playlistref )
{
	if( AllPlaylistsArray().contains( playlistref ) )
	{
		file.customPlaylist = playlistref
		settings.spawnOptions[ "use_custom_playlist" ] <- true
	}
	else 
	{
		Warning( "Tried to specify custom playlist for spawn pak, but playlist \"" + playlistref + "\" doesn't exist." )
	}
}

string function SpawnSystem_GetCurrentSpawnSet()
{
	return file.currentSpawnPak
}

asset function SpawnSystem_GetCurrentSpawnAsset()
{
	asset returnAsset = $""
	
	try 
	{
		returnAsset = CastStringToAsset( file.currentSpawnPak )
		GetDataTable( returnAsset )
	}
	catch(e)
	{
		Warning( "Warning -- cast failed: " + e )
	}
	
	return returnAsset
}

int function SpawnSystem_FindBaseMapForPak( int eMap )
{
	switch( eMap )
	{
		case eMaps.mp_rr_desertlands_64k_x_64k_nx:
		case eMaps.mp_rr_desertlands_64k_x_64k_tt:
			return eMaps.mp_rr_desertlands_64k_x_64k
			
		case eMaps.mp_rr_canyonlands_mu1:
		case eMaps.mp_rr_canyonlands_mu1_night:
			return eMaps.mp_rr_canyonlands_64k_x_64k
			
		case eMaps.mp_rr_aqueduct_night:
			return eMaps.mp_rr_aqueduct
		
		default:
			return eMap
	}
	
	unreachable
}

array<LocPair> function SpawnSystem_GenerateRandomSpawns( vector origin, vector angles, float radius, float radiusScalar = 1.0, int amount = 10 ) //todo: radius towards origin optional param
{
	float radiusFrac = radius * radiusScalar
	
	array<vector> spawnOrigins
	int spawnsAdded
	int attempts
	
	while( spawnsAdded < amount )
	{
		vector spawnOrigin = GetRandom3DPointIn2DCircle( radiusFrac, origin )
		
		if( CheckSpawn( spawnOrigin ) )
		{
			spawnOrigins.append( spawnOrigin )
			spawnsAdded++
		}
		
		attempts++
		
		if( attempts > MAX_GENERATE_RANDOM_ATTEMPTS )
			break
	}
	
	if( !spawnOrigins.len() )
	{
		LocPair failed
		
		failed.origin = origin 
		failed.angles = angles 
		
		return [ failed ]
	}
	
	array<LocPair> generatedSpawns
	
	foreach( vector randomOrg in spawnOrigins )
	{
		LocPair point
		
		point.origin = randomOrg 
		point.angles = angles
		
		generatedSpawns.append( point )
	}
	
	return generatedSpawns
}

bool function CheckSpawn( vector origin )
{
	vector mins = <-16, -16, 0>
	vector maxs = <16, 16, 72>
	
	TraceResults result = TraceHull( origin, origin + <0, 0, 1>, mins, maxs, null, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )

	if ( result.startSolid )
		return false

	bool traceFinalResult = result.fraction == 1.0
	
	return traceFinalResult
}

void function SpawnSystem_SetRunCallbacks( bool setting )
{
	file.bRunCallbacks = setting
}

void function SpawnSystem_SetPanelLocation( vector origin, vector angles )
{
	AddCallback_FlowstateSpawnsPostInit
	(
		LocPairData function() : ( origin, angles )
		{
			LocPair panels = NewLocPair( origin, angles )
			return SpawnSystem_CreateLocPairObject( [], false, null, panels )
		}
	)
}

void function __ResolveAndSetPakData( string info )
{
	array<string> kvFrac = split( info, "." )
	array<string> keyValue = split( kvFrac[ 1 ], ":" )	
	file.pakData[ keyValue[ 0 ] ] <- keyValue[ 1 ]	
}

string function SpawnSystem_GetPakInfoForKey( string key )
{
	if( key in file.pakData )
		return file.pakData[ key ]
		
	return "_NOTFOUND"
}

void function SpawnSystem_SetMetaDataHandler( void functionref( SpawnData ) processFunc )
{
	file.PakMetaDataHandler = processFunc
}

void function SpawnSystem_SetValidateSpawnsOnLoad( bool setting )
{
	file.bValidateSpawns = setting
}

table< string, array< SpawnData > > function SpawnSystem_SortSpawnsByMetaData( array<SpawnData> spawns )
{
	table< string, array< SpawnData > > sorted
	foreach( SpawnData data in spawns )
	{
		if( !( data.info in sorted ) )
			sorted[ data.info ] <- [ data ]
		else
			sorted[ data.info ].append( data )
	}
	
	#if DEVELOPER 
		DEV_PrintSortedSpawns( sorted )
	#endif 
	
	return sorted
}

//////////////////////////////////////////////////////////////////////
//						  DEVELOPER FUNCTIONS						//
//////////////////////////////////////////////////////////////////////

#if DEVELOPER

void function DEV_PrintSortedSpawns( table< string, array< SpawnData > > printSpawns )
{
	printw( "=== DEV_PrintSortedSpawns ===" )
	foreach( string setName, array<SpawnData> spawnDataz in printSpawns )
	{
		if( empty( setName ) )
			setName = "_EMPTY_CLASS"
			
		int count = 0
		printt( " " )
		printt( " " )
		printt( "=== Spawns for:", setName, "===" )	
		foreach( SpawnData data in spawnDataz )
		{		
			count++
			printt( count + ":", VectorToString( data.spawn.origin ), VectorToString( data.spawn.angles ) )
		}
	}
	
	printt( " " )
	printt( " " )
}

bool function IsValidSpawnIndex( int index )
{
	return index >= 0 && index < file.dev_positions.len()
}

void function __RemoveAllPanels()
{
	int toDelete = SpawnCount() + 2
	
	for( int i = 0; i < toDelete; i++ )
	{
		foreach( player in GetPlayerArray() )
		{
			RemovePanelText( player, i )
		}
	}
}

void function DEV_ReloadInfo()
{	
	if( !__bCheckReload() )
		return
	
	if( file.bSpawnInfoPanels )
	{
		printt( "Reloading info panels." )
		printm( "Reloading info panels." )
		__RemoveAllPanels()
		DEV_PrintSpawns( true )
	}
	else 
	{
		printt( "Info panels are disabled." )
		printm( "Info panels are disabled." )
	}
}

void function DEV_InfoPanelOffset( vector offset = <0, 0, 600>, vector angles = ZERO_VECTOR )
{
	file.infoPanelOffset = offset 
	file.infoPanelOffsetAngles = angles
	
	DEV_ReloadInfo()	
}

bool function __bCheckReload()
{
	if( file.bInfoPanelsAreReloading )
	{
		__ReloadWaitMsg()
	}
	else 
	{
		__ReloadingMsg()
	}
	
	return !file.bInfoPanelsAreReloading
}

void function __ReloadWaitMsg()
{
	string reloadMsg = " PANELS ARE STILL RELOADING \n\n please wait and try again... "
	
	printt( reloadMsg )
	printm( reloadMsg )
	
	foreach( player in GetPlayerArray() )
		LocalEventMsg( player, "", reloadMsg )
}

void function __ReloadingMsg()
{
	string reloading = " RELOADING PANELS "
	
	printt( reloading )
	printm( reloading )
	
	foreach( player in GetPlayerArray() )
	{
		LocalEventMsg( player, "", reloading )
	}
}

void function DEV_DeleteSpawn( int index )
{	
	if( IsValidSpawnIndex( index ) )
	{
		if( !__bCheckReload() )
		{
			__DispatchDeleteEvent( index )
			return
		}
		
		__RemoveAllPanels()
		
		GetSpawns().remove( index )
		file.dev_positions.remove( index )
		printt( "Removed spawn:", index )
		printm( "Removed spawn:", index )
		
		__DestroyHighlight( index )
		DEV_HighlightAll( REMOVE )
		DEV_HighlightAll( LOAD )	
		DEV_PrintSpawns( true )
		
		CheckAutoSave()
	}
	else 
	{
		printt( "Index", index, "was invalid and could not be removed." )
		printm( "Index", index, "was invalid and could not be removed." )
	}
}

void function __DeleteThread()
{
	for( ; ; )
	{
		WaitSignal( file.dummyEnt, "EventDeleteQueued" )
		
		{
			while( file.deleteEventsQueue.len() > 0 )
			{
				while( !__bCheckReload() )
					WaitFrame()
					
				int removeSpawnIndex = file.deleteEventsQueue.remove( 0 )
				DEV_DeleteSpawn( removeSpawnIndex )
			}
		}
	}
}

void function __DispatchDeleteEvent( int index )
{
	file.deleteEventsQueue.append( index )
	file.dummyEnt.Signal( "EventDeleteQueued" )
}

void function DEV_DeleteLast()
{
	DEV_DeleteSpawn( ( GetSpawns().len() - 1 ) )
}

void function DEV_PrintSpawns( bool bSyncInfoPanels = false )
{
	string printstring = "\n\n ----- POSITIONS ARRAY ----- \n\n"
	printm( "\n\n ----- POSITIONS ARRAY ----- \n\n" )
	
	array< table<vector,string> > spawnInfosList = []
	
	int spawnSetCount = 0
	
	if( file.dev_positions.len() > 0 )
	{		
		foreach( index, posString in file.dev_positions )
		{	
			table<vector,string> spawnInfos = {}
			string identifier = GetIdentifier( index, file.iTeamCount )
			
			if( IsNewSet( index ) || index == 0 )
			{
				string style = index > 1 ? "\n" : "";
				spawnSetCount++; 
				printstring += style + "Spawn set " + spawnSetCount + "\n############\n"
				printm( style + "Spawn set " + spawnSetCount + "\n############\n" )
			}
			
			spawnInfos[ < spawnSetCount, index, 0 > ] <- identifier
			spawnInfosList.append( spawnInfos )
			
			printstring += string( index ) + " = " + posString + " :Team: " + identifier + "\n";
			printm( string( index ) + " = " + posString + " :Team: " + identifier )
		}
	}
	else 
	{
		printstring += "~~none~~";
		printm( "~~none~~" )
	}
	
	if( file.bSpawnInfoPanels )
	{
		if( spawnInfosList.len() > 0 )
		{
			__LoopPanelDeletion( spawnInfosList, bSyncInfoPanels )
		}
	}
	
	printt( printstring )
}

bool function IsNewSet( int index )
{
	if( SpawnCount() < file.iTeamCount )
		return false 
		
	return ( index + 1 ) % file.iTeamCount == 1
}

void function __LoopPanelDeletion( array< table<vector, string> > spawnInfosListRef = [], bool bSyncInfoPanels = false )
{
	file.bInfoPanelsAreReloading = true
	
	thread( void function() : ( spawnInfosListRef, bSyncInfoPanels )
	{		
		array< table<vector, string> > spawnInfosList = []
		
		if( file.savedSpawnInfosExtendedArray.len() > 0 )
		{
			spawnInfosList = clone file.savedSpawnInfosExtendedArray
		}
		else 
		{
			spawnInfosList = clone spawnInfosListRef
		}
		
		array< table<vector, string> > spawnInfosArray
		array< table<vector, string> > spawnInfosExtendedArray
		
		bool bEnd = false
		int last = spawnInfosList.len() - 1
		
		if( spawnInfosList.len() > 10 )
		{
			spawnInfosArray = spawnInfosList.slice( 0, 9 ) //10 items
			file.savedSpawnInfosExtendedArray = spawnInfosList.slice( 9 )
			last = -1
		}
		else 
		{
			spawnInfosArray = spawnInfosList
			bEnd = true
		}
		
		foreach( int index, spawnInfos in spawnInfosArray )
		{	
			if( ( !bSyncInfoPanels && last != -1 && index == last ) || bSyncInfoPanels )
			{
				foreach( vector info, string identifier in spawnInfos )
				{
					//info.x = setcount, info.y = index
					waitthread __CreateInfoPanelForSpawn( int( info.x ), int( info.y ), identifier )
				}
			}
		}
		
		if( !bEnd )
		{
			__LoopPanelDeletionRecursive( bSyncInfoPanels )
		}
		else 
		{
			file.savedSpawnInfosExtendedArray.clear()
			file.bInfoPanelsAreReloading = false
		}
	})()
}

void function __LoopPanelDeletionRecursive( bool bSyncInfoPanels = false )
{
	__LoopPanelDeletion( [], bSyncInfoPanels )
}

array<string> letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];
const int LETTER_COUNT = 26

string function GetIdentifier( int index, int teamsize )
{
    int setIndex = index % teamsize
    int letterIndex = setIndex % LETTER_COUNT
    int cycle = setIndex / LETTER_COUNT
    return letters[letterIndex] + ( cycle > 0 ? cycle.tostring() : "" )
}

string function DEV_append_pos_array_squirrel( vector origin, vector angles, string info )
{	
	return "NewLocPair( < " + origin.x + ", " + origin.y + ", " + origin.z + " >, < " + angles.x + ", " + angles.y + ", " + angles.z + " > ), //\"" + info + "\"";	
}

string function DEV_append_pos_array_csv( vector origin, vector angles, string info )
{
	return "\"< " + origin.x + ", " + origin.y + ", " + origin.z + " >\",\"< " + angles.x + ", " + angles.y + ", " + angles.z + ">\" ,   \"" + info + "\"";
}

void function DEV_convert_array_to_csv_from_squirrel()
{
	for( int i = 0; i < file.dev_positions.len(); i++ )
	{	
		file.dev_positions[i] = StringReplaceLimited( file.dev_positions[i], "NewLocPair( < ", "\"< ", 1 )
		file.dev_positions[i] = StringReplace( file.dev_positions[i], " >, < ", ">\",\"< " )
		file.dev_positions[i] = StringReplace( file.dev_positions[i], " > ),", ">\" " )
		file.dev_positions[i] = StringReplaceLimited( file.dev_positions[i], "//", ",   ", 1 )	
	}
	
	printt("Converted current array to csv.")
	printm("Converted current array to csv.")
	DEV_PrintSpawns()
}

void function DEV_convert_array_to_squirrel_from_csv()
{
	for( int i = 0; i < file.dev_positions.len(); i++ )
	{
		file.dev_positions[i] = StringReplaceLimited( file.dev_positions[i], "\"< ", "NewLocPair( < ", 1 )
		file.dev_positions[i] = StringReplace( file.dev_positions[i], ">\",\"< " , " >, < " )
		file.dev_positions[i] = StringReplace( file.dev_positions[i], ">\" ", " > )," )
		file.dev_positions[i] = StringReplaceLimited( file.dev_positions[i], ",   ", "//", 1 )
	}
	
	printt("Converted current array to squirrel.")
	printm("Converted current array to squirrel.")
	DEV_PrintSpawns()
}

string function DEV_SpawnType( string setToType = "", bool bIgnorePrints = false )
{
	if ( !empty( setToType ) )
	{
		if ( file.validPosTypes.contains( setToType ) )
		{
			if( setToType == "csv" && DEV_SpawnType() == "sq" )
			{
				DEV_convert_array_to_csv_from_squirrel()
			}
			else if( setToType == "sq" && DEV_SpawnType() == "csv" )
			{
				DEV_convert_array_to_squirrel_from_csv()
			}
			else if( !empty( DEV_SpawnType() ) )
			{
				printt( "Type is already set to ", setToType )
				printm( "Type is already set to ", setToType )
				return file.dev_positions_type
			}
				
			file.dev_positions_type = setToType
			
			if( !bIgnorePrints )
			{
				printt("Spawn saving format was set to", "\"" + setToType + "\"" )
				printm("Spawn saving format was set to", "\"" + setToType + "\"" )
			}
		}
		else 
		{
			printt( "Invalid type [", setToType,"] specified." )
			printm( "Invalid type [", setToType,"] specified." )
			return file.dev_positions_type
		}
	}
	return file.dev_positions_type
}

void function DEV_AddSpawn( string ornull checkpid, string info = "", int replace = -1, LocPair ornull spawnPointOrNull = null )
{	
	entity player
	
	if( checkpid != null )
	{
		string pid = expect string( checkpid )
		
		if( empty( pid ) )
		{
			printt( "No player provided to first param of", FUNC_NAME() + "()" )
			printm( "No player provided to first param of", FUNC_NAME() + "()" )
			return
		}

		player = GetPlayer( pid )
	
		if( !IsValid( player ) )
		{
			printt( "Invalid player" )
			printm( "Invalid player" )
			return
		}
	}
	
	bool bUsePlayer = IsValid( player )
	string contextInfo = CheckFirstUse()
	
	if( empty( DEV_SpawnType() ) )
	{
		string txt = "\n\nNo type was set. Set type with DEV_SpawnType(\"csv\") or \"sq\" for squirrel code. Setting to squirrel code. \n"
		printt( txt )
		printm( txt )
		
		DEV_SpawnType( "sq" )
	}
	
	int currentSpawnCount = SpawnCount()
	string msg = ""
	
	if( currentSpawnCount > SPAWN_POSITIONS_BUDGET )
	{
		msg = " SPAWN BUDGET REACHED \n\n Cannot add more spawns "
		
		if( bUsePlayer )
			LocalEventMsg( player, "", msg )
			
		printt( msg )
		printm( msg )
		
		return
	}
	
	if( empty( info ) )
	{
		string spawnSetName = _SpawnSetInfo()
		
		if( !empty( spawnSetName ) )
			info = spawnSetName //auto set
		else
			info = "spawn_" + currentSpawnCount
	}
	else 
	{
		if( !IsSafeString( info, MAX_SPAWN_INFO_LENGTH ) )
		{
			msg = IssueInfoWarning( info.len() )
			info = ""
			
			Warning( msg )
			printm( msg )
		}
	}
	
	vector origin 
	vector angles 
	
	if( bUsePlayer )
	{
		table playerPos = GetPlayerPos( player )
		origin = expect vector( playerPos.origin )
		angles = expect vector( playerPos.angles )
	}
	else if( spawnPointOrNull != null )
	{
		LocPair spawnPoint = expect LocPair ( spawnPointOrNull )
		origin = spawnPoint.origin
		angles = spawnPoint.angles
	}
	else if( spawnPointOrNull == null )
	{
		msg += "\n\nError: spawnPoint was null during add"
		
		printt( msg )
		printm( msg )
		return 
	}

	string str = ""
	
	switch( DEV_SpawnType() )
	{
		case "csv":
			if( DEV_SpawnType() == "sq" )
				DEV_convert_array_to_csv_from_squirrel()
				
			str = DEV_append_pos_array_csv( origin, <angles.x, angles.y, angles.z>, info )
			
		break
		case "sq":
			if ( DEV_SpawnType() == "csv" )
				DEV_convert_array_to_squirrel_from_csv()
				
			str = DEV_append_pos_array_squirrel( origin, <angles.x, angles.y, angles.z>, info )
			
		break
		
		default:
			string z = "No type was set. Set type with DEV_SpawnType(\"csv\") or \"sq\" for squirrel code"
			printt( z )
			printm( z )
			return
	}
	
	LocPair data;
	data.origin = origin 
	data.angles = angles
	
	if( replace > -1 && IsValidSpawnIndex( replace ) )
	{
		GetSpawns()[ replace ] = data
		file.dev_positions[ replace ] = str 
		DEV_Highlight( replace, file.bHighlightPersistent )
		DEV_ReloadInfo()
	}
	else
	{
		GetSpawns().append( data )
		file.dev_positions.append( str )
		DEV_Highlight( ( SpawnCount() - 1 ), file.bHighlightPersistent )
		DEV_PrintSpawns( false )
	}
	
	if( bUsePlayer )
		LocalEventMsg( player, "", " SPAWN ADDED \n\n " + " " + str + contextInfo + " " )
	
	#if TRACKER && HAS_TRACKER_DLL
		SendServerMessage( "Spawn added: " + str )
	#endif
	
	printt( format( "\n\n Newly Added Spawn Pos: %s", str ) )
	printm( format( "\n\n Newly Added spawn Pos: %s", str ) )
	
	if( file.bAutoDelInvalid )
		DEV_ValidateSpawn( SpawnCount() - 1, true, player )
		
	if( DEV_AutoSimulateRing() )
	{
		if( IsNewSet( SpawnCount() ) )
		{
			int spawnSet = GetPreviousSpawnSet( SpawnCount() )
			
			if( spawnSet > 0 )
				DEV_SimulateRing( spawnSet )
		}
	}
	
	CheckAutoSave()
}

int function GetCurrentSpawnSet( int index, int teamsize = -1 )
{
	if ( teamsize == -1 )
		teamsize = file.iTeamCount 
	
	return ( index + 1 ) / teamsize + 1
}

int function GetPreviousSpawnSet( int index, int teamsize = -1 )
{
	if ( teamsize == -1 )
		teamsize = file.iTeamCount 
		
	int previous = GetCurrentSpawnSet( index, teamsize ) - 1
	
	if( previous > 0 )
		return ( previous )
		
	return -1
}

void function DEV_KeepHighlight( bool setting = true )
{
	file.bHighlightPersistent = setting
	
	printt( "Keep highlights set to:", setting )
	printm( "Keep highlights set to:", setting )
}

void function DEV_ClearSpawns( bool clearHighlights = true )
{
	__RemoveAllPanels()
	
	file.dev_positions.clear()
	GetSpawns().clear()
	
	string msg = "Cleared all saved positions"
	printt( msg )
	printm( msg )
	
	if( clearHighlights )
	{
		DEV_HighlightAll( REMOVE ) //removes all with true passed
	}
}

void function DEV_TeleportToSpawn( string pid = "", int posIndex = 0 )
{	
	entity player 
	
	if ( !empty( pid ) )
	{
		player = GetPlayer( pid )
	}
	else 
	{
		printt( "No player specified for param 1 of", FUNC_NAME() )
		printm( "No player specified for param 1 of", FUNC_NAME() )
		return
	}
	
	if( !IsValid( player ) )
	{
		printt( "Invalid player" )
		printm( "Invalid player" )
		return 
	}
	
	if( !IsValidSpawnIndex( posIndex ) )
	{
		printt( "Invalid spawn selected" )
		printm( "Invalid spawn selected" )
		return
	}
	
	if( SpawnCount() != file.dev_positions.len() )
	{
		Warning( "LOCPAIR & PRINT POSITIONS DO NOT MATCH" )
		printm( "LOCPAIR & PRINT POSITIONS DO NOT MATCH" )
		return
	}

	printt( "Teleporting to spawnpoint", posIndex )
	printm( "Teleporting to spawnpoint", posIndex )
	printt( file.dev_positions[posIndex] )
	printm( file.dev_positions[posIndex] )
	TP( player, GetSpawns()[posIndex] )
}

void function DEV_SpawnHelp()
{
	string context = CheckFirstUse()
	
	if( !empty( context ) )
	{
		foreach( player in GetPlayerArray() )
			LocalEventMsg( player, context )
			
		file.bFirstTimeUse = false
	}
	
	string helpinfo = "\n\n ---- SPAWN TOOL COMMANDS ----- \n\n"
	
	foreach( command, helpstring in file.DEV_POS_COMMANDS )
	{
		int offset = file.maxIndentNeeded - command.len()
		
		string spacing = TableIndent2( offset ) + " = "
		
		if( command.find("===") != -1 || command.find("...") != -1 )
			spacing = TableIndent3( offset )
			
		if( command.find("...") != -1 )
			command = ""
			
		helpinfo += command + " " + spacing + helpstring + "\n";
		printm( command + " " + spacing + " = " + helpstring )	
	}
	
	printt( helpinfo )
}

string function GenerateSpawnPakMetaData( bool bConsoleForm = false )
{
	array<string> settings
	string data		
	
	settings.append( 	format( "playlist:%s",		DEV_SpawnsPlaylist( "", true ) ) 	)
	settings.append( 	format( "map:%s",			GetMapName() )						)
	settings.append( 	format( "spawnsCount:%d",	SpawnCount() )						)
	settings.append( 	format( "teamCount:%d", 	file.iTeamCount ) 					)
	settings.append( 	format( "devAutoSave:%s", 	string( file.bAutoSave ) ) 			)//for dev debug
	
	if( bConsoleForm )
	{
		foreach( keyValue in settings )
		{
			printt( keyValue )
			printm( keyValue )
		}
		
		return ""
	}
	
	string prefix = "pakData."
	foreach( setting in settings )
		data += __WritePakInfoKV( prefix + setting ) + "\n"	
		
	return data
}

string function __WritePakInfoKV( string keyValue )
{
	switch( DEV_SpawnType() )
	{
		case "sq":
			return "// " + keyValue
			break 
			
		case "csv":
			return rPakCorrection( DEV_append_pos_array_csv( ZERO_VECTOR, ZERO_VECTOR, keyValue ) )
			break
	}
	
	unreachable //this should not happen.
}

void function DEV_WriteSpawnFile( string type = "", bool bAutoSave = false )
{
	if( file.dev_positions.len() <= 0 )
	{
		string msg = "No spawn positions to write stdout"
		
		printt( msg )
		printm( msg )
		return 
	}
	
	if( !empty( type ) )
		DEV_SpawnType( type )
	
	DevTextBufferClear()
	
	//////////////
	// AUTOSAVE //
	//////////////
	bool bReconvert = false
	
	if( bAutoSave )
	{
		if( DEV_SpawnType() == "csv" )
		{
			DEV_SpawnType( "sq", true )
			bReconvert = true
		}
	}
	
	//////////////
	// 	 OPEN	//
	//////////////
	if( DEV_SpawnType() == "csv" )
		DevTextBufferWrite( "origin,angles,info\n" )		
		
	string pakData = GenerateSpawnPakMetaData()
	DevTextBufferWrite( pakData )
		
	if( DEV_SpawnType() == "sq" )
		DevTextBufferWrite( "array<LocPair> spawns = \n[ \n" )
		
	string spacing = DEV_SpawnType() == "sq" ? TableIndent(15) : "";
	
	foreach( position in file.dev_positions )
		DevTextBufferWrite( rPakCorrection( spacing + position + "\n" ) )
	
	//////////////
	//	CLOSURE	//
	//////////////
	if( DEV_SpawnType() == "csv" )
		DevTextBufferWrite( "vector,vector,string\n" )
		
	if( DEV_SpawnType() == "sq" )
		DevTextBufferWrite( "];" )
	
	string fType = ".txt";
	
	if( DEV_SpawnType() == "csv" )
	{
		fType = ".csv"
	}
	else if( DEV_SpawnType() == "sq" ) 
	{
		fType = ".nut"
	}
	
	int uTime 			= GetUnixTimestamp()
	string file 		= "fs_spawns_" + DEV_SpawnsPlaylist() + "_" + DEV_SpawnsBaseMap() + "_set_" + string( uTime ) + fType
	string directory 	= "output/"
	
	if( bAutoSave )
		file = "spawns_autosave.nut"
	
	DevP4Checkout( file )
	DevTextBufferDumpToFile( directory + file )
	
	if( !bAutoSave )
	{
		string msg = "Wrote file to: " + directory + file
		
		printt( msg )
		printm( msg )
		
		string setPlaylist = DEV_SpawnsPlaylist( "", true )	
		int maxTeamsPerArenaRound = GetTeamCount()
		
		if( maxTeamsPerArenaRound > -2 && maxTeamsPerArenaRound != 0 )
		{
			if( SpawnCount() % maxTeamsPerArenaRound != 0 )
			{
				Warning( "Warning: Expected total \"spawns\" to be multiples of \"teams per spawn set\"" )
				Warning( "This pak may cause issues with gamemode logic" )
				printw( "SpawnCount:", SpawnCount(), " Teams Per Spawn Set:", maxTeamsPerArenaRound )
			}
		}
		
		string consolePrint = GenerateSpawnPakMetaData( true )
		printt( consolePrint )
		printm( consolePrint )
		
		array<string> errors = []
		foreach ( int index, LocPair spawn in GetSpawns() )
		{
			if( !CheckSpawn( spawn.origin ) )
			{
				string originString = VectorToString( spawn.origin )
				string anglesString = VectorToString( spawn.angles )
				errors.append( "INVALID: index[ " + index + " ]" + "Loc: " + originString + anglesString )
			}
		}
		
		if( errors.len() > 0 )
		{
			string header = "=== The following spawns did not pass player hull checks (OOB) ==="
			{
				printw( header )		
				foreach( string errorMsg in errors )
					printw( errorMsg )
					
				printm( header )				
				foreach( string errorMsg in errors )
					printm( errorMsg )
			}
		}
	}
	else if( bReconvert )
	{
		DEV_SpawnType( "csv", true )	
	}
}

string function rPakCorrection( string checkString )
{
	if( DEV_SpawnType() == "csv" )
		return StringReplace( checkString, ",   \"", ",\"" ) 
	
	return checkString
}

string function DEV_SpawnsPlaylist( string playlist = "", bool bDisablePrints = false )
{
	string context = " is "
	
	if( !empty( playlist ) && IsSafeString( playlist, 60, FILE_NAME_REGEX ) )
	{
		if( !AllPlaylistsArray().contains( playlist ) )
			Warning( "Notice: \"" + playlist + "\" is not configured in \"sh_mapname_playlist_gamemode_enums.gnut\"" )
		
		file.spawnsPlaylist = playlist
		context = " was "
		
		switch( playlist )
		{
			case "fs_scenarios":
				
				DEV_SetTeamCount( GetPlaylistVarInt( "fs_scenarios", "max_team_size", 5 ) )
				break
				
			case "fs_1v1":
				DEV_SetTeamCount( 2 )
				break
				
			case "fs_realistic_ttv":
				DEV_SetTeamCount( 1 )
				DebugDrawSphere( < 9864.35, 5497.93, -3567.97 >, 4100, 255, 0, 0, true, 800.0 )
				break
				
			//
		}
	}
	
	string filePlaylist = file.spawnsPlaylist	
	
	if( !bDisablePrints )
	{
		string msg = "SpawnSystem(dev):: playlist" + context + "set to: \"" + filePlaylist + "\""
		
		printt( msg )
		printm( msg )
	}
	
	return filePlaylist
}

string function DEV_SpawnsBaseMap( string baseMap = "", bool bIgnoreInvalid = false, bool bDisablePrints = false )
{
	string context = " is "
	
	if( !empty( baseMap ) && IsSafeString( baseMap, 60, FILE_NAME_REGEX ) )
	{
		if( !AllMapsArray().contains( baseMap ) )
		{
			Warning( "Notice: \"" + baseMap + "\" is not configured in \"sh_mapname_playlist_gamemode_enums.gnut\"" )
		}
		else 
		{	
			int mapEnumValue = GetEnumValue( "eMaps", baseMap )
			int baseMapEnumValue = SpawnSystem_FindBaseMapForPak( mapEnumValue )
			
			if( mapEnumValue != baseMapEnumValue && !bIgnoreInvalid )
			{
				string newBaseMap = AllMapsArray()[ baseMapEnumValue ]
				
				string basemsg
				{
					basemsg += "\n\nProvided map was corrected to basemap for this spawn rpak: \n"
					basemsg += "Old: " + baseMap + "\n"
					basemsg += "New (basemap): " + newBaseMap + "\n"
				}
				
				baseMap = newBaseMap
				Warning( basemsg )
			}
			
		}
		
		file.spawnsMap = baseMap
		context = " was "
	}
	
	string fileMap = file.spawnsMap
	
	if( !bDisablePrints )
	{
		string msg = "SpawnSystem(dev):: baseMap" + context + "set to: \"" + fileMap + "\""
		
		printt( msg )
		printm( msg )
	}
	
	return fileMap
}

void function DEV_SetTeamCount( int count )
{
	bool bReload = false
	
	string info
	if( count == 0 )
	{
		info = "Cannot set team count to 0. Did you mean -1 for all spawns same team?"	
		printt( info )
		printm( info )
		
		return
	}
	
	if( DEV_SpawnsPlaylist() == "fs_scenarios" )
	{
		if( count > SCENARIOS_MAX_ALLOWED_TEAMSIZE )
		{
			info = "Cannot set team count greater than " + SCENARIOS_MAX_ALLOWED_TEAMSIZE + " for scenarios gamemode."
			printt( info )
			printm( info )
			return
		}
	}
	
	if( file.iTeamCount != count )
		bReload = true
	
	file.iTeamCount = count
	
	string msg = "Team count per \"Spawn Set\" was set to"
	
	printt( msg, count )
	printm( msg, count )
	
	if( bReload )
		DEV_PrintSpawns( true )
}

int function GetTeamCount()
{
	return file.iTeamCount
}

void function DEV_TeleportToPanels( string identifier )
{
	entity player = GetPlayer( identifier )
	
	if( IsValid ( player ) )
	{
		if ( !IsValid( file.panelsloc ) )
		{
			printt("No panel locations")
			printm("No panel locations")
			return
		}
		
		TP( player, file.panelsloc )
	}
	else 
	{
		printt("Invalid player.")
		printm("Invalid player.")
	}
}

void function DEV_HighlightAll( bool removeAll = LOAD )
{
	if( SpawnCount() == 0 && !removeAll )
	{
		printt( "No spawns in PosArray to highlight" )
		printm( "No spawns in PosArray to highlight" )
		return 
	}
	
	string msg = ""
	if ( removeAll || file.bHighlightToggleAll )
	{
		foreach( int index, entity beam in file.allBeamEntities )
		{
			if( IsValid ( beam ) )
			{
				beam.Destroy()
			}
		}
		
		file.bHighlightToggleAll = false 
		msg = "Removed all spawn highlights."
	}
	else 
	{		
		foreach ( int index, LocPair spawn in GetSpawns() )
		{
			entity beam = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( $"P_ar_titan_droppoint_tall" ), spawn.origin, <0,0,0> )
			EffectSetControlPointVector( beam, 1, Vector( 235, 213, 52 ) )
			__DestroyHighlight( index )
			file.allBeamEntities[ index ] <- beam
		}
		
		file.bHighlightToggleAll = true 
		msg = "Highlighted all spawns."
	}
	
	printt( msg )
	printm( msg )
}

bool function __DestroyHighlight( int index )
{
	if( index in file.allBeamEntities )
	{
		if( IsValid( file.allBeamEntities[ index ] ) )
		{
			file.allBeamEntities[ index ].Destroy()
			return true
		}
	}
	
	return false
}

void function DEV_RemoveHighlight( int index )
{
	if ( __DestroyHighlight ( index ) )
	{
		printt( "Highlight", index, "was removed" )
		printm( "Highlight", index, "was removed" )
	}
	else
	{
		printt( "No highlight exists for spawn index:", index )
		printm( "No highlight exists for spawn index:", index )
	}
}

void function DEV_Highlight( int index, bool persistent = true )
{
	if( index >= SpawnCount() || index < 0 )
	{
		printt( "Location does not exist" )
		printm( "Location does not exist" )
		return
	}
	
	LocPair spawn = GetSpawns()[ index ]
	entity beam = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( $"P_ar_titan_droppoint_tall" ), spawn.origin, <0,0,0> )
	EffectSetControlPointVector( beam, 1, Vector( 63, 72, 204 ) )
	
	if( persistent )
	{
		__DestroyHighlight( index )
		file.allBeamEntities[ index ] <- beam
	}
	else
	{
		thread __HighlightSpawn_DelayedEnd( beam )
	}	
}

void function __HighlightSpawn_DelayedEnd( entity beam )
{
	if ( !IsValid( beam ) )
		return
	
	Signal( svGlobal.levelEnt, "DelayedHighlightActivate" )
	EndSignal( svGlobal.levelEnt, "DelayedHighlightActivate" )
	
	OnThreadEnd( void function() : ( beam )
	{
		if( IsValid( beam ) )
		{
			beam.Destroy()
		}
	})
	
	wait HIGHLIGHT_SPAWN_DELAY	
}

void function DEV_LoadPak( string pak = "", string playlist = "" )
{
	if( !__bCheckReload() )
		return
		
	if( empty( DEV_SpawnType() ) )
	{
		Warning( "No spawn-maker type was set." )
		Warning( "Setting to squirrel code." )
		Warning( "Set type with DEV_SpawnType(\"csv\") or \"sq\" for squirrel code" )
		DEV_SpawnType("sq")
	}

	bool usePlaylist = false
	bool bUsePak = false
	
	if( empty( pak ) )
	{
		pak = file.currentSpawnPak		
		if( empty( pak ) )
		{
			string msg = "Cannot set an empty pak (none loaded)"
			printt( msg )
			printm( msg )
		}
		
		printt( "Custom Pak was empty, using current based on DEV_SpawnPlaylist()." )
		printm( "Custom Pak was empty, using current based on DEV_SpawnPlaylist()." )
	}
	else 
	{
		//pak was specified, use the override 
		bUsePak = true
	}
	
	if( !empty( playlist ) )
	{
		SpawnSystem_SetCustomPlaylist( playlist )
		usePlaylist = true
	}
	else if( !empty( DEV_SpawnsPlaylist() ) )
	{
		SpawnSystem_SetCustomPlaylist( DEV_SpawnsPlaylist() )
		usePlaylist = true
	}

	if( !settings.bOptionsAreSet )
		Flowstate_SpawnSystem_InitGamemodeOptions()
		
	table<string,bool> spawnOptions = {}
	
	spawnOptions["use_sets"] <- true
	spawnOptions["use_random"] <- false
	spawnOptions["prefer"] <- false
	spawnOptions["use_custom_rpak"] <- SpawnSystem_SetCustomPak( pak )
	spawnOptions["use_custom_playlist"] <- usePlaylist
	
	array<SpawnData> devLocations = customDevSpawnsList().len() > 0 && !bUsePak ? SpawnSystem_CreateSpawnObjectArray( customDevSpawnsList() ) : SpawnSystem_ReturnAllSpawnLocations( MapName(), spawnOptions )
	
	if( devLocations.len() > 0 )
	{
		DEV_ClearSpawns()
		
		string str 
		string info
		string dataInfo
		
		int iter = 0
		foreach( spawnInfo in devLocations )
		{
			dataInfo = spawnInfo.info
			info = !empty( dataInfo ) ? dataInfo : "spawn_" + iter
			
			switch( DEV_SpawnType() )
			{
				case "csv":
					if( DEV_SpawnType() == "sq" )
						DEV_convert_array_to_csv_from_squirrel()
						
					str = DEV_append_pos_array_csv( spawnInfo.spawn.origin, spawnInfo.spawn.angles, info )
					
				break
				case "sq":
					if ( DEV_SpawnType() == "csv" )
						DEV_convert_array_to_squirrel_from_csv()
						
					str = DEV_append_pos_array_squirrel( spawnInfo.spawn.origin, spawnInfo.spawn.angles, info )
					
				break
				
				default:
					Warning("No type was set. Set type with DEV_SpawnType(\"csv\") or \"sq\" for squirrel code")
					printm("No type was set. Set type with DEV_SpawnType(\"csv\") or \"sq\" for squirrel code")
					return
			}
			
			GetSpawns().append( spawnInfo.spawn )
			file.dev_positions.append( str )
			
			iter++;
		}
		
		Warning( "----LOADED PAK: " + pak + "----" )
		printm( "----LOADED PAK: " + pak + "----" )
		DEV_HighlightAll()
		DEV_PrintSpawns( true )
	}
	else 
	{
		Warning("Locations are empty.")
		printm("Locations are empty.")
	}
}

void function __CreateInfoPanelForSpawn( int set, int index, string identifier )
{
	if( index >= SpawnCount() )
	{
		sqerror( "Spawn doesn't exist for index: " + index )
		return 
	}
	
	LocPair spawn = GetSpawns()[ index ]
	int id = index + 1
	vector faceup = < 90, 360, 0 >
	
	foreach( player in GetPlayerArray() )
	{	
		RemovePanelText( player, id )
		WaitFrame()
		CreatePanelText( player, "SpawnSet: " + set, "index# [ " + index + " ] Team: " + identifier, ( spawn.origin + <0,0,5> + file.infoPanelOffset ), faceup + file.infoPanelOffsetAngles, false, 2, id )
	}
}

void function DEV_PanelInfo( bool setting = true )
{
	file.bSpawnInfoPanels = setting
	string msg = "Set info panels to " + ( setting ? "show (true)" : "not show (false)" )
	
	printt( msg )
	printm( msg )
}

void function DEV_RotateInfoPanels( string direction = "clockwise" )
{
	if( !__bCheckReload() )
		return
	
	vector info = file.infoPanelOffsetAngles 
	
	switch( direction )
	{
		case "clockwise":
			if( info.z >= 270 )
			{
				file.infoPanelOffsetAngles = < info.x, info.y, 0 >
			}
			else 
			{
				file.infoPanelOffsetAngles = < info.x, info.y, info.z + 90 >
			}
			
			DEV_ReloadInfo()
			break 
			
		case "counterclockwise":
			if( info.z <= 90 )
			{
				file.infoPanelOffsetAngles = < info.x, info.y, 360 >
			}
			else 
			{
				file.infoPanelOffsetAngles = < info.x, info.y, info.z - 90 >
			}
			
			DEV_ReloadInfo()
			break 
			
		default:
			printt( "Invalid rotation. clockwise/counterclockwise" )
			printm( "Invalid rotation. clockwise/counterclockwise" )
	}
}

array<LocPair> function DEV_ShowCenter( int set, bool bReturnData = false )
{
	array<LocPair> spawns = [] 
	
	int iSpawnsLen = SpawnCount()	
	int iStartPos = ( set - 1 ) * file.iTeamCount 
	int iEndPos = iStartPos + file.iTeamCount
	
	if( iStartPos < 0 || iStartPos >= iSpawnsLen || iEndPos > iSpawnsLen )//for loop end
	{
		printt( "Invalid Set, not enough spawns." )
		printm( "Invalid Set, not enough spawns." )
		return spawns
	}
	
	for( int i = iStartPos; i < iEndPos ; i++ )
	{
		spawns.append( GetSpawns()[ i ] )
	}
	
	vector center = OriginToGround( GetCenterOfCircle( spawns ) )
	
	printt( "Calculated center is: ", VectorToString( center ) )
	printm( "Calculated center is: ", VectorToString( center ) )
	
	entity beam = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( $"P_chamber_beam" ), center, <0,0,0> )
	thread __HighlightSpawn_DelayedEnd( beam )
	
	if( bReturnData )
	{
		spawns.append( NewLocPair( center, ZERO_VECTOR ) )
		return spawns
	}
	else 
	{
		array<LocPair> nullspawns
		return nullspawns
	}
		
	unreachable
}

void function DEV_ValidateSpawn( int index = -1, bool remove = false, entity player = null )
{
	thread __SpawnValidate_internal( index, remove, player )
}

void function __SpawnValidate_internal( int index = -1, bool remove = false, entity player = null )
{
	if( IsValid( player ) )
		player.EndSignal( "OnDestroy" )
	
	int thisthread = file.iValidatorTracker++;
	
	if( file.bValidatorRunning )
	{
		for( ; ; )
		{
			table results = WaitSignal( file.signalDummy, "RunValidatorIfWaiting" )
			
			if( results.runthread == null )
				return
			
			if( expect int( results.runthread ) == thisthread )
				break			
		}
	}
	
	file.bValidatorRunning = true
	
	OnThreadEnd
	(
		function() : ( thisthread )
		{
			file.bValidatorRunning = false
			Signal( file.signalDummy, "RunValidatorIfWaiting", { runthread = ( thisthread + 1 ) } )
			
			#if DEBUG_SPAWN_TRACE
				printt("Thread", thisthread, "ended" )
			#endif 
		}
	)
	
	int spawnsLen = SpawnCount()
	
	if( spawnsLen == 0 || ( index != -1 && !IsValidSpawnIndex( index ) ) )
	{
		printt( "Invalid spawn index provided:", index )
		printm( "Invalid spawn index provided:", index )
		return
	}
	
	if( index != -1 )
	{
		thread __SignalIsValidSpawn( GetSpawns()[ index ].origin, index, player )
		table spawnResults = WaitSignal( file.signalDummy, "IsSpawnValidStatus" )
		
		if( expect bool( spawnResults.validspawn ) == false && expect int( spawnResults.spawnIndex ) == index )
		{
			if( remove )
			{
				string delmsg = format("Spawn [ %d ] was positioned badly and removed.", index )
				
				DEV_DeleteSpawn( index )
				DEV_MessageAll( "WARNING", delmsg )
				
				printt( delmsg )
				printm( delmsg )
				
			}
			else
			{
				string consoleMsg = "Issue with spawn [ " + index + " ].\n Spawn was positioned badly and should be removed or modified."
				
				DEV_MessageAll( "WARNING", consoleMsg )
				printt( consoleMsg )
				printm( consoleMsg )
			}

			return
		}
		
		printf( "spawn [ %d ] is valid.", index )
		printm( "spawn [ " + index + " ] is valid." )
		return
	}
	
	array<string> errors = []
	
	for( int i = spawnsLen - 1; i >= 0; i-- )
	{
		thread __SignalIsValidSpawn( GetSpawns()[ i ].origin, i, player )	
		table spawnResultsAll = WaitSignal( file.signalDummy, "IsSpawnValidStatus" )
		
		if( expect bool( spawnResultsAll.validspawn ) == false && expect int( spawnResultsAll.spawnIndex ) == i )
		{
			if( remove )
			{
				DEV_DeleteSpawn( i )
				errors.append( "Spawn [ " + i + " ] was bad and removed" )
			}
			else 
			{
				errors.append( "Spawn [ " + i + " ] is bad and should be removed or modified" )
			}
		}
		
		WaitFrame()
	}
	
	if( errors.len() > 0 )
	{	
		errors.insert( 0, "=== THE FOLLOWING SPAWNS HAD AN ISSUE ===" )
		
		print_string_array( errors )
		
		#if MULTIPLAYER_DEBUG_PRINTS
			foreach( error in errors )
			{
				printm( error )
			}
		#endif
	}
}

void function DEV_MessageAll( string msg, string msg2 = "" )
{
	foreach( player in GetPlayerArray() )
	{
		Message( player, msg, msg2 )
	}
}

void function __SignalIsValidSpawn( vector origin, int spawnIndex, entity player = null ) 
{
	WaitFrame()
	
	vector mins
	vector maxs
	array<entity> ignoreEnts = []
	vector playerOrigin
	
	if ( !IsValid( player ) ) 
	{
		mins = <-16, -16, 0>
		maxs = <16, 16, 72>
	} 
	else
	{
		player.EndSignal( "OnDestroy" )
		playerOrigin = player.GetOrigin()
		ignoreEnts.append( player )
		mins = player.GetPlayerMins()
		maxs = player.GetPlayerMaxs()
		
		#if DEBUG_SPAWN_TRACE
			printt( "player mins:", mins, "maxs:", maxs )
		#endif
	}
	
	// check for doors and close them before doing trace	
	// better ways to trace but since we have this checker doing this here
	array<entity> scan = ArrayEntSphere( origin, DOOR_SCAN_RADIUS )
	
	entity lastDoor
	bool bDoorFound = false
	array<entity> doorsToClose	
	
	foreach( doorEnt in scan )
	{	
		if( IsValid( doorEnt ) && IsDoorOpen( doorEnt ) ) //IsDoorOpen checks if is door
		{			
			#if DEBUG_SPAWN_TRACE
				printt("open")
			#endif 
			
			doorsToClose.append( doorEnt )	
			lastDoor = doorEnt
			
			if( !bDoorFound )
				bDoorFound = true 
		}
		else
		{
			#if DEBUG_SPAWN_TRACE		
				if( IsValid( doorEnt ) && IsDoor( doorEnt ) )
				{
					printt
					(
						"info: ",
						doorEnt.e.isOpen, 
						IsDoorOpen( doorEnt )
					)
				}
				else 
				{
					printt( "not a door" )
				}
			#endif
		}
	}
	
	if( file.bAutoDelInvalid && bDoorFound && IsValid( player ) )
	{		
		PushAwayFromDoor( doorsToClose, player, 300 )		
		
		wait 0.25
		
		if( !player.IsNoclipping() )
			ClientCommand( player, "noclip" )
	}
	
	foreach( door in doorsToClose )
	{
		if( IsValid( door ) && IsDoorOpen( door ) )
		{
			Signal( door, "CloseDoor" )
			door.CloseDoor( null )
			door.e.isOpen = false
		}
	}
	
	float startTime = Time()
	
	while( IsValid( lastDoor ) && IsDoorOpen( lastDoor ) )
	{
		WaitFrame()
		
		if( Time() - startTime > 3 )
			break
	}
	
	if( file.bAutoDelInvalid && bDoorFound && IsValid( player ) )	
	{
		if( player.IsNoclipping() )
			ClientCommand( player, "noclip" )
	}
			
	TraceResults result = TraceHull( origin, origin + <0, 0, 1>, mins, maxs, ignoreEnts, TRACE_MASK_PLAYERSOLID, TRACE_COLLISION_GROUP_PLAYER )

	if ( result.startSolid )
		Signal( file.signalDummy, "IsSpawnValidStatus", { validspawn = false, spawnIndex = spawnIndex } )

	bool traceFinalResult = result.fraction == 1.0
	
	Signal( file.signalDummy, "IsSpawnValidStatus", { validspawn = traceFinalResult, spawnIndex = spawnIndex } )
}

void function PushAwayFromDoor( array<entity> doors, entity player, float force )
{
	if ( !IsValid( player ) || ( !player.IsPlayer() && !player.IsNPC() ) || doors.len() < 1 )
		return

	vector doorLine
	vector playerOrigin = player.GetOrigin()

	if ( doors.len() == 1 ) 
	{
		entity door = doors[0]
		vector doorMins = door.GetBoundingMins()
		vector doorMaxs = door.GetBoundingMaxs()
		vector doorCenter = ( doorMins + doorMaxs ) * 0.5
		
		vector toPlayer = playerOrigin - doorCenter
		toPlayer.z = 0
		
		float angle = acos( door.GetForwardVector().Dot( toPlayer ) / ( Length( door.GetForwardVector() ) * Length( toPlayer ) ) ) * ( 180.0 / PI )
		vector direction = angle < 90 ? -Normalize( door.GetForwardVector() ) : Normalize( door.GetForwardVector() )
		
		vector velocity = direction * force
		velocity.z = max( 200, fabs( velocity.z ) )
		
		player.SetVelocity(velocity)
		
		#if DEBUG_SPAWN_TRACE
			DebugDrawBox( doorCenter, doorMins, doorMaxs, 0, 255, 0, 0, 5.0 )
			DebugDrawLine( playerOrigin, doorCenter, 0, 0, 255, true, 5.0 )
			DebugDrawLine( playerOrigin, playerOrigin + velocity * 5, 255, 0, 0, true, 5.0 )
			Warning( "Door Center: " + doorCenter.tostring() )
			Warning( "Player Origin: " + playerOrigin.tostring() )
			Warning( "Direction to Push: " + direction.tostring() )
		#endif
		
	} 
	else 
	{
		entity firstDoor = doors[0]
		entity lastDoor = doors[ doors.len() - 1 ]
		vector firstDoorCenter = ( firstDoor.GetBoundingMins() + firstDoor.GetBoundingMaxs() ) * 0.5
		vector lastDoorCenter = ( lastDoor.GetBoundingMins() + lastDoor.GetBoundingMaxs() ) * 0.5
		doorLine = lastDoorCenter - firstDoorCenter
		doorLine.z = 0
		
		vector toFirstDoor = firstDoorCenter - playerOrigin
		toFirstDoor.z = 0
		
		float angle = acos(doorLine.Dot(toFirstDoor) / (Length(doorLine) * Length( toFirstDoor )) ) * ( 180.0 / PI )
		
		vector direction = angle < 90 ? -Normalize(doorLine) : Normalize(doorLine);
		
		vector velocity = direction * force
		velocity.z = max(200, fabs(velocity.z))
		
		player.SetVelocity(velocity)
		
		#if DEBUG_SPAWN_TRACE
			DebugDrawBox( firstDoorCenter, firstDoor.GetBoundingMins(), firstDoor.GetBoundingMaxs(), 0, 255, 0, 0, 5.0 )
			DebugDrawBox( lastDoorCenter, lastDoor.GetBoundingMins(), lastDoor.GetBoundingMaxs(), 0, 255, 0, 0, 5.0 )
			DebugDrawLine( playerOrigin, firstDoorCenter, 0, 0, 255, true, 5.0 )
			DebugDrawLine( firstDoorCenter, lastDoorCenter, 255, 0, 0, true, 5.0 )
			DebugDrawLine( lastDoorCenter, playerOrigin, 0, 0, 255, true, 5.0 )
			DebugDrawLine( playerOrigin, playerOrigin + velocity * 5, 255, 0, 0, true, 5.0 )
			Warning( "first door center: " + firstDoorCenter.tostring() )
			Warning( "las door center: " + lastDoorCenter.tostring() )
			Warning( "player origin: " + playerOrigin.tostring() )
			Warning( "direction: " + direction.tostring() )
		#endif
    }
}

void function CalculateMaxIndent()
{
	int maxlen = 0
	
	foreach( keyname, helpstring in file.DEV_POS_COMMANDS )
	{
		if( keyname.len() > maxlen )
			maxlen = keyname.len()
	}
	
	file.maxIndentNeeded = maxlen + 3
}

void function AutoSetupSettings()
{
	DEV_SpawnsPlaylist( GetCurrentPlaylistName(), true )
	DEV_SpawnsBaseMap( GetMapName(), false, true )
}

void function DEV_AutoDeleteInvalid( bool setting = true )
{
	file.bAutoDelInvalid = setting
	
	string msg = "bAutoDelInvalid set to " + setting
	
	printt( msg )
	printm( msg )
}

LocPair ornull function DEV_GetSpawn( int index )
{
	LocPair nullLoc
	string msg
	
	if( !IsValidSpawnIndex( index ) )
	{
		msg = "Invalid spawn index."
		printt( msg )
		printm( msg )
		
		return null
	}
	
	return GetSpawns()[ index ]
}

int function SpawnCount()
{
	return GetSpawns().len()
}

array<LocPair> function GetSpawns()
{
	return file.dev_positions_LocPair
}

bool function GetAutoSave()
{
	return file.bAutoSave
}

void function CheckAutoSave()
{
	if( !GetAutoSave() )
		return
		
	if( SpawnCount() == 0 )
		return
		
	DEV_WriteSpawnFile( "", true )
}

void function DEV_SetAutoSave( bool bSave = true )
{
	file.bAutoSave = bSave 
	
	string msg = "Set Autosave to " + bSave
	
	printt( msg )
	printm( msg )
}

array<string> function GetSpawnSettings()
{
	array<string> settings = []
	
	settings.append( " === CURRENT SETTINGS === " )
	settings.append( " Auto Save = " + file.bAutoSave )
	settings.append( " Spawn Pak Playlist = " + DEV_SpawnsPlaylist( "", true ) )
	settings.append( " Spawn Pak BaseMap = " + DEV_SpawnsBaseMap( "", false, true ) )
	settings.append( " Spawns Count = " + SpawnCount() )
	settings.append( " Teams Per Spawn Set = " + file.iTeamCount )
	settings.append( " Saving File Type = " + file.dev_positions_type )
	settings.append( " Current spawn set info = " + file.spawnSetName )
	settings.append( " Panel Locations = " + file.panelsloc.origin + "," + file.panelsloc.angles )
	settings.append( " Auto Simulate Ring ? = " + file.autoSimulateRing )
	settings.append( " Spawn Info Panels ? = " + file.bSpawnInfoPanels )
	settings.append( " infoPanelOffset = " + file.infoPanelOffset )
	settings.append( " infoPanelOffsetAngles = " + file.infoPanelOffsetAngles )
	settings.append( " Highlight Toggle All ? = " + file.bHighlightToggleAll )
	settings.append( " Highlight Persistent ? = " + file.bHighlightPersistent )
	settings.append( " Auto Delete Invalid ? = " + file.bAutoDelInvalid )
	settings.append( " " )
	settings.append( " === DEBUG INFO === " )
	settings.append( " allBeamEntities count = " + file.allBeamEntities.len() )
	settings.append( " bInfoPanelsAreReloading = " + file.bInfoPanelsAreReloading )
	settings.append( " bValidatorRunning = " + file.bValidatorRunning )
	settings.append( " iValidatorTracker = " + file.iValidatorTracker )
	settings.append( " maxIndentNeeded = " + file.maxIndentNeeded )
	settings.append( " bFirstTimeUse = " + file.bFirstTimeUse )
	//settings.append( " = " + file. )
	
	return settings
}

void function PrintSpawnSettings()
{
	foreach( text in GetSpawnSettings() )
		printt( text )
	
	#if MULTIPLAYER_DEBUG_PRINTS
		foreach( text in GetSpawnSettings() )
			printm( text )
	#endif 
}

const array<int> DEV_PLAYLISTS =
[
	ePlaylists.survival_dev,
	ePlaylists.dev_default
]

string function CheckFirstUse()
{
	if( !file.bFirstTimeUse )
		return ""
	
	array<string> msg
	
	msg.append( " " )
	msg.append( " " )
	msg.append( "---------------------------------------------------" )
    msg.append( "|                                                 |" )
	msg.append( "| ____ _    ____ _ _ _ ____ ___ ____ ___ ____     |" )
    msg.append( "| |___ |    |  | | | | [__   |  |__|  |  |___     |" )
    msg.append( "| |    |___ |__| |_|_| ___]  |  |  |  |  |___     |" )
    msg.append( "|      ____ ___  ____ _    _       ___            |" )
    msg.append( "|      [__  |__| |__| \\    / |\\ | [__             |" )
    msg.append( "|      ___] |    |  |  \\/\\/  | \\| ___]            |" )
    msg.append( "|                                                 |" )
    msg.append( "| Flowstate SpawnSystem & Tool - Created by Mkos. |" )
    msg.append( "|                                                 |" )
    msg.append( "---------------------------------------------------" )
    msg.append( " " )
	msg.append( "NOTICE: Make sure to have a folder called 'output' in r5reloaded/platform directory" )
	msg.append( "NOTICE: AutoSave is disabled by default. To turn on run 'script DEV_SetAutoSave()'" )	
	msg.append( "NOTICE: You should run DEV_SpawnsPlaylist( \"fs_playlistname_here\" ) with the intended playlist for spawns." )
	
	if( !DEV_PLAYLISTS.contains( Playlist() ) )
		msg.append( "NOTICE: It is reccomended to load dev_default if creating spawns." )
	
	msg.append( " " )
	msg.append( " " )
	msg.append( "       run:  script DEV_SpawnHelp()    to see the help documentation." )
	msg.append( " " )
	
	foreach( txt in msg )
		printt( txt )
		
	#if MULTIPLAYER_DEBUG_PRINTS
		foreach( txt in msg )
			printm( txt )
	#endif
	
	PrintSpawnSettings()
	
	file.bFirstTimeUse = false
	
	string info = "\n\n This is the first time running the spawn tool. Check console for more info. "
	
	return info
}

void function DEV_PrintSettings()
{
	PrintSpawnSettings()
}

void function _CreateSpawnWithInfoAtPoint( int index, LocPair spawn, string info )
{
	DEV_AddSpawn( null, info, index, spawn )
}

void function DEV_SetSpawnInfo( int index, string info = "" )
{
	string msg
	
	if( !IsValidSpawnIndex( index ) )
	{
		msg = "Can't add info to an invalid spawn."
		
		printt( msg )
		printm( msg )
		
		return
	}
	
	if( !empty( info ) )
	{
		if( !IsSafeString( info, MAX_SPAWN_INFO_LENGTH ) )
		{
			msg = IssueInfoWarning( info.len() )
			info = ""
			
			Warning( msg )
			printm( msg )
		}
	}
	
	LocPair spawn = clone GetSpawns()[ index ]
	_CreateSpawnWithInfoAtPoint( index, spawn, info )
}

void function DEV_AutoSetInfo( string info = "" )
{
	string msg
	
	if( !empty( info ) )
	{
		if( !IsSafeString( info, MAX_SPAWN_INFO_LENGTH ) )
		{
			msg = IssueInfoWarning( info.len() )
			Warning( msg )
			info = ""
		}
		else 
		{
			msg = "Set auto SpawnSetName to \"" + info + "\""
		}
	}
	else 
	{
		msg = "Cleared SpawnSetName."
	}

	_SpawnSetInfo( info )
	
	printt( msg )
	printm( msg )
}

string function IssueInfoWarning( int strLen )
{
	bool bOverLimit
	string tooLong 
	
	if( strLen > MAX_SPAWN_INFO_LENGTH )
		tooLong = "info was " + strLen + " characters long. " + ( strLen - MAX_SPAWN_INFO_LENGTH ) + " chars too many. Max length: " + MAX_SPAWN_INFO_LENGTH
	
	if( !empty( tooLong ) )
		return tooLong 
	else	
		return "Provided info contained invalid characters"
		
	unreachable
}

string function _SpawnSetInfo( string ornull info = null )
{
	if( info == null )
		return file.spawnSetName
		
	string setinfo = expect string( info )
	file.spawnSetName = setinfo 
	
	return setinfo
}

bool function DEV_AutoSimulateRing( bool ornull bSetting = null )
{
	bool userSetting = false 
	
	if( bSetting == null )
	{
		return file.autoSimulateRing
	}
	else 
	{
		userSetting = expect bool( bSetting )
		file.autoSimulateRing = userSetting
		
		string msg = "Set AutoSimulateRing to " + string( userSetting )
		
		printt( msg )
		printm( msg )
	}
	
	return userSetting
}

void function DEV_SimulateRing( int spawnSet = -1, bool bLoop = false )
{	
	string msg = ""
	
	if( spawnSet == -1 )
	{
		msg = "No spawnset was provided. Spawn sets are shown in yellow on spawn info panels."
		
		printt( msg )
		printm( msg )
		return
	}
	
	if( SpawnCount() < 2 )
	{
		msg = "Not enough spawns to simulate ring";
		printt( msg )
		printm( msg )
		return
	}
	
	int iSpawnsLen = SpawnCount()	
	int iStartPos = ( spawnSet - 1 ) * file.iTeamCount 
	int iEndPos = iStartPos + file.iTeamCount
	
	if( iStartPos < 0 || iStartPos >= iSpawnsLen || iEndPos > iSpawnsLen )//for loop end
	{
		printt( "Invalid Set, not enough spawns." )
		printm( "Invalid Set, not enough spawns." )
		return
	}
	
	string ringIdentifier = GetRingIdentifier( spawnSet )
	
	RegisterSignal( ringIdentifier )
	
	FS_Scenarios_CreateCustomDeathfield_clone( spawnSet, ringIdentifier, bLoop )
	
	msg = format( "Ring simulation started for spawnset [ %d ]", spawnSet )
	printt( msg )
	printm( msg )
	DEV_MessageAll( "Ring Started", msg )
}

void function DEV_RingInfo( bool bActiveOnly = true )
{
	bool bFound = false 
	
	if( bActiveOnly )
	{
		foreach( ring in GetRingArray() )
		{
			if( !bFound )
				bFound = true 
				
			PrintRingInfo( SearchForRingInfo( ring ) )
		}
	}
	else 
	{
		foreach( string ringIdentifier, RingInfo ringInfo in GetRings() )
		{
			if( !bFound )
				bFound = true 
				
			PrintRingInfo( ringInfo )
		}
	}
	
	if( !bFound )
	{
		string msg = "No available ring data to show."
		
		printt( msg )
		printm( msg )
	}
}

void function PrintRingInfo( RingInfo ringInfo )
{		
	array<string> arrayprints = []
	
	arrayprints.append( "Entity: " + ringInfo.ringEnt + "\n" )
	arrayprints.append( "Spawnset:" + ringInfo.spawnSet + "\n" )
	arrayprints.append( "Loop Setting:" + ringInfo.loopSetting + "\n" )
	arrayprints.append( "Center:" + ringInfo.center + "\n" )
	arrayprints.append( "Radius:" + ringInfo.radius + "\n" )
	arrayprints.append( "Original Close Max Time:" + ringInfo.closeMaxTime + "\n" )
	
	string localprint = "\n\n"
	
	foreach( prnt in arrayprints )
		localprint += prnt
	
	printt( localprint )
	
	#if MULTIPLAYER_DEBUG_PRINTS 
		foreach( prnt in arrayprints )
			printm( prnt )
	#endif
}

RingInfo function SearchForRingInfo( entity ring )
{	
	RingInfo nullRingInfo 
	
	if( !IsValid( ring ) )
		return nullRingInfo
	
	foreach( string ringIdentifier, RingInfo ringInfo in GetRings() )
	{
		if( IsRingValid( ringIdentifier ) )
			if( ringInfo.ringEnt == ring )
				return ringInfo
	}
	
	return nullRingInfo
}

string function GetRingIdentifierBySpawnSet( int findSpawnSet )
{
	foreach( string ringIdentifier, RingInfo ringInfo in GetRings() )
	{
		if( ringInfo.spawnSet == findSpawnSet )
			return ringIdentifier
	}
	
	return "_invalid"
}

bool function DoesRingSettingsExist( string ringIdentifier )
{
	return ( ringIdentifier in GetRings() )
}

table<string,RingInfo> function GetRings()
{
	return clonedSettings.allRings
}

bool function IsRingValid( string ringIdentifier )
{
	if( !DoesRingSettingsExist( ringIdentifier ) )
		return false 
		
	if( !IsValid( GetRings()[ ringIdentifier ].ringEnt ) )
		return false 
		
	return true
}

bool function LoopRing( string ringIdentifier, bool ornull setting = null )
{
	bool bExists = DoesRingSettingsExist( ringIdentifier )
	bool bSettingValue = false 
	
	if ( setting != null )
	{
		bSettingValue = expect bool( setting )
	}
	else 
	{
		if( bExists )
			return GetRings()[ ringIdentifier ].loopSetting
		else 
			return false
	}
	
	if( bExists )
		GetRings()[ ringIdentifier ].loopSetting = bSettingValue
	else 
		mAssert( false, "LoopRing() was applied on a ring whos settings were not first created." )
		
	return bSettingValue
}

void function CreateRingSettings( string ringIdentifier, entity ring, int spawnSet, bool loopSetting, vector center, float radius, float closeMaxTime )
{
	RingInfo ringInfo	
	
	ringInfo.identifier		= ringIdentifier
	ringInfo.ringEnt 		= ring
	ringInfo.spawnSet 		= spawnSet 
	ringInfo.loopSetting 	= loopSetting
	ringInfo.center			= center
	ringInfo.radius			= radius
	ringInfo.closeMaxTime	= closeMaxTime
	
	AddEntityDestroyedCallback( ring, RemoveRingFromScriptManagedRingArray )
	AddToScriptManagedRingArray( ring )
	
	if( !DoesRingSettingsExist( ringIdentifier ) )
		GetRings()[ ringIdentifier ] <- ringInfo
	else 
		GetRings()[ ringIdentifier ] = ringInfo
}

bool function IsRingInfoValid( string identifier )
{
	RingInfo ringInfo = GetRingInfoByRef( identifier )	
	return ringInfo.identifier != "_invalid"
}

RingInfo function GetRingInfoByRef( string identifier )
{	
	if( identifier in GetRings() )
		return GetRings()[ identifier ]
	
	RingInfo ringInfo
	
	return ringInfo
}

array<entity> function GetRingArray()
{
	return clonedSettings.ringArray
}

void function AddToScriptManagedRingArray( entity ring )
{
	mAssert( !GetRingArray().contains( ring ), "Tried to add the same ring twice" )
	GetRingArray().append( ring )
}

void function RemoveRingFromScriptManagedRingArray( entity ring )
{
	if( GetRingArray().contains( ring ) )
		GetRingArray().removebyvalue( ring )
}

string function GetRingIdentifier( int spawnSet )
{
	string ringIdentifier = "continue_ring_" + spawnSet
	
	return ringIdentifier
}

void function DEV_KillRing( int spawnSet = -1, bool instantly = true, bool keepLooping = false )
{
	if( spawnSet == -1 )
	{
		KillAllRings()
		return
	}
	
	string ringIdentifier = GetRingIdentifier( spawnSet )
	string msg = ""
	
	if( !IsRingInfoValid( ringIdentifier ) )
	{
		msg = "Ring info was invalid";
		printt( msg )
		printm( msg )
		return
	}
	
	if( DoesRingSettingsExist( ringIdentifier ) )
	{
		if( !keepLooping )
			LoopRing( ringIdentifier, false )	
		
		if( instantly )
		{
			Signal( file.dummyEnt, ringIdentifier )
			msg = format( "Ring for spawnset [ %d ] was killed", spawnSet )
		}
		else if( !LoopRing( ringIdentifier ) )
		{
			msg = format( "Ring for spawnset [ %d ] will end after completion.", spawnSet )
		}	
	}
	else 
	{
		msg = format( "ring for spawnset [ %d ] does not exist.", spawnSet )
	}
	
	printt( msg )
	printm( msg )
}

void function KillAllRings()
{
	string msg = ""
	
	if( GetRings().len() == 0 )
	{
		msg = "No ring settings exist to kill all"
		
		printt( msg )
		printm( msg )
		return
	}
	
	if( GetRingArray().len() == 0 )
	{
		msg = "No active rings to kill."
		
		printt( msg )
		printm( msg )
		
		return
	}
	
	foreach( string identifier, RingInfo ringInfo in GetRings() )
	{
		//printt( "Table- Ring: ", identifier )
		
		if( empty( identifier ) )
			continue 
			
		LoopRing( identifier, false )
		Signal( file.dummyEnt, identifier )
	}
}

void function DEV_SetRingSettings( table<string, float> settings )
{	
	string msg = "" 
	string out = ""
	bool bFound = false 
	
	if( settings.len() == 0 )
	{
		msg = "No settings provided. Use { setting = value, setting2 = value }"
		printt( msg )
		printm( msg )
		return
	}
	
	foreach ( key, value in settings )
	{
		bool bFailed = false 
		
		if( !( key in clonedSettings.ringSettings ) )
			continue 
			
		if( !__UpdateRingSetting( key, value ) )
		{
			bFailed = true
			print("Warning: " + key + " not found in clonedSettings\n")
			
			continue 
		}
		
		if( !bFailed )
		{
			if( !bFound )
				bFound = true
			
			out = "Updated setting: " + key + " with value: \"" + string( value ) + "\"\n"
			msg += out
			
			printm( out )	
		}
	}
	
	if( bFound )
	{
		string prefix = "\n\n=== Ring Settings Updated ===\n"
		printt( prefix )
	}
	
	printt( msg )
}

array<vector> function GetPointsOnCircleForRing( vector origin, float radius, int segments = 16, float offset = 0 )
{
	array<vector> pointsOnCircle = []
	float degrees = 360.0 / float(segments)
	
	for ( int i = 0; i < segments; i++ )
	{
		float angle = degrees * i
		float radians = angle * ( PI / 180.0 )

		float x = ( radius - offset ) * cos( radians )
		float y = ( radius - offset ) * sin( radians )

		vector point = origin + <x, y, 0>
		
		pointsOnCircle.append( point )
	}
	
	return pointsOnCircle
}

//this blows, structs are weak man, weak!
bool function __UpdateRingSetting( string key, float value )
{
	bool bSuccess = true
	
	switch( key )
	{
		case "default_radius_padding":
			clonedSettings.fs_scenarios_default_radius_padding = value
			break 
			
		case "default_radius":
			clonedSettings.fs_scenarios_default_radius = value
			break
			
		case "maxIndividualMatchTime":
			clonedSettings.fs_scenarios_maxIndividualMatchTime = value
			break
			
		case "zonewars_ring_ringclosingspeed":
			clonedSettings.fs_scenarios_zonewars_ring_ringclosingspeed = value
			break
			
		case "ring_damage_step_time":
			clonedSettings.fs_scenarios_ring_damage_step_time = value
			break
			
		case "game_start_time_delay":
			clonedSettings.fs_scenarios_game_start_time_delay = value
			break
			
		case "ring_damage":
			clonedSettings.fs_scenarios_ring_damage = value
			break
			
		case "ringclosing_maxtime":
			clonedSettings.fs_scenarios_ringclosing_maxtime = value
			break
			
		case "use_random":
			clonedSettings.fs_scenarios_use_random = value
			break
			
		default:
			bSuccess = false 
	}
	
	return bSuccess
}

float function __FetchRingSetting( string key )
{
	if( empty( key ) )
		return -1.0
		
	switch( key )
	{
		case "default_radius_padding":
			return clonedSettings.fs_scenarios_default_radius_padding
			
		case "default_radius":
			return clonedSettings.fs_scenarios_default_radius
			
		case "maxIndividualMatchTime":
			return clonedSettings.fs_scenarios_maxIndividualMatchTime
			
		case "zonewars_ring_ringclosingspeed":
			return clonedSettings.fs_scenarios_zonewars_ring_ringclosingspeed
			
		case "ring_damage_step_time":
			return clonedSettings.fs_scenarios_ring_damage_step_time
			
		case "game_start_time_delay":
			return clonedSettings.fs_scenarios_game_start_time_delay
			
		case "ring_damage":
			return clonedSettings.fs_scenarios_ring_damage
			
		case "ringclosing_maxtime":
			return clonedSettings.fs_scenarios_ringclosing_maxtime
			
		case "use_random":
			return clonedSettings.fs_scenarios_use_random
			
		default:
			return -1.0
	}
	
	unreachable
}

void function DEV_RingSettings()
{
	string out 		= ""
	string display 	= ""
	
	foreach( key, value in clonedSettings.ringSettings )
	{
		int offset = 40 - key.len()
		display = "[\"" + key + "\"] " + TableIndent( offset ) + string( __FetchRingSetting( key ) )
		out += "\n" + display
		
		printm( display )
	}
	
	printt( out )
}

struct
{
	bool fs_scenarios_dropshipenabled = false
	int fs_scenarios_playersPerTeam = -1
	int fs_scenarios_teamAmount = -1

	// float fs_scenarios_max_queuetime = 150
	// int fs_scenarios_minimum_team_allowed = 1 // used only when max_queuetime is triggered
	// int fs_scenarios_maximum_team_allowed = 3
	
	bool fs_scenarios_ground_loot = false
	bool fs_scenarios_inventory_empty = false
	bool fs_scenarios_deathboxes_enabled = true
	bool fs_scenarios_bleedout_enabled = true
	bool fs_scenarios_show_death_recap_onkilled = true
	bool fs_scenarios_zonewars_ring_mode = false
	bool fs_scenarios_characterselect_enabled = true
	
	float fs_scenarios_characterselect_time_per_player = 3.5
	
	float fs_scenarios_default_radius_padding = 169
	float fs_scenarios_default_radius = 8000
	float fs_scenarios_maxIndividualMatchTime = 300
	float fs_scenarios_zonewars_ring_ringclosingspeed = 1.0
	float fs_scenarios_ring_damage_step_time = 1.5
	float fs_scenarios_game_start_time_delay = 3.0
	float fs_scenarios_ring_damage = 25.0
	float fs_scenarios_ringclosing_maxtime = 120
	float fs_scenarios_use_random = 1.0 //float bool for testing
	
	
	table<string,RingInfo> allRings
	
	array<entity> ringArray
	
	table<string,string> ringSettings =
	{
		["default_radius_padding"] 			= "fs_scenarios_default_radius_padding",
		["default_radius"] 					= "fs_scenarios_default_radius",
		["maxIndividualMatchTime"] 			= "fs_scenarios_maxIndividualMatchTime",
		["zonewars_ring_ringclosingspeed"] 	= "fs_scenarios_zonewars_ring_ringclosingspeed",
		["ring_damage_step_time"] 			= "fs_scenarios_ring_damage_step_time",
		["game_start_time_delay"] 			= "fs_scenarios_game_start_time_delay",
		["ring_damage"] 					= "fs_scenarios_ring_damage",
		["ringclosing_maxtime"] 			= "fs_scenarios_ringclosing_maxtime",
		["use_random"]						= "fs_scenarios_use_random"
	}
	
} clonedSettings

void function InitClonedSettings()
{
	file.dummyEnt = CreateEntity( "info_target" )
	
	clonedSettings.fs_scenarios_dropshipenabled 				= GetCurrentPlaylistVarBool( "fs_scenarios_dropshipenabled", true )
	clonedSettings.fs_scenarios_maxIndividualMatchTime 			= GetCurrentPlaylistVarFloat( "fs_scenarios_maxIndividualMatchTime", 300.0 )
	clonedSettings.fs_scenarios_playersPerTeam 					= GetCurrentPlaylistVarInt( "fs_scenarios_playersPerTeam", 3 )
	clonedSettings.fs_scenarios_teamAmount 						= GetCurrentPlaylistVarInt( "fs_scenarios_teamAmount", 2 )
	// clonedSettings.fs_scenarios_max_queuetime 				= GetCurrentPlaylistVarFloat( "fs_scenarios_max_queuetime", 150.0 )
	// clonedSettings.fs_scenarios_minimum_team_allowed 		= GetCurrentPlaylistVarInt( "fs_scenarios_minimum_team_allowed", 1 ) // used only when max_queuetime is triggered
	// clonedSettings.fs_scenarios_maximum_team_allowed 		= GetCurrentPlaylistVarInt( "fs_scenarios_maximum_team_allowed", 3 )

	clonedSettings.fs_scenarios_ground_loot 					= GetCurrentPlaylistVarBool( "fs_scenarios_ground_loot", true )
	clonedSettings.fs_scenarios_inventory_empty 				= GetCurrentPlaylistVarBool( "fs_scenarios_inventory_empty", true )
	clonedSettings.fs_scenarios_deathboxes_enabled 				= GetCurrentPlaylistVarBool( "fs_scenarios_deathboxes_enabled", true )
	clonedSettings.fs_scenarios_bleedout_enabled 				= GetCurrentPlaylistVarBool( "fs_scenarios_bleedout_enabled", true )
	clonedSettings.fs_scenarios_show_death_recap_onkilled 		= GetCurrentPlaylistVarBool( "fs_scenarios_show_death_recap_onkilled", true )
	clonedSettings.fs_scenarios_zonewars_ring_mode 				= GetCurrentPlaylistVarBool( "fs_scenarios_zonewars_ring_mode", true )
	clonedSettings.fs_scenarios_zonewars_ring_ringclosingspeed 	=  GetCurrentPlaylistVarFloat( "fs_scenarios_zonewars_ring_ringclosingspeed", 1.0 )
	clonedSettings.fs_scenarios_ring_damage_step_time 			= GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage_step_time", 1.5 )
	clonedSettings.fs_scenarios_game_start_time_delay 			= GetCurrentPlaylistVarFloat( "fs_scenarios_game_start_time_delay", 3.0 )
	clonedSettings.fs_scenarios_ring_damage 					= GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage", 25.0 )
	clonedSettings.fs_scenarios_characterselect_enabled 		= GetCurrentPlaylistVarBool( "fs_scenarios_characterselect_enabled", true )
	clonedSettings.fs_scenarios_characterselect_time_per_player = GetCurrentPlaylistVarFloat( "fs_scenarios_characterselect_time_per_player", 3.5 )
	clonedSettings.fs_scenarios_ringclosing_maxtime 			= GetCurrentPlaylistVarFloat( "fs_scenarios_ringclosing_maxtime", 100 )
}

void function FS_Scenarios_StartRingMovementForGroup_clone( entity ring, vector calculatedRingCenter, float currentRingRadius, int spawnSet )
{
	if( !IsValid( ring ) )
		return

	string ringIdentifier = GetRingIdentifier( spawnSet )
	
	Signal( file.dummyEnt, ringIdentifier )
	WaitFrame()
	
	EndSignal( file.dummyEnt, ringIdentifier )
	
	OnThreadEnd
	(
		function() : ( ring, spawnSet, ringIdentifier )
		{
			if( IsValid( ring ) )
			{
				ring.Destroy()
			}
			
			if( LoopRing( ringIdentifier ) )
				FS_Scenarios_CreateCustomDeathfield_clone( spawnSet )
		}
	)

	float starttime = Time()
	float endtime = Time() + clonedSettings.fs_scenarios_ringclosing_maxtime
	float startradius = currentRingRadius
	float oldMaxTime = clonedSettings.fs_scenarios_ringclosing_maxtime
	
	string ringDebug = "RING SIMULATION STARTED: Duration Closing " + ( endtime - Time() ) + "Starting Radius: " + startradius
	printt( ringDebug )
	printm( ringDebug )

	while ( currentRingRadius > 0 )
	{
		float radius = currentRingRadius
		
		if ( clonedSettings.fs_scenarios_ringclosing_maxtime != oldMaxTime )
		{
			endtime = AdjustEndTime( oldMaxTime, clonedSettings.fs_scenarios_ringclosing_maxtime, endtime )
			oldMaxTime = clonedSettings.fs_scenarios_ringclosing_maxtime
		}
	
		if( !clonedSettings.fs_scenarios_zonewars_ring_mode )
			currentRingRadius = radius - clonedSettings.fs_scenarios_zonewars_ring_ringclosingspeed
		else
			currentRingRadius = GraphCapped( Time(), starttime, endtime, startradius, 0 )

		foreach( player in GetPlayerArray() )
		{
			player.SetPlayerNetTime( "FS_Scenarios_currentDeathfieldRadius", currentRingRadius )
			player.SetPlayerNetTime( "FS_Scenarios_currentDistanceFromCenter", Distance2D( player.GetOrigin(), calculatedRingCenter ) )
		}

		WaitFrame()
	}
	
	DEV_KillRing( spawnSet, false, true )
}

float function AdjustEndTime( float oldMaxTime, float newMaxTime, float currentEndTime )
{
	float timeNow = Time()
	float timeElapsed = timeNow - ( currentEndTime - oldMaxTime )
	float newEndTime = timeNow + ( newMaxTime - timeElapsed )
	
	return newEndTime
}

vector function OriginToGround_Inverse_clone( vector origin )
{
	vector startorigin = origin - < 0, 0, 1000 >
	TraceResults traceResult = TraceLine( startorigin, origin + < 0, 0, 128 >, [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )

	return traceResult.endPos
}

void function FS_Scenarios_CreateCustomDeathfield_clone( int spawnSet, string ringIdentifier = "", bool bLoop = true )
{
	array<LocPair>spawnSetInfo = DEV_ShowCenter( spawnSet, true )
	
	mAssert( spawnSetInfo.len() > 2, "Invalid spawns passed to ring simulator" )
	
	LocPair spawnSetCenter = spawnSetInfo.pop()

	vector Center = OriginToGround_Inverse_clone( spawnSetCenter.origin )
	
	float ringRadius = 0
	
	if( clonedSettings.fs_scenarios_use_random )
	{
		foreach( LocPair spawn in spawnSetInfo )
		{
			if( Distance( spawn.origin, Center ) > ringRadius )
				ringRadius = Distance( spawn.origin, Center )
		}
		
		Center = OriginToGround_Inverse_clone
				( 
					GetPointsOnCircleForRing
					( 
						Center, 
						ringRadius + RandomFloatRange( 50.0, 500.0 ),
						16,
						RandomFloatRange( 20.0, 500.0 )
						
					).getrandom() 
				)
	}
	
	foreach( LocPair spawn in spawnSetInfo )
	{
		if( Distance( spawn.origin, Center ) > ringRadius )
			ringRadius = Distance( spawn.origin, Center )
	}
	

	float calculatedRingRadius = ringRadius + clonedSettings.fs_scenarios_default_radius_padding
	float currentRingRadius = calculatedRingRadius
	
	if( !clonedSettings.fs_scenarios_zonewars_ring_mode )
		calculatedRingRadius = clonedSettings.fs_scenarios_default_radius

	float radius = calculatedRingRadius


    vector smallRingCenter = Center
	entity smallcircle = CreateEntity( "prop_script" )
	smallcircle.SetValueForModelKey( $"mdl/dev/empty_model.rmdl" )
	smallcircle.kv.fadedist = 2000
	smallcircle.kv.renderamt = 1
	smallcircle.kv.solid = 0
	smallcircle.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	smallcircle.SetOwner( file.dummyEnt )
	smallcircle.SetOrigin( smallRingCenter )
	smallcircle.SetAngles( <0, 0, 0> )
	smallcircle.NotSolid()
	smallcircle.DisableHibernation()
	SetTargetName( smallcircle, "scenariosDeathField" )

	DispatchSpawn(smallcircle)

	entity ring = smallcircle
	
	if( empty( ringIdentifier ) )
		ringIdentifier = GetRingIdentifierBySpawnSet( spawnSet )
	
	CreateRingSettings
	(
		ringIdentifier,
		ring,
		spawnSet,
		bLoop,
		Center,
		radius,
		clonedSettings.fs_scenarios_ringclosing_maxtime
	)
	
	LoopRing( ringIdentifier, bLoop )

	thread FS_Scenarios_StartRingMovementForGroup_clone( ring, Center, currentRingRadius, spawnSet )
}

array<LocPair> function customDevSpawnsList()
{
	array<LocPair> spawns
	
	//add sq code spawns for usage with DEV_LoadPak()
	spawns = 
	[

	]
	
	return spawns
}
#endif //DEVELOPER