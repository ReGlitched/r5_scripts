global function Olympus_MapInit_Common

#if SERVER
global function Olympus_SetRiftParams
#endif

const float RIFT_INNER_RADIUS = 850.0
const float RIFT_OUTER_RADIUS = 1200.0
const float RIFT_REDUCE_SPEED_INNER = 250.0
const float RIFT_REDUCE_SPEED_OUTER = 500.0
const float RIFT_PULL_SPEED = 1500.0
const float RIFT_SWIRL_ACCEL = 1200.0
const float RIFT_TRIGGER_BOX_SIZE = 350.0

global struct OlympusRiftParams
{
	float innerRadius = RIFT_INNER_RADIUS
	float outerRadius = RIFT_OUTER_RADIUS
	float reduceSpeedInner = RIFT_REDUCE_SPEED_INNER
	float reduceSpeedOuter = RIFT_REDUCE_SPEED_OUTER
	float pullSpeed = RIFT_PULL_SPEED
	float swirlAccel = RIFT_SWIRL_ACCEL
	float triggerBoxSize = RIFT_TRIGGER_BOX_SIZE
}

struct
{
	table< entity, int > riftHandles
	OlympusRiftParams &riftParams
} file

void function Olympus_MapInit_Common()
{
	printf( "%s()", FUNC_NAME() )

	SetVictorySequencePlatformModel( $"mdl/levels_terrain/mp_rr_olympus/floating_victory_platform_01.rmdl", < 0, 0, -10 >, < 0, 0, 0 > )

	if ( MapName() == eMaps.mp_rr_olympus_tt || MapName() == eMaps.mp_rr_olympus_mu1 ){
		PathTT_Init()}

	#if CLIENT
		Freefall_SetPlaneHeight( 12500 )
		Freefall_SetDisplaySeaHeightForLevel( -11500 )
		SetVictorySequenceLocation(<15002.5635, 16763.1055, 2355.54785>, <0, 15.1553955, 0> )
		//SetVictorySequenceEffectPackage( <15002.5635, 16763.1055, 2355.54785>, <0, 105.155, 0>, OLYMPUS_VICTORY_EFFECT )
	#endif

	#if SERVER

		if ( GetCurrentPlaylistVarBool( "olympus_rift_enabled", true ) )
		{
			AddSpawnCallback( "info_target", Rift_Init )
		}
		
		if ( MapName() == eMaps.mp_rr_olympus_tt || MapName() == eMaps.mp_rr_olympus_mu1 )
		{
			InitLootRollers()
		}

		//thread KillPlayersUnderMap_Thread( MAP_KILL_VOLUME_OFFSET_OLYMPUS ) //-28320

		/////////////////////////////////////////////////////////////REMOVE THESE ONCE FIXED/////////////////////////////////////////////////////////////////////////

		AddSpawnCallbackEditorClass( "player_vehicle", "hover_vehicle", EditorSpawnCallbackRemoveEnts )
		//AddSpawnCallbackEditorClass( "prop_dynamic", "script_loot_marvin", EditorSpawnCallbackRemoveEnts )
		AddSpawnCallbackEditorClass( "prop_dynamic", "audio_log_console_03", EditorSpawnCallbackRemoveEnts )
		AddSpawnCallbackEditorClass( "prop_dynamic", "audio_log_console_tunnel", EditorSpawnCallbackRemoveEnts )
		AddSpawnCallbackEditorClass( "prop_dynamic", "script_survival_crafting_harvester", EditorSpawnCallbackRemoveEnts )
		AddSpawnCallbackEditorClass( "prop_dynamic", "script_survival_crafting_workbench_cluster", EditorSpawnCallbackRemoveEnts )//TODO: REMOVE THESE!!!
		AddSpawnCallbackEditorClass( "func_brush", "func_brush_control_wall", EditorSpawnCallbackRemoveEnts )
		InitVehicleARBarriers()
	#endif

	#if SERVER
		AddCallback_EntitiesDidLoad( EntitiesDidLoad )
	#endif

	#if CLIENT
		SetMinimapBackgroundTileImage( $"overviews/mp_rr_canyonlands_bg" )
	#endif
}

#if SERVER
void function EntitiesDidLoad()
{
	#if SERVER && DEVELOPER
		//test_runmapchecks()
	#endif

	// JFS: Create phase runner pings
}

void function EditorSpawnCallbackRemoveEnts( entity ent )
{
	if( !IsValid( ent ) )
		return

	ent.Destroy()//TODO: Remove this function once we get tridents -LorryLeKral
}
#endif



#if SERVER
void function InitVehicleARBarriers()
{
	AddSpawnCallback( "func_brush", void function ( entity brush )
	{
		//printf( "Vehicle AR Barriers - tn:'%s', ec:'%s'", brush.GetTargetName(), GetEditorClass( brush ) )
		if ( brush.GetScriptName() != "vehicle_fence_01" )
			return

		brush.NotSolid()
		brush.Destroy()//TODO: Recover this function once we get tridents -LorryLeKral
	} )
}

///// Olympus rift /////

void function Rift_Init( entity ent )
{
	if ( ent.GetTargetName() != "z4_antigrav" )
		return

	entity trigger = CreateEntity( "trigger_point_gravity" )
	trigger.SetOrigin( ent.GetOrigin() )
	trigger.SetAngles( ent.GetAngles() )
	trigger.SetParams( file.riftParams.innerRadius, file.riftParams.outerRadius, file.riftParams.reduceSpeedInner, file.riftParams.reduceSpeedOuter, file.riftParams.swirlAccel, file.riftParams.pullSpeed )
	trigger.SetEnterCallback( OnEntityEnterRiftTrigger )
	trigger.SetLeaveCallback( OnEntityLeaveRiftTrigger )
	trigger.kv.triggerFilterPlayer = "all"
	trigger.kv.triggerFilterPhaseShift = "any"

	//DebugDrawCylinder( trigger.GetOrigin() , < -90, 0, 0 >, file.riftParams.innerRadius, -trigger.GetAboveHeight(), 255, 90, 0, true, 9999.9 )
	//DebugDrawCylinder( trigger.GetOrigin() , < -90, 0, 0 >, file.riftParams.outerRadius, -trigger.GetBelowHeight(), 0, 255, 0, true, 9999.9 )

	DispatchSpawn( trigger )

	// trigger.SetHasConstantPullStregnth( true )
	// trigger.SetAndEnableTriggerSize( file.riftParams.triggerBoxSize )

	trigger.Enable()
}

void function OnEntityEnterRiftTrigger( entity trigger, entity ent )
{
	printf( "Rift: Entity entered" )

	// PreparePlayerForPositionReset here and in sh_warp_gates.gnut

	if ( IsValid( ent ) ) //&& ent.IsPlayerVehicle() && ent.VehicleGetType() == VEHICLE_FLYING_CAMERA )
		ent.TakeDamage( ent.GetMaxHealth(), svGlobal.worldspawn, svGlobal.worldspawn, { damageSourceId = eDamageSourceId.crushed, scriptType =  DF_BYPASS_SHIELD | DF_SKIPS_DOOMED_STATE }   )

	if ( IsValidPlayer( ent ) )
		GravityAirControl( ent )
}

void function OnEntityLeaveRiftTrigger( entity trigger, entity ent )
{
	printf( "Rift: Entity leaving" )

	if ( IsValidPlayer( ent ) )
		DisableGravityAirControl( ent )
}

void function GravityAirControl( entity player )
{
	//StatusEffect_AddEndless(player, eStatusEffect.in_olympus_rift, 1.0)
	player.SetOrigin( <20000,0,-100>)
	player.kv.airSpeed = 500
	player.kv.airAcceleration = 10000
}

void function DisableGravityAirControl( entity player )
{
	// StatusEffect_Stop(player, eStatusEffect.in_olympus_rift)
	player.kv.airSpeed = player.GetPlayerSettingFloat( "airSpeed" )
	player.kv.airAcceleration = player.GetPlayerSettingFloat( "airAcceleration" )
}

void function Olympus_SetRiftParams( OlympusRiftParams params )
{
	file.riftParams = params
}            
#endif