// Made by @CafeFPS ( original idea and code template )
// mkos - multiplayer compatibility overhaul, code refactor, features
// Todo(mk): QOL Update-- Allow each slot to have a set playback rate per player, with a ui slider/input field to modify per-slot. 0 for inf or frozen.

#if SERVER
	global function ClientCommand_DestroyDummys
	global function MovementRecorder_SetPlaybackRate
#endif

#if CLIENT
	global function FS_MovementRecorder_UpdateHints
	global function FS_MovementRecorder_CreateInputHintsRUI
#endif

global function Sh_FS_MovementRecorder_Init

struct RecordingAnimation
{
	vector origin
	vector angles
	var anim
}

const int MAX_SLOT = 5
const int MAX_NPC_BUDGET = 120 //dirty cap
const int DUMMY_MAX_HEALTH = 100

struct
{
	#if CLIENT
		array<var> inputHintLines
		table<string,string> playerOriginalBindings
	#endif
	
	#if SERVER
		int playbackLimit = -1	
		table<int, table<int, array<entity> > > playerDummyMaps //[ehandle][slot] = dummy
		table<int, table<int,int> > playerPlaybackAmounts = {} //[ehandle][slot] = amount
		//table<int, table<int,float> > playerPlaybackDurations = {} //[ehandle][slot] = duration
		
		float helmet_lv4 = 0.65
		float adminSetPlaybackRate = 1.0
		bool bDummyDeathNotifications = true
		bool bAutoRefilAmmoOnHit
		float randomPlaybackDelay = 0.2
		
		table<int, array<entity> > _dummyMaps__Template = {
			[ 0 ] = [ null ],
			[ 1 ] = [ null ],
			[ 2 ] = [ null ],
			[ 3 ] = [ null ],
			[ 4 ] = [ null ]
		}
		
		table <int, int> _playbackAmounts__Template = {
			[ 0 ] = 0,
			[ 1 ] = 0,
			[ 2 ] = 0,
			[ 3 ] = 0,
			[ 4 ] = 0
		}
		
		// table <int, float> _playbackDuration__Template = {
			// [ 0 ] = 1.0,
			// [ 1 ] = 1.0,
			// [ 2 ] = 1.0,
			// [ 3 ] = 1.0,
			// [ 4 ] = 1.0
		// }
	
	#endif
	
} file

void function Sh_FS_MovementRecorder_Init()
{
	#if CLIENT
		AddCallback_OnClientScriptInit( FS_MovementRecorder_SetBindings )
		AddClientCallback_OnResolutionChanged( FS_MovementRecorder_OnResolutionChanged )	
	#endif
	
	#if SERVER
		//Todo(mk): Dynmaically create all templates from one source
		disableoverwrite( file._playbackAmounts__Template ) //(mk): prevent modifying template
		disableoverwrite( file._dummyMaps__Template )
		//disableoverwrite( file._playbackDuration__Template )
		
		AddCallback_OnClientConnected( FS_MovementRecorder_OnPlayerConnected )
		AddCallback_OnClientDisconnected( _HandlePlayerDisconnect )
		AddCallback_OnPlayerRespawned( _HandleRespawn )
		AddCallback_OnPlayerKilled( _OnPlayerKilled )
		
		AddClientCommandCallback( "recorder_toggleRecorder", ClientCommand_ToggleMovementRecorder )
		AddClientCommandCallback( "PlayAnimInSlot", ClientCommand_PlayAnimInSlot )
		AddClientCommandCallback( "PlayAllAnims", ClientCommand_PlayAllAnims )
		AddClientCommandCallback( "recorder_switchCharacter", ClientCommand_SwitchCharacter )
		AddClientCommandCallback( "recorder_recorderHideHud", ClientCommand_HideHud )
		AddClientCommandCallback( "recorder_toggleContinueLoop", ClientCommand_ToggleContinueLoop )	
		AddClientCommandCallbackNew( "DestroyDummys", ClientCommand_DestroyDummys )
			
		RegisterSignal( "EndDummyThread" )
		RegisterSignal( "FinishedRecording" )
		RegisterSignal( "PlayRandomAnimation" )
		
		foreach( k,v in file._playbackAmounts__Template )
		{
			RegisterSignal( "EndDummyThread_Slot_" + k.tostring() )
		}
		
		file.playbackLimit 				= GetCurrentPlaylistVarInt( "flowstate_limit_playback_per_slot_amount", -1 )
		file.helmet_lv4 				= GetCurrentPlaylistVarFloat( "helmet_lv4", 0.65 )
		file.bDummyDeathNotifications 	= GetCurrentPlaylistVarBool( "register_dummie_kill_as_actual_kill", false )
		file.bAutoRefilAmmoOnHit		= GetCurrentPlaylistVarBool( "auto_refill_ammo_on_hit", false )
		file.randomPlaybackDelay		= GetCurrentPlaylistVarFloat( "delay_between_random_playback", 0.2 )
		
		if( !FlowState_AdminTgive() )
			INIT_WeaponsMenu()
		else
			INIT_WeaponsMenu_Disabled()
	#endif
}

#if SERVER
void function INIT_WeaponsMenu()
{
	AddClientCommandCallback("CC_MenuGiveAimTrainerWeapon", CC_MenuGiveAimTrainerWeapon ) 
	AddClientCommandCallback("CC_AimTrainer_SelectWeaponSlot", CC_AimTrainer_SelectWeaponSlot )
	AddClientCommandCallback("CC_AimTrainer_WeaponSelectorClose", CC_AimTrainer_CloseWeaponSelector )
	AddClientCommandCallbackNew("CC_AimTrainer_WeaponSelectorClose", MovementRecorder_SetupWeapons )
}

void function INIT_WeaponsMenu_Disabled()
{
	AddClientCommandCallback("CC_MenuGiveAimTrainerWeapon", MessagePlayer_Disabled ) 
	AddClientCommandCallback("CC_AimTrainer_SelectWeaponSlot", MessagePlayer_Disabled )
	AddClientCommandCallback("CC_AimTrainer_WeaponSelectorClose", MessagePlayer_Disabled )
}

bool function MessagePlayer_Disabled( entity player, array<string> args )
{
	LocalEventMsg( player, "#FS_DisabledTDMWeps" )
	return true
}

void function MovementRecorder_SetupWeapons( entity player, array<string> args )
{	
	if( !IsValid( player ) )
		return 
		
	if( Playlist() == ePlaylists.fs_movementrecorder && !FlowState_AdminTgive() )
	{
		entity primary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_0 )
		entity secondary = player.GetNormalWeapon( WEAPON_INVENTORY_SLOT_PRIMARY_1 )
		
		player.RefillAllAmmo()
		
		if( IsValid( primary ) )
			SetupInfiniteAmmoForWeapon( player, primary )
			
		if( IsValid( secondary ) )
			SetupInfiniteAmmoForWeapon( player, secondary )
	}
}

void function MovementRecorder_SetPlaybackRate( float value )
{
	file.adminSetPlaybackRate = value
}
#endif

//shared
string function slotname( int slot )
{
	switch( slot )
	{
		case 1: return "[F3]";
		case 2: return "[F4]";
		case 3: return "[F5]";
		case 4: return "[F6]";
		case 5: return "[F7]";
		default: return "";
	}
	
	unreachable
}

#if CLIENT

// Todo(mk): Create BindSystem_ framework for any game mode to use during development for client scripts, 
// saves current bindings, adds a disconnect callback to restore binds, proper checking.. etc 
// will need to handle gamepad as well as various bind types (held) etc. 
// save for next release, for now, this recorder specific logic.

const table<string,string> RECORDER_BINDINGS = 
{
	["F2"] = "recorder_toggleRecorder",
	["F3"] = "\"PlayAnimInSlot 0\"",
	["F4"] = "\"PlayAnimInSlot 1\"",
	["F5"] = "\"PlayAnimInSlot 2\"",
	["F6"] = "\"PlayAnimInSlot 3\"",
	["F7"] = "\"PlayAnimInSlot 4\"",
	["F8"] = "PlayAllAnims",
	["F11"] = "recorder_switchCharacter",
	["F12"] = "recorder_toggleContinueLoop"
}

void function FS_MovementRecorder_SetBindings( entity player )
{
	MovementRecorder_SaveCurrentBindings()
	AddCallback_OnPlayerDisconnected( FS_MovementRecorder_ResetAllBindings )
	
	foreach( key, command in RECORDER_BINDINGS )
		player.ClientCommand( "bind_US_standard " + key + " " + command )

	FS_MovementRecorder_CreateInputHintsRUI( false )
}

void function MovementRecorder_SaveCurrentBindings()
{
	foreach( keyName, _ in RECORDER_BINDINGS )
	{
		int keyCode 	= KeyNameToKeyCode( keyName ) 
		string command 	= GetKeyTappedBinding( keyCode )
		
		file.playerOriginalBindings[ keyName ] <- command
	}
}

string function MovementRecorder_GetSavedBindCommand( string keyName )
{
	if( keyName in file.playerOriginalBindings )
		return file.playerOriginalBindings[ keyName ]
		
	return ""
}

void function FS_MovementRecorder_ResetAllBindings( entity player )
{
	if( player != GetLocalClientPlayer() )
		return 
		
	foreach( keyName, _ in RECORDER_BINDINGS )
	{
		string commandToRestore = MovementRecorder_GetSavedBindCommand( keyName )
		
		if( commandToRestore == "" )
			player.ClientCommand( "unbind " + keyName )
		else
			player.ClientCommand( "bind_US_standard " + keyName + " " + commandToRestore )
	}
}

void function FS_MovementRecorder_CreateInputHintsRUI( bool state )
{
	foreach( line in file.inputHintLines )
		if( line != null )
		{
			RuiDestroyIfAlive( line )
		}

	file.inputHintLines.clear()

	if( state )
		return

	UISize screenSize = GetScreenSize()
	var topo = RuiTopology_CreatePlane( <( screenSize.width * 0.070),( screenSize.height * 0 ), 0>, <float( screenSize.width ), 0, 0>, <0, float( screenSize.height ), 0>, false )
	var hintRui = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui, "buttonText", "%F2%" )
	RuiSetString( hintRui, "gamepadButtonText", "%F2%" )
	RuiSetString( hintRui, "hintText", "Start Recording" )
	RuiSetString( hintRui, "altHintText", "" )
	RuiSetInt( hintRui, "hintOffset", 0 )
	RuiSetBool( hintRui, "hideWithMenus", false )
	file.inputHintLines.append( hintRui )

	var hintRui2 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui2, "buttonText", "%F3%" )
	RuiSetString( hintRui2, "gamepadButtonText", "%F3%" )
	RuiSetString( hintRui2, "hintText", "Slot [F3] - Empty" )
	RuiSetString( hintRui2, "altHintText", "" )
	RuiSetInt( hintRui2, "hintOffset", 1 )
	RuiSetBool( hintRui2, "hideWithMenus", false )
	file.inputHintLines.append( hintRui2 )

	var hintRui3 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui3, "buttonText", "%F4%" )
	RuiSetString( hintRui3, "gamepadButtonText", "%F4%" )
	RuiSetString( hintRui3, "hintText", "Slot [F4] - Empty" )
	RuiSetString( hintRui3, "altHintText", "" )
	RuiSetInt( hintRui3, "hintOffset", 2 )
	RuiSetBool( hintRui3, "hideWithMenus", false )
	file.inputHintLines.append( hintRui3 )

	var hintRui4 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui4, "buttonText", "%F5%" )
	RuiSetString( hintRui4, "gamepadButtonText", "%F5%" )
	RuiSetString( hintRui4, "hintText", "Slot [F5] - Empty" )
	RuiSetString( hintRui4, "altHintText", "" )
	RuiSetInt( hintRui4, "hintOffset", 3 )
	RuiSetBool( hintRui4, "hideWithMenus", false )
	file.inputHintLines.append( hintRui4 )

	var hintRui5 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui5, "buttonText", "%F6%" )
	RuiSetString( hintRui5, "gamepadButtonText", "%F6%" )
	RuiSetString( hintRui5, "hintText", "Slot [F6] - Empty" )
	RuiSetString( hintRui5, "altHintText", "" )
	RuiSetInt( hintRui5, "hintOffset", 4 )
	RuiSetBool( hintRui5, "hideWithMenus", false )
	file.inputHintLines.append( hintRui5 )

	var hintRui6 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui6, "buttonText", "%F7%" )
	RuiSetString( hintRui6, "gamepadButtonText", "%F7%" )
	RuiSetString( hintRui6, "hintText", "Slot [F7] - Empty" )
	RuiSetString( hintRui6, "altHintText", "" )
	RuiSetInt( hintRui6, "hintOffset", 5 )
	RuiSetBool( hintRui6, "hideWithMenus", false )
	file.inputHintLines.append( hintRui6 )

	var hintRui7 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui7, "buttonText", "%F8%" )
	RuiSetString( hintRui7, "gamepadButtonText", "%F8%" )
	RuiSetString( hintRui7, "hintText", "Play All Anims" )
	RuiSetString( hintRui7, "altHintText", "" )
	RuiSetInt( hintRui7, "hintOffset", 6 )
	RuiSetBool( hintRui7, "hideWithMenus", false )
	file.inputHintLines.append( hintRui7 )

	var hintRui8 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui8, "buttonText", "%F11%" )
	RuiSetString( hintRui8, "gamepadButtonText", "%F11%" )
	RuiSetString( hintRui8, "hintText", "Character: Wraith" )
	RuiSetString( hintRui8, "altHintText", "" )
	RuiSetInt( hintRui8, "hintOffset", 7 )
	RuiSetBool( hintRui8, "hideWithMenus", false )
	file.inputHintLines.append( hintRui8 )

	var hintRui9 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui9, "buttonText", "%F12%" )
	RuiSetString( hintRui9, "gamepadButtonText", "%F12%" )
	RuiSetString( hintRui9, "hintText", "Loop Anim: ON" )
	RuiSetString( hintRui9, "altHintText", "" )
	RuiSetInt( hintRui9, "hintOffset", 8 )
	RuiSetBool( hintRui9, "hideWithMenus", false )
	file.inputHintLines.append( hintRui9 )

	var hintRui10 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui10, "buttonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui10, "gamepadButtonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui10, "hintText", "Crouch + Slot to clear" )
	RuiSetString( hintRui10, "altHintText", "" )
	RuiSetInt( hintRui10, "hintOffset", 9 )
	RuiSetBool( hintRui10, "hideWithMenus", false )
	file.inputHintLines.append( hintRui10 )
	
	var hintRui11 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui11, "buttonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui11, "gamepadButtonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui11, "hintText", "Crouch + %F8% = clearall" )
	RuiSetString( hintRui11, "altHintText", "" )
	RuiSetInt( hintRui11, "hintOffset", 10 )
	RuiSetBool( hintRui11, "hideWithMenus", false )
	file.inputHintLines.append( hintRui11 )
	
	var hintRui12 = RuiCreate( $"ui/tutorial_hint_line.rpak", topo, RUI_DRAW_POSTEFFECTS, MINIMAP_Z_BASE + 10 )
	RuiSetString( hintRui12, "buttonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui12, "gamepadButtonText", "%$rui/menu/buttons/tip%" )
	RuiSetString( hintRui12, "hintText", "Crouch + %F2% = random" )
	RuiSetString( hintRui12, "altHintText", "" )
	RuiSetInt( hintRui12, "hintOffset", 11 )
	RuiSetBool( hintRui12, "hideWithMenus", false )
	file.inputHintLines.append( hintRui12 )
}

void function FS_MovementRecorder_UpdateHints( int hint, bool state, float duration )
{
	if( file.inputHintLines[ hint ] == null )
		return

	if( hint == 0 && state )
	{
		RuiSetString( file.inputHintLines[0], "hintText", "Stop Recording" )
		return
	} else if( hint == 0 && !state )
	{
		RuiSetString( file.inputHintLines[0], "hintText", "Start Recording" )
		return
	}

	if( hint == 7 )
	{
		string characterToUse
		switch( duration.tointeger() )
		{
			case 0:
			characterToUse = "Wraith"
			break
			
			case 1:
			characterToUse = "Pathfinder"
			break
			
			case 2:
			characterToUse = "Bangalore"
			break
			
			case 3:
			characterToUse = "Octane"
			break

			default:
			characterToUse = "Wraith"
			break
		}
		RuiSetString( file.inputHintLines[hint], "hintText", "Character: " + characterToUse )
		return
	}

	if( hint == 8 && state )
	{
		RuiSetString( file.inputHintLines[hint], "hintText", "Loop Anim: ON" )
		return
	}
	else if( hint == 8 && !state )
	{
		RuiSetString( file.inputHintLines[hint], "hintText", "Loop Anim: OFF" )
		return
	}

	if( state )	
	{
		DisplayTime dt = SecondsToDHMS( duration.tointeger() )
		RuiSetString( file.inputHintLines[hint], "hintText", "Slot " + slotname(hint) + " - Play " + format( "%.2d:%.2d", dt.minutes, dt.seconds ) )
		return
	} else if( !state )
	{
		RuiSetString( file.inputHintLines[hint], "hintText", "Slot " + slotname(hint) + " - Empty" )
		return
	}
}

void function FS_MovementRecorder_OnResolutionChanged()
{
	FS_MovementRecorder_CreateInputHintsRUI( false )
}
#endif //CLIENT

#if SERVER

void function _HandlePlayerDisconnect( entity player )
{
	int playerHandle = player.p.handle 
	
	//(mk): might be helpful to free up open slots. ty wanderer for looking up internal mechanisms. 
	ForceStopRecording( player )
	
	foreach ( slot, dummies in file.playerDummyMaps[playerHandle] )
			DestroyDummyForSlot( player, slot, playerHandle )
}

void function _HandleRespawn( entity player )
{
	AssignCharacter( player, 8 )
}

void function _OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	ForceStopRecording( victim )
}

void function FS_MovementRecorder_OnPlayerConnected( entity player )
{
	player.p.recordingAnims.resize( MAX_SLOT )
	player.p.recordingAnimsCoordinates.resize( MAX_SLOT )
	player.p.recordingAnimsChosenCharacters.resize( MAX_SLOT )
	
	FS_MovementRecorder_PlayerInit( player )
	SetTeam( player, 2 )
}

void function FS_MovementRecorder_PlayerInit( entity player )
{
	if ( !IsValid( player ) )
		return 
		
	int playerHandle = player.p.handle
	
	table<int, array<entity> > init_playerDummyMap 	= clone file._dummyMaps__Template
	table<int,int> init_playerPlaybackAmounts 		= clone file._playbackAmounts__Template	
	//table<int,float> init_playerPlaybackDurations	= clone file._playbackDuration__Template
	
	file.playerPlaybackAmounts[ playerHandle ] <- init_playerPlaybackAmounts
	file.playerDummyMaps[ playerHandle ] <- init_playerDummyMap
	//file.playerPlaybackDurations[ playerHandle ] <- init_playerPlaybackDurations
	
	//PrintMovementRecorderTable( file.playerPlaybackAmounts )
}

bool function ClientCommand_ToggleMovementRecorder( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return false

	bool bPlayRandom = player.IsInputCommandHeld( IN_DUCK )

	if( bPlayRandom )
	{
		if( !bDoesAnyAnimationExist( player ) )
		{
			if( !player.p.recorderHideHud )
				LocalEventMsg( player, "#FS_NO_ANIMS", "", 3 )
				
			return true
		}
		
		if( !IsOverBudget( player ) )	
			thread PlayRandomAnimation( player )
			
		return true
	}

	if( player.p.isRecording )
	{
		StopRecordingAnimation( player )
	} 
	else
	{
		int slot = FS_MovementRecorder_GetEmptySlotForPlayer( player )
	
		if( slot == -1 )
		{
			if( !player.p.recorderHideHud )
				LocalEventMsg( player, "#FS_NO_SLOTS" )
				
			return true
		}
	
		if( !IsAlive( player ) )
			DecideRespawnPlayer( player, true )

		player.p.isRecording = true //(mk): prevent thread leak, set here.
		thread StartRecordingAnimation( player )
	}
	
	return true
}

bool function ClientCommand_PlayAnimInSlot( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return false
		
	if( args.len() == 0 )
		return false
	
	int slot = 0
	
	if( IsNumeric( args[ 0 ] ) )
	{
		slot = args[ 0 ].tointeger()
	}
	else 
	{
		#if DEVELOPER
			printt( "Invalid commmand sent" )
		#endif
		return false
	}
	
	bool remove = player.IsInputCommandHeld( IN_DUCK )
	
	if( !remove && !HasSlotAllocation( player, slot ) )
	{
		return true
	}

	thread PlayAnimInSlot( player, slot, remove )
		return true
}

bool function ClientCommand_PlayAllAnims( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return false

	bool remove = player.IsInputCommandHeld( IN_DUCK )

	if( !player.p.recorderHideHud )
	{	
		string token = remove ? "#FS_REMOVING_ALL_ANIMS" : "#FS_PLAYING_ALL_ANIMS";
		LocalEventMsg( player, token )
	}
	
	bool removeAll = false
	
	if( remove )
	{
		removeAll = true
	}
	

	for( int i = 0; i < MAX_SLOT ; i++ )
		thread PlayAnimInSlot( player, 	i, remove, removeAll )

	return true
}

bool function ClientCommand_SwitchCharacter( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return false

	if( player.p.isRecording )
	{
		if( !player.p.recorderHideHud )
			LocalEventMsg( player, "#FS_CANT_SWITCH_LEGEND", "", 3 )
			
		return false
	}

	if( player.p.movementRecorderCharacter + 1 > 3 )
	{ 
		player.p.movementRecorderCharacter = 0
	} 
	else 
	{
		player.p.movementRecorderCharacter++
	}

	Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 7, true, player.p.movementRecorderCharacter )
	
	AssignCharacter( player, PlayerSavedCharacter_To_ItemFlavorIndex( player.p.movementRecorderCharacter ) )
	
	return true
}

bool function ClientCommand_HideHud(entity player, array<string> args)
{
	if( !IsValid( player ) )
		return false

	if( player.p.recorderHideHud )
	{
		player.p.recorderHideHud = false
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_CreateInputHintsRUI", false )
	}
	else if( !player.p.recorderHideHud )
	{
		player.p.recorderHideHud = true
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_CreateInputHintsRUI", true )
	}
	return true
}

bool function ClientCommand_ToggleContinueLoop(entity player, array<string> args)
{
	if( !IsValid( player ) )
		return false

	if( player.p.continueLoop )
	{
		player.p.continueLoop = false
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 8, false, -1 )
	} 
	else if( !player.p.continueLoop )
	{
		player.p.continueLoop = true
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 8, true, -1 )
	}
	return true
}

int function PlayerSavedCharacter_To_ItemFlavorIndex( int switchcase )
{
	switch( switchcase )
	{
		case 0: return 8;
		case 1: return 7;
		case 2: return 0;
		case 3: return 6;
		default: return 0;	
	}
	unreachable
}

void function StartRecordingAnimation( entity player )
{
	if( !IsValid( player ) )//(mk):threaded off
		return
		
	if( !player.p.isRecording )
		mAssert( false, "Tried to spawn recording thread without setting state." )
		
	player.p.currentOrigin = player.GetOrigin()
	player.p.currentAngles = player.GetAngles()
	
	string msg1

	switch( player.p.movementRecorderCharacter )
	{
		case 0:
			msg1 = "RECORDING MOVEMENT AS WRAITH"
			AssignCharacter(player, 8)
		break
		
		case 1:
			msg1 = "RECORDING MOVEMENT AS PATHFINDER"
			AssignCharacter(player, 7)
		break
		
		case 2:
			msg1 = "RECORDING MOVEMENT AS BANGALORE"
			AssignCharacter(player, 0)
		break
		
		case 3:
			msg1 = "RECORDING MOVEMENT AS OCTANE"
			AssignCharacter(player, 6)
		break
		
		default:
			msg1 = "RECORDING MOVEMENT"
			AssignCharacter(player, 0)
		break
	}

	if( !player.p.recorderHideHud )
	{
		LocalEventMsg( player, "#FS_RECORDINGANIM_CUSTOM", msg1, 86400 )
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 0, true, -1 )
	}
	
	//asset playermodel = player.GetModelName() //?
	
	//MovementRecorder_SetStartRecordingTime( player, Time() )
	player.StartRecordingAnimation( player.p.currentOrigin, player.p.currentAngles )
	
	OnThreadEnd
	(
		void function() : ( player )
		{
			if( IsValid( player ) )
			{
				if( player.p.isRecording )
					StopRecordingAnimation( player )
			}
		}
	)
	
	//(mk): Recording animations disappear after 2:30, hard-set limit of 3000 frames.
	waitthread WaitSignalOrTimeout( player, 148, "OnDestroy", "OnDisconnected", "FinishedRecording" )
}

void function ForceStopRecording( entity player ) //(mk):caller must check
{
	if( !player.p.isRecording )
		return 
		
	player.StopRecordingAnimation()
	player.p.isRecording = false
	
	LocalEventMsg( player, "#FS_SPACE", "", 1 )
	Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 0, false, -1 )
}

// void function MovementRecorder_SetStartRecordingTime( entity player, float time )
// {
	// player.p.recordingStartTime = time
// }

// float function MovementRecorder_GetStartRecordingTime( entity player )
// {
	// return player.p.recordingStartTime
// }

int function FS_MovementRecorder_GetEmptySlotForPlayer( entity player )
{
	foreach( int i, var anim in player.p.recordingAnims )
	{
		if( anim == null )
			return i
	}
	
	return -1
}
void function StopRecordingAnimation( entity player )
{
	if( !player.p.isRecording )
		return
	
	int slot = FS_MovementRecorder_GetEmptySlotForPlayer( player )
	
	if( slot == -1 )
	{
		if( !player.p.recorderHideHud )
			LocalEventMsg( player, "#FS_NO_SLOTS" )
			
		ForceStopRecording( player )
		
		return
	}

	LocPair animData
	animData.origin = player.p.currentOrigin
	animData.angles = player.p.currentAngles

	player.p.recordingAnims[ slot ] = player.StopRecordingAnimation(); player.p.isRecording = false
	player.p.recordingAnimsCoordinates[ slot ] = animData
	player.p.recordingAnimsChosenCharacters[ slot ] = player.p.movementRecorderCharacter
	player.Signal( "FinishedRecording" ) //(mk): cleanup watcher thread.
	
	
	// float endTime = Time()
	// float startTime = MovementRecorder_GetStartRecordingTime( player )
	// float slotDuration = endTime - startTime
	
	// MovementRecorder_SetSlotDuration( player, slot, slotDuration )

	if( !player.p.recorderHideHud )
	{
		LocalEventMsg( player, "#FS_MOVEMENT_SAVED", slotname( slot + 1 ) )
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", 0, false, -1 )

		var anim = player.p.recordingAnims[ slot ]
		float duration = GetRecordedAnimationDuration( anim )
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", slot + 1, true, duration )
	}
}

const array<string> r5rDevs = 
[
	"CafeFPS",
	"DEAFPS",
	"zee_x64",
	"Makimakima",
	"Endergreen12",
	"Julefox",
	"amos_x64",
	"rexx_x64",
	"IcePixelx", 
	"KralRindo",
	"sal",
	"mkos",
	"fireproof"
]

bool function bDoesAnyAnimationExist( entity player )
{
	if( !IsValid( player ) )
		return false
		
	int playerHandle = player.p.handle
		
	if( !( playerHandle in file.playerDummyMaps ) )
		return false
		
	foreach( slot, dummyArray in file._dummyMaps__Template )
	{
		if ( player.p.recordingAnims[ slot ] != null )
			return true
	}
	
	return false
}

void function PlayRandomAnimation( entity player )
{
	if( !IsValid( player ) )
		return 
	
	ClientCommand_DestroyDummys( player, [] )
	player.Signal( "PlayRandomAnimation" )	
	EndSignal( player, "OnDisconnected", "OnDestroy", "PlayRandomAnimation" )
	
	int slot;
	int playerHandle = player.p.handle
	
	if( !player.p.recorderHideHud )
		LocalMsg( player, "#FS_PLAYING_RANDOM", "#FS_PLAYING_RANDOM_DESC" )
	
	OnThreadEnd
	(
		void function() : ( player, slot )
		{
			if( IsValid( player ) )
			{
				DestroyDummyForSlot( player, slot )
			}
		}
	)
	
	while( true )
	{
		WaitFrame()
		
		if( !IsValid( player ) )
			return 
		
		if( !( playerHandle in file.playerDummyMaps ) )
			return 
			
		array<int> randomSlots = []
	
		for( int i = 0; i < file._dummyMaps__Template.len(); i++ )
		{
			if( player.p.recordingAnims[i] != null )
				randomSlots.append( i )
		}
		
		if( randomSlots.len() <= 0 )
		{
			if( !player.p.recorderHideHud )
				LocalEventMsg( player, "#FS_NO_ANIMS" )
			
			return
		}
		
		slot = randomSlots.getrandom()
		var anim = player.p.recordingAnims[slot]
		
		if( anim == null )
			continue
			
		if( !HasSlotAllocation( player, slot, true ) )
			continue 
			
		PlayAnimInSlot( player, slot, false, false, true )
		
		//(mk): No need to wait, PlayAnimInSlot() will wait this thread as well.
		//MovementRecorder_WaitForAnimToFinish( anim ) 
		
		wait 0.1
		
		if( !IsValid( player ) || !player.p.continueLoop )
			return
			
		wait file.randomPlaybackDelay
	}
}

void function PlayAnimInSlot( entity player, int slot, bool remove = false, bool removeAll = false, bool bIsPlayingRandomSlot = false )
{
	if( !remove && !HasSlotAllocation( player, slot ) )
	{
		return
	}
	
	if( !remove && IsOverBudget( player ) )
	{
		return
	}
	
	EndSignal( player, "EndDummyThread", "EndDummyThread_Slot_" + slot.tostring() )
	EndSignal( svGlobal.levelEnt, "EndDummyThread" )
	
	int playerHandle = player.p.handle
	
	#if DEVELOPER
		printt( "playaniminslot", slot )
	#endif

	var anim = player.p.recordingAnims[slot]
	
	if( !remove && anim == null )
	{
		if( !player.p.recorderHideHud )
			LocalEventMsg( player, "#FS_ANIM_NOT_FOUND", "", 3 )
			
		return
	}

	if( remove && anim != null )
	{
		player.p.recordingAnims[ slot ] = null
		Remote_CallFunction_NonReplay( player, "FS_MovementRecorder_UpdateHints", slot + 1, false, -1 )

		if( !player.p.recorderHideHud && !removeAll )
			LocalEventMsg( player, "#FS_ANIM_REMOVED_SLOT", slotname( slot + 1 ), 3 )
			
		DestroyDummyForSlot( player, slot )
		
		return
	}
	else if( !remove )
	{
		if( !player.p.recorderHideHud )
			LocalEventMsg( player, "#FS_PLAYING_ANIM", slotname( slot + 1 ), 3 )
	}
	else if ( remove )
	{
		return
	}

	vector initialpos = player.p.recordingAnimsCoordinates[ slot ].origin
	vector initialang = player.p.recordingAnimsCoordinates[ slot ].angles

	string aiFileToUse
	switch( player.p.recordingAnimsChosenCharacters[ slot ] )
	{
		case 0:
			aiFileToUse = "npc_dummie_wraith"
		break
		
		case 1:
			aiFileToUse = "npc_dummie_pathfinder"
		break
		
		case 2:
			aiFileToUse = "npc_dummie_bangalore"
		break
		
		case 3:
			aiFileToUse = "npc_dummie_octane"
		break
		
		default:
			aiFileToUse = "npc_dummie_wraith"
		break
	}
	

	while( true )
	{
		entity dummy = CreateDummy( 99, initialpos, initialang )
		file.playerPlaybackAmounts[ player.p.handle ][ slot ]++
		
			EndSignal( player, "EndDummyThread", "EndDummyThread_Slot_" + slot.tostring() )
			EndSignal( svGlobal.levelEnt, "EndDummyThread" )

			OnThreadEnd
			( 
				void function() : ( player, dummy, slot )
				{
					if( IsValid( dummy ) )
						RemoveDummyForPlayer( player, dummy, slot )			
				}
			)
		
		vector pos = dummy.GetOrigin()
		vector angles = dummy.GetAngles()
		StartParticleEffectInWorld( GetParticleSystemIndex( FIRINGRANGE_ITEM_RESPAWN_PARTICLE ), pos, angles )
		SetSpawnOption_AISettings( dummy, aiFileToUse )

		dummy.Hide()

		DispatchSpawn( dummy )
		SetDummyProperties( dummy, 2 )
		
		WaitFrame()
		
		dummy.PlayRecordedAnimation( anim, initialpos, initialang, 0.5 )
		dummy.SetRecordedAnimationPlaybackRate( file.adminSetPlaybackRate )
		dummy.Show()

		file.playerDummyMaps[ playerHandle ][ slot ].append(dummy)
		
		if( !IsValid( player ) )
			return

		waitthread function () : ( player, anim, dummy, slot )
		{
			EndSignal( dummy, "OnDeath", "OnDestroy" )
			EndSignal( player, "EndDummyThread", "EndDummyThread_Slot_" + slot.tostring() )
			EndSignal( svGlobal.levelEnt, "EndDummyThread" )

			OnThreadEnd( function() : ( player, dummy, slot )
			{
				RemoveDummyForPlayer( player, dummy, slot )			
			})
			
			MovementRecorder_WaitForAnimToFinish( anim ) //(mk):this can be long
			 
			//wait MovementRecorder_GetSlotDuration( player, slot ) / ( file.adminSetPlaybackRate )
		}()

		if( IsValid( player ) && !player.p.continueLoop || bIsPlayingRandomSlot )
		{	
			break
		}
	}
}

void function MovementRecorder_WaitForAnimToFinish( var anim )
{
	Assert( IsThreadTop(), "not thread top" )
	//Todo(mk): Implement wait based on playback rate setting for this player, for this slot. (currently global setting)
	wait GetRecordedAnimationDuration( anim ) / ( file.adminSetPlaybackRate * file.adminSetPlaybackRate ) //(mk): don't worry about it.
}

void function RemoveDummyForPlayer( entity player, entity dummy, int slot )
{	
	if( !IsValid( dummy ) )
		return
			
	if( IsValid( player ) && file.playerDummyMaps[ player.p.handle ][ slot ].contains( dummy ) )
		file.playerDummyMaps[ player.p.handle ][ slot ].removebyvalue( dummy )

	if( dummy.IsEntAlive() ) //(mk): only destroy if dummy was still alive, else let damagecode handle
		dummy.Destroy()
	
	file.playerPlaybackAmounts[ player.p.handle ][ slot ]--;
}

void function DestroyDummyForSlot( entity player, int slot, int playerHandle = -1 )
{
	if( IsValid( player ) )
	{
		player.Signal( "EndDummyThread_Slot_" + string( slot ) )
		playerHandle = player.p.handle
	}
	
	#if DEVELOPER
		printf( "Destroy %d dummys for slot %d ", file.playerDummyMaps[ playerHandle ][ slot ].len(), slot )
	#endif
	
	if( !( playerHandle in file.playerDummyMaps ) )
		return
	
	if ( slot in file.playerDummyMaps[ playerHandle ] )
	{	
		foreach( k,slotDummy in file.playerDummyMaps[ playerHandle ][ slot ] )
		{		
			if( !IsValid( slotDummy ) )
			{
				continue
			}
			
			slotDummy.Destroy()
			
			#if DEVELOPER
				CheckDummyDestroyed( slotDummy )
			#endif
		}
	}
	else 
	{
		return
	}
	
	file.playerDummyMaps[ playerHandle ][ slot ].resize(0)
	file.playerPlaybackAmounts[ playerHandle ][ slot ] = 0
}

void function CheckDummyDestroyed( entity dummy )
{
	mAssert( !IsValid(dummy), "Dummy was not destroyed!!" )
}

void function AssignCharacter( entity player, int index )
{
	ItemFlavor PersonajeEscogido = GetAllCharacters()[ index ]
	CharacterSelect_AssignCharacter( ToEHI( player ), PersonajeEscogido )		
	
	ItemFlavor playerCharacter = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_CharacterClass() )
	asset characterSetFile = CharacterClass_GetSetFile( playerCharacter )
	player.SetPlayerSettingsWithMods( characterSetFile, [] )
}

int function ReturnShieldAmountForDesiredLevel( int shield )
{
	switch(shield)
	{
		case 0:
			return 0
		case 1:
			return 50
		case 2:
			return 75
		case 3:
			return 100
		case 4:
			return 125
			
		default:
			return 50
	}
	unreachable
}

void function SetDummyProperties( entity dummy, int shield )
{
	dummy.SetTitle( r5rDevs.getrandom() )
	dummy.SetShieldHealthMax( ReturnShieldAmountForDesiredLevel( shield ) )
	dummy.SetShieldHealth( ReturnShieldAmountForDesiredLevel( shield ) )
	dummy.SetMaxHealth( DUMMY_MAX_HEALTH )
	dummy.SetHealth( DUMMY_MAX_HEALTH )
	dummy.SetDamageNotifications( true )
	dummy.SetTakeDamageType( DAMAGE_YES )
	dummy.SetCanBeMeleed( true )
	AddEntityCallback_OnDamaged( dummy, RecordingAnimationDummy_OnDamaged )
	
	if( file.bDummyDeathNotifications )
		dummy.SetDeathNotifications( true )

	dummy.SetForceVisibleInPhaseShift( true )
}

void function RecordingAnimationDummy_OnDamaged( entity dummy, var damageInfo )
{
	entity ent = dummy	
	entity attacker = DamageInfo_GetAttacker(damageInfo)
	
	if( !attacker.IsPlayer() ) 
		return

	float damage = DamageInfo_GetDamage( damageInfo )
	
	//fake helmet
	float headshotMultiplier = GetHeadshotDamageMultiplierFromDamageInfo(damageInfo)
	float basedamage = DamageInfo_GetDamage( damageInfo )/headshotMultiplier
	
	if( IsValidHeadShot( damageInfo, dummy ) )
	{
		int headshot = int(basedamage*(file.helmet_lv4+(1-file.helmet_lv4)*headshotMultiplier))
		DamageInfo_SetDamage( damageInfo, headshot)
	}

	if( file.bAutoRefilAmmoOnHit )
		attacker.RefillAllAmmo()
}



void function ClientCommand_DestroyDummys( entity player, array<string> args )
{
	if( !IsValid( player ) )
		return
	
	string param = ""
	int playerHandle = player.p.handle
	
	if( args.len() > 0 )
	{
		param = args[ 0 ]
	}
	
	switch( param )
	{
		case "":
			
			if( !( player.p.handle in file.playerDummyMaps ) )
				return
			
			foreach ( slot, dummies in file.playerDummyMaps[ playerHandle ] )
				DestroyDummyForSlot( player, slot )
			
			if( !player.p.recorderHideHud )
				LocalEventMsg( player, "#FS_RECORDER_ENDALL" )
			
			break
		
		case "Admin":
		
			if( !VerifyAdmin( player.p.name, player.p.UID ) )
				return
	
			if( IsValid( svGlobal.levelEnt ) )
			{
				svGlobal.levelEnt.Signal( "EndDummyThread" )
			}
			
			foreach( pHandle, playbackTable in file.playerPlaybackAmounts )
			{
				foreach( slot, amount in playbackTable )
				{
					amount = 0
				}
			}
			
			array<entity> dummysToRemove = GetEntArrayByClass_Expensive( "npc_dummie" )
			
			foreach( dummy in dummysToRemove )
			{
				if( IsValid(dummy) )
				{
					dummy.Destroy()
				}
			}
			
			foreach( sPlayer in GetPlayerArray() )
			{
				if( !IsValid( sPlayer ) )
					continue 
				
				if( !player.p.recorderHideHud )
					LocalEventMsg( sPlayer, "#FS_ADMIN_RECORDER_ENDALL" )
			}
			
			break
	}
}

//TODO(mk): Preferably we use more performant budget management strategy in the future, for now.. this.
bool function IsOverBudget( entity player, int amountToPlay = 1 )
{
	if ( ( GetEntArrayByClass_Expensive( "npc_dummie" ).len() + amountToPlay ) < MAX_NPC_BUDGET )
	{
		return false 
	}
	else 
	{
		if( IsValid( player ) )
		{
			if( !player.p.recorderHideHud )
				LocalEventMsg( player, "#FS_OVER_BUDGET" )
		}
		
		return true
	}
	
	unreachable
}

bool function HasSlotAllocation( entity player, int slot, bool hidehud = false )
{
	if ( file.playbackLimit > -1 && file.playerPlaybackAmounts[ player.p.handle ][ slot ] >= file.playbackLimit )
	{
		if( !hidehud && !player.p.recorderHideHud )
			LocalEventMsg( player, "#FS_PLAYBACK_LIMIT" )
			
		return false
	}
	
	return true
}

// void function MovementRecorder_SetSlotDuration( entity player, int slot, float duration )
// {
	// if( !IsValid( player ) )
		// return 
		
	// int playerHandle = player.p.handle 
	
	// if( playerHandle in file.playerPlaybackDurations )
		// file.playerPlaybackDurations[ playerHandle ][ slot ] = duration
// }

// float function MovementRecorder_GetSlotDuration( entity player, int slot )
// {
	// int playerHandle = player.p.handle 
	
	// if( playerHandle in file.playerPlaybackDurations )
	// {
		// if( slot in file.playerPlaybackDurations[ playerHandle ] )
			// return file.playerPlaybackDurations[ playerHandle ][ slot ]
	// }
	
	// return 0.0
// }

//////////////////////
//		  DEV		//
//////////////////////

#if DEVELOPER
	void function PrintMovementRecorderTable( table< int, table< int, int > > tbl )
	{
		PrintTableTyped( 0, 0, 2, tbl )
	}

	void function PrintTableTyped( int indent, int depth, int maxDepth, table< int, table< int, int > > tbl )
	{
		printt("\n\n")
		printt("--- TABLE ---")
		
		if ( depth >= maxDepth )
		{
			printt( "{...}" )
			return
		}

		printt( "{" )
		foreach ( k, v in tbl )
		{
			printt( TableIndent( indent + 2 ) + k + " = " )
			PrintNestedTableTyped( indent + 2, depth + 1, maxDepth, v )
		}
		printt( TableIndent( indent ) + "}" )
		
		printt("\n\n")
	}

	void function PrintNestedTableTyped( int indent, int depth, int maxDepth, table< int, int > tbl )
	{
		if ( depth >= maxDepth )
		{
			printl( "{...}" )
			return
		}

		printt( TableIndent( indent ) + "{" )
		foreach ( k, v in tbl )
		{
			printt( TableIndent( indent + 2 ) + k + " = " + v )
		}
		printt( TableIndent( indent ) + "}" )
	}	
#endif //DEVELOPER


#endif //IF SERVER