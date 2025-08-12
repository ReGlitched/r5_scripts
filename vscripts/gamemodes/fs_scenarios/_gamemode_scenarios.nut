// Made and designed by @CafeFPS
//
// mkos - feedback, playtest, spawns framework, stats
// DarthElmo & Balvarine - gamemode idea, spawns, feedback, playtest

global function Init_FS_Scenarios
global function FS_Scenarios_GroupToInProgressList
global function FS_Scenarios_ReturnGroupForPlayer
global function FS_Scenarios_RespawnIn3v3Mode
global function FS_Scenarios_Main_Thread

global function FS_Scenarios_GetInProgressGroupsMap
global function FS_Scenarios_GetPlayerToGroupMap
global function FS_Scenarios_GetGroundLootEnabled
global function FS_Scenarios_GetInventoryEmptyEnabled
global function FS_Scenarios_GetAmountOfTeams
global function FS_Scenarios_GetDeathboxesEnabled
global function FS_Scenarios_ForceAllRoundsToFinish
global function FS_Scenarios_SaveLocationFromLootSpawn
global function FS_Scenarios_SaveLootbinData
global function FS_Scenarios_SaveBigDoorData
global function FS_Scenarios_HandleGroupIsFinished
global function FS_Scenarios_SetStopMatchmaking
global function FS_Scenarios_GetAllPlayersForGroup
global function FS_Scenarios_GetScenariosTeamCount

global function FS_Scenarios_getWaitingRoomLocation
global function FS_Scenarios_ForceRest
global function FS_Scenarios_SetupPanels
global function FS_Scenarios_ClientCommand_Rest
global function FS_Scenarios_PlayerCanPing
global function FS_Scenarios_GetMatchIsEnding

#if TRACKER 
	global function Scenarios_PlayerDataCallbacks
#endif 

#if DEVELOPER
	global function Cafe_KillAllPlayers
	global function Cafe_EndAllRounds
	global function Mkos_ForceCloseRecap
#endif

global const int SCENARIOS_MAX_ALLOWED_TEAMSIZE = 5

global struct scenariosTeamStruct
{
	array<entity> players
	int team
}

global struct scenariosGroupStruct
{
	entity dummyEnt
	int groupHandle

	array<scenariosTeamStruct> teams //changed to be modular. Cafe
	
	soloLocStruct &groupLocStruct
	entity ring
	
	float currentRingRadius
	vector calculatedRingCenter
	int slotIndex //realm slot

	bool IsFinished = false
	float startTime
	float endTime
	bool showedEndMsg = false
	bool isReady = false
	bool isValid = false

	// realm based ground loot system
	array<entity> groundLoot
	array<entity> lootbins
	array<entity> doors
	
	int trackedEntsArrayIndex = -1
	float lastTimeRingDamagedGroup = 0
	bool isLastGameFromRound
	bool isForcedGame
}

struct doorsData
{
	entity door
	vector origin
	vector angles

	bool linked
	vector linkOrigin
	vector linkAngles
}

struct bigDoorsData
{
	vector origin
	vector angles
	asset model
	string scriptname
}

struct lootbinsData
{
	vector origin
	vector angles
}

struct 
{
	table<int, scenariosGroupStruct> scenariosPlayerToGroupMap = {} //map for quick assessment
	table<int, scenariosGroupStruct> scenariosGroupsInProgress = {} //group map to group
	
	array<vector> allLootSpawnsLocations
	array<lootbinsData> allMapLootbins
	array<doorsData> allMapDoors
	array<bigDoorsData> allBigMapDoors

	array<entity> aliveDropships
	array<entity> aliveDeathboxes
	array<entity> aliveItemDrops
	
	bool scenariosStopMatchmaking = true
	entity pWorldSpawn
	
} file

struct
{
	int fs_scenarios_playersPerTeam = -1
	int fs_scenarios_teamAmount = -1

	float fs_scenarios_default_radius_padding = 500

	float fs_scenarios_max_queuetime = 30.0
	int fs_scenarios_min_players_forced_match = 2 // used only when max_queuetime is triggered
	int fs_scenarios_low_player_threshold
	float fs_scenarios_max_queuetime_low
	
	bool fs_scenarios_ground_loot = false
	bool fs_scenarios_inventory_empty = false
	bool fs_scenarios_deathboxes_enabled = true
	bool fs_scenarios_show_death_recap_onkilled = true
	float fs_scenarios_zonewars_ring_ringclosingspeed = 1.0
	float fs_scenarios_ring_damage_step_time = 1.5
	float fs_scenarios_game_start_time_delay = 3.0
	float fs_scenarios_ring_damage = 25.0
	float fs_scenarios_characterselect_time_per_player = 3.5
	bool fs_scenarios_characterselect_enabled = true
	float fs_scenarios_ringclosing_maxtime = 120
	float fs_scenarios_matchmaking_delay_after_dying = 8.0
	bool fs_scenarios_recharge_tactical_only
	
	int waitingRoomRadius = 3000
	array<LocPair> lobbyLocs
	
} settings

const float TRANSFER_TIME = 3.0
array< bool > teamSlots

void function Init_FS_Scenarios()
{
	int playersPerTeam = GetCurrentPlaylistVarInt( "fs_scenarios_playersPerTeam", 3 )
	int teamAmount = GetCurrentPlaylistVarInt( "fs_scenarios_teamAmount", 2 )
	
	settings.fs_scenarios_playersPerTeam = playersPerTeam
	settings.fs_scenarios_teamAmount = teamAmount
	
	settings.fs_scenarios_max_queuetime = GetCurrentPlaylistVarFloat( "fs_scenarios_max_queuetime", 35.0 )
	settings.fs_scenarios_min_players_forced_match =  GetCurrentPlaylistVarInt( "fs_scenarios_min_players_forced_match", 2 )
	settings.fs_scenarios_low_player_threshold = GetCurrentPlaylistVarInt( "fs_scenarios_low_player_threshold", DetermineLowThreshold( teamAmount, playersPerTeam ) )
	settings.fs_scenarios_max_queuetime_low = GetCurrentPlaylistVarFloat( "fs_scenarios_max_queuetime_low", 15.0 )
	
	settings.fs_scenarios_ground_loot = GetCurrentPlaylistVarBool( "fs_scenarios_ground_loot", true )
	settings.fs_scenarios_inventory_empty = GetCurrentPlaylistVarBool( "fs_scenarios_inventory_empty", true )
	settings.fs_scenarios_deathboxes_enabled = GetCurrentPlaylistVarBool( "fs_scenarios_deathboxes_enabled", true )
	settings.fs_scenarios_show_death_recap_onkilled = GetCurrentPlaylistVarBool( "fs_scenarios_show_death_recap_onkilled", true )
	settings.fs_scenarios_zonewars_ring_ringclosingspeed =  GetCurrentPlaylistVarFloat( "fs_scenarios_zonewars_ring_ringclosingspeed", 1.0 )
	settings.fs_scenarios_ring_damage_step_time = GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage_step_time", 1.5 )
	settings.fs_scenarios_game_start_time_delay = GetCurrentPlaylistVarFloat( "fs_scenarios_game_start_time_delay", 3.0 )
	settings.fs_scenarios_ring_damage = GetCurrentPlaylistVarFloat( "fs_scenarios_ring_damage", 25.0 )
	settings.fs_scenarios_characterselect_enabled = GetCurrentPlaylistVarBool( "fs_scenarios_characterselect_enabled", true )
	settings.fs_scenarios_characterselect_time_per_player = GetCurrentPlaylistVarFloat( "fs_scenarios_characterselect_time_per_player", 3.5 )
	settings.fs_scenarios_ringclosing_maxtime = GetCurrentPlaylistVarFloat( "fs_scenarios_ringclosing_maxtime", 100 )
	settings.fs_scenarios_matchmaking_delay_after_dying = GetCurrentPlaylistVarFloat( "fs_scenarios_matchmaking_delay_after_dying", 8.0 )
	settings.fs_scenarios_recharge_tactical_only = GetCurrentPlaylistVarBool( "fs_scenarios_recharge_tactical_only", true )

	settings.lobbyLocs.append( NewLobbyPair( <-495.617645, 1285.12402, 50272.0625> , <0, -42.2699738, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <-460.676514, 20.4265499, 50272.0625> , <0, 49.0330009, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <962.6203, 217.382111, 50016.0625> , <0, 143.405518, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <1037.58313, 1008.25964, 50016.0625> , <0, -128.112335, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <-14.3175983, 1255.98291, 50016.0625> , <0, -91.0898666, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <-127.673027, 60.6526756, 50016.0625> , <0, 89.0122375, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <-1051.12842, 477.404785, 50016.0625> , <0, 35.1141701, 0>))
	settings.lobbyLocs.append( NewLobbyPair( <891.747009, 641.80957, 50054.5352> , <0, 179.900742, 0> ))

	teamSlots.resize( 119 )
	teamSlots[ 0 ] = true
	teamSlots[ 1 ] = true
	teamSlots[ 2 ] = true
	
	for (int i = 1; i < teamSlots.len(); i++)
	{
		teamSlots[ i ] = false
	}
	
	SurvivalFreefall_Init()
	SurvivalShip_Init()

	AddClientCommandCallback( "playerRequeue_CloseDeathRecap", ClientCommand_FS_Scenarios_Requeue )	
	
	AddClientCommandCallback( "rest", FS_Scenarios_ClientCommand_Rest )
	Gamemode1v1_SetRestEnabled()

	RegisterSignal( "FS_Scenarios_GroupIsReady" )
	RegisterSignal( "FS_Scenarios_GroupFinished" )

	AddSpawnCallback( "prop_death_box", FS_Scenarios_StoreAliveDeathbox )
	AddSpawnCallback( "prop_survival", FS_Scenarios_StoreAliveDrops )

	AddCallback_OnPlayerKilled( FS_Scenarios_OnPlayerKilled )
	AddCallback_OnClientConnected( FS_Scenarios_OnPlayerConnected )
	AddCallback_OnClientDisconnected( FS_Scenarios_OnPlayerDisconnected )
	AddDamageCallbackSourceID( eDamageSourceId.deathField, RingDamagePunch )
	
	Survival_AddCallback_OnAttackerSquadWipe( FS_Scenarios_OnSquadWipe )
	Survival_AddCallback_OnAttackerSoloRatEliminated( FS_Scenarios_OnRatEliminated )

	AddCallback_EntitiesDidLoad( EntitiesDidLoad )
	//AddCallback_FlowstateSpawnsPostInit( CustomSpawns )
	
	vector mapCenter = SURVIVAL_GetMapCenter()
	SpawnSystem_SetPanelLocation( mapCenter + <0,0,50000>, ZERO_VECTOR )

	FS_Scenarios_Score_System_Init()
}

void function EntitiesDidLoad()
{
	vector mapCenter = SURVIVAL_GetMapCenter()
	
	Scenarios_SetWaitingRoomRadius( 2600 )
	SpawnFlowstateLobbyProps( mapCenter + <0,0,50000> )
	
	file.pWorldSpawn = GetEnt( "worldspawn" )
}

void function FS_Scenarios_ForceRest( entity player )
{
	#if TRACKER
		if( IsBotEnt( player ) ) //temporary messagebot bullcrap hack ( all of these need removed )
			return
	#endif
		
	_CleanupPlayerEntities( player )
	FS_Scenarios_HandleGroupIsFinished( player )
	scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )

	if( group != null )
	{
		expect scenariosGroupStruct( group )
		if( IsValid( group ) && group.isValid && !group.IsFinished )
			FS_Scenarios_UpdatePlayerScore( player, FS_ScoreType.PENALTY_DESERTER )	
	}
	
	if( !isPlayerInWaitingList( player ) )
		soloModePlayerToWaitingList( player ) //logic that cleans up a player is contained here.
	
	_3v3ModePlayerToRestingList( player ) // Manually assign
	
	try
	{
		player.Die( file.pWorldSpawn, file.pWorldSpawn, { scriptType = DF_SKIPS_DOOMED_STATE, damageSourceId = eDamageSourceId.damagedef_despawn } )
	}
	catch (error) //despawn
	{}

	LocalMsg( player, "#FS_YouAreResting", "#FS_BASE_RestText" )
	
	HolsterAndDisableWeapons( player )
	FS_Scenarios_RespawnIn3v3Mode( player ) //respawn
	player.p.lastRestUsedTime = Time()
}

bool function FS_Scenarios_ClientCommand_Rest( entity player, array<string> args )
{
	if( Time() < player.p.lastRestUsedTime + 3 )
	{
		LocalEventMsg( player, "#FS_RESTCOOLDOWN" )
		return false
	}
	
	if( IsCurrentState( player, e1v1State.CHARSELECT ) || IsCurrentState( player, e1v1State.PREMATCH ) )
	{
		LocalEventMsg( player, "#FS_NOT_AVAILABLE" )
		return true 
	}
		
	if( IsCurrentState( player, e1v1State.MATCHING ) )
	{
		if( args.len() == 0 || !player.p.rest_request )
		{
			//LocalMsg( player, "#FS_WARNING", "#FS_REST_CONFIRM" )
			Remote_CallFunction_UI( player, "ServerCallback_UiConfirmRest" )
			player.p.rest_request = true
			return true
		}
		else if( player.p.rest_request && args.len() > 0 && args[ 0 ] == "1" )
		{
			scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )

			if( group != null )
			{
				expect scenariosGroupStruct( group )
				
				if( IsValid( group) && group.isValid && !group.IsFinished )
				{
					FS_Scenarios_UpdatePlayerScore( player, FS_ScoreType.PENALTY_DESERTER )
					
					if( FS_Scenarios_GetDeathboxesEnabled() && group.isReady )
					{
						Dev_ForceDropDeathbox( player )
					}
				}
			}

			player.p.rest_request = false 
		}
		else
		{
			return true
		}
	}		
	
	string restText = "#FS_BASE_RestText";

	if( isPlayerInRestingList( player ) )
	{
		if( player.IsObserver() || IsValid( player.GetObserverTarget() ) )
		{
			player.SetSpecReplayDelay( 0 )
			player.SetObserverTarget( null )
			player.StopObserverMode()
			//Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
			Remote_CallFunction_ByRef( player, "ServerCallback_KillReplayHud_Deactivate" )
			player.MakeVisible()
			player.ClearInvulnerable()
			player.SetTakeDamageType( DAMAGE_YES )
		}

		LocalMsg( player, "#FS_MATCHING" )
		soloModePlayerToWaitingList( player )
		
		try
		{
			player.Die( file.pWorldSpawn, file.pWorldSpawn, { scriptType = DF_SKIPS_DOOMED_STATE, damageSourceId = eDamageSourceId.damagedef_despawn } )
		}
		catch ( error )
		{}
	}
	else
	{				
		_CleanupPlayerEntities( player )
		FS_Scenarios_HandleGroupIsFinished( player )
		scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )

		if( group != null )
		{
			expect scenariosGroupStruct( group )
			if( IsValid( group ) && group.isValid && !group.IsFinished )
				FS_Scenarios_UpdatePlayerScore( player, FS_ScoreType.PENALTY_DESERTER )	
		}
		
		soloModePlayerToWaitingList( player ) //logic that cleans up a player is contained here.
		_3v3ModePlayerToRestingList( player ) // Manually assign
		
		try
		{
			player.Die( file.pWorldSpawn, file.pWorldSpawn, { scriptType = DF_SKIPS_DOOMED_STATE, damageSourceId = eDamageSourceId.damagedef_despawn } )
		}
		catch (error) //despawn
		{}

		LocalMsg( player, "#FS_YouAreResting", restText )
	}
	
	HolsterAndDisableWeapons( player )
	FS_Scenarios_RespawnIn3v3Mode( player ) //respawn
	player.p.lastRestUsedTime = Time()
	return true
}

int function FS_Scenarios_GetScenariosTeamCount()
{
	return settings.fs_scenarios_teamAmount
}

bool function ClientCommand_FS_Scenarios_Requeue(entity player, array<string> args )
{
	if( !IsValid(player) )
		return false
	
	if( Time() < player.p.lastRequeueUsedTime + 3 )
	{
		return false
	}
	
	// player.p.InDeathRecap = false
	// player.p.lastRequeueUsedTime = Time()

	return true
}

void function FS_Scenarios_OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	#if DEVELOPER
		printt( "[+] OnPlayerKilled Scenarios -", victim, "by", attacker )
	#endif

	if ( !IsValid( victim ) || !IsValid( attacker ) || !victim.IsPlayer() )
	{
		#if DEVELOPER
			printw( "player died but returned" )
		#endif
		return
	}

	scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( victim )
	bool bDespawn = ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.damagedef_despawn ) //&& ( ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_SKIPS_DOOMED_STATE ) > 0 )	
		
	thread function () : ( victim, bDespawn ) 
	{
		ScenariosPersistence_SendStandingsToClient( victim )

		EndSignal( victim, "OnDestroy" ) //it should be before waitframe. Cafe
		
		WaitFrame()
		
		if( !bDespawn && settings.fs_scenarios_show_death_recap_onkilled )
			Remote_CallFunction_ByRef( victim, "ServerCallback_ShowFlowstateDeathRecapNoSpectate" ) //Fixme

		if( !bDespawn )
		{
			WaitRespawnTime( victim, TRANSFER_TIME )
			//delay before sending to lobby
		}
		
		// victim.p.lastRequeueUsedTime = Time()
		
		if( !bDespawn )
		{
			soloModePlayerToWaitingList( victim )
			
			#if DEVELOPER
				printt( victim, "sent to waiting room and added to 'WaitingList" )
			#endif
		}
	}()

	float elapsedTime
	if( group != null )
	{
		expect scenariosGroupStruct( group )
	
		if( IsValid( group ) && group.isValid )
		{
			foreach( splayer in FS_Scenarios_GetAllPlayersForGroup( group ) )
			{
				Remote_CallFunction_Replay( splayer, "FS_Scenarios_ChangeAliveStateForPlayer", victim.GetEncodedEHandle(), false )
			}
			
			if( group.isReady )
				elapsedTime = Time() - group.startTime
		} else if ( !IsValid( group ) || !group.isValid || !group.isReady ) //Do not calculate stats for players not in a round
		{
			return
		}
	}

	FS_Scenarios_UpdatePlayerScore( victim, FS_ScoreType.PENALTY_DEATH )
	
	if( elapsedTime > 0 )
		FS_Scenarios_UpdatePlayerScore( victim, FS_ScoreType.SURVIVAL_TIME, null, elapsedTime )
	
	if ( victim.GetTeam() != attacker.GetTeam() && attacker.IsPlayer() )
	{
		FS_Scenarios_UpdatePlayerScore( attacker, FS_ScoreType.KILL, victim )
	}
	
	FS_Scenarios_HandleGroupIsFinished( victim )

	if( FS_Scenarios_GetDeathboxesEnabled() )
	{
		thread SURVIVAL_Death_DropLoot( victim, damageInfo )
	}

	thread EnemyKilledDialogue( attacker, victim.GetTeam(), victim )
	
	if( group != null )
	{
		expect scenariosGroupStruct( group )
		
		if( group.isValid && group.IsFinished )
			return
	}

	if( GetPlayerArrayOfTeam_Alive( victim.GetTeam() ).len() == 1 )
	{
		entity soloPlayer = GetPlayerArrayOfTeam_Alive( victim.GetTeam() )[0]
		
		if( IsValid( soloPlayer ) && !Bleedout_IsBleedingOut( soloPlayer ) )
		{
			FS_Scenarios_UpdatePlayerScore( soloPlayer, FS_ScoreType.BONUS_BECOMES_SOLO_PLAYER )
		}
	}
}

bool function FS_Scenarios_IsFullTeamBleedout( entity attacker, entity victim ) 
{
	int count = 0
	foreach( player in GetPlayerArrayOfTeam_Alive( victim.GetTeam() ) )
	{
		if( player == victim )
			continue

		if( IsAlive( player ) && !Bleedout_IsBleedingOut( player ) )
			count++
	}
	
	#if DEVELOPER
		printt( "FS_Scenarios_IsFullTeamBleedout", count )
	#endif
	
	return count == 0
}

void function FS_Scenarios_OnPlayerConnected( entity player )
{
	#if DEVELOPER
		printt( "[+] OnPlayerConnected Scenarios -", player )
	#endif

	ValidateDataTable( player, "datatable/flowstate_scenarios_score_system.rpak" )

	AddEntityCallback_OnPostDamaged( player, FS_Scenarios_OnPlayerDamaged ) //(mk): changed to post damage

	//Put player into scenarios game Cafe
	thread function () : ( player )
	{
		EndSignal( player, "OnDestroy" )
		
		while( IsDisconnected( player ) )
			WaitFrame()
		
		if( !isPlayerInWaitingList( player) && !isPlayerInRestingList( player ) && !FS_Scenarios_IsPlayerIn3v3Mode( player ) )
		{
			soloModePlayerToWaitingList(player)
		}
	}()
}

void function FS_Scenarios_OnPlayerDamaged( entity victim, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsPlayer() || Bleedout_IsBleedingOut( victim ) )
		return

	entity attacker = InflictorOwner( DamageInfo_GetAttacker( damageInfo ) )
	
	int sourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	if ( sourceId == eDamageSourceId.bleedout || sourceId == eDamageSourceId.human_execution || sourceId == eDamageSourceId.damagedef_despawn )
		return
	
	// if( settings.fs_scenarios_show_death_recap_onkilled )
		//fix var

	float damage = DamageInfo_GetDamage( damageInfo )

	int currentHealth = victim.GetHealth()
	if ( !( DamageInfo_GetCustomDamageType( damageInfo ) & DF_BYPASS_SHIELD ) )
		currentHealth += victim.GetShieldHealth()
	
	vector damagePosition = DamageInfo_GetDamagePosition( damageInfo )
	int damageType = DamageInfo_GetCustomDamageType( damageInfo )
	entity weapon = DamageInfo_GetWeapon( damageInfo )

	TakingFireDialogue( attacker, victim, weapon )

	if ( currentHealth - damage <= 0 && !IsInstantDeath( damageInfo ) && !IsDemigod( victim ) )
	{
		if( victim.IsZiplining() || victim.IsMountingZipline() )
			victim.Zipline_Stop()
		
		if( victim.IsGrappleAttached() )
			victim.GrappleDetach()
	}
	
	if ( currentHealth - damage <= 0 && PlayerRevivingEnabled() && !IsInstantDeath( damageInfo ) && Bleedout_AnyOtherSquadmatesAliveAndNotBleedingOut( victim ) && !IsDemigod( victim ) )
	{
		if( !IsValid(attacker) || !IsValid(victim) )
			return

		thread EnemyDownedDialogue( attacker, victim )
	}
}

void function FS_Scenarios_OnPlayerDisconnected( entity player )
{
	#if DEVELOPER
		printt( "[+] OnPlayerDisconnected Scenarios -", player )
	#endif
	
	_CleanupPlayerEntities( player )

	FS_Scenarios_HandleGroupIsFinished( player )

	scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )

	if( group != null )
	{
		expect scenariosGroupStruct( group )
		
		if( IsValid( group ) && group.isValid && !group.IsFinished )
		{
			FS_Scenarios_UpdatePlayerScore( player, FS_ScoreType.PENALTY_DESERTER )
			
			if( FS_Scenarios_GetDeathboxesEnabled() && group.isReady )
			{
				Dev_ForceDropDeathbox( player )
			}
		}
	}

	//If player was in waiting room, remove. Cafe
	foreach ( playerHandle, playerInWaitingStruct in FS_1v1_GetPlayersWaiting() )
	{
		if( !IsValid( playerInWaitingStruct ) )
			continue
		
		if ( playerInWaitingStruct.handle == player.p.handle )
		{
			deleteWaitingPlayer( player.p.handle )
			break
		}
	}

	//If player was in a match, remove. Cafe
	if( player.p.handle in file.scenariosPlayerToGroupMap )
		delete file.scenariosPlayerToGroupMap[ player.p.handle ]
}

void function FS_Scenarios_SaveBigDoorData( entity door )
{
	bigDoorsData bigDoor
	bigDoor.origin = door.GetOrigin()
	bigDoor.angles = door.GetAngles()
	bigDoor.model = door.GetModelName()
	bigDoor.scriptname = door.GetScriptName()
	
	file.allBigMapDoors.append( bigDoor )

	door.Destroy()
}

void function FS_Scenarios_SpawnBigDoorsForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	EndSignal( group.dummyEnt, "FS_Scenarios_GroupFinished" )

	vector Center = group.calculatedRingCenter
	int realm = group.slotIndex

	array< bigDoorsData > chosenSpawns
	int count = 0

	foreach( i, bigDoorsData data in file.allBigMapDoors )
	{
		if( Distance2D( data.origin, Center) <= group.currentRingRadius )
			chosenSpawns.append( data )
	}
	
	foreach( i, bigDoorsData data in chosenSpawns )
	{
	    entity door = CreateEntity( "prop_dynamic" )
        {
            door.SetValueForModelKey( data.model )
            door.SetOrigin( data.origin )
            door.SetAngles( data.angles )
            door.SetScriptName( data.scriptname )
			SetTargetName( door, "flowstate_realms_doors_by_cafe" )
			door.kv.solid = SOLID_VPHYSICS
			door.AllowMantle()
			door.RemoveFromAllRealms()
			door.AddToRealm( realm )

            DispatchSpawn( door )

			group.doors.append( door )
			count++
        }
	}
	#if DEVELOPER
		printt( "created", count, "big doors for group", group.groupHandle )
	#endif
}

void function FS_Scenarios_SaveDoorsData()
{
	foreach( door in GetAllPropDoors() )
	{
		doorsData mapDoor
		mapDoor.door = door
		mapDoor.origin = door.GetOrigin()
		mapDoor.angles = door.GetAngles()
		mapDoor.linked = IsValid( door.GetLinkEnt() )

		mapDoor.linkOrigin = mapDoor.linked == true ? door.GetLinkEnt().GetOrigin() : <0,0,0>
		mapDoor.linkAngles = mapDoor.linked == true ? door.GetLinkEnt().GetAngles() : <0,0,0>
		
		file.allMapDoors.append( mapDoor )
		RemoveDoorFromManagedEntArray( door )
	}

	foreach( i, doorsData data in file.allMapDoors )
	{
		foreach( j, doorsData data2 in file.allMapDoors )
		{
			if( data.linked && IsValid( data.door ) && IsValid( data2.door ) && data.door.GetLinkEnt() == data2.door )
			{
				file.allMapDoors.remove( j )
				// printt( "removed double door" )
				data2.door.Destroy() //save edicts even more
				j--
			}
		}
	}
	
	foreach( i, doorsData data in file.allMapDoors )
	{
		if( IsValid( data.door ) )
			data.door.Destroy() //save edicts even more
	}
}

void function FS_Scenarios_SpawnDoorsForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	EndSignal( group.dummyEnt, "FS_Scenarios_GroupFinished" )

	vector Center = group.calculatedRingCenter
	int realm = group.slotIndex

	array< doorsData > chosenSpawns
	
	foreach( i, doorsData data in file.allMapDoors )
	{
		if( Distance2D( data.origin, Center) <= group.currentRingRadius )
			chosenSpawns.append( data )
	}
	
	foreach( i, doorsData data in chosenSpawns )
	{
		entity singleDoor = CreateEntity("prop_door")
		singleDoor.SetValueForModelKey( $"mdl/door/canyonlands_door_single_02.rmdl" )
		singleDoor.SetScriptName( "flowstate_door_realms" )
		singleDoor.SetOrigin( data.origin )
		singleDoor.SetAngles( data.angles )

		singleDoor.RemoveFromAllRealms()
		singleDoor.AddToRealm( realm )

		DispatchSpawn( singleDoor )
		
		if( data.linked )
		{
			entity doubleDoor = CreateEntity("prop_door")
			doubleDoor.SetValueForModelKey( $"mdl/door/canyonlands_door_single_02.rmdl" )
			doubleDoor.SetScriptName( "flowstate_door_realms" )
			doubleDoor.SetOrigin( data.linkOrigin )
			doubleDoor.SetAngles( data.linkAngles )

			doubleDoor.RemoveFromAllRealms()
			doubleDoor.AddToRealm( realm )
			doubleDoor.LinkToEnt( singleDoor )

			DispatchSpawn( doubleDoor )
			group.doors.append( doubleDoor )
		}

		group.doors.append( singleDoor )
	}

	//bro
	bool skip = false
	foreach( door in group.doors )
	{
		skip = false
		foreach( door2 in group.doors )
		{
			if( skip )
				continue

			if( door == door2 )
				continue

			if( door.GetOrigin() == door2.GetOrigin() )
			{
				if( IsValid( door ) && IsValid( door.GetLinkEnt() ) )
					door2.Destroy()
				else if( IsValid( door ) )
					door.Destroy()

				skip = true
			}
		}
	}
	#if DEVELOPER
		printt( "spawned", group.doors.len(), "doors for realm", realm )
	#endif
}

void function FS_Scenarios_DestroyDoorsForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	int count = 0
	foreach( door in group.doors )
		if( IsValid( door ) )
		{
			count++
			RemoveDoorFromManagedEntArray( door )
			door.Destroy()
		}

	#if DEVELOPER
		printt( "destroyed", count, "doors for group", group.groupHandle )
	#endif
}

int function FS_Scenarios_GetAmountOfTeams()
{
	return settings.fs_scenarios_teamAmount
}

bool function FS_Scenarios_GetDeathboxesEnabled()
{
	return settings.fs_scenarios_deathboxes_enabled
}

void function FS_Scenarios_StoreAliveDeathbox( entity deathbox )
{
	if( !IsValid( deathbox ) )
		return

	file.aliveDeathboxes.append( deathbox )
	
	#if DEVELOPER
		printt( "added deathbox to alive deathboxes array", deathbox )
	#endif
}

void function FS_Scenarios_StoreAliveDrops( entity prop )
{
	if( !IsValid( prop ) || prop.GetClassName() != "prop_survival" ) //Shouldn't happen but my debugging say the inverse so just in case. Cafe
		return

	file.aliveItemDrops.append( prop )
}

void function FS_Scenarios_CleanupDrops()
{
	int maxIter = file.aliveItemDrops.len() - 1
	
	for( int i = maxIter; i >= 0; i-- )
	{
		if( !IsValid( file.aliveItemDrops[ i ] ) )
			file.aliveItemDrops.remove( i )
	}
}

void function FS_Scenarios_CleanupDeathboxes()
{
	int maxIter = file.aliveDeathboxes.len() - 1
	
	for( int i = maxIter; i >= 0; i-- )
	{
		if( !IsValid( file.aliveDeathboxes[ i ] ) )
			file.aliveDeathboxes.remove( i )
	}
}

void function FS_Scenarios_DestroyAllAliveDeathboxesForRealm( int realm = -1 )
{
	int count = 0
	foreach( deathbox in file.aliveDeathboxes )
	{
		if( IsValid( deathbox ) )
		{
			if( realm == -1 || deathbox.IsInRealm( realm )  )
			{
				if( IsValid( deathbox.GetParent() ) &&  deathbox.GetParent().GetClassName() == "prop_physics" )
					deathbox.GetParent().Destroy() // Destroy physics. This is not always the physics. [Cafe]

				deathbox.Destroy()
				
				count++
			}
		}
	}
	#if DEVELOPER
		printt( "removed", count, "deathboxes for realm", realm )
	#endif
}

void function FS_Scenarios_DestroyAllAliveDroppedLootForRealm( int realm = -1 )
{
	printw("FS_Scenarios_DestroyAllAliveDroppedLootForRealm" )
	
	int count = 0
	foreach( drop in file.aliveItemDrops )
	{
		if( IsValid( drop ) && drop.GetClassName() == "prop_survival" )
		{
			if( realm == -1 || drop.IsInRealm( realm )  )
			{
				// printt( "FS_Scenarios_DestroyAllAliveDroppedLootForRealm", drop, drop.GetParent() )
				if( IsValid( drop.GetParent() ) &&  drop.GetParent().GetClassName() == "prop_physics" )
					drop.GetParent().Destroy() // Destroy physics. This is not always the physics. [Cafe]
				
				drop.Destroy()
				
				count++
			}
		}
	}
	#if DEVELOPER
		printw( "[+] Removed", count, "prop_survival items for realm", realm )
	#endif
}

void function FS_Scenarios_StoreAliveDropship( entity dropship )
{
	if( !IsValid( dropship ) )
		return

	file.aliveDropships.append( dropship )
	
	#if DEVELOPER
		printt( "added dropship to alive dropships array", dropship )
	#endif
}

void function FS_Scenarios_CleanupDropships()
{
	int maxIter = file.aliveDropships.len() - 1
	
	for( int i = maxIter; i >= 0; i-- )
	{
		if( !IsValid( file.aliveDropships[ i ] ) )
			file.aliveDropships.remove( i )
	}
}

void function FS_Scenarios_DestroyAllAliveDropships()
{
	foreach( dropship in file.aliveDropships )
		if( IsValid( dropship ) )
			dropship.Destroy()
}

void function FS_Scenarios_SaveLootbinData( entity lootbin )
{
	lootbinsData lootbinStruct
	lootbinStruct.origin = lootbin.GetOrigin()
	lootbinStruct.angles = lootbin.GetAngles()
	file.allMapLootbins.append( lootbinStruct )

	lootbin.Destroy() //save edicts even more
}

void function FS_Scenarios_SpawnLootbinsForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	EndSignal( group.dummyEnt, "FS_Scenarios_GroupFinished" )

	vector Center = group.calculatedRingCenter
	int realm = group.slotIndex

	array< lootbinsData > chosenSpawns
	
	foreach( i, lootbinStruct in file.allMapLootbins )
		if( Distance2D( lootbinStruct.origin, Center) <= group.currentRingRadius )
			chosenSpawns.append( lootbinStruct )

	string zoneRef = "zone_high"

	int count = 0
	int weapons = 0

	foreach( lootbinStruct in chosenSpawns )
	{
		entity lootbin = FS_Scenarios_CreateCustomLootBin( lootbinStruct.origin, lootbinStruct.angles )

		if( !IsValid( lootbin ) )
			continue

		FS_Scenarios_InitLootBin( lootbin )

		array<string> Refs
		string itemRef
		LootData lootData

		for(int i = 0; i < RandomIntRangeInclusive(3,5); i++)
		{
			for(int j = 0; j < 1; j++)
			{
				itemRef = SURVIVAL_GetWeightedItemFromGroup( "zone_high" )
				lootData = SURVIVAL_Loot_GetLootDataByRef( itemRef )

				if(  lootData.lootType == eLootType.RESOURCE ||
				lootData.lootType == eLootType.DATAKNIFE ||
				lootData.lootType == eLootType.INCAPSHIELD ||
				lootData.lootType == eLootType.BACKPACK ||
				lootData.lootType == eLootType.HELMET ||
				lootData.lootType == eLootType.ARMOR ||
				lootData.lootType == eLootType.GADGET ||
				itemRef == "blank" ||
				itemRef == "mp_weapon_raygun" ||
				itemRef == "" )
				{
					j--
					continue
				}
				
				if( lootData.lootType == eLootType.MAINWEAPON )
					weapons++

				Refs.append( itemRef )
			}
		}
		
		lootbin.RemoveFromAllRealms()
		lootbin.AddToRealm( realm )
		
		AddMultipleLootItemsToLootBin( lootbin, Refs )

		group.lootbins.append( lootbin )
		count++
	}
	
	#if DEVELOPER
		printt("spawned", count, "lootbins for group", group.groupHandle, "in realm", group.slotIndex, "- WEAPONS: ", weapons )
	#endif
}

entity function FS_Scenarios_CreateCustomLootBin( vector origin, vector angles )
{
	entity lootbin = CreateEntity( "prop_dynamic" )
	lootbin.SetScriptName( LOOT_BIN_SCRIPTNAME_CUSTOM_REALMS )
	lootbin.SetValueForModelKey( LOOT_BIN_MODEL )
	lootbin.SetOrigin( origin )
	lootbin.SetAngles( angles )
	lootbin.kv.solid = SOLID_VPHYSICS

	DispatchSpawn( lootbin )

	return lootbin
}

void function FS_Scenarios_DestroyLootbinsForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	int count = 0
	foreach( lootbin in group.lootbins )
		if( IsValid( lootbin ) )
		{
			count++
			RemoveLootBinReferences_Preprocess( lootbin )
			lootbin.Destroy()
		}
		
	#if DEVELOPER
		printt( "destroyed", count, "lootbins for group", group.groupHandle )
	#endif
}

void function FS_Scenarios_SaveLocationFromLootSpawn( entity ent )
{
	if( GetEditorClass( ent ) == "info_survival_weapon_location" || GetEditorClass( ent ) == "info_survival_loot_hotzone" )
		file.allLootSpawnsLocations.append( ent.GetOrigin() )
	
	ent.Destroy() //save edicts even more
}

void function FS_Scenarios_SpawnLootForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	EndSignal( group.dummyEnt, "FS_Scenarios_GroupFinished" )

	vector Center = group.calculatedRingCenter
	int realm = group.slotIndex

	array<vector> chosenSpawns
	
	foreach( spawn in file.allLootSpawnsLocations )
		if( Distance2D( spawn, Center) <= group.currentRingRadius )
			chosenSpawns.append( spawn )

	string zoneRef = "zone_high"

	int count = 0
	int weapons = 0

	foreach( spawn in chosenSpawns )
	{
		string itemRef
		LootData lootData

		for(int i = 0; i < 1; i++)
		{
			itemRef = SURVIVAL_GetWeightedItemFromGroup( zoneRef )
			lootData = SURVIVAL_Loot_GetLootDataByRef( itemRef )

			if(  lootData.lootType == eLootType.RESOURCE ||
			lootData.lootType == eLootType.DATAKNIFE ||
			lootData.lootType == eLootType.INCAPSHIELD ||
			lootData.lootType == eLootType.BACKPACK ||
			lootData.lootType == eLootType.HELMET ||
			lootData.lootType == eLootType.ARMOR ||
			lootData.lootType == eLootType.GADGET ||
			itemRef == "blank" ||
			itemRef == "mp_weapon_raygun" ||
			itemRef == "" )
			{
				i--
				continue
			}
		}
	
		entity loot

		int lootType = SURVIVAL_Loot_GetLootDataByRef( itemRef ).lootType
		vector origin = spawn
		vector startOrigin = origin + <0, 0, 8>
		vector endOrigin   = origin - <0, 0, 20000>
		vector newOrigin   = GetGroundPosition( startOrigin, endOrigin ).endPos

		if( lootData.lootType == eLootType.MAINWEAPON )
		{
			loot = SpawnWeaponAndAmmo( itemRef, newOrigin, realm )
			group.groundLoot.append( loot )
			count++
			continue
		}
		
		loot = SpawnGenericLoot( itemRef, newOrigin, <-1, -1, -1>, SURVIVAL_Loot_GetLootDataByRef( itemRef ).countPerDrop )

		if ( loot == null )
			continue

		vector angles = AnglesOnSurface( GetGroundPosition( startOrigin, endOrigin ).surfaceNormal, AnglesToForward( loot.GetAngles() ) )
		loot.SetAngles( <0,0,angles.z> )

		//Check for moving geo
		TraceResults trace = TraceLineHighDetail( loot.GetOrigin(), loot.GetOrigin() - <0, 0, 88>, loot, LOOT_TRACE, LOOT_COLLISION_GROUP )
		if ( IsValid( trace.hitEnt ) && trace.hitEnt.HasPusherAncestor() )
		{
			loot.SetParent( trace.hitEnt, "", true, 0 )
		}

		loot.RemoveFromAllRealms()
		loot.AddToRealm( realm )

		group.groundLoot.append( loot )
		count++
	}

	#if DEVELOPER
		printt("spawned", count, "ground loot for group", group.groupHandle, "in realm", group.slotIndex, "- WEAPONS: ", weapons )
	#endif
}

void function FS_Scenarios_DestroyLootForGroup( scenariosGroupStruct group )
{
	if( !group.isValid )
		return

	int count = 0
	foreach( loot in group.groundLoot )
		if( IsValid( loot ) )
		{
			count++
			loot.Destroy()
		}
		
	#if DEVELOPER
		printt( "destroyed", count, "ground loot for group", group.groupHandle )
	#endif
}

table<int, scenariosGroupStruct> function FS_Scenarios_GetInProgressGroupsMap()
{
	return file.scenariosGroupsInProgress
}

table<int, scenariosGroupStruct> function FS_Scenarios_GetPlayerToGroupMap()
{
	return file.scenariosPlayerToGroupMap
}

bool function FS_Scenarios_GetGroundLootEnabled()
{
	return settings.fs_scenarios_ground_loot
}

bool function FS_Scenarios_GetInventoryEmptyEnabled()
{
	return settings.fs_scenarios_inventory_empty
}

void function FS_Scenarios_SetIsUsedBoolForTeamSlot( int team, bool usedState )
{
	if( team == -1 )
		return

	try
	{
		if ( !team ) { return } //temporary crash fix
		teamSlots[ team ] = usedState
	}
	catch(e)
	{	
		#if DEVELOPER
			sqprint("SetIsUsedBoolForRealmSlot crash " + e )
		#endif
	}
}

int function FS_Scenarios_GetAvailableTeamSlotIndex()
{
	for( int slot = 3; slot < teamSlots.len(); slot++ )
	{
		if( teamSlots[slot] == false )
		{
			FS_Scenarios_SetIsUsedBoolForTeamSlot( slot, true )
			return slot
		}
	}

	return -1
}
bool function FS_Scenarios_IsPlayerIn3v3Mode( entity player ) 
{
	if( !IsValid (player) )
	{	
		#if DEVELOPER
			sqprint("isPlayerInSoloMode entity was invalid")
		#endif
		
		return false 
	}
	
    return ( player.p.handle in file.scenariosPlayerToGroupMap )
}

bool function FS_Scenarios_GroupToInProgressList( scenariosGroupStruct newGroup, array<entity> players ) 
{
	#if DEVELOPER
		printt( "FS_Scenarios_GroupToInProgressList" )
	#endif

	int slotIndex = getAvailableRealmSlotIndex()

	if( slotIndex == -1 )
		return false
	
	foreach( player in players )
	{
		if( !IsValidPlayer( player ) )
			continue
		
		if( player.p.handle in file.scenariosPlayerToGroupMap )
		{
			delete file.scenariosPlayerToGroupMap[ player.p.handle ]
		}

		player.p.scenariosTeamsMatched = 0
		
		player.SetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby", -1 )
		
		deleteWaitingPlayer( player.p.handle )
		deleteSoloPlayerResting( player )
		LocalMsg( player, "#FS_NULL", "", eMsgUI.EVENT, 1 )

		if( Bleedout_IsBleedingOut( player ) )
			Signal( player, "BleedOut_OnRevive" )
	}

	newGroup.slotIndex = slotIndex
    newGroup.groupLocStruct = soloLocations.getrandom()
	int groupHandle = GetUniqueID()

	newGroup.groupHandle = groupHandle
	newGroup.dummyEnt = CreateEntity( "info_target" )

	try 
	{
		if( !( groupHandle in file.scenariosGroupsInProgress ) )
		{
			#if DEVELOPER
				sqprint(format("adding group: %d", groupHandle ))
			#endif

			foreach( player in players )
			{
				if( !IsValid( player ) || player.p.handle in file.scenariosPlayerToGroupMap )
					continue

				file.scenariosPlayerToGroupMap[ player.p.handle] <- newGroup
			}

			file.scenariosGroupsInProgress[ groupHandle ] <- newGroup

			//Cafe
			foreach( scenariosTeamStruct team in newGroup.teams )
			{
				foreach( player in team.players )
				{
					if( !IsValid( player ) )
						continue

					SetTeam( player, team.team )
				}
			}
		}
		else 
		{	
			#if DEVELOPER
			sqerror(format("Logic flow error, group: [%d] already exists", groupHandle))
			#endif
			return false
		}
	}
	catch(e)
	{
		#if DEVELOPER
			sqprint("addGroup crash: " + e)
		#endif
		return false
	}

    return true
}

void function FS_Scenarios_RemoveGroup( scenariosGroupStruct groupToRemove ) 
{
	if( !groupToRemove.isValid )
	{
		sqerror("Logic flow error:  groupToRemove is invalid")
		return
	}
	
	groupToRemove.isValid = false

	if( groupToRemove.groupHandle in file.scenariosGroupsInProgress )
	{
		#if DEVELOPER
			sqprint(format("removing group: %d", groupToRemove.groupHandle) )
		#endif
		delete file.scenariosGroupsInProgress[groupToRemove.groupHandle]
	}
	else 
	{
		#if DEVELOPER
			sqprint(format("groupToRemove.groupHandle: %d not in file.groupsInProgress", groupToRemove.groupHandle ))
		#endif
	}

	Signal( groupToRemove.dummyEnt, "FS_Scenarios_GroupFinished" )
	if( IsValid( groupToRemove.dummyEnt ) )
		groupToRemove.dummyEnt.Destroy()
}

scenariosGroupStruct ornull function FS_Scenarios_ReturnGroupForPlayer( entity player ) 
{
	if( !IsValid (player) )
	{	
		#if DEVELOPER
			sqprint("FS_Scenarios_ReturnGroupForPlayer entity was invalid")
		#endif
		
		return null
	}

	if ( player.p.handle in file.scenariosPlayerToGroupMap ) 
	{	
		if( IsValid( file.scenariosPlayerToGroupMap[ player.p.handle ] ) )
			return file.scenariosPlayerToGroupMap[ player.p.handle ]
	}else 
	{
		#if DEVELOPER
			sqprint("FS_Scenarios_ReturnGroupForPlayer player handle not in group map")
		#endif
	}

	return null
}

void function FS_Scenarios_RespawnIn3v3Mode( entity player )
{
	if ( !IsValid(player) )
		return
	
	if ( !player.p.isConnected )
		return

   	if( player.p.isSpectating )
    {
		player.SetPlayerNetInt( "spectatorTargetCount", 0 )
		player.p.isSpectating = false
		player.SetSpecReplayDelay( 0 )
		player.SetObserverTarget( null )
		player.StopObserverMode()
        Remote_CallFunction_ByRef( player, "ServerCallback_KillReplayHud_Deactivate" )
		//Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
        player.MakeVisible()
		player.ClearInvulnerable()
		player.SetTakeDamageType( DAMAGE_YES )
    }

	Remote_CallFunction_ByRef( player, "ForceScoreboardLoseFocus" )

   	if( isPlayerInRestingList( player ) )
	{	
		try
		{
			DecideRespawnPlayer( player, false )
		}
		catch (erroree)
		{	
			#if DEVELOPER
				sqprint("Caught an error that would crash the server" + erroree)
			#endif
		}
	
		LocPair waitingRoomLocation = FS_Scenarios_getWaitingRoomLocation()
		if (!IsValid(waitingRoomLocation)) return //why would it be invalid. 
		
		// GivePlayerCustomPlayerModel( player )
		maki_tp_player(player, waitingRoomLocation)
		player.MakeVisible()
		player.ClearInvulnerable() // !FIXME
		player.SetTakeDamageType( DAMAGE_YES )
		HolsterAndDisableWeapons(player)

		//set realms for resting player
		FS_ClearRealmsAndAddPlayerToAllRealms( player )

		return
	}
}

void function FS_Scenarios_Main_Thread()
{
    WaitForGameState(eGameState.Playing)
	FS_Scenarios_SaveDoorsData()

	OnThreadEnd(
		function() : (  )
		{
			Warning(Time() + "Solo thread is down!!!!!!!!!!!!!!!")
			GameRules_ChangeMap( GetMapName(), GameRules_GetGameMode() )
		}
	)

	for( ; ; )
	{
		wait 0.1

		FS_Scenarios_CleanupDropships()
		FS_Scenarios_CleanupDeathboxes()
		FS_Scenarios_CleanupDrops()

		// Los jugadores que están en la sala de espera no se pueden alejar mucho de ahí
		foreach ( playerHandle, playerInWaitingStruct in FS_1v1_GetPlayersWaiting() )
		{
			if( !IsValid( playerInWaitingStruct ) )
				continue
			
			entity player = playerInWaitingStruct.player

			if ( !IsValidPlayer( player ) ) //IsValidPlayer will check if player is disconnecting as well
				continue

			if( !IsAlive( player ) )
			{
				DecideRespawnPlayer( player, false )
				HolsterAndDisableWeapons( player )
				
			}
			
			player.SetHealth( player.GetMaxHealth() )
			player.SetShieldHealth( player.GetShieldHealthMax() )
			player.SetSkin(0)
			player.SetCamo( 0 )
			
			LocPair waitingRoomLocation = FS_Scenarios_getWaitingRoomLocation() 

			if( Distance( player.GetOrigin(), waitingRoomLocation.origin ) > settings.waitingRoomRadius ) //waiting player should be in waiting room,not battle area
			{
				maki_tp_player( player, waitingRoomLocation ) //waiting player should be in waiting room,not battle area
				HolsterAndDisableWeapons( player )
			}
		}

		array<scenariosGroupStruct> groupsToRemove

		foreach( groupHandle, group in file.scenariosGroupsInProgress ) 
		{
			if( !group.isValid )
				continue

			array<entity> players = FS_Scenarios_GetAllPlayersForGroup( group )

			if( group.isReady && !group.IsFinished && group.endTime > 0 )
			{
				bool shouldRingDoDamageThisFrame = false
				//Anuncio que la ronda individual está a punto de terminar
				if( IsValid( group.ring ) && Time() > ( group.endTime - 30 ) && !group.showedEndMsg )
				{
					foreach( player in players )
					{
						if( !IsValid( player ) )
							continue

						LocalMsg( player, "#FS_Scenarios_30Remaining", "", eMsgUI.EVENT, 5 )
					}
					group.showedEndMsg = true
				}

				if( Time() - group.lastTimeRingDamagedGroup > settings.fs_scenarios_ring_damage_step_time )
				{
					shouldRingDoDamageThisFrame = true
					group.lastTimeRingDamagedGroup = Time()
				}

				// No se pueden alejar mucho de la zona de juego
				vector Center = group.calculatedRingCenter

				foreach( player in players )
				{
					if( !IsValid( player ) || IsValid( player.p.respawnPod ) || !IsAlive( player ) ) 
						continue

					if ( player.IsPhaseShifted() )
						continue

					if( Distance2D( player.GetOrigin(),Center) > group.currentRingRadius && shouldRingDoDamageThisFrame && !group.IsFinished && group.isReady )
					{
						Remote_CallFunction_Replay( player, "ServerCallback_PlayerTookDamage", 0, 0, 0, 0, DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, eDamageSourceId.deathField, null )
						player.TakeDamage( settings.fs_scenarios_ring_damage, null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
						FS_Scenarios_UpdatePlayerScore( player, FS_ScoreType.PENALTY_RING )
						// printt( player, " TOOK DAMAGE", Distance2D( player.GetOrigin(),Center ) )
					}
				}
			}

			// Acabó la ronda, todos los jugadores de un equipo murieron
			if ( group.IsFinished )
			{
				#if DEVELOPER
					printw( "[+] GROUP FINISHED MATCH", group.groupHandle )
				#endif

				FS_Scenarios_SendRecapData( group )

				FS_Scenarios_DestroyRingsForGroup( group )
				FS_Scenarios_DestroyDoorsForGroup( group )

				if( settings.fs_scenarios_ground_loot )
				{
					FS_Scenarios_DestroyLootForGroup( group )
					FS_Scenarios_DestroyLootbinsForGroup( group )
				}

				FS_Scenarios_DestroyAllAliveDroppedLootForRealm( group.slotIndex )
				FS_Scenarios_DestroyAllAliveDeathboxesForRealm( group.slotIndex )
				ClearActiveProjectilesForRealm( group.slotIndex )

				SetIsUsedBoolForRealmSlot( group.slotIndex, false )
				foreach( scenariosTeamStruct team in group.teams )
				{
					FS_Scenarios_SetIsUsedBoolForTeamSlot( team.team, false )
				}

				//Some abilities designed to stay like, bombardments, zipline, care package, decoy, grenades
				//should be destroyed when the scenarios round ends and not when the player dies

				array<entity> ents = GetScriptManagedEntArray( group.trackedEntsArrayIndex )
				foreach ( ent in ents )
				{
					if( IsValid( ent ) )
					{
						ent.Destroy()
					}
				}
				#if DEVELOPER
					printt( "tracked ents removed", ents.len(), "for group", group.groupHandle )
				#endif 
				
				DestroyScriptManagedEntArray( group.trackedEntsArrayIndex )

				foreach( player in players )
				{
					if( !IsValid( player ) )
						continue

					soloModePlayerToWaitingList( player )
					HolsterAndDisableWeapons( player )
				}
				
				groupsToRemove.append(group)
			}
		}//foreach

		if( groupsToRemove.len() > 0 )
		{
			foreach ( group in groupsToRemove )
			{
				FS_Scenarios_RemoveGroup(group)
			}
			
			continue
		}

		// Revivir jugadores muertos que están descansando ( No debería pasar, pero por si acaso )
		foreach ( restingPlayerHandle, restingStruct in FS_1v1_GetPlayersResting() )
		{
			if( !restingPlayerHandle )
			{	
				sqerror("Null handle")
				continue
			}
			
			entity restingPlayerEntity = GetEntityFromEncodedEHandle( restingPlayerHandle )
			
			if( !IsValid( restingPlayerEntity ) ) 
				continue

			if( !IsAlive( restingPlayerEntity )  )
				FS_Scenarios_RespawnIn3v3Mode( restingPlayerEntity )
			
			HolsterAndDisableWeapons( restingPlayerEntity )
		}

		//Condiciones que detienen la creación de juegos
		if( GetScoreboardShowingState() || file.scenariosStopMatchmaking )
			continue

		table<int, soloPlayerStruct> waitingPlayersShuffledTable = clone FS_1v1_GetPlayersWaiting()
		array<entity> waitingPlayers
		int playersThatForceMatchmaking
		
		foreach ( playerHandle, eachPlayerStruct in waitingPlayersShuffledTable )
		{	
			if( !IsValid(eachPlayerStruct) )
				continue				
			
			entity player = eachPlayerStruct.player
			
			// if( player.GetPlayerName() == "r5r_CafeFPS" )
				// continue
			
			if( !IsValidPlayer( player ) ) //don't pass here if player is disconnecting Cafe
				continue
			
			#if TRACKER
			if( IsBotEnt( player ) ) //temporary messagebot bullcrap hack ( all of these need removed )
				continue
			#endif

			// if( player.p.InDeathRecap ) //Has player closed Death Recap? //Not reliable until we solve all the death recap. Cafe
				// continue
			// #if DEVELOPER
				// Warning( "Checking for player " + (Time() - player.p.lastRequeueUsedTime) )
			// #endif
			
			// if( Time() - player.p.lastRequeueUsedTime < settings.fs_scenarios_matchmaking_delay_after_dying ) // Penalizar a los que mueren.
				// continue
			
			if( player.GetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby" ) == -1 ) //shouldn't happen but just in case
				player.SetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby", Time() )
			
			if( GetGlobalNetInt( "livingPlayerCount" ) >= settings.fs_scenarios_low_player_threshold )
			{
				if( Time() - player.GetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby" ) > settings.fs_scenarios_max_queuetime )
					playersThatForceMatchmaking++
			}
			else 
			{
				if( Time() - player.GetPlayerNetTime( "FS_Scenarios_timePlayerEnteredInLobby" ) > settings.fs_scenarios_max_queuetime_low )
					playersThatForceMatchmaking++
			}
			
			waitingPlayers.append( player )
		}
		
		bool forceGame = playersThatForceMatchmaking >= settings.fs_scenarios_min_players_forced_match && playersThatForceMatchmaking >= waitingPlayers.len() && waitingPlayers.len() > 1
		//if there a 3 players and they are two seconds left to start and a player joins, this will make wait for the new player to reach the time again ( 30s )
		//playersThatForceMatchmaking == waitingPlayers.len() is to do the force logic only when there are barely players in the server. If there are games runnings, should be fast enough for players to wait in the timeout. Cafe
		
		#if DEVELOPER
		if( forceGame )
			Warning( "Force game because players have waited a long time " + playersThatForceMatchmaking )
		#endif
		
		// Hay suficientes jugadores para crear un equipo?
		if( waitingPlayers.len() < ( settings.fs_scenarios_playersPerTeam * settings.fs_scenarios_teamAmount ) && !forceGame )
			continue	

		scenariosGroupStruct newGroup //Creates a new game
		newGroup.isForcedGame = forceGame //Todo something with e.e. Cafe

		Assert( waitingPlayers.len() < ( settings.fs_scenarios_playersPerTeam * settings.fs_scenarios_teamAmount ) )

		#if DEVELOPER
			printt("------------------MATCHING GROUP------------------")
		#endif

		waitingPlayers.randomize()

		waitingPlayers.sort( FS_SortPlayersByPriority )


		//Create required team structs and request team slot
		for( int i = 0; i < settings.fs_scenarios_teamAmount; i++ )
		{
			Assert( newGroup.teams.len() == settings.fs_scenarios_teamAmount )
			scenariosTeamStruct team
			team.team = FS_Scenarios_GetAvailableTeamSlotIndex()
			
			newGroup.teams.append( team )
		} 

		int playersN = minint( waitingPlayers.len(), ( settings.fs_scenarios_playersPerTeam * settings.fs_scenarios_teamAmount ) )
		
		//Limpiar equipos sobrantes.
		int CALCULATED_TEAMS = minint( int( ceil( playersN / settings.fs_scenarios_playersPerTeam + 0.5 ) ), settings.fs_scenarios_teamAmount ) //Cafe was here
		
		for( int i = newGroup.teams.len() - 1; i >= 0 ; i-- )
		{
			if( i < CALCULATED_TEAMS )
				continue
			
			if( newGroup.teams[i].players.len() == 0 )
				newGroup.teams.remove( i )
		}

	
		//This iterates over all players in lobby to assign them a team ( a game has to be created )
		// mkos please add proper matchmaking for teams lol	- (mk): will do.
		for( int i = waitingPlayers.len() - 1; i >= 0 ; i-- )
		{
			entity player = waitingPlayers[i]

			scenariosTeamStruct team = FS_GetBestTeamToFillForGroup( newGroup.teams )
			
			if( team.players.len() < settings.fs_scenarios_playersPerTeam )
			{
				team.players.append( player )
				waitingPlayers.remove( i )
			}
			else
				break //Stop iteration. No more teams to fill. Break
		}

		#if DEVELOPER
			printt( "[Scenarios]", waitingPlayers.len(), " players didn't join to this match and will be still waiting. Calculated Teams: " + CALCULATED_TEAMS )
		#endif

		foreach( player in waitingPlayers ) //players that didn't get into a match this frame
		{
			if( !IsValid( player ) )
				continue

			player.p.scenariosTeamsMatched++ //To give priority next game. Cafe
		}

		array<entity> players = FS_Scenarios_GetAllPlayersForGroup( newGroup )

		bool success = FS_Scenarios_GroupToInProgressList( newGroup, players )

		if( !success )
		{
			NukeGroupCuzIsNotValidAnymore( newGroup )
			continue
		}
		else
			newGroup.isValid = true

		soloLocStruct groupLocStruct = newGroup.groupLocStruct
	
		//Randomize spawns if there are less than max teams
		if( CALCULATED_TEAMS < settings.fs_scenarios_teamAmount )
			groupLocStruct.respawnLocations.randomize() //todo make an algo that grabs the spawns with the furthest distance between them. Cafe
		
		newGroup.calculatedRingCenter = OriginToGround_Inverse( groupLocStruct.Center )//to ensure center is above ground. Colombia

		#if DEVELOPER
			printt( "Calculated center for ring: ", newGroup.calculatedRingCenter )
			DebugDrawSphere( newGroup.calculatedRingCenter, 30, 255,0,0, true, 300 )
		#endif

		newGroup.trackedEntsArrayIndex = CreateScriptManagedEntArray()
		
		#if DEVELOPER
			printt( "tracked ents script managed array created for group", newGroup.groupHandle, newGroup.trackedEntsArrayIndex )
		#endif
		
		//fix this to iterate over all group.teams teams
		//Scenarios_CleanupMiscProperties( [ newGroup.team1Players, newGroup.team2Players, newGroup.team3Players ] )
		
		//Leave it this way to avoid issues with cards. They only support 2 or 3 teams.
		if( newGroup.teams.len() == 2 || newGroup.teams.len() == 3 )
		{
			array<entity> team1 = newGroup.teams[0].players
			array<entity> team2 = newGroup.teams[1].players
			array<entity> team3
			
			if( newGroup.teams.len() == 3 )
				team3 = newGroup.teams[2].players
			// Setup HUD
			foreach( player in team1 )
			{
				foreach( splayer in team1 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddAllyHandle", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team2 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team3 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle2", splayer.GetEncodedEHandle() )
				}
			}
			
			foreach( player in team2 )
			{
				foreach( splayer in team1 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team2 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddAllyHandle", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team3 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle2", splayer.GetEncodedEHandle() )
				}
			}

			foreach( player in team3 )
			{
				foreach( splayer in team1 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team2 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddEnemyHandle2", splayer.GetEncodedEHandle() )
				}
				foreach( splayer in team3 )
				{
					if( IsValid( player ) && IsValid( splayer ) )
						Remote_CallFunction_NonReplay( player, "FS_Scenarios_AddAllyHandle", splayer.GetEncodedEHandle() )
				}
			}
		} else //Show compass if cards won't show
		{
			foreach ( entity player in players )
			{
				if( !IsValidPlayer( player ) )
					continue
					
				Remote_CallFunction_ByRef( player, "FS_ForceCompass" )
			}
		}

		thread function () : ( newGroup, players )
		{
			EndSignal( newGroup.dummyEnt, "FS_Scenarios_GroupFinished" )

			//Match found.. show msg wait a bit. Cafe
			foreach ( entity player in players )
			{
				if( !IsValidPlayer( player ) )
					continue
					
				Gamemode1v1_SetPlayerGamestate( player, e1v1State.PREMATCH )
				
				LocalMsg( player, "#FS_NULL", "", eMsgUI.EVENT, 1 )
				Remote_CallFunction_Replay( player, "Flowstate_ShowMatchFoundUI", 3 )
			}
			
			wait 3
			
			if( !IsValid( newGroup ) || !newGroup.isValid )
			{
				NukeGroupCuzIsNotValidAnymore( newGroup )
				return
			}
			
			FS_Scenarios_CreateCustomDeathfield( newGroup )
			soloLocStruct groupLocStruct = newGroup.groupLocStruct

			thread FS_Scenarios_SpawnDoorsForGroup( newGroup )
			thread FS_Scenarios_SpawnBigDoorsForGroup( newGroup )

			//Play fx on players screen
			if( !settings.fs_scenarios_characterselect_enabled )
				foreach ( entity player in players )
				{
					if( !IsValidPlayer( player ) )
						continue

					//Remote_CallFunction_NonReplay( player, "FS_CreateTeleportFirstPersonEffectOnPlayer" )
					Remote_CallFunction_ByRef( player, "FS_CreateTeleportFirstPersonEffectOnPlayer" )
					Flowstate_AssignUniqueCharacterForPlayer( player, true )
					if( GetCurrentPlaylistVarBool( "flowstate_giveskins_characters", false ) )
					{
						array<ItemFlavor> characterSkinsA = GetValidItemFlavorsForLoadoutSlot( ToEHI( player ), Loadout_CharacterSkin( LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_CharacterClass() ) ) )
						CharacterSkin_Apply( player, characterSkinsA[characterSkinsA.len()-RandomIntRangeInclusive(1,4)])
					}
				}

			if( settings.fs_scenarios_ground_loot )
			{
				thread FS_Scenarios_SpawnLootbinsForGroup( newGroup )
				thread FS_Scenarios_SpawnLootForGroup( newGroup )
			}
			#if DEVELOPER
				else
				{
					printt( "ground loot is disabled from playlist!" )
				}
			#endif

			wait 0.5

			if( !IsValid( newGroup ) || !newGroup.isValid )
			{
				NukeGroupCuzIsNotValidAnymore( newGroup )
				return
			}
			
			ArrayRemoveInvalid( players )
			int spawnSlot = -1
			int oldSpawnSlot = -1
			int j = 0
			foreach ( int i, entity player in players )
			{
				if( !IsValidPlayer( player ) )
					continue

				FS_SetRealmForPlayer( player, newGroup.slotIndex )			
				
				int amountPlayersPerTeam

				foreach( int k, scenariosTeamStruct team in newGroup.teams )
				{
					if( player.GetTeam() == team.team )
					{
						spawnSlot = k
						amountPlayersPerTeam = team.players.len()
						break
					}
				}
				
				#if DEVELOPER
					printw("spawning player in slot", spawnSlot, player )
				#endif

				if ( spawnSlot == -1 ) 
				{
					soloModePlayerToWaitingList( player )
					continue
				}
				
				//avoid to grab spawns from other locations by forcing it adding the location a random one of the availables
				//spawns should be desgined for settings.fs_scenarios_teamAmount
				//in case there are more teams than the designed spawns, choose a random spawn for that team /solves a bug where it grabs locations from other zones

				if( spawnSlot >= settings.fs_scenarios_teamAmount )
					spawnSlot = RandomIntRangeInclusive( 0, settings.fs_scenarios_teamAmount - 1 )
				
				if( spawnSlot != oldSpawnSlot )
					j = 0
				
				FS_Scenarios_RespawnIn3v3Mode( player )

				EmitSoundOnEntityOnlyToPlayer( player, player, "PhaseGate_Enter_1p" )
				EmitSoundOnEntityExceptToPlayer( player, player, "PhaseGate_Enter_3p" )

				{
					LocPair location = groupLocStruct.respawnLocations[ spawnSlot ]
					player.MovementDisable()
					AddCinematicFlag( player, CE_FLAG_INTRO )
					player.SetVelocity( < 0,0,0 > )
					player.SetAngles( location.angles )
					vector pos = location.origin

					float r = float(j) / float( amountPlayersPerTeam ) * 2 * PI
					vector circledPos = pos + 30.0 * <sin( r ), cos( r ), 0.0> 

					TraceResults result = TraceHull( circledPos + <0, 0, 50>, circledPos - <0, 0, 10>, player.GetBoundingMins(), player.GetBoundingMaxs(), null, TRACE_MASK_SOLID | CONTENTS_PLAYERCLIP, TRACE_COLLISION_GROUP_NONE )

					if( result.fraction == 1.0 || result.startSolid )
					{
						circledPos = pos //fallback to ogspawn pos which we know is good. Café
					} else
						circledPos = result.endPos

					// player.SetOrigin( circledPos )
					ClearLastAttacker( player )
					player.SnapToAbsOrigin( circledPos )
					player.SnapEyeAngles( location.angles )
					player.SnapFeetToEyes()
					j++
				}

				oldSpawnSlot = spawnSlot
				//Remote_CallFunction_NonReplay( player, "UpdateRUITest")
				Remote_CallFunction_ByRef( player, "UpdateRUITest" )
			}

			thread FS_Scenarios_GiveWeaponsToGroup( players )

			thread function () : ( newGroup, players )
			{
				EndSignal( newGroup.dummyEnt, "FS_Scenarios_GroupFinished" )

				OnThreadEnd
				(
					function() : ( newGroup, players  )
					{
						foreach( entity player in players )
						{
							if( !IsValidPlayer( player ) )
								continue

							player.Server_TurnOffhandWeaponsDisabledOff() //vm activity cant be enabled without
							entity currentWeapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
							if( IsValid( currentWeapon ) && !newGroup.IsFinished && !currentWeapon.IsWeaponOffhand() )
							{
								int ammoType = currentWeapon.GetWeaponAmmoPoolType()
								player.AmmoPool_SetCount( ammoType, player.p.lastAmmoPoolCount )
								
								if( currentWeapon.UsesClipsForAmmo() )
									currentWeapon.SetWeaponPrimaryClipCountNoRegenReset( currentWeapon.GetWeaponPrimaryClipCountMax() )
								
								if( currentWeapon.Anim_HasActivity( "ACT_VM_DRAWFIRST" ) )
									currentWeapon.StartCustomActivity("ACT_VM_DRAWFIRST", 0)
							}

							player.MovementEnable()
							player.UnforceStand()
							DeployAndEnableWeapons( player )
							
							UnlockWeaponsAndMelee( player )
							EnableAllWeaponsExceptHandsOrIncap( player )
							
							player.ClearFirstDeployForAllWeapons()
							// player.UnfreezeControlsOnServer()
							ClearInvincible(player)
							Highlight_ClearEnemyHighlight( player )

							if( !newGroup.IsFinished )
							{
								//string spawnName = newGroup.groupLocStruct.name
								string ids = newGroup.groupLocStruct.ids
								LocalMsg( player, "#FS_Scenarios_Tip", "", eMsgUI.EVENT, 5 ) //, " \n\n Spawning at:  " + spawnName + " \n All Spawns IDS for fight: " + ids ) //Why is this needed? Looks like useless debug info for the end user [Cafe] - //(mk): this was just a test to see how spawn metadata would be used for a game mode
							}
							
							if( settings.fs_scenarios_characterselect_enabled )
							{
								player.SetPlayerNetInt( "characterSelectLockstepIndex", -1 )
								player.SetPlayerNetBool( "hasLockedInCharacter", true )
							}
							
							//Setup starting shields
							PlayerRestoreHP_1v1(player, 100, Equipment_GetDefaultShieldHP() )
							
							Inventory_SetPlayerEquipment( player, "incapshield_pickup_lv3", "incapshield")
							Inventory_SetPlayerEquipment( player, "backpack_pickup_lv3", "backpack")
							
							array<string> loot = [ "mp_weapon_frag_grenade", "health_pickup_ultimate", "health_pickup_ultimate", "health_pickup_combo_full", "health_pickup_combo_large", "health_pickup_combo_large", "health_pickup_combo_large", "health_pickup_health_large", "health_pickup_health_large", "health_pickup_combo_small", "health_pickup_combo_small", "health_pickup_combo_small", "health_pickup_combo_small", "health_pickup_combo_small", "health_pickup_combo_small", "health_pickup_health_small", "health_pickup_health_small"]
								foreach(item in loot)
									SURVIVAL_AddToPlayerInventory(player, item)
							
							SURVIVAL_AutoEquipOrdnanceFromInventory( player, false )
						}
					}
				)

				foreach( player in players )
				{
					if( !IsValidPlayer( player ) )
						continue

					player.ForceStand()
					
					player.Server_TurnOffhandWeaponsDisabledOn()
					
					LockWeaponsAndMelee( player )
					DisableAllWeaponsExceptHandsOrIncap( player )
					
					player.MovementDisable()
					
					entity weapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )
					
					if( IsValid( weapon ) )
					{
						int ammoType = weapon.GetWeaponAmmoPoolType()
						player.p.lastAmmoPoolCount = player.AmmoPool_GetCount( ammoType )
						player.AmmoPool_SetCount( ammoType, 0 )
						
						if( weapon.UsesClipsForAmmo() )
							weapon.SetWeaponPrimaryClipCountNoRegenReset( 0 )
						
						weapon.SetNextAttackAllowedTime( Time() + settings.fs_scenarios_game_start_time_delay )
						weapon.OverrideNextAttackTime( Time() + settings.fs_scenarios_game_start_time_delay )
					}

					foreach ( newWeapon in player.GetMainWeapons() )
					{
						//Cafe was here
						ItemFlavor ornull weaponSkinOrNull = null
						array<string> fsCharmsToUse = [ "SAID00701640565", "SAID01451752993", "SAID01334887835", "SAID01993399691", "SAID00095078608", "SAID01439033541", "SAID00510535756", "SAID00985605729" ]
						ItemFlavor ornull weaponCharmOrNull 
						int chosenCharm = ConvertItemFlavorGUIDStringToGUID( fsCharmsToUse.getrandom() )

						if( newWeapon.e.charmItemFlavorGUID != -1 )
							chosenCharm = newWeapon.e.charmItemFlavorGUID
							
						if( newWeapon.e.skinItemFlavorGUID != -1 )
						{
							weaponSkinOrNull = GetItemFlavorByGUID( newWeapon.e.skinItemFlavorGUID )
						} else if ( GetCurrentPlaylistVarBool( "flowstate_giveskins_weapons", false ) )
						{
							ItemFlavor ornull weaponFlavor = GetWeaponItemFlavorByClass( newWeapon.GetWeaponClassName() )
							
							if( weaponFlavor != null )
							{
								array<int> weaponLegendaryIndexMap = FS_ReturnLegendaryModelMapForWeaponFlavor( expect ItemFlavor( weaponFlavor ) )
								if( weaponLegendaryIndexMap.len() > 1 )
									weaponSkinOrNull = GetItemFlavorByGUID( weaponLegendaryIndexMap[RandomIntRangeInclusive(1,weaponLegendaryIndexMap.len()-1)] )
							}
						}

						if ( GetCurrentPlaylistVarBool( "flowstate_givecharms_weapons", false ) )
							weaponCharmOrNull = GetItemFlavorByGUID( chosenCharm )

						WeaponCosmetics_Apply( newWeapon, weaponSkinOrNull, weaponCharmOrNull )
					}
					
					MakeInvincible(player)
				}

				UpdatePlayerCounts()
				
				if( settings.fs_scenarios_characterselect_enabled )
				{
					#if DEVELOPER 
						printt( "STARTING CHARACTER SELECT FOR GROUP", newGroup.groupHandle, "IN REALM", newGroup.slotIndex )
					#endif 
					
					waitthread FS_Scenarios_StartCharacterSelectForGroup( newGroup )
				}

				float startTime = Time() + settings.fs_scenarios_game_start_time_delay
				foreach( player in players )
				{
					if( !IsValidPlayer( player ) )
						continue
					
					player.SetMinimapZoomScale( 0.75, 3.0 )
					Remote_CallFunction_NonReplay( player, "FS_Scenarios_OnRingCreated", newGroup.ring )
					
					Highlight_ClearEnemyHighlight( player )
					Highlight_SetEnemyHighlight( player, "hackers_wallhack" )

					if( settings.fs_scenarios_characterselect_enabled )
					{
						player.SetPlayerNetBool( "characterSelectionReady", false )
						player.Server_TurnOffhandWeaponsDisabledOn()
					}
					else
						GiveLoadoutRelatedWeapons( player )

					RemoveCinematicFlag( player, CE_FLAG_INTRO )
					player.SetPlayerNetTime( "FS_Scenarios_gameStartTime", startTime )
					
					Remote_CallFunction_NonReplay( player, "FS_Scenarios_SetupPlayersCards", false )
					player.SetShieldHealth( 0 )
					player.SetShieldHealthMax( 0 )
					Inventory_SetPlayerEquipment(player, "", "armor")
					
					player.SetSkin(2)
					player.SetCamo( player.GetTeam() % 10 )
				}

				wait settings.fs_scenarios_game_start_time_delay
				
				Signal( newGroup.dummyEnt, "FS_Scenarios_GroupIsReady" )
				
				SetGamestateForPlayers( players, e1v1State.MATCHING )

				newGroup.startTime = Time()
				newGroup.isReady = true
			}()
		}()
	}//while(true)

}//thread

void function NukeGroupCuzIsNotValidAnymore( scenariosGroupStruct newGroup )
{
	FS_Scenarios_RemoveGroup( newGroup )
	array<entity> players = FS_Scenarios_GetAllPlayersForGroup( newGroup )	
	
	foreach( team in newGroup.teams )
	{
		FS_Scenarios_SetIsUsedBoolForTeamSlot( team.team, false )
	}
	
	foreach( player in players )
	{
		if( !IsValid( player ) )
			continue

		soloModePlayerToWaitingList(player)
	}
}

void function SetGamestateForPlayers( array<entity> players, int state)
{
	foreach( player in players )
		Gamemode1v1_SetPlayerGamestate( player, state )
}

int function FS_SortPlayersByPriority( entity a, entity b )
{
	if ( a.p.scenariosTeamsMatched > b.p.scenariosTeamsMatched )
		return 1
	if ( a.p.scenariosTeamsMatched < b.p.scenariosTeamsMatched )
		return -1

	return 0
}

void function FS_Scenarios_HandleGroupIsFinished( entity player )
{
	if( !IsValid( player ) )
		return

	if( !IsCurrentState( player, e1v1State.RESTING ) )
		Gamemode1v1_SetPlayerGamestate( player, e1v1State.WAITING )
		
	scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )
	
	if( group == null )
		return
	
	expect scenariosGroupStruct( group )
	
	if( !IsValid( group ) || !group.isValid || group.IsFinished || !group.isReady )
		return

	int aliveTeamCount
	int lastTeamAlive //to count for alive 
	
	array<entity> winners
	
	foreach( scenariosTeamStruct team in group.teams )
	{
		foreach( splayer in team.players )
		{
			if( !IsValid( splayer ) )
				continue
			
			if( IsAlive( splayer ) ) //&& !Bleedout_IsBleedingOut( splayer ) ) //Give points to the downed alive players as well. So being alive and not skipping the knockdown stage will be more rewardable. Bleeding players can win the game if the remaining enemy dies to something first. Cafe
			{
				if( lastTeamAlive != team.team )
					aliveTeamCount++
				
				lastTeamAlive = team.team

				winners.append( splayer )
			}
		}
	}

	if( aliveTeamCount == 1 && winners.len() > 0 )
	{
		bool success = false
		//todo if there are players in the winners array from different teams, return. Cafe
		
		float elapsedTime = Time() - group.startTime

		if( winners.len() > 1 ) //These players should be from the same team, if not, game hasn't finished
		{
			foreach( winner in winners )
			{
				FS_Scenarios_UpdatePlayerScore( winner, FS_ScoreType.SURVIVAL_TIME, null, elapsedTime )
				FS_Scenarios_UpdatePlayerScore( winner, FS_ScoreType.TEAM_WIN )
				player.SetPlayerNetInt( "FS_Scenarios_MatchesWins", player.GetPlayerNetInt( "FS_Scenarios_MatchesWins" ) + 1 )
			}
		}
		else if( winners.len() == 1 )
		{
			FS_Scenarios_UpdatePlayerScore( winners[0], FS_ScoreType.SURVIVAL_TIME, null, elapsedTime )
			FS_Scenarios_UpdatePlayerScore( winners[0], FS_ScoreType.SOLO_WIN )
			player.SetPlayerNetInt( "FS_Scenarios_MatchesWins", player.GetPlayerNetInt( "FS_Scenarios_MatchesWins" ) + 1 )
		}

		//End the game delayed.. Cafe
		thread function () : ( group )
		{
			group.isReady = false //Stop ring
			foreach ( splayer in FS_Scenarios_GetAllPlayersForGroup( group ) )
			{
				MakeInvincible(splayer)
				Remote_CallFunction_ByRef( splayer, "ServerCallback_Scenarios_MatchEndAnnouncement" )

				//Revivir a los knockeados
				if( Bleedout_IsBleedingOut( splayer ) )
					Signal( splayer, "BleedOut_OnRevive" )
			}
			
			wait 5

			foreach ( splayer in FS_Scenarios_GetAllPlayersForGroup( group ) ) //before is finished to avoid issues
			{
				ClearInvincible(splayer)
			}
			group.IsFinished = true //tell thread this round has finished
			
			if( IsValid( group.dummyEnt ) )
			{
				Signal( group.dummyEnt, "FS_Scenarios_GroupFinished" )
				group.dummyEnt.Destroy()
			}
			
			#if DEVELOPER
				printt( "Group has finished delayed" )
			#endif
		}()

		if( group.isLastGameFromRound )
		{
			g_fCurrentRoundEndTime = Time() //Set the global flowstate end time to end right now if this group was the last group from the round and everyone was waiting for them
			SetGlobalNetTime( "flowstate_DMRoundEndTime", g_fCurrentRoundEndTime + 3 + 1 ) //3 from champion screen
		}
	}
} 

void function FS_Scenarios_StartCharacterSelectForGroup( scenariosGroupStruct group )
{
	if( !group.isValid || group.IsFinished )
		return

	table< int, array< entity > > groupedPlayers
	
	foreach( int i, scenariosTeamStruct team in group.teams )
	{
		groupedPlayers[i] <- team.players
	}

	#if DEVELOPER
	printt( "GIVING LOCKSTEP ORDER FOR PLAYERS GROUP", group.groupHandle, "IN REALM", group.slotIndex )
	#endif

	float startime = Time()
	float timeBeforeCharacterSelection = CharSelect_GetIntroCountdownDuration() + CharSelect_GetPickingDelayBeforeAll()

	float timeToSelectAllCharacters = CharSelect_GetPickingDelayOnFirst()
	for ( int pickIndex = 0; pickIndex < settings.fs_scenarios_playersPerTeam; pickIndex++ )
		timeToSelectAllCharacters += Survival_GetCharacterSelectDuration( pickIndex ) + CharSelect_GetPickingDelayAfterEachLock()

	float timeAfterCharacterSelection = CharSelect_GetPickingDelayAfterAll() + CharSelect_GetOutroTransitionDuration()

	foreach( int team, array<entity> players in groupedPlayers )
	{
		if ( players.len() == 0 )
			continue

		ArrayRemoveInvalid( players )
		players.randomize()
		int i = 0
		foreach( entity player in players )
		{
			Gamemode1v1_SetPlayerGamestate( player, e1v1State.CHARSELECT )
			player.SetPlayerNetInt( "characterSelectLockstepPlayerIndex", i )
			player.SetPlayerNetTime( "pickLoadoutGamestateStartTime", startime + CharSelect_GetIntroTransitionDuration() )
			player.SetPlayerNetTime( "pickLoadoutGamestateEndTime", startime + timeBeforeCharacterSelection + timeToSelectAllCharacters + timeAfterCharacterSelection )
			player.SetPlayerNetBool( "hasLockedInCharacter", false )
			player.SetPlayerNetBool( "characterSelectionReady", true )
			i++
		}
	}

	wait CharSelect_GetIntroTransitionDuration()
	#if DEVELOPER
	printt( "[Scenarios] SIGNALING THAT CHARACTER SELECT SHOULD OPEN ON CLIENTS OF GROUP", group.groupHandle, "IN REALM", group.slotIndex )
	#endif

	wait CharSelect_GetPickingDelayBeforeAll()

	for ( int pickIndex = 0; pickIndex < settings.fs_scenarios_playersPerTeam; pickIndex++ )
	{
		float startTime = Time()

		float timeSpentOnSelection = settings.fs_scenarios_characterselect_time_per_player

		float endTime = startTime + timeSpentOnSelection

		foreach( int team, array<entity> players in groupedPlayers )
		{
			if ( players.len() == 0 )
				continue

			ArrayRemoveInvalid( players )
			foreach( entity player in players )
			{
				player.SetPlayerNetInt( "characterSelectLockstepIndex", pickIndex )
				player.SetPlayerNetTime( "characterSelectLockstepStartTime", startTime )
				player.SetPlayerNetTime( "characterSelectLockstepEndTime", endTime )
			}
		}
		#if DEVELOPER
		printt( "[Scenarios] SIGNALING LOCKSTEP INDEX CHANGE FOR GROUP", group.groupHandle, "IN REALM", group.slotIndex, "SHOULD WAIT", timeSpentOnSelection )
		#endif

		wait timeSpentOnSelection
		foreach( int team, array<entity> players in groupedPlayers )
		{
			if ( players.len() == 0 )
				continue

			ArrayRemoveInvalid( players )

			foreach ( player in FS_Scenarios_GetAllPlayersOfLockstepIndex( pickIndex, players ) )
			{
				ItemFlavor selectedCharacter = LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_CharacterClass() )
				CharacterSelect_AssignCharacter( player, selectedCharacter )
				thread RechargePlayerAbilities( player, -1, settings.fs_scenarios_recharge_tactical_only ) // may need threaded or pass legend index in second param -- since you already have the flacor we should pass that directly to avoid double waits. 
			}

			foreach ( player in FS_Scenarios_GetAllPlayersOfLockstepIndex( pickIndex + 1, players ) )
			{
				if ( !player.GetPlayerNetBool( "hasLockedInCharacter" ) )
				{
					Flowstate_AssignUniqueCharacterForPlayer(player, false)
					if( GetCurrentPlaylistVarBool( "flowstate_giveskins_characters", false ) )
					{
						array<ItemFlavor> characterSkinsA = GetValidItemFlavorsForLoadoutSlot( ToEHI( player ), Loadout_CharacterSkin( LoadoutSlot_GetItemFlavor( ToEHI( player ), Loadout_CharacterClass() ) ) )
						CharacterSkin_Apply( player, characterSkinsA[characterSkinsA.len()-RandomIntRangeInclusive(1,4)])
					}
				}
			}
		}

		wait CharSelect_GetPickingDelayAfterEachLock()
		#if DEVELOPER
		printt( "[Scenarios] GIVING CHARACTER FOR PLAYERS WITH SLOT", pickIndex, "OF GROUP", group.groupHandle, "IN REALM", group.slotIndex )
		#endif
	}

	wait 3

	foreach( int team, array<entity> players in groupedPlayers )
	{
		ArrayRemoveInvalid( players )
		
		if ( players.len() == 0 )
			continue
			
		foreach( entity player in players )
		{
			Remote_CallFunction_ByRef( player, "FS_CreateTeleportFirstPersonEffectOnPlayer" )
			//Remote_CallFunction_NonReplay( player, "FS_CreateTeleportFirstPersonEffectOnPlayer" )
		}
	}
	
	wait 0.5
}

array<entity> function FS_Scenarios_GetAllPlayersOfLockstepIndex( int index, array<entity> players )
{
	array<entity> result = []

	foreach ( player in players )
		if ( player.GetPlayerNetInt( "characterSelectLockstepPlayerIndex" ) == index )
			result.append( player )

	return result
}

void function FS_Scenarios_StartRingMovementForGroup( scenariosGroupStruct group )
{
	if( !group.isValid || group.IsFinished )
		return
	
	EndSignal( group.dummyEnt, "FS_Scenarios_GroupFinished" )
	
	array<entity> players = clone FS_Scenarios_GetAllPlayersForGroup( group )
	
	foreach( player in  players )
	{
		player.SetPlayerNetTime( "FS_Scenarios_currentDeathfieldRadius", group.currentRingRadius )
		player.SetPlayerNetTime( "FS_Scenarios_currentDistanceFromCenter", -1 )
	}
	
	WaitSignal( group.dummyEnt, "FS_Scenarios_GroupIsReady" )
	
	ArrayRemoveInvalid( players )
	
	float closingSpeed = settings.fs_scenarios_zonewars_ring_ringclosingspeed // Per frame
	float frameDuration = 0.05 // 1 / GetConVarFloat( "script_server_fps" ) // Time per frame in seconds
	float starttime = Time()
	float startradius = group.currentRingRadius
	
	// Total frames required to close the ring
	float framesToClose = startradius / closingSpeed
	// Calculate time to close based on frames
	float timeToClose = framesToClose * frameDuration * 2.0
	float endtime = starttime + timeToClose
	
	foreach( player in players )
	{
		Remote_CallFunction_NonReplay( player, "FS_Scenarios_SetRingCloseTimeForMinimap", timeToClose )
	}
	
	group.endTime = endtime
	
	float maxEndTime = settings.fs_scenarios_characterselect_enabled == true ? ( 7.0 + settings.fs_scenarios_characterselect_time_per_player*settings.fs_scenarios_playersPerTeam ) : 0.0
	maxEndTime += group.endTime + 5
	
	if( maxEndTime > g_fCurrentRoundEndTime )
	{
		//not enough time for another match. Cafe
		g_fCurrentRoundEndTime = maxEndTime //Set the global flowstate end time to the max time this round could have and don't create new games
		SetGlobalNetTime( "flowstate_DMRoundEndTime", g_fCurrentRoundEndTime )
		file.scenariosStopMatchmaking = true
		group.isLastGameFromRound = true
	
		#if DEVELOPER
		Warning("[Scenarios] Time was extended", maxEndTime )
		#endif
	}
	
	table<int, soloPlayerStruct> waitingPlayers = clone FS_1v1_GetPlayersWaiting()
	
	foreach ( playerHandle, eachPlayerStruct in waitingPlayers )
	{	
		if( !IsValid(eachPlayerStruct) )
			continue				
		
		entity player = eachPlayerStruct.player
	
		if( !IsValidPlayer( player ) ) //don't pass here if player is disconnecting Cafe
			continue
		
		if( players.contains( player ) )
			continue
	
		if( file.scenariosStopMatchmaking )
			LocalMsg( player, "#FS_Scenarios_WaitingForRoundEnd", "", eMsgUI.EVENT, maxEndTime - Time() )
	}		
	
	EndSignal( group.ring, "OnDestroy" )
	
	while ( group.currentRingRadius > -1 )
	{
		if( !group.isReady )
		{
			wait frameDuration
			continue
		}
	
		players.clear()
		players = clone FS_Scenarios_GetAllPlayersForGroup( group )
	
		// Decrease radius
		group.currentRingRadius -= closingSpeed
	
		foreach( player in players )
		{
			player.SetPlayerNetTime( "FS_Scenarios_currentDeathfieldRadius", group.currentRingRadius )
			player.SetPlayerNetTime( "FS_Scenarios_currentDistanceFromCenter", Distance2D( player.GetOrigin(), group.calculatedRingCenter ) )
		}
		
		wait frameDuration
	}
}


void function FS_Scenarios_CreateCustomDeathfield( scenariosGroupStruct group )
{
	if( !group.isValid || group.IsFinished )
		return

	soloLocStruct groupLocStruct = group.groupLocStruct
	vector Center = group.calculatedRingCenter

	float ringRadius = 0

	foreach( LocPair spawn in groupLocStruct.respawnLocations )
	{
		if( Distance2D( spawn.origin, Center ) > ringRadius )
			ringRadius = Distance2D(spawn.origin, Center )
	}

	group.currentRingRadius = ringRadius + settings.fs_scenarios_default_radius_padding

	printw( "RING RADIUS WAS CREATED WITH ", group.currentRingRadius, "UNITS" )
	int realm = group.slotIndex
	float radius = group.currentRingRadius

	entity smallcircle = CreateEntity( "prop_script" )
	smallcircle.SetValueForModelKey( $"mdl/dev/empty_model.rmdl" )
	smallcircle.kv.fadedist = 2000
	smallcircle.kv.renderamt = 1
	smallcircle.kv.solid = 0
	smallcircle.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE
	// smallcircle.SetOwner(Owner)
	smallcircle.SetOrigin( Center )
	smallcircle.SetAngles( <0, 0, 0> )
	smallcircle.NotSolid()
	smallcircle.DisableHibernation()
	SetTargetName( smallcircle, "scenariosDeathField" )

	if( realm > -1 )
	{
		smallcircle.RemoveFromAllRealms()
		smallcircle.AddToRealm( realm )
	}
	
	DispatchSpawn( smallcircle )

	group.ring = smallcircle

	thread FS_Scenarios_StartRingMovementForGroup( group )
}

void function FS_Scenarios_DestroyRingsForGroup( scenariosGroupStruct group )
{
	if( IsValid(group.ring) )
		group.ring.Destroy()
}

void function FS_Scenarios_ForceAllRoundsToFinish()
{
	FS_Scenarios_DestroyAllAliveDropships()

	foreach(player in GetPlayerArray())
	{
		if(!IsValid(player)) continue
		
		try{
			if(player.p.isSpectating)
			{
				player.SetPlayerNetInt( "spectatorTargetCount", 0 )
				player.p.isSpectating = false
				player.SetSpecReplayDelay( 0 )
				player.SetObserverTarget( null )
				player.StopObserverMode()
				Remote_CallFunction_ByRef( player, "ServerCallback_KillReplayHud_Deactivate" )
				//Remote_CallFunction_NonReplay(player, "ServerCallback_KillReplayHud_Deactivate")
				player.MakeVisible()
				player.ClearInvulnerable()
				player.SetTakeDamageType( DAMAGE_YES )
			}
		}catch(e420){}
		
		if(isPlayerInWaitingList(player))
		{
			continue
		}

		scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer(player) 	
		
		if( group != null )
		{
			expect scenariosGroupStruct( group )

			if( IsValid( group ) && group.isValid && !group.IsFinished )
			{
				FS_Scenarios_DestroyRingsForGroup(group)		
				group.IsFinished = true //tell solo thread this round has finished
			}
		}
	}
}

vector function FS_ClampToWorldSpace( vector origin )
{
	// temp solution for start positions that are outside the world bounds
	origin.x = clamp( origin.x, -MAX_WORLD_COORD, MAX_WORLD_COORD )
	origin.y = clamp( origin.y, -MAX_WORLD_COORD, MAX_WORLD_COORD )
	origin.z = clamp( origin.z, -MAX_WORLD_COORD, MAX_WORLD_COORD )

	return origin
}

vector function OriginToGround_Inverse( vector origin )
{
	vector startorigin = origin - < 0, 0, 1000 >
	TraceResults traceResult = TraceLine( startorigin, origin + < 0, 0, 128 >, [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )

	return traceResult.endPos
}

#if DEVELOPER
	void function Cafe_KillAllPlayers()
	{
		entity player = gp()[0]
		
		foreach( splayer in gp() )
		{
			if( splayer == player )
				continue
			
			splayer.TakeDamage( 420, null, null, { scriptType = DF_BYPASS_SHIELD | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.deathField } )
		}
	}

	void function Cafe_EndAllRounds()
	{
		FS_Scenarios_ForceAllRoundsToFinish()
	}

	void function Mkos_ForceCloseRecap()
	{
		foreach( player in GetPlayerArray() )
		{
			Remote_CallFunction_UI( player, "UICallback_ForceCloseDeathScreenMenu" )
			ClientCommand_FS_Scenarios_Requeue( player, [] )
		}
	}
#endif


void function FS_Scenarios_SendRecapData( scenariosGroupStruct group ) //mkos
{
	//Cafe
	foreach( player in FS_Scenarios_GetAllPlayersForGroup( group ) )
		ScenariosPersistence_SendStandingsToClient( player ) //lol
}

void function Scenarios_SetWaitingRoomRadius( int radius )
{
	settings.waitingRoomRadius = radius
}

void function FS_Scenarios_SetStopMatchmaking( bool set )
{
	file.scenariosStopMatchmaking = set
}

// void function Scenarios_CleanupMiscProperties( array< array<entity> > allPlayersInRound )
// {
	// foreach( array<entity> playerArrays in allPlayersInRound )
	// {
		// foreach( player in playerArrays )
		// {
			// ClearLastAttacker( player )
			// ...
		// }
	// }
// }

void function FS_Scenarios_OnSquadWipe( entity victim, entity attacker )
{
	FS_Scenarios_UpdatePlayerScore( attacker, FS_ScoreType.BONUS_TEAM_WIPE, victim )
}

void function FS_Scenarios_OnRatEliminated( entity victim, entity attacker )
{
	FS_Scenarios_UpdatePlayerScore( attacker, FS_ScoreType.BONUS_KILLED_SOLO_PLAYER, victim )
}

array<entity> function FS_Scenarios_GetAllPlayersForGroup( scenariosGroupStruct group )
{
	array<entity> players
	foreach( team in group.teams )
	{
		ArrayRemoveInvalid( team.players )
		players.extend( team.players )
	}
	return players
}

int function FS_SortTeamsByLessPlayersAmount( scenariosTeamStruct a, scenariosTeamStruct b )
{
	if ( a.players.len() > b.players.len() )
		return 1
	if ( a.players.len() < b.players.len() )
		return -1

	return 0
}

//This allows us to fill teams one by one instead of all members of one team first by getting the team with less players
scenariosTeamStruct function FS_GetBestTeamToFillForGroup( array<scenariosTeamStruct> teams )
{
	teams.sort( FS_SortTeamsByLessPlayersAmount )
	// printt( "selected a team with less players", teams[0].players.len() )
	return teams[0]
}

LocPair function FS_Scenarios_getWaitingRoomLocation()
{

	return settings.lobbyLocs.getrandom()
}

LocPair function NewLobbyPair(vector origin, vector angles)
{
	LocPair locPair
	locPair.origin = origin
	locPair.angles = angles

	return locPair
}

array<entity> function __GetGroupTeamArrayOfPlayer( entity player )
{
	scenariosGroupStruct ornull group = FS_Scenarios_ReturnGroupForPlayer( player )
	
	array<entity> none
	
	if( group == null )
		return none
	
	expect scenariosGroupStruct( group )
	
	if( !IsValid( group ) || !group.isValid )
		return none
	
	foreach( team in group.teams )
	{
		if( team.players.contains( player ) )
			return team.players
	}
	
	return none
}

void function __RemovePlayerFromActiveGroup( entity player )
{
	array<entity> team = __GetGroupTeamArrayOfPlayer( player )
	
	if( team.contains( player ) )
		team.removebyvalue( player )
	else 
		return
}

void function WaitRespawnTime( entity player, float time )
{
	EndSignal( player, "OnDestroy" )
	
	Remote_CallFunction_Replay( player, "Flowstate_ShowRespawnTimeUI", time )
	wait time
}

void function FS_Scenarios_SetupPanels()
{
	PanelTable panels = 
	{
		[ "#FS_START_REST_TOGGLE" ] 	= null,
		[ "#FS_REST_TOGGLE" ] 			= null,
		//["add another"] = null,
	};
	
	Gamemode1v1_CreatePanels( g_waitingRoomPanelLocation.origin, g_waitingRoomPanelLocation.angles, panels )
	DefinePanelCallbacks( panels )
}

void function DefinePanelCallbacks( PanelTable panels )
{
	// Start in rest setting button
	AddCallback_OnUseEntity
	( 
		panels["#FS_START_REST_TOGGLE"],
		
		void function( entity panel, entity user, int input )
		{
			if ( !IsValid(user) ) 
				return
				
			if( !CheckRate( user ) )
				return 
			
			if ( user.p.start_in_rest_setting == true )
			{
				user.p.start_in_rest_setting = false
				SavePlayerData( user, "start_in_rest_setting", false )
				LocalMsg(user, "#FS_StartInRestDisabled")
			}
			else
			{   
				user.p.start_in_rest_setting = true
				SavePlayerData( user, "start_in_rest_setting", true )
				LocalMsg( user, "#FS_StartInRestEnabled" )
			}
		}
	)
		
	// Rest button
	AddCallback_OnUseEntity
	( 
		panels["#FS_REST_TOGGLE"], 
		
		void function(entity panel, entity user, int input )
		{
			if ( !IsValid( user ) ) 
				return     
				
			FS_Scenarios_ClientCommand_Rest( user, [] )
		}
	)
}

bool function FS_Scenarios_PlayerCanPing( entity player )
{
	if( !IsCurrentState( player, e1v1State.MATCHING ) )
		return false 
		
	return true
}

int function DetermineLowThreshold( int teamAmount, int playersPerTeam )
{
	return teamAmount * playersPerTeam 
}

bool function FS_Scenarios_GetMatchIsEnding()
{
	return file.scenariosStopMatchmaking
}
#if TRACKER
	void function Scenarios_PlayerDataCallbacks() //todo move to convar
	{
		AddCallback_PlayerData( "start_in_rest_setting", UpdateStartInRestSetting )
	}
#endif 