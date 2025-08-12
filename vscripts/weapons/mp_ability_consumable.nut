global function WeaponDrivenConsumablesEnabled

global function OnWeaponAttemptOffhandSwitch_Consumable
global function OnWeaponActivate_Consumable
global function OnWeaponChargeBegin_Consumable
global function OnWeaponChargeEnd_Consumable
global function OnWeaponPrimaryAttack_Consumable
global function OnWeaponDeactivate_Consumable
global function OnWeaponOwnerChanged_Consumable
global function OnWeaponRaise_Consumable

global function Consumable_Init
global function Consumable_PredictConsumableUse
global function Consumable_IsValidConsumableInfo
global function Consumable_GetConsumableInfo
global function Consumable_CanUseConsumable
global function Consumable_CreatePotentialHealData
#if CLIENT
global function OnCreateChargeEffect_Consumable
global function OnCreateMuzzleFlashEffect_Consumable

global function Consumable_UseItemByType
global function Consumable_UseItemByRef
global function Consumable_UseCurrentSelectedItem
global function Consumable_GetBestConsumableTypeForPlayer
global function Consumable_GetLocalViewPlayerSelectedConsumableType
global function Consumable_SetSelectedConsumableType
global function Consumable_OnSelectedConsumableTypeNetIntChanged
global function Consumable_CancelHeal
global function Consumable_IsCurrentSelectedConsumableTypeUseful

global function Consumable_SetClientTypeOnly
global function AddModAndFireWeapon_Thread
#endif // CLIENT

#if SERVER
global function Consumable_AddCallback_OnPlayerHealingStarted
global function Consumable_AddCallback_OnPlayerHealingEnded

#endif // SERVER
global function GetConsumableInfoFromRef

global function Consumable_IsValidModCommand
global function Consumable_IsHealthItem
global function Consumable_IsShieldItem

global enum eConsumableType
{
	HEALTH_SMALL
	HEALTH_LARGE
	SHIELD_LARGE
	SHIELD_SMALL
	COMBO_FULL

	ULTIMATE
	SND_BOMB
	
	_count
}

const float UNSET_CHARGE_TIME = -1
global struct ConsumableInfo
{
	LootData&           lootData
	float               chargeTime = UNSET_CHARGE_TIME
	string              chargeSoundName = ""
	string              cancelSoundName = ""
	int					healAmount
	int					shieldAmount
	float               ultimateAmount
	float               healTime
	table< int, float > healBonus = {
		[ePassives.PAS_SYRINGE_BONUS] = 0.0,
		[ePassives.PAS_HEALTH_BONUS_MED] = 0.0,
		[ePassives.PAS_HEALTH_BONUS_ALL] = 0.0,
		[ePassives.PAS_BONUS_SMALL_HEAL] = 25.0
	}
	table< int, float > shieldBonus = {
		[ePassives.PAS_BONUS_SMALL_HEAL] = 25.0
	}
	float               healCap = 100

	string modName
}

global struct PotentialHealData
{
	ConsumableInfo &consumableInfo
	int kitType
	int count
	int overHeal
	int overShield

	int possibleHealthAdd
	int possibleShieldAdd

	float healthPerSecond

	int totalOverheal
	int totalAppliedHeal
}

enum eUseConsumableResult
{
	ALLOW,
	DENY_NONE,
	DENY_ULT_FULL,
	DENY_ULT_NOTREADY,
	DENY_HEALTH_FULL,
	DENY_SHIELD_FULL,
	DENY_NO_HEALTH_KIT,
	DENY_NO_SHIELD_KIT,
	DENY_NO_PHOENIX_KIT,
	DENY_NO_KITS,
	DENY_NO_SHIELDS,
	DENY_FULL,
	COUNT,
}

enum eConsumableRecoveryType
{
	HEALTH,
	SHIELDS,
	COMBINED,
	ULTIMATE,
}

struct ConsumablePersistentData
{
	bool useFinished = false
	int  healAmount = 0
	int  healAmountRemaining = 0	// primarily for healTime > 0
	int  healthKitResourceId = 0
	int  shieldStatusHandle = 0
	int  healthStatusHandle = 0
	int  lastMissingHealth = -1
	int  lastMissingShields = -1
	int  lastCurrentHealth = -1

	array<int> statusEffectHandles
}

struct
{
	table< string, int > modNameToConsumableType

	table< int, ConsumableInfo >              consumableTypeToInfo
	table< entity, array<int> >               playerHealResourceIds
	table< entity, ConsumablePersistentData > weaponPersistentData

	array< int > consumableUseOrder = []

	array< void functionref(entity) > Callbacks_OnPlayerHealingStarted
	array< void functionref(entity) > Callbacks_OnPlayerHealingEnded

	bool chargeTimesInitialized = false

	table< entity, float > playerToLastHealChatterTime
	table< entity, float > playerToLastShieldChatterTime

	#if SERVER
		table< entity, string > playerToNextMod
	#endif //SERVER
	#if CLIENT
		string clientPlayerNextMod

		bool healCompletedSuccessfully
		int  clientSelectedConsumableType
		int  healScreenFxHandle
	#endif // CLIENT

} file

global const int OFFHAND_SLOT_FOR_CONSUMABLES = OFFHAND_ANTIRODEO
global const string CONSUMABLE_WEAPON_NAME = "mp_ability_consumable"

const float HEAL_CHATTER_DEBOUNCE = 10.0
const RESTORE_HEALTH_COCKPIT_FX = $"P_heal_loop_screen"
global const vector HEALTH_RGB = < 114, 245, 250 >

//Wattson
const string WATTSON_EXTRA_ULT_ACCEL_SFX = "Wattson_Xtra_A"

// This init isn't with the rest of the weapon init functions in _utility_shared.gnut, because it has to run
// after the init for loot has been run so mods can be associated with the appropriate lootdata.
void function Consumable_Init()
{
	RegisterWeaponForUse( CONSUMABLE_WEAPON_NAME )
	RegisterSignal( "ConsumableDestroyRui" ) // idk really, from S7 or so...
		RegisterSignal( "VCTBlueFX" )

	{ // Phoenix Kit - Full health and shields
		ConsumableInfo phoenixKit
		{
			phoenixKit.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_combo_full" )
			phoenixKit.healAmount = 100
			phoenixKit.shieldAmount = 999
			phoenixKit.chargeSoundName = "PhoenixKit_Charge"
			phoenixKit.cancelSoundName = "shield_battery_failure"
			phoenixKit.modName = "phoenix_kit"
		}
		file.consumableTypeToInfo[ eConsumableType.COMBO_FULL ] <- phoenixKit
	}

	{
		// Large shield cell
		ConsumableInfo shieldLarge
		{
			shieldLarge.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_combo_large" )
			shieldLarge.healAmount = 0
			shieldLarge.shieldAmount = 999
			shieldLarge.healCap = 0.0
			shieldLarge.chargeSoundName = "Shield_Battery_Charge"
			shieldLarge.cancelSoundName = "shield_battery_failure"
			shieldLarge.modName = "shield_large"
		}
		file.consumableTypeToInfo[ eConsumableType.SHIELD_LARGE ] <- shieldLarge
	}

	{
		// Small shield cell
		ConsumableInfo shieldSmall
		{
			shieldSmall.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_combo_small" )
			shieldSmall.healAmount = 0
			shieldSmall.shieldAmount = 25
			shieldSmall.healCap = 0.0
			shieldSmall.chargeSoundName = "Shield_Battery_Charge_Short"
			shieldSmall.cancelSoundName = "shield_battery_failure"
			shieldSmall.modName = "shield_small"
		}
		file.consumableTypeToInfo[ eConsumableType.SHIELD_SMALL ] <- shieldSmall
	}

	{
		// Large health kit
		ConsumableInfo healthLarge
		{
			healthLarge.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_health_large" )
			healthLarge.healAmount = 100
			healthLarge.shieldAmount = 0
			healthLarge.chargeSoundName = "Health_Syringe_Charge"
			healthLarge.cancelSoundName = "Health_Syringe_Failure"
			healthLarge.modName = "health_large"
		}
		file.consumableTypeToInfo[ eConsumableType.HEALTH_LARGE ] <- healthLarge
	}

	{
		// Small health kit
		ConsumableInfo healthSmall
		{
			healthSmall.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_health_small" )
			healthSmall.healAmount = 25
			healthSmall.shieldAmount = 0
			healthSmall.chargeSoundName = "Health_Syringe_Charge_Short"
			healthSmall.cancelSoundName = "Health_Syringe_Failure"
			healthSmall.modName = "health_small"
		}
		file.consumableTypeToInfo[ eConsumableType.HEALTH_SMALL ] <- healthSmall
	}

	{
		// Ultimate battery
		ConsumableInfo ultimateBattery
		{
			ultimateBattery.ultimateAmount = 35.0
			ultimateBattery.healAmount = 0
			ultimateBattery.healTime = 0.0
			ultimateBattery.lootData = SURVIVAL_Loot_GetLootDataByRef( "health_pickup_ultimate" )
			ultimateBattery.chargeSoundName = "Ult_Acc_Charge"
			ultimateBattery.cancelSoundName = ""
			ultimateBattery.modName = "ultimate_battery"
		}
		file.consumableTypeToInfo[ eConsumableType.ULTIMATE ] <- ultimateBattery
	}

	if( Gamemode() == eGamemodes.fs_snd )
	{
		// Bomb
		ConsumableInfo bomb
		{
			bomb.ultimateAmount = 0.0
			bomb.healAmount = 0
			bomb.healTime = 0.0
			bomb.lootData = SURVIVAL_Loot_GetLootDataByRef( "snd_bomb" )
			bomb.chargeSoundName = "Wattson_Xtra_A"
			bomb.cancelSoundName = "ui_lobby_rankchip_disable"//"UI_Networks_Invitation_Canceled"
			bomb.modName = "snd_bomb"
		}
		file.consumableTypeToInfo[ eConsumableType.SND_BOMB ] <- bomb
	}
	
	file.modNameToConsumableType[ "health_small" ] <-        eConsumableType.HEALTH_SMALL
	file.modNameToConsumableType[ "health_large" ] <-        eConsumableType.HEALTH_LARGE
	file.modNameToConsumableType[ "shield_small" ] <-        eConsumableType.SHIELD_SMALL
	file.modNameToConsumableType[ "shield_large" ] <-        eConsumableType.SHIELD_LARGE
	file.modNameToConsumableType[ "phoenix_kit" ] <-        eConsumableType.COMBO_FULL
	file.modNameToConsumableType[ "ultimate_battery" ] <-    eConsumableType.ULTIMATE
	
	if( Gamemode() == eGamemodes.fs_snd )
		file.modNameToConsumableType[ "snd_bomb" ] <-    eConsumableType.SND_BOMB
	
	file.consumableUseOrder.append( eConsumableType.SHIELD_LARGE )
	file.consumableUseOrder.append( eConsumableType.SHIELD_SMALL )
	file.consumableUseOrder.append( eConsumableType.COMBO_FULL )
	file.consumableUseOrder.append( eConsumableType.HEALTH_LARGE )
	file.consumableUseOrder.append( eConsumableType.HEALTH_SMALL )
	if( Gamemode() == eGamemodes.fs_snd )
		file.consumableUseOrder.append( eConsumableType.SND_BOMB )
	
	#if SERVER
		AddCallback_OnClientConnected( OnClientConnected )

		AddClientCommandCallbackNew( "SetSelectedConsumableTypeNetInt", ClientCommand_SetSelectedConsumableTypeNetInt )
		AddClientCommandCallbackNew( "SetNextHealModType", ClientCommand_SetNextHealModType  )

		RegisterSignal( "StartHeal" )
	#endif

	#if CLIENT
		AddCallback_OnPlayerConsumableInventoryChanged( SwitchSelectedConsumableIfEmptyAndPushClientSelectionToServer ) //client authoritative selection

		SetCallback_UseConsumable( Consumable_HandleConsumableUseCommand )
		AddTargetNameCreateCallback( "flowstate_bomb", BombCreated )
		RegisterSignal("OnlyOneBombSound")
	#endif
}


void function OnClientConnected( entity player )
{
	file.playerHealResourceIds[player] <- []

	#if SERVER
	//printt("OnClientConnected SERVER")
	file.playerToNextMod[player] <- "phoenix_kit"
	#endif
}

// =========================================================================================================================
// #     # #######    #    ######  ####### #     #       ####### #     # #     #  #####  ####### ### ####### #     #  #####
// #  #  # #         # #   #     # #     # ##    #       #       #     # ##    # #     #    #     #  #     # ##    # #     #
// #  #  # #        #   #  #     # #     # # #   #       #       #     # # #   # #          #     #  #     # # #   # #
// #  #  # #####   #     # ######  #     # #  #  #       #####   #     # #  #  # #          #     #  #     # #  #  #  #####
// #  #  # #       ####### #       #     # #   # #       #       #     # #   # # #          #     #  #     # #   # #       #
// #  #  # #       #     # #       #     # #    ##       #       #     # #    ## #     #    #     #  #     # #    ## #     #
//  ## ##  ####### #     # #       ####### #     #       #        #####  #     #  #####     #    ### ####### #     #  #####
// =========================================================================================================================

void function TryAddWeaponPersistenceData( entity weapon )
{
	if (!( weapon in file.weaponPersistentData ))
	{
		ConsumablePersistentData data
		file.weaponPersistentData[ weapon ] <- data
	}
}

void function OnWeaponOwnerChanged_Consumable( entity weapon, WeaponOwnerChangedParams changeParams )
{
	entity weaponOwner = weapon.GetOwner()

	if ( !IsValid( changeParams.oldOwner ) )
	{
		#if CLIENT
			if ( weaponOwner == GetLocalViewPlayer() )
		#endif // CLIENT
		{
			TryAddWeaponPersistenceData( weapon )
		}
	}

	file.playerToLastHealChatterTime[ weapon.GetOwner() ] <- Time()
	file.playerToLastShieldChatterTime[ weapon.GetOwner() ] <- Time()

	if ( file.chargeTimesInitialized )
		return

	foreach ( string modName, int consumableType in file.modNameToConsumableType )
	{
		ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
		if ( info.chargeTime == UNSET_CHARGE_TIME )
		{
			#if SERVER
				weapon.SetMods( [ modName ] )
				info.chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
			#endif // SERVER
			#if CLIENT
				if ( weapon.GetOwner() != GetLocalClientPlayer() || !InPrediction() )
					return

				weapon.SetMods( [ modName ] )
				printt( format( "[CONSUMABlE-%s] OnWeaponOwnerChanged_Consumable: Add mod (%s)", weaponOwner.GetPlayerName(), modName ) )
				info.chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
			#endif // CLIENT
		}
	}

	file.chargeTimesInitialized = true
	#if SERVER
		weapon.SetMods( [] )
	#elseif CLIENT
		if( InPrediction()  )
			weapon.SetMods( [] )
	#endif

	printt( format( "[CONSUMABlE-%s] OnWeaponOwnerChanged_Consumable: Remove mods", weaponOwner.GetPlayerName() ) )
}


bool function OnWeaponAttemptOffhandSwitch_Consumable( entity weapon )
{
	string nextMod

	#if SERVER
		if ( ! (weapon.GetOwner() in file.playerToNextMod) )
		{
			printt( format( "[CONSUMABlE-%s] Offhand switch NOT allowed, player not in file's next mod table", weapon.GetOwner().GetPlayerName() ) )
			return false
		}

		nextMod = file.playerToNextMod[ weapon.GetOwner() ]
	#elseif CLIENT
		nextMod = file.clientPlayerNextMod
	#endif

	if ( !CanSwitchToWeapon( weapon, nextMod ) )
	{
		printt( format( "[CONSUMABlE-%s] Offhand switch NOT allowed for nextMod (%s)", weapon.GetOwner().GetPlayerName(), nextMod ) )
		return false
	}


	printt( format( "[CONSUMABlE-%s] Offhand switch allowed for nextMod (%s)", weapon.GetOwner().GetPlayerName(), nextMod ) )
	return true
}


void function OnWeaponActivate_Consumable( entity weapon )
{
	entity weaponOwner = weapon.GetOwner()
	string modName

	TryAddWeaponPersistenceData( weapon )
	#if SERVER
		weaponOwner.p.playerIsPlantingBomb = true
		modName = file.playerToNextMod[ weaponOwner ]
		printt( format( "[CONSUMABlE-%s] Activating consumable (%s)", weaponOwner.GetPlayerName(), modName ) )

		Signal( weaponOwner, "StartHeal" )
		weaponOwner.SetPlayerNetBool( "isHealing", true )

		//Certain player movements are always restricted
		weaponOwner.DisableMantle()



		foreach ( callbackFunc in file.Callbacks_OnPlayerHealingStarted )
		{
			callbackFunc( weaponOwner )
		}

		//Create tracking point of intrest for this heal.
		TrackingVision_CreatePOI( eTrackingVisionNetworkedPOITypes.PLAYER_HEAL, weaponOwner, weaponOwner.GetOrigin(), weaponOwner.GetTeam(), weaponOwner )
	#endif // SERVER

	#if CLIENT
		if ( weapon.GetOwner() != GetLocalViewPlayer() && !IsSpectatorSpectatingPlayer( weapon.GetOwner() ) )
			return
		
		weaponOwner.p.playerIsPlantingBomb = true

		modName = file.clientPlayerNextMod
		printt( format( "[CONSUMABlE] Activating consumable (%s)", modName ) )

		if ( IsSpectator( GetLocalClientPlayer() ) )
		{
			modName = GetConsumableModOnWeapon( weapon )
			Assert( modName != "", "No consumable mod on weapon for pure spectator" )
		}

		// Don't continue if we still have an empty mod name
		if ( modName == "" )
			return

		file.healCompletedSuccessfully = false

		RunUIScript( "CloseAllMenus" )
	#endif // CLIENT

#if CLIENT
	if ( InPrediction() ) //&& weapon.IsPredicted())
#endif
	{
		if ( modName == "phoenix_kit" )
			weapon.SetWeaponSkin( 1 )
		else
			weapon.SetWeaponSkin( 0 )

		weapon.SetScriptTime0( Time() ) // sets heal start time for rui
		weapon.SetMods( [ modName ] )
		printt( format( "[CONSUMABlE-%s] OnWeaponActivate_Consumable: Add mod (%s)", weaponOwner.GetPlayerName(), modName ) )
	}

	ConsumablePersistentData useData
#if CLIENT
	if ( IsSpectatorSpectatingPlayer( weapon.GetOwner() ) && (weapon in file.weaponPersistentData) )
#endif
	{
		useData = file.weaponPersistentData[ weapon ]
		ResetConsumableData( useData )
	}

		if ( GetCurrentPlaylistVarBool( "survival_healthkits_limit_movement", true ) )
		{
			#if CLIENT
					if ( InPrediction() )
			#endif
			{
				if( modName != "ultimate_battery" && !PlayerHasPassive( weaponOwner, ePassives.PAS_SUPPORT ) )
					useData.statusEffectHandles.append( StatusEffect_AddEndless( weaponOwner, eStatusEffect.move_slow, 0.479 ) )
				else if( PlayerHasPassive( weaponOwner, ePassives.PAS_SUPPORT ) || modName == "ultimate_battery" )
					useData.statusEffectHandles.append( StatusEffect_AddEndless( weaponOwner, eStatusEffect.move_slow, 0.183 ) )

				useData.statusEffectHandles.append( StatusEffect_AddEndless( weaponOwner, eStatusEffect.disable_wall_run_and_double_jump, 1.0 ) )
			}
		}

	int consumableType  = file.modNameToConsumableType[ modName ]
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

#if CLIENT
	if ( SURVIVAL_CountItemsInInventory( weapon.GetOwner(), info.lootData.ref ) <= 0 )
	{
		Consumable_CancelHeal( weapon.GetOwner() )
	}
	
	Chroma_ConsumableBegin( weapon, info )
#endif // CLIENT

	#if SERVER
		weaponOwner.SetPlayerNetInt( "healingKitTypeCurrentlyBeingUsed", consumableType )
	#endif

	if ( file.consumableTypeToInfo[ consumableType ].healAmount > 0 )
	{
		if ( (weaponOwner in file.playerToLastHealChatterTime) && Time() - file.playerToLastHealChatterTime[ weaponOwner ] > HEAL_CHATTER_DEBOUNCE )
		{
			#if CLIENT
			if ( !IsSpectatorSpectatingPlayer( weaponOwner ) )
			#endif
			{
			
				file.playerToLastHealChatterTime[ weaponOwner ] <- Time()
				if(modName == "phoenix_kit")
				{
					PlayBattleChatterToSelfOnClientAndTeamOnServer( weaponOwner, "bc_healingPhoenix" )
				}
				else
				{
					PlayBattleChatterToSelfOnClientAndTeamOnServer( weaponOwner, "bc_healing" )
				}
			}
		}
	}
	else if ( file.consumableTypeToInfo[ consumableType ].shieldAmount > 0 )
	{
		if ( (weaponOwner in file.playerToLastHealChatterTime) && Time() - file.playerToLastShieldChatterTime[ weaponOwner ] > HEAL_CHATTER_DEBOUNCE )
		{
		#if CLIENT
			if ( !IsSpectatorSpectatingPlayer( weaponOwner ) )
		#endif
			{
				file.playerToLastShieldChatterTime[ weaponOwner ] <- Time()
				PlayBattleChatterToSelfOnClientAndTeamOnServer( weaponOwner, "bc_usingShieldCell" )
			}
		}
	}

	int consumableRecoveryType = Consumable_GetConsumableRecoveryType( consumableType )

	#if CLIENT
		if ( InPrediction() )
	#endif // CLIENT
	{
		weapon.SetScriptInt0( consumableRecoveryType )
		printt( format( "[CONSUMABlE-%s] Done activating, setting consumable int to %d", weaponOwner.GetPlayerName(), consumableRecoveryType ) )
	}

#if SERVER
	if ( modName == "health_small" || modName == "health_large" )
		EmitSoundOnEntityExceptToPlayer( weaponOwner, weaponOwner, "Health_Syringe_Draw_3p" )
	else if ( modName == "shield_small" || modName == "shield_large" || modName == "phoenix_kit" )
		EmitSoundOnEntityExceptToPlayer( weaponOwner, weaponOwner, "Shield_Battery_Draw_3p" )
	else if ( modName == "ultimate_battery" )
		EmitSoundOnEntityExceptToPlayer( weaponOwner, weaponOwner, "Ult_Acc_Start_3p" )
#endif

	#if CLIENT
		thread Consumable_DisplayProgressBar( weaponOwner, weapon, consumableRecoveryType, modName )
	#endif
}


void function OnWeaponDeactivate_Consumable( entity weapon )
{
	entity weaponOwner = weapon.GetOwner()

	//R5DEV-397243
	if ( !IsValid( weaponOwner ) )
		return

	ConsumablePersistentData useData

	#if SERVER
		string currentMod = GetConsumableModOnWeapon( weapon )
		Assert( currentMod != "", "No consumable mod on weapon" )
		
		weaponOwner.p.playerIsPlantingBomb = false

		if ( currentMod == "health_small" || currentMod == "health_large" )
			StopSoundOnEntity( weaponOwner, "Health_Syringe_Draw_3p" )
		else if ( currentMod == "shield_small" || currentMod == "shield_large" || currentMod == "phoenix_kit" )
			StopSoundOnEntity( weaponOwner, "Shield_Battery_Draw_3p" )
		else if ( currentMod == "ultimate_battery" )
			StopSoundOnEntity( weaponOwner, "Ult_Acc_Start_3p" )
		weaponOwner.SetPlayerNetBool( "isHealing", false )
		weaponOwner.SetPlayerNetInt( "healingKitTypeCurrentlyBeingUsed", -1 )

		useData = file.weaponPersistentData[ weapon ]

		if ( IsValid( weaponOwner ) )
		{
			foreach ( effectHandle in useData.statusEffectHandles )
				StatusEffect_Stop( weaponOwner, effectHandle )

			weaponOwner.EnableMantle()
			if ( useData.shieldStatusHandle != 0 )
				StatusEffect_Stop( weaponOwner, useData.shieldStatusHandle )

			if ( useData.healthStatusHandle != 0 )
				StatusEffect_Stop( weaponOwner, useData.healthStatusHandle )
			
			if ( weaponOwner in file.playerToNextMod )
				printt( format( "[CONSUMABLE-%s] OnWeaponDeactivate, file struct's nextMod is (%s)", weaponOwner.GetPlayerName(), file.playerToNextMod[ weaponOwner ] ) )
		}

		string lootDataRef = ""

		if( currentMod in file.modNameToConsumableType )
		{
			int consumableType = file.modNameToConsumableType[ currentMod ]
			ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
			lootDataRef = info.lootData.ref
		}
		foreach ( callbackFunc in file.Callbacks_OnPlayerHealingEnded )
			callbackFunc( weaponOwner )
	#endif // SERVER

	#if CLIENT
		if ( IsValid( weaponOwner ) && weaponOwner != GetLocalViewPlayer() )
			return
		
		weaponOwner.p.playerIsPlantingBomb = false
		
		Signal( weaponOwner, "ConsumableDestroyRui" )
		Chroma_ConsumableEnd()

		printt( format( "[CONSUMABLE] OnWeaponDeactivate, file struct's nextMod is (%s)", file.clientPlayerNextMod ) )

		if ( !InPrediction() )
			return

		useData = file.weaponPersistentData[ weapon ]

		string currentMod = GetConsumableModOnWeapon( weapon )
		if ( currentMod != "" )
		{
			int consumableType  = file.modNameToConsumableType[ currentMod ]
			ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

			if ( !file.healCompletedSuccessfully && info.cancelSoundName != "" && DoesAliasExist( info.cancelSoundName ) )
			{
				EmitSoundOnEntity( weaponOwner, info.cancelSoundName )
			}
		}
	#endif //CLIENT
}


void function OnWeaponRaise_Consumable( entity weapon )
{
	string modName
	entity weaponOwner = weapon.GetOwner()

	#if SERVER
		modName = file.playerToNextMod[ weaponOwner ]
	#endif // SERVER

	#if CLIENT
		Assert( weaponOwner == GetLocalClientPlayer() )
		Assert( InPrediction() )

		if ( !IsFirstTimePredicted() )
			return

		modName = file.clientPlayerNextMod
	#endif // CLIENT

	printt( format( "[CONSUMABLE-%s] OnWeaponRaise for mod (%s)", weaponOwner.GetPlayerName(), modName ) )

	int consumableType = file.modNameToConsumableType[ modName ]

	if ( modName == "phoenix_kit" )
		weapon.SetWeaponSkin( 1 )
	else
		weapon.SetWeaponSkin( 0 )

	weapon.SetMods( [ modName ] )
	printt( format( "[CONSUMABlE-%s] OnWeaponRaise_Consumable: Add mod (%s)", weaponOwner.GetPlayerName(), modName ) )

	if ( file.consumableTypeToInfo[ consumableType ].ultimateAmount > 0 )
	{
		if ( ShouldPlayUltimateSuperchargedFX( weaponOwner ) )
			weapon.AddMod( "ultimate_battery_supercharged_fx" )
	}
}


#if CLIENT
void function Consumable_DisplayProgressBar( entity player, entity weapon, int consumableRecoveryType, string modName)
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnChargeEnd" )
	player.EndSignal( "ConsumableDestroyRui" )

	string consumableName = weapon.GetWeaponSettingString( eWeaponVar.printname )
	asset hudIcon = weapon.GetWeaponSettingAsset( eWeaponVar.hud_icon )
	float raiseTime = weapon.GetWeaponSettingFloat( eWeaponVar.raise_time )
	if(modName == "snd_bomb")
		raiseTime = 0.4
	float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )

	var rui = CreateCockpitPostFXRui( $"ui/consumable_progress.rpak" )


	if(modName == "snd_bomb")
	{
		chargeTime -= 2
		raiseTime -= 2
		RuiSetGameTime( rui, "healStartTime", Time() )
		RuiSetString( rui, "consumableName", consumableName )
		RuiSetFloat( rui, "raiseTime", raiseTime )
		RuiSetFloat( rui, "chargeTime", chargeTime )
		RuiSetImage( rui, "hudIcon", $"rui/flowstatecustom/bombicon" )
		RuiSetInt( rui, "consumableType", 0 )

		RuiSetString( rui, "hintController", "PRESS %attack% TO STOP PLANTING" )
		RuiSetString( rui, "hintKeyboardMouse", "PRESS %attack% TO STOP PLANTING" )
	}
	else 
	{
		RuiSetGameTime( rui, "healStartTime", Time() )
		RuiSetString( rui, "consumableName", consumableName )
		RuiSetFloat( rui, "raiseTime", raiseTime )
		RuiSetFloat( rui, "chargeTime", chargeTime )
		RuiSetImage( rui, "hudIcon", hudIcon )
		RuiSetInt( rui, "consumableType", consumableRecoveryType )
	}
	
	OnThreadEnd(
		function() : ( rui, player )
		{
			RuiDestroy( rui )
		}
	)

	float startTime = Time()
	float endTime = startTime + raiseTime + chargeTime
	
	while ( Time() < endTime )
	{
		if( chargeTime != weapon.GetWeaponSettingFloat( eWeaponVar.charge_time ) )
		{
			if(modName == "snd_bomb")
				raiseTime = 0.4
			else
				raiseTime = weapon.GetWeaponSettingFloat( eWeaponVar.raise_time )
			
			chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
			endTime = startTime + raiseTime + chargeTime

			RuiSetFloat( rui, "raiseTime", raiseTime )
			RuiSetFloat( rui, "chargeTime", chargeTime )
		}

		wait 0.1
	}
}


void function OnCreateMuzzleFlashEffect_Consumable( entity weapon, int fxHandle )
{
	if ( !IsValid( weapon.GetOwner() ) )
		return

	string modName = GetConsumableModOnWeapon( weapon )

	if ( modName == "health_small" )
		return

	if ( modName == "health_large" )
		return

	int armorTier   = EquipmentSlot_GetEquipmentTier( weapon.GetOwner(), "armor" )
	vector colorVec = GetFXRarityColorForTier( armorTier )

	EffectSetControlPointVector( fxHandle, 2, colorVec )
}

void function OnCreateChargeEffect_Consumable( entity weapon, int fxHandle )
{
	//printt( "Charge effect " + weapon + " " + fxHandle )
	if ( !IsValid( weapon.GetOwner() ) )
		return

	string modName = GetConsumableModOnWeapon( weapon )

	if ( modName == "health_small" )
		return

	if ( modName == "health_large" )
		return
	
	if ( modName == "snd_bomb" )
		return
	
	int armorTier   = EquipmentSlot_GetEquipmentTier( weapon.GetOwner(), "armor" )
	vector colorVec = GetFXRarityColorForTier( armorTier )

	weapon.kv.renderColor = colorVec
	EffectSetControlPointVector( fxHandle, 2, colorVec )
}
#endif // CLIENT

//true or false based on if you're allowed to charge
bool function OnWeaponChargeBegin_Consumable( entity weapon )
{
	string currentMod = GetConsumableModOnWeapon( weapon )
	if( currentMod == "" )
	{
		foreach ( string mod in weapon.GetMods() )
		{
			printt( format( "[CONSUMABLE] OnWeaponChargeBegin: No consumable mods on weapon, print current weapon mods: %s", mod ) )
		}
	}

	Assert( currentMod != "", "[CONSUMABlE] No consumable mods on weapon" )
	if ( currentMod == "" )
		return false

	entity player = weapon.GetOwner()

	if ( IsValid( player ) )
		printt( format( "[CONSUMABLE-%s] OnWeaponChargeBegin (%s)", player.GetPlayerName(), currentMod ) )

	Assert( currentMod in file.modNameToConsumableType, "Invalid mod on consumable weapon: " + currentMod )
	if ( !(currentMod in file.modNameToConsumableType) )
		return false

	int consumableType  = file.modNameToConsumableType[ currentMod ]
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

	string itemName = info.lootData.ref

	weapon.SetWeaponChargeFractionForced( 0.0 )

	#if SERVER
		ConsumablePersistentData useData = file.weaponPersistentData[ weapon ]
		
		if(itemName == "snd_bomb")
		{
			player.SetVelocity(Vector(0,0,0))
			player.MovementDisable()
			player.SetMoveSpeedScale(0)
			player.ForceCrouch() 
			thread UseConsumable_Bomb( player, info )			
		}
		else
			thread UseConsumable( player, info, useData )

	#endif // SERVER

	#if CLIENT
		if ( player != GetLocalViewPlayer() || !(InPrediction() && IsFirstTimePredicted()) )
			return true

		if ( info.chargeSoundName != "" && DoesAliasExist( info.chargeSoundName ) )
		{
			EmitSoundOnEntity( player, info.chargeSoundName )
		}

		if ( ShouldPlayUltimateSuperchargedFX( player ) && DoesAliasExist( WATTSON_EXTRA_ULT_ACCEL_SFX ) )
		{
			EmitSoundOnEntity( player, WATTSON_EXTRA_ULT_ACCEL_SFX )
		}

		if ( SURVIVAL_CountItemsInInventory( weapon.GetOwner(), info.lootData.ref ) <= 0 )
		{
			Consumable_CancelHeal( weapon.GetOwner() )
		}
	#endif // CLIENT

	return true

}

void function OnWeaponChargeEnd_Consumable( entity weapon )
{
	string currentMod = GetConsumableModOnWeapon( weapon )
	Assert( currentMod != "", "No consumable mod on weapon" )
	entity player = weapon.GetOwner()

	int consumableType  = file.modNameToConsumableType[ currentMod ]
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
	string itemName     = info.lootData.ref

	float chargeFracAtEnd = weapon.GetWeaponChargeFraction()

	if ( chargeFracAtEnd < 1.0 )
	{
		Signal( player, "OnChargeEnd" )
	}

	#if DEVELOPER
		printt( "chargeFracAtEnd", chargeFracAtEnd )
	#endif

	#if CLIENT
	if ( player != GetLocalViewPlayer() )
		return

	if ( currentMod != "" ) //
	{
		if ( info.chargeSoundName != "" )
		{
			StopSoundOnEntity( player, info.chargeSoundName )
		}

		if ( ShouldPlayUltimateSuperchargedFX( player ) )
		{
			StopSoundOnEntity( player, WATTSON_EXTRA_ULT_ACCEL_SFX )
		}
	}
#endif

	#if SERVER
		ConsumablePersistentData useData = file.weaponPersistentData[ weapon ]

		if ( IsAlive( player ) )
		{
			if ( weapon.GetWeaponChargeFraction() < 1.0 && !useData.useFinished )
			{
				EntityHealResource_Remove( player, useData.healthKitResourceId )
			}
		}
	
		if(itemName == "snd_bomb")
		{
			player.SetMoveSpeedScale(1)
			player.UnforceCrouch()
			player.MovementEnable()
			
			thread function() : (player)
			{
				player.ForceStand()

				WaitFrame()

				if ( IsValid( player ) && IsAlive( player ) )
					player.UnforceStand()
			}()
		}
	#endif // SERVER
}


var function OnWeaponPrimaryAttack_Consumable( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetOwner()

	if ( weapon.GetWeaponChargeFraction() < 1.0 )
		return 0

	string currentMod = GetConsumableModOnWeapon( weapon )

	if ( IsValid( player ) )
		printt( format( "[CONSUMABlE-%s] OnWeaponPrimaryAttack (%s)", player.GetPlayerName(), currentMod ) )

	if ( currentMod == "" )
		return 0

	int consumableType  = file.modNameToConsumableType[ currentMod ]
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

	#if CLIENT
	if ( SURVIVAL_CountItemsInInventory( weapon.GetOwner(), info.lootData.ref ) <= 0 )
	{
		return 1
	}
	#endif

	#if SERVER
		string itemName = info.lootData.ref
		float healAmount = CalculateTotalHealFromItem( player, info )

		PIN_OnPlayerHealed( player, int( min( info.shieldAmount, player.GetShieldHealthMax() - player.GetShieldHealth() ) ), itemName, player, true )
		PIN_OnPlayerHealed( player, int( min( healAmount, player.GetMaxHealth() - player.GetHealth() ) ), itemName, player )

		ConsumablePersistentData useData = file.weaponPersistentData[ weapon ]
		useData.useFinished = true
		UpdateConsumableUse( player, info, useData, true )
		useData.healAmount = int( healAmount )

		if( info.ultimateAmount > 0 )
			UltimatePackUse( player, info )

		if( Gamemode() == eGamemodes.fs_snd && itemName == "snd_bomb" || Gamemode() != eGamemodes.fs_snd )
		{
			int dropAmount = 1
			if ( !PlayerHasPassive( player, ePassives.PAS_INFINITE_HEAL ) )
				SURVIVAL_RemoveFromPlayerInventory( player, itemName, dropAmount )

			LiveAPI_WriteLogUsingDefinedFields( eLiveAPI_EventTypes.inventoryUse,
				[ LiveAPI_GetPlayerIdentityTable( player ), itemName,  dropAmount ],
				[ 3/*player*/,                              4/*item*/, 5/*quantity*/ ]
			)
		}
		
		StatsHook_PlayerUsedResource( player, null, itemName )
		Remote_CallFunction_NonReplay( player, "ServerCallback_RefreshInventory" )
	#endif

	#if CLIENT
		if ( player != GetLocalClientPlayer() )
			return

		file.healCompletedSuccessfully = true

		if ( !IsFirstTimePredicted() )
			return

		bool playerAtFullHealthAndShields = (player.GetHealth() + info.healAmount) >= player.GetMaxHealth() && (player.GetShieldHealth() + info.shieldAmount) >= player.GetShieldHealthMax()
		if ( !playerAtFullHealthAndShields && !IsConsumableTypeUsefulToPlayer( player, file.clientSelectedConsumableType, info.healAmount, info.shieldAmount ) )
		{
			TryUpdateCurrentSelectedConsumableToBest( player, info.healAmount, info.shieldAmount )
		}

		if ( info.healAmount > 0 && (info.shieldAmount == 0 || (player.GetShieldHealth() >= player.GetShieldHealthMax())) )
		{
			Consumable_DoHealScreenFx( player )
		}
		Chroma_ConsumableSucceeded( info )
	#endif

	return 1
}


float function CalculateTotalHealFromItem( entity player, ConsumableInfo info )
{
	if( PlayerHasPassive( player, ePassives.PAS_SYRINGE_BONUS ) )
		return info.healAmount + info.healBonus[ ePassives.PAS_SYRINGE_BONUS ]

	if( PlayerHasPassive( player, ePassives.PAS_HEALTH_BONUS_MED ) )
		return info.healAmount + info.healBonus[ ePassives.PAS_HEALTH_BONUS_MED ]

	if( PlayerHasPassive( player, ePassives.PAS_HEALTH_BONUS_ALL ) )
		return info.healAmount + info.healBonus[ ePassives.PAS_HEALTH_BONUS_ALL ]

	if( PlayerHasPassive( player, ePassives.PAS_BONUS_SMALL_HEAL ) )
		return info.healAmount + info.healBonus[ ePassives.PAS_BONUS_SMALL_HEAL ]
	
	return float( info.healAmount )
}

float function CalculateTotalShieldFromItem( entity player, ConsumableInfo info )
{
	if( Playlist()  == ePlaylists.fs_haloMod_survival )
	{
		float maxShields = min( 200.0, info.shieldAmount )

		if( PlayerHasPassive( player, ePassives.PAS_BONUS_SMALL_HEAL ) )
			maxShields += info.shieldBonus[ ePassives.PAS_BONUS_SMALL_HEAL ]
		
		return maxShields
	}
	
	if( PlayerHasPassive( player, ePassives.PAS_BONUS_SMALL_HEAL ) )
		return info.shieldAmount + info.shieldBonus[ ePassives.PAS_BONUS_SMALL_HEAL ]
	
	return float( info.shieldAmount )
}

ConsumableInfo function GetConsumableInfoFromRef( string ref )
{
	foreach ( int consumableType, ConsumableInfo info in file.consumableTypeToInfo )
	{
		if ( info.lootData.ref == ref )
			return info
	}

	Assert( false, "Unknown ref \"" + ref + "\" used in mp_ability_consumable." )
	unreachable
}
// ============================================================================================================================
//  #####  #       ### ####### #     # #######    ####### #     # #     #  #####  ####### ### ####### #     #  #####
// #     # #        #  #       ##    #    #       #       #     # ##    # #     #    #     #  #     # ##    # #     #
// #       #        #  #       # #   #    #       #       #     # # #   # #          #     #  #     # # #   # #
// #       #        #  #####   #  #  #    #       #####   #     # #  #  # #          #     #  #     # #  #  #  #####
// #       #        #  #       #   # #    #       #       #     # #   # # #          #     #  #     # #   # #       #
// #     # #        #  #       #    ##    #       #       #     # #    ## #     #    #     #  #     # #    ## #     #
//  #####  ####### ### ####### #     #    #       #        #####  #     #  #####     #    ### ####### #     #  #####
// ============================================================================================================================

#if CLIENT

void function Consumable_SetClientTypeOnly()
{
	file.clientSelectedConsumableType = eConsumableType.COMBO_FULL
}

void function Consumable_UseCurrentSelectedItem( entity player )
{
	int selectedPickupType = file.clientSelectedConsumableType
	if ( !Consumable_CanUseConsumable( player, selectedPickupType ) )
	{
		return
		// auto-switch behavior - not using right now
		//selectedPickupType = Consumable_GetBestConsumableTypeForPlayer( player )
		//player.ClientCommand( "SetSelectedConsumableType " + selectedPickupType )
	}

	ConsumableInfo info = file.consumableTypeToInfo[ selectedPickupType ]

	thread AddModAndFireWeapon_Thread( player, info.modName )
}

void function Consumable_UseItemByRef( entity player, string itemName )
{
	ConsumableInfo info = GetConsumableInfoFromRef( itemName )

	thread AddModAndFireWeapon_Thread( player, info.modName )
}

void function Consumable_UseItemByType( entity player, int consumableType )
{
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

	thread AddModAndFireWeapon_Thread( player, info.modName )
}

void function ServerCallback_TryUseConsumable( entity player, int consumableType )
{
	if ( !( consumableType in file.consumableTypeToInfo ) )
		return

	Consumable_UseItemByType( player, consumableType )
}
void function Consumable_HandleConsumableUseCommand( entity player, string consumableCommand )
{
	int consumableType = eConsumableType._count

	if ( consumableCommand == "HEALTH_SMALL" )
		consumableType = eConsumableType.HEALTH_SMALL
	if ( consumableCommand == "HEALTH_LARGE" )
		consumableType = eConsumableType.HEALTH_LARGE
	if ( consumableCommand == "SHIELD_SMALL" )
		consumableType = eConsumableType.SHIELD_SMALL
	if ( consumableCommand == "SHIELD_LARGE" )
		consumableType = eConsumableType.SHIELD_LARGE
	if ( consumableCommand == "PHOENIX_KIT" )
		consumableType = eConsumableType.COMBO_FULL
	if ( consumableCommand == "snd_bomb" )
		consumableType = eConsumableType.CUSTOMPICKUP
	
	if ( consumableType == eConsumableType._count )
		return

	Consumable_UseItemByType( player, consumableType )
}

void function AddModAndFireWeapon_Thread( entity player, string modName )
{
	if ( ! (player == GetLocalClientPlayer() && player == GetLocalViewPlayer()) )
		return

	if ( player.IsBot() )
		return
	int consumableType  = file.modNameToConsumableType[ modName ]
	if ( !Consumable_CanUseConsumable( player, consumableType, true ) )
	{
		printt( format( "[CONSUMABLE] Not allowed to use consumable (%s), not activating offhand weapon", modName ) )
		return
	}

	entity selectedWeapon = player.GetSelectedWeapon( eActiveInventorySlot.mainHand )
	entity activeWeapon = player.GetActiveWeapon( eActiveInventorySlot.mainHand )

	if ( IsValid( selectedWeapon ) && selectedWeapon.GetWeaponClassName() == CONSUMABLE_WEAPON_NAME
			|| IsValid( activeWeapon ) && activeWeapon.GetWeaponClassName() == CONSUMABLE_WEAPON_NAME)
	{
		printt( format( "[CONSUMABLE] Already using consumable, not activating offhand weapon", modName ) )
		return
	}

	entity weapon = player.GetOffhandWeapon( OFFHAND_SLOT_FOR_CONSUMABLES )

	printt( format( "[CONSUMABLE] Activating offhand weapon, mod is %s", modName ) )
	file.clientPlayerNextMod = modName
	player.ClientCommand( "SetNextHealModType " + file.modNameToConsumableType[ modName ] )

	#if DEVELOPER
		printt("AddModAndFireWeapon_Thread", "SetNextHealModType " + modName )
	#endif

	ActivateOffhandWeaponByIndex( OFFHAND_SLOT_FOR_CONSUMABLES )
}

int function Consumable_GetLocalViewPlayerSelectedConsumableType()
{
	return GetSelectedConsumableTypeForPlayer( GetLocalViewPlayer() )
}

int function GetSelectedConsumableTypeForPlayer( entity player )
{
	if ( !IsValid( player ) )
		return eConsumableType.HEALTH_SMALL

	return player.GetPlayerNetInt( "selectedHealthPickupType" )
}

void function Consumable_SetSelectedConsumableType( int type )
{
	// #if DEVELOPER
		// DumpStack()
	// #endif 
	if( GetLocalClientPlayer().GetPlayerNetInt( "selectedHealthPickupType" ) == type ) //player has that consumable equipped already.. Cafe
		return
	
	GetLocalClientPlayer().ClientCommand( "SetSelectedConsumableTypeNetInt " + type )
	file.clientSelectedConsumableType = type
}

void function Consumable_OnSelectedConsumableTypeNetIntChanged( entity player, int oldkitType, int kitType, bool actuallyChanged )
{
	if ( !actuallyChanged )
		return

	if ( player != GetLocalClientPlayer() )
		return

	file.clientSelectedConsumableType = kitType
}

int function Consumable_GetClientSelectedConsumableType( entity player )
{
	if ( player != GetLocalClientPlayer() )
		return -1

	return file.clientSelectedConsumableType
}

void function SwitchSelectedConsumableIfEmptyAndPushClientSelectionToServer( entity player )
{
	if ( player != GetLocalClientPlayer() )
		return

	ConsumableInfo kitInfo = Consumable_GetConsumableInfo( file.clientSelectedConsumableType )

	if ( SURVIVAL_CountItemsInInventory( player, kitInfo.lootData.ref ) == 0 )
	{
		file.clientSelectedConsumableType = Consumable_GetBestConsumableTypeForPlayer( player, 0, 0 )
	}

	Consumable_SetSelectedConsumableType( file.clientSelectedConsumableType )
}

void function TryUpdateCurrentSelectedConsumableToBest( entity player, int addedHealth, int addedShields )
{
	int healthPickupType = file.clientSelectedConsumableType

	if ( healthPickupType == -1 )
		return

	ConsumableInfo kitInfo = Consumable_GetConsumableInfo( healthPickupType )

	if ( SURVIVAL_CountItemsInInventory( player, kitInfo.lootData.ref ) > 0 )
	{
		// keep the current kit, because it heals and I don't have full health
		if ( kitInfo.healAmount > 0 && ((player.GetHealth() + addedHealth) < player.GetMaxHealth()) )
			return

		// keep the current kit because it shields and I don't have full shields
		if ( kitInfo.shieldAmount > 0 && player.GetShieldHealthMax() > 0 && ((player.GetShieldHealth() + addedShields) < player.GetShieldHealthMax()) )
			return
	}

	healthPickupType = Consumable_GetBestConsumableTypeForPlayer( player, addedHealth, addedShields )

	Consumable_SetSelectedConsumableType( healthPickupType )
}

int function Consumable_GetBestConsumableTypeForPlayer( entity player, int addedHealth, int addedShields )
{
	array< PotentialHealData > healthDataArray
	foreach ( int consumableType in file.consumableUseOrder )
	{
		PotentialHealData healData = Consumable_CreatePotentialHealData( player, consumableType, addedHealth, addedShields )
		healthDataArray.append( healData )
	}

	healthDataArray.sort( CompareHealData )

	foreach ( PotentialHealData healData in healthDataArray )
	{
		#if CLIENT
			printt( Localize( healData.consumableInfo.lootData.pickupString ), healData.totalAppliedHeal, healData.healthPerSecond )
		#endif
	}

	foreach ( PotentialHealData healData in healthDataArray )
	{
		if ( healData.count > 0 && IsConsumableTypeUsefulToPlayer( player, healData.kitType, addedHealth, addedShields ) )
		{
			return healData.kitType
		}
	}
	
	// We couldn't find a useful consumable to give, so the best consumable is the one we currently still have selected
	return GetSelectedConsumableTypeForPlayer( player )
}

bool function Consumable_IsCurrentSelectedConsumableTypeUseful()
{
	entity player = GetLocalClientPlayer()

	return IsConsumableTypeUsefulToPlayer( player, file.clientSelectedConsumableType, 0, 0 )
}

bool function IsConsumableTypeUsefulToPlayer( entity player, int consumableType, int addedHealth, int addedShields )
{
	if ( !IsValid( player ) || !IsAlive( player ) )
		return false

	if ( ! (consumableType in file.consumableTypeToInfo) )
		return false

	if ( SURVIVAL_CountItemsInInventory( player, file.consumableTypeToInfo[ GetSelectedConsumableTypeForPlayer( player ) ].lootData.ref ) == 0 )
		return true

	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

	return (info.shieldAmount > 0 && ((player.GetShieldHealth() + addedShields) < player.GetShieldHealthMax())) || (info.healAmount > 0 && ((player.GetHealth() + addedHealth) < player.GetMaxHealth()))
}

void function Consumable_DoHealScreenFx( entity player )
{
	thread DoHealScreenFx( player )
}

void function DoHealScreenFx( entity player )
{
	EndSignal( player, "OnDeath" )
	EndSignal( player, "OnDestroy" )

	if ( player != GetLocalViewPlayer() )
		return

	entity cockpit = player.GetCockpit()
	if ( !IsValid( cockpit ) )
		return

	if ( EffectDoesExist( file.healScreenFxHandle ) )
		return

	int fxID = GetParticleSystemIndex( RESTORE_HEALTH_COCKPIT_FX )
	file.healScreenFxHandle = StartParticleEffectOnEntity( cockpit, fxID, FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	EffectSetIsWithCockpit( file.healScreenFxHandle, true )

	OnThreadEnd( function() {
		if ( EffectDoesExist( file.healScreenFxHandle ) )
			EffectStop( file.healScreenFxHandle, false, true )
	} )

	WaitFrame()
}

void function PlayConsumableUseChroma( entity weapon, ConsumableInfo info )
{
	EndSignal( weapon.GetOwner(), "EndChroma" )

	float raiseTime = weapon.GetWeaponSettingFloat( eWeaponVar.raise_time )
	float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )

	Chroma_ConsumableBegin( weapon, info )

	OnThreadEnd(
		function() : ()
		{
			Chroma_ConsumableEnd()
		}
	)

	wait raiseTime + chargeTime

}

void function Consumable_CancelHeal( entity player )
{
	if ( player.GetActiveWeapon( eActiveInventorySlot.mainHand ).GetWeaponClassName() != CONSUMABLE_WEAPON_NAME )
		return

	player.ClientCommand( "invnext" )
}

bool function PlayerHasHealthKits( entity player )
{
	foreach ( int type, ConsumableInfo info in file.consumableTypeToInfo )
	{
		if ( info.healAmount > 0 )
		{
			if ( SURVIVAL_CountItemsInInventory( player, info.lootData.ref ) > 0 )
			{
				return true
			}
		}
	}

	return false
}

bool function PlayerHasShieldKits( entity player )
{
	foreach ( int type, ConsumableInfo info in file.consumableTypeToInfo )
	{
		if ( info.shieldAmount > 0 )
		{
			if ( SURVIVAL_CountItemsInInventory( player, info.lootData.ref ) > 0 )
			{
				return true
			}
		}
	}

	return false
}

string function GetCanUseResultString( int consumableUseActionResult )
{
	switch ( consumableUseActionResult )
	{
		case eUseConsumableResult.ALLOW:
		case eUseConsumableResult.DENY_NONE:
			return ""

		case eUseConsumableResult.DENY_ULT_FULL:
			return "#DENY_ULT_FULL"

		case eUseConsumableResult.DENY_ULT_NOTREADY:
			return "#DENY_ULT_NOTREADY"

		case eUseConsumableResult.DENY_HEALTH_FULL:
			return "#DENY_HEALTH_FULL"

		case eUseConsumableResult.DENY_SHIELD_FULL:
			return "#DENY_SHIELD_FULL"

		case eUseConsumableResult.DENY_NO_HEALTH_KIT:
			return "#DENY_NO_HEALTH_KIT"

		case eUseConsumableResult.DENY_NO_SHIELD_KIT:
			return "#DENY_NO_SHIELD_KIT"

		case eUseConsumableResult.DENY_NO_PHOENIX_KIT:
			return "#DENY_NO_PHOENIX_KIT"

		case eUseConsumableResult.DENY_NO_KITS:
			return "#DENY_NO_KITS"

		case eUseConsumableResult.DENY_NO_SHIELDS:
			return "#DENY_NO_SHIELDS"

		case eUseConsumableResult.DENY_FULL:
			return "#DENY_FULL"
		default:
			return ""
	}

	unreachable
}
#endif // CLIENT

// ================================================================================================================================
//  #####  ####### ######  #     # ####### ######     ####### #     # #     #  #####  ####### ### ####### #     #  #####
// #     # #       #     # #     # #       #     #    #       #     # ##    # #     #    #     #  #     # ##    # #     #
// #       #       #     # #     # #       #     #    #       #     # # #   # #          #     #  #     # # #   # #
//  #####  #####   ######  #     # #####   ######     #####   #     # #  #  # #          #     #  #     # #  #  #  #####
//       # #       #   #    #   #  #       #   #      #       #     # #   # # #          #     #  #     # #   # #       #
// #     # #       #    #    # #   #       #    #     #       #     # #    ## #     #    #     #  #     # #    ## #     #
//  #####  ####### #     #    #    ####### #     #    #        #####  #     #  #####     #    ### ####### #     #  #####
// ================================================================================================================================

#if SERVER
void function UseConsumable( entity player, ConsumableInfo info, ConsumablePersistentData useData )
{
	EndSignal( player, "OnChargeEnd" )
	EndSignal( player, "OnDisconnected" )
	EndSignal( player, "OnDestroy" )

	string itemName = info.lootData.ref

	float delayScale
	if ( PlayerHasPassive( player, ePassives.PAS_FAST_HEAL ) )
		delayScale = 0.5
	else
		delayScale = 1.0
	float delayTime = ( info.chargeTime * delayScale )


	float endTime = Time() + delayTime - 0.01 	// Accounting for float math issues to make sure it's always the same amount of ticks
	while ( Time() < endTime )
	{
		UpdateConsumableUse( player, info, useData, info.healTime > 0.0 )
		WaitFrame()
	}
}


void function UpdateConsumableUse( entity player, ConsumableInfo info, ConsumablePersistentData useData, bool allowApply )
{
	if ( !IsAlive( player ) )
		return

	int currentHealth   = player.GetHealth()
	int healthMax       = player.GetMaxHealth()
	int currentShields  = player.GetShieldHealth()
	int shieldHealthMax = player.GetShieldHealthMax()

	int resourceHealthRemaining = EntityHealResource_GetRemainingTotal( player )
	int virtualHealth           = minint( currentHealth + resourceHealthRemaining, healthMax )
	int missingHealth           = healthMax - virtualHealth
	int missingShields          = shieldHealthMax - currentShields

	//int virtualShields		= minint ( StatusEffect_GetSeverity( player, eStatusEffect.target_shields ) * float ( shieldHealthMax ) ) - float ( currentShields )

	// TODO: These don't play nice with healTime > 0, should probaby move out unless we want heal amounts to change while using the consumable
	float healAmount   = CalculateTotalHealFromItem( player, info )
	float shieldAmount = CalculateTotalShieldFromItem( player, info )

	bool shouldUpdateHealth  = missingHealth != useData.lastMissingHealth
	bool shouldUpdateShields = missingShields != useData.lastMissingShields

	if ( healAmount > 0 )
	{
		int healthToApply = minint( int( healAmount ), missingHealth )
		Assert( virtualHealth + healthToApply <= healthMax, "Bad math: " + virtualHealth + " + " + healthToApply + " > max health of  " + healthMax )

		if ( healthToApply != 0 )
		{
			if ( useData.useFinished )
			{
				//Cafe check if item still exists
				if( SURVIVAL_CountItemsInInventory( player, info.lootData.ref ) == 0 )
					return
				
				StatusEffect_Stop( player, useData.healthStatusHandle )
				if ( info.healTime == 0 )
				{
					if ( allowApply )
					{
						player.SetHealth( minint( currentHealth + healthToApply, player.GetMaxHealth() ) )
					}
				}
				else
				{
					float healTime      = info.healTime
					float healAmountCpy = healAmount
					float HPS           = healAmount / healTime
					if ( resourceHealthRemaining > 0 )
					{
						foreach ( resourceId in file.playerHealResourceIds[player] )
						{
							EntityHealResource_Remove( player, resourceId )
						}

						healAmountCpy += float( resourceHealthRemaining )
						healTime += resourceHealthRemaining / healTime
					}

					useData.healthKitResourceId = EntityHealResource_Add( player, healTime, (healAmountCpy / healTime), 0.0, info.lootData.ref, player )
					file.playerHealResourceIds[player].append( useData.healthKitResourceId )
				}
			}
			else if ( shouldUpdateHealth )
			{
				StatusEffect_Stop( player, useData.healthStatusHandle )
				useData.healthStatusHandle = StatusEffect_AddEndless( player, eStatusEffect.target_health, (healthToApply + resourceHealthRemaining) / float(healthMax) )
			}
		}
	}

	if ( shieldAmount > 0 )
	{
		if ( allowApply )
		{
			if ( useData.useFinished )
			{
				//Cafe check if item still exists
				if( SURVIVAL_CountItemsInInventory( player, info.lootData.ref ) == 0 )
					return
				
				if ( info.healTime > 0 )
				{
					if ( useData.healAmountRemaining > 0  )
						player.SetShieldHealth( minint( player.GetShieldHealth() + useData.healAmountRemaining, shieldHealthMax ) )
				}
				else
				{
					player.SetShieldHealth( minint( int( player.GetShieldHealth() + shieldAmount ), shieldHealthMax ) )
				}
			}
			else if ( info.healTime > 0 )
			{
				int shieldAmountThisFrame = minint( int ( ( shieldAmount / info.healTime ) * 0.1 ), useData.healAmountRemaining )
				player.SetShieldHealth( minint( player.GetShieldHealth() + shieldAmountThisFrame, shieldHealthMax ) )
				useData.healAmount += shieldAmountThisFrame
				useData.healAmountRemaining -= shieldAmountThisFrame
			}
		}

		if ( shouldUpdateShields )
		{
			StatusEffect_Stop( player, useData.shieldStatusHandle )
			float targetShields = 0
			if ( shieldHealthMax > 0 )
				targetShields = shieldAmount / float( shieldHealthMax )
			useData.shieldStatusHandle = StatusEffect_AddEndless( player, eStatusEffect.target_shields, targetShields )
		}
	}


	useData.lastMissingHealth = missingHealth
	useData.lastMissingShields = missingShields
	useData.lastCurrentHealth = currentHealth
}

int function EntityHealResource_GetRemainingTotal( entity player )
{
	array<int> activeHealResourceIds
	int totalRemaining

	foreach ( healResourceId in file.playerHealResourceIds[player] )
	{
		int remaining = EntityHealResource_GetRemainingHeals( player, healResourceId )
		if ( remaining <= 0 )
			continue

		activeHealResourceIds.append( healResourceId )
		totalRemaining = remaining
	}

	return totalRemaining
}

void function UltimatePackUse( entity player, ConsumableInfo info )
{
	entity ultimateAbility = player.GetOffhandWeapon( OFFHAND_INVENTORY )
	int ammo = ultimateAbility.GetWeaponPrimaryClipCount()
	int maxAmmo = ultimateAbility.GetWeaponPrimaryClipCountMax()
	ammo += int( maxAmmo * (info.ultimateAmount/100) )

	if( ammo < maxAmmo )
		ultimateAbility.SetWeaponPrimaryClipCount( ammo )
	else
		ultimateAbility.SetWeaponPrimaryClipCount( maxAmmo )
	// Gives Wattson full ult on ult accel
	if( PlayerHasPassive( player, ePassives.PAS_BATTERY_POWERED )) {
		ultimateAbility.SetWeaponPrimaryClipCount( maxAmmo )
	}
}


void function ClientCommand_SetNextHealModType( entity player, array<string> args )
{
	if ( args.len() == 0 )
		return

	int nextModType = int( args[0] )

	if( !( nextModType in file.consumableTypeToInfo ) )
		return

	string nextModName = file.consumableTypeToInfo[ nextModType ].modName

	#if DEVELOPER
		printt( format( "[CONSUMABLE] Setting Next Heal Mod Type for player %s to %s", player.GetPlayerName(), nextModName ) )
	#endif 
	
	file.playerToNextMod[ player ] <- nextModName}

void function ClientCommand_SetSelectedConsumableTypeNetInt( entity player, array<string> args )
{
	if ( args.len() == 0 )
		return

	int consumableType = int( args[0] )

	SetSelectedConsumableTypeNetInt( player, consumableType )
}

void function SetSelectedConsumableTypeNetInt( entity player, int consumableType )
{
	Warning( "SetSelectedConsumableTypeNetInt " + player + " " + consumableType )
	switch( consumableType )
	{
		case eConsumableType.COMBO_FULL:
		case eConsumableType.SHIELD_LARGE:
		case eConsumableType.SHIELD_SMALL:
		case eConsumableType.HEALTH_LARGE:
		case eConsumableType.HEALTH_SMALL:
		case eConsumableType.SND_BOMB:
			player.SetPlayerNetInt( "selectedHealthPickupType", consumableType )
			return

		default:
			Assert( 0, "tried to set an unsupported Consumable Type" )
			return
	}
}

void function Consumable_AddCallback_OnPlayerHealingStarted( void functionref(entity) callbackFunc )
{
	Assert( !file.Callbacks_OnPlayerHealingStarted.contains( callbackFunc ), "Already added " + string( callbackFunc ) + " with Consumable_AddCallback_OnPlayerHealingStarted" )
	file.Callbacks_OnPlayerHealingStarted.append( callbackFunc )
}

void function Consumable_AddCallback_OnPlayerHealingEnded( void functionref(entity) callbackFunc )
{
	Assert( !file.Callbacks_OnPlayerHealingEnded.contains( callbackFunc ), "Already added " + string( callbackFunc ) + " with Consumable_AddCallback_OnPlayerHealingStarted" )
	file.Callbacks_OnPlayerHealingEnded.append( callbackFunc )
}

#endif // SERVER

bool function Consumable_IsValidModCommand( entity player, entity weapon, string mod, bool isAdd )
{
	if ( weapon.GetWeaponClassName() != CONSUMABLE_WEAPON_NAME )
		return false

	if ( ! ( mod in file.modNameToConsumableType ) )
		return false

	if ( isAdd )
	{
		if ( !Consumable_CanUseConsumable( player, file.modNameToConsumableType[ mod ], false ) )
			return false
	}

	return true
}
void function UseConsumable_Bomb( entity player, ConsumableInfo info )//, ConsumablePersistentData useData )
{
	if( !IsValid(player) || player.GetTeam() != Sh_GetAttackerTeam() || GetGameState() != eGameState.Playing ) return
	
	if( Gamemode() == eGamemodes.fs_snd )
		PlayBattleChatterToSelfOnClientAndTeamOnServer( player,"bc_super" )

	#if SERVER
	EndSignal( player, "OnDeath" )
	EndSignal( player, "OnChargeEnd" )

	string itemName = info.lootData.ref

	float delayScale = 1.0
	float delayTime = ( info.chargeTime * delayScale )

	float endTime = Time() + delayTime
	
	while ( Time() < endTime )
		WaitFrame()

	if( !IsValid(player) || player.GetTeam() != Sh_GetAttackerTeam() || GetGameState() != eGameState.Playing ) return
	
	player.SetPlayerNetInt("planted", player.GetPlayerNetInt("planted") + 1 )
	player.p.playerHasBomb = false

	entity bomb = CreatePropDynamic($"mdl/Weapons/bomb/w_bomb.rmdl", player.GetOrigin() + Vector(0,0,2), Vector(0,0,0))

	if(!IsValid(bomb)) return
	
	// foreach( sPlayer in GetPlayerArray() )
	// {
		// if(!IsValid(sPlayer)) continue
	
		// Message(sPlayer, "Bomb planted", "Exploding in " + EXPLODE_BOMB_TIME.tostring() + " seconds")
	// }

	foreach ( entity sPlayer in GetPlayerArrayOfTeam(Sh_GetDefenderTeam()) )
	{
		thread function() : (sPlayer)
		{
			wait 1
			if(!IsValid(sPlayer)) return
			
			Remote_CallFunction_NonReplay( sPlayer, "SND_HintCatalog", 10, 0)
		}()
	}
	
	foreach ( sPlayer in GetPlayerArrayOfTeam(Sh_GetAttackerTeam()) )
	{
		if(!IsValid(sPlayer)) continue
		
		int moneytoGive = SCORE_BOMBPLANTED_REWARD
		sPlayer.p.availableMoney += moneytoGive
		Remote_CallFunction_NonReplay( sPlayer, "ServerCallback_OnMoneyAdded",moneytoGive )
		// Remote_CallFunction_NonReplay( sPlayer, "SND_HintCatalog", 9, moneytoGive)
		AddPlayerScore( sPlayer, "FS_SND_BombPlanted", sPlayer, "", moneytoGive)
	}
	
	bomb.SetOwner( player )
	bomb.kv.fadedist = 99999
	// EmitSoundOnEntity(bomb, "HUD_MP_BountyHunt_BankBonusPts_Deposit_End_Successful_3P")

	thread HandleBombExplosion(bomb)
	
	if( IsValid( GetPlantedBombEntity() ) )
		GetPlantedBombEntity().Destroy()
	
	SetPlantedBombEntity(bomb)
	SetBombState(bombState.ONGROUND_PLANTED)
	
	SetTargetName(bomb, "flowstate_bomb")
	bomb.SetUsable()
	bomb.AddUsableValue( USABLE_CUSTOM_HINTS | USABLE_BY_OWNER | USABLE_BY_PILOTS | USABLE_BY_ENEMIES )
	bomb.SetUsableValue( USABLE_BY_ALL | USABLE_CUSTOM_HINTS )
	bomb.SetUsePrompts( "Press %use%to defuse the bomb", "Press %use% to defuse the bomb" )
	
	Highlight_SetNeutralHighlight( bomb, "sp_objective_entity" )

	SetCallback_CanUseEntityCallback( bomb, Bomb_CanUse )
	AddCallback_OnUseEntity( bomb, Bomb_OnUse )

	thread function() : (player)
	{
		player.ForceStand()
		WaitFrame()
		if ( IsValid( player ) && IsAlive( player ) )
			player.UnforceStand()
	}()
	#endif
}

#if SERVER
void function HandleBombExplosion(entity bomb)
{
	EndSignal(bomb, "OnDestroy")

	float endTime = Time() + EXPLODE_BOMB_TIME
	
	foreach ( player in GetPlayerArray() )
	{
		if(!IsValid(player)) continue
		
		Remote_CallFunction_Replay( player, "ServerCallback_OnBombPlantedInGameHint", bomb, endTime)
	}
	
	// if( endTime >= GetRoundEndTime() )
		UpdateRoundEndTime( endTime + 1 ) // just adding a bit of extra time to guarantee the bomb to explode or being defused (time won't ran over)
	
	while( Time() < endTime && IsValid(bomb) )
		WaitFrame()
	
	if(!IsValid(bomb) || GetGameState() != eGameState.Playing ) return
	
	SetBombState( bombState.ONGROUND_EXPLODED )
	
	foreach ( player in GetPlayerArrayOfTeam( Sh_GetAttackerTeam() ) )
	{
		if(!IsValid(player)) continue
		
		player.p.availableMoney += 3500
		Remote_CallFunction_NonReplay(player, "ServerCallback_OnMoneyAdded", 3500)
	}
	
	StartParticleEffectInWorld( PrecacheParticleSystem( $"P_xo_exp_nuke_3P" ), bomb.GetOrigin(), <0,0,0> )
	EmitSoundAtPosition( TEAM_UNASSIGNED, bomb.GetOrigin(), "bangalore_ultimate_explosion_concrete" )
	
	foreach ( player in GetPlayerArray_Alive() )
	{
		if(!IsValid(player)) continue
		
		float playerDist = Distance2D( player.GetOrigin(), bomb.GetOrigin() )
		if ( playerDist <= 700 )
		{
			entity attacker
			
			if( IsValid(bomb.GetOwner()) && IsAlive(bomb.GetOwner()) )
				attacker = bomb.GetOwner()
			else
				attacker = null
			
			player.TakeDamage( player.GetMaxHealth() + 1, attacker, attacker, { damageSourceId = eDamageSourceId.snd_bomb, scriptType=DF_BYPASS_SHIELD } )
		}
	}
	
	bomb.Destroy()
}

#endif

#if CLIENT
void function HandleBombSound(entity bomb)
{
	EndSignal(bomb, "OnDestroy")

	Signal(GetLocalClientPlayer(), "OnlyOneBombSound")
	EndSignal(GetLocalClientPlayer(), "OnlyOneBombSound")
	
	// P_thermite_spark
	// P_thermite_igniter_dlight_FP
	
	float startTime = Time()
	float endTime = Time() + EXPLODE_BOMB_TIME
	string soundtoplay = "HUD_match_start_timer_tick_1P" 
	float waittime
	float timePercentage
	
	while( Time() < endTime && IsValid(bomb) ) //sorry for this it was a desperate action
	{
		if(endTime - Time() <= 2)
		{
			// soundtoplay = "ui_ingame_markedfordeath_countdowntoyouaremarked"
			// EmitSoundOnEntity( bomb, soundtoplay )
			// wait 2
			// break
			waittime = 0.05
		}
		else if(endTime - Time() <= 5)
		{
			waittime = 0.1
		}
		else if(endTime - Time() <= 10)
		{
			waittime = 0.2
		}
		else if(endTime - Time() <= 15)
		{
			waittime = 0.4
		}
		else if(endTime - Time() <= 20)
		{
			waittime = 0.7
		}
		else
		{
			waittime = 1
		}
		
		//lerp will update waittime each second, do we want that?
		
		// timePercentage = (Time() - startTime) / ((endTime+5) - Time())	
		// waittime = LerpFloat( 1, 0.15, timePercentage )
		
		StopSoundOnEntity( bomb, soundtoplay )
		EmitSoundOnEntity( bomb, soundtoplay )
		wait waittime
	}
}

void function BombCreated( entity ent )
{
	SetCallback_CanUseEntityCallback( ent, Bomb_CanUse )
	AddCallback_OnUseEntity( ent, Bomb_OnUse )
	
	thread HandleBombSound(ent)
}
#endif

bool function Bomb_CanUse( entity player, entity bomb)
{
	if(!IsValid(player) || !IsValid(bomb)) return false
	#if SERVER
		player.Server_TurnOffhandWeaponsDisabledOff()
	#endif
	if ( player.GetWeaponDisableFlags() == WEAPON_DISABLE_FLAGS_ALL )
		return false
	
	if ( player.GetTeam() == Sh_GetAttackerTeam() )
		return false
	
	return true
}

void function Bomb_OnUse( entity bomb, entity player, int useInputFlags )
{
	if ( !(useInputFlags & USE_INPUT_LONG ) )
		return

	#if CLIENT
	HidePlayerHint( "Press %use% to defuse the bomb" )
	#endif

	ExtendedUseSettings settings
	settings.successSound = "UI_InGame_HalftimeText_Enter"
	#if CLIENT
		settings.loopSound = "HUD_MP_BountyHunt_BankBonusPts_Ticker_Loop_1P"
		settings.displayRui = $"ui/consumable_progress.rpak"
		settings.displayRuiFunc = DisplayRuiForBomb
		settings.icon = $"rui/flowstatecustom/bombicon"
		settings.hint = "Defusing Bomb"
	#elseif SERVER
		//settings.startFunc = RespawnBeaconStartUse
		//settings.endFunc = RespawnBeaconStopUse
		settings.successFunc = BombDefused
		settings.exclusiveUse = true
		settings.movementDisable = true
		settings.holsterWeapon = true
		#endif
	settings.duration = DEFUSE_BOMB_TIME
	settings.useInputFlag = IN_USE_LONG
	
	#if SERVER
		if( Gamemode() == eGamemodes.fs_snd )
		{
			Highlight_SetFriendlyHighlight( player, "hackers_wallhack" )
		}
	#endif
	
	thread ExtendedUse( bomb, player, settings )
	
}

#if CLIENT
void function DisplayRuiForBomb( entity ent, entity player, var rui, ExtendedUseSettings settings )
{
	DisplayRuiForBomb_Internal( rui, settings.icon, Time(), Time() + settings.duration, settings.hint )
}

void function DisplayRuiForBomb_Internal( var rui, asset icon, float startTime, float endTime, string hint )
{
	RuiSetGameTime( rui, "healStartTime", Time() )
	RuiSetString( rui, "consumableName", "Defusing bomb" )
	RuiSetFloat( rui, "raiseTime", 0 )
	RuiSetFloat( rui, "chargeTime", endTime - Time() )
	RuiSetImage( rui, "hudIcon", $"rui/flowstatecustom/bombicon" )
	RuiSetInt( rui, "consumableType", 0 )

	RuiSetString( rui, "hintController", "" )
	RuiSetString( rui, "hintKeyboardMouse", "" )
}
#endif

void function BombDefused( entity bomb, entity player, ExtendedUseSettings settings )
{
	//player has bomb?
	#if CLIENT
	Signal(GetLocalClientPlayer(), "OnlyOneBombSound")
	#endif
	
	#if SERVER
	foreach ( sPlayer in GetPlayerArrayOfTeam(Sh_GetDefenderTeam()) )
	{
		if(!IsValid(sPlayer)) continue
		
		sPlayer.p.availableMoney += 3500
		Remote_CallFunction_NonReplay(sPlayer, "ServerCallback_OnMoneyAdded", 3500)
	}
	
	SetPlantedBombEntity(null)
	SetBombState(bombState.ONGROUND_DEFUSED)
	bomb.Destroy()
	player.SetPlayerNetInt("defused", player.GetPlayerNetInt("defused") + 1 )
	//Message(player, "You've defused the bomb", "Poggers")
	#endif
}


// ======================================================================================================================
//  #####  #     #    #    ######  ####### ######     ####### #     # #     #  #####  ####### ### ####### #     #  #####
// #     # #     #   # #   #     # #       #     #    #       #     # ##    # #     #    #     #  #     # ##    # #     #
// #       #     #  #   #  #     # #       #     #    #       #     # # #   # #          #     #  #     # # #   # #
//  #####  ####### #     # ######  #####   #     #    #####   #     # #  #  # #          #     #  #     # #  #  #  #####
//       # #     # ####### #   #   #       #     #    #       #     # #   # # #          #     #  #     # #   # #       #
// #     # #     # #     # #    #  #       #     #    #       #     # #    ## #     #    #     #  #     # #    ## #     #
//  #####  #     # #     # #     # ####### ######     #        #####  #     #  #####     #    ### ####### #     #  #####
// ======================================================================================================================

bool function Consumable_IsValidConsumableInfo( int consumableType )
{
	return (consumableType in file.consumableTypeToInfo)
}


ConsumableInfo function Consumable_GetConsumableInfo( int consumableType )
{
	Assert( consumableType in file.consumableTypeToInfo, "Invalid ConsumableType \"" + consumableType + "\" not present in table." )

	return file.consumableTypeToInfo[ consumableType ]
}


PotentialHealData function Consumable_CreatePotentialHealData( entity player, int consumableType, int addedHealth = 0, int addedShields = 0 )
{
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
	string itemName     = info.lootData.ref

	PotentialHealData healData
	healData.kitType = consumableType
	healData.count = SURVIVAL_CountItemsInInventory( player, itemName )

	healData.possibleHealthAdd = info.healAmount
	healData.possibleShieldAdd = info.shieldAmount

	int health = player.GetHealth() + addedHealth
	int shields = player.GetShieldHealth() + addedShields
	health = minint( health, player.GetMaxHealth() )
	shields = minint( shields, player.GetShieldHealthMax() )

	int missingHealth  = player.GetMaxHealth() - health
	int missingShields = player.GetShieldHealthMax() - shields

	missingHealth = maxint( 0, missingHealth )
	missingShields = maxint( 0, missingShields )


	healData.consumableInfo = clone info

	int appliedHeal = minint( missingHealth, info.healAmount)
	healData.overHeal = maxint( info.healAmount - missingHealth, 0 )

	int appliedShields = minint( missingShields, info.shieldAmount)
	healData.overShield = maxint( info.shieldAmount  - missingShields, 0 )
	
	healData.totalAppliedHeal = appliedHeal + appliedShields
	healData.totalOverheal = (healData.overHeal + healData.overShield)

	healData.healthPerSecond = healData.totalAppliedHeal / info.chargeTime


	return healData
}


int function CompareHealData( PotentialHealData a, PotentialHealData b )
{
		///SORT SHIELDS
		if ( a.possibleShieldAdd > 0 && a.totalAppliedHeal == b.totalAppliedHeal && a.consumableInfo.chargeTime < b.consumableInfo.chargeTime )
			return -1
		else if ( b.possibleShieldAdd > 0 && b.totalAppliedHeal == a.totalAppliedHeal && b.consumableInfo.chargeTime < a.consumableInfo.chargeTime)
			return 1

		if ( a.possibleShieldAdd > 0  && a.overShield < a.possibleShieldAdd && a.healthPerSecond > b.healthPerSecond )
			return -1
		else if ( b.possibleShieldAdd > 0 && b.overShield < b.possibleShieldAdd && b.healthPerSecond > a.healthPerSecond )
			return 1

		//SORT HEALTH
		if ( a.possibleHealthAdd > 0 && a.consumableInfo.chargeTime < b.consumableInfo.chargeTime )
			return -1
		else if( b.possibleHealthAdd > 0 && b.consumableInfo.chargeTime < a.consumableInfo.chargeTime  )
			return 1

		return 0
}

int function Consumable_GetConsumableRecoveryType( int consumableType )
{
	int consumableRecoveryType

	if ( file.consumableTypeToInfo[ consumableType ].healAmount > 0 )
	{
		if ( file.consumableTypeToInfo[ consumableType ].shieldAmount > 0 )
			consumableRecoveryType = eConsumableRecoveryType.COMBINED
		else
			consumableRecoveryType = eConsumableRecoveryType.HEALTH
	}
	else if ( file.consumableTypeToInfo[ consumableType ].shieldAmount > 0 )
	{
		consumableRecoveryType = eConsumableRecoveryType.SHIELDS
	}
	if ( file.consumableTypeToInfo[ consumableType ].ultimateAmount > 0 )
	{
		consumableRecoveryType = eConsumableRecoveryType.ULTIMATE
	}

	return consumableRecoveryType
}

bool function Consumable_CanUseConsumable( entity player, int consumableType, bool printReason = true )
{

	if ( IsFallLTM() && IsPlayerShadowSquad( player ) )
		return false

	int canUseResult = TryUseConsumable( player, consumableType )

	if( consumableType == eConsumableType.SND_BOMB && canUseResult == eUseConsumableResult.ALLOW )
	{
		return CanPlantBombHere(player)
	}

	if ( canUseResult == eUseConsumableResult.ALLOW )
	{
		return true
	}

	#if CLIENT
		if ( printReason && !player.GetPlayerNetBool( "isHealing" ) )
		{
			switch( canUseResult )
			{
				case eUseConsumableResult.DENY_NO_KITS:
				case eUseConsumableResult.DENY_NO_HEALTH_KIT:
				case eUseConsumableResult.DENY_NO_PHOENIX_KIT:
				case eUseConsumableResult.DENY_SHIELD_FULL:
				case eUseConsumableResult.DENY_NO_SHIELDS:
					if ( player.GetHealth() < player.GetMaxHealth() && !PlayerHasHealthKits( player ) )
					{
						player.ClientCommand( "ClientCommand_Quickchat " + eCommsAction.INVENTORY_NEED_HEALTH )
					}
					else if ( player.GetShieldHealth() < player.GetShieldHealthMax() && !PlayerHasShieldKits( player ) )
					{
						player.ClientCommand( "ClientCommand_Quickchat " + eCommsAction.INVENTORY_NEED_SHIELDS )
					}
					break

				case eUseConsumableResult.DENY_NO_SHIELD_KIT:
				case eUseConsumableResult.DENY_HEALTH_FULL:
					if ( player.GetShieldHealth() < player.GetShieldHealthMax() && !PlayerHasShieldKits( player ) )
					{
						player.ClientCommand( "ClientCommand_Quickchat " + eCommsAction.INVENTORY_NEED_SHIELDS )
					}
					break

				default:
				}
			string reason = GetCanUseResultString( canUseResult )
			if ( reason == "" )
				return false

			if ( (PlayerHasHealthKits( player ) && player.GetHealth() < player.GetMaxHealth()) || (PlayerHasShieldKits( player ) && player.GetShieldHealth() < player.GetShieldHealthMax()) )
			{
				reason = Localize( "#SWITCH_HEALTH_KIT_ENTIRE", Localize ( GetCanUseResultString( canUseResult ) ), Localize( "#SWITCH_HEALTH_KIT" ) )
			}
			//AnnouncementMessageRight( player, reason )
			SND_QuickHint(reason, false)
			return false
		}
	#endif
	return false
}


int function TryUseConsumable( entity player, int consumableType )
{
#if CLIENT
	if ( player != GetLocalClientPlayer() )
		return eUseConsumableResult.DENY_NONE

	if ( player != GetLocalViewPlayer() )
		return eUseConsumableResult.DENY_NONE

	if ( IsWatchingReplay() )
		return eUseConsumableResult.DENY_NONE
#elseif SERVER
	if ( Bleedout_IsPlayerGivingFirstAid( player ) )
		return eUseConsumableResult.DENY_NONE
#endif

	while ( player.ContextAction_IsActive() ) // not a real loop
	{
		if ( player.ContextAction_IsRodeo() )
			break // allow

		return eUseConsumableResult.DENY_NONE
	}
	
	if ( Bleedout_IsBleedingOut( player ) )
		return eUseConsumableResult.DENY_NONE

	if ( !IsAlive( player ) )
		return eUseConsumableResult.DENY_NONE

	if ( player.IsPhaseShifted() )
		return eUseConsumableResult.DENY_NONE

	if ( StatusEffect_GetSeverity( player, eStatusEffect.placing_phase_tunnel ) )
		return eUseConsumableResult.DENY_NONE

	if ( player.GetWeaponDisableFlags() == WEAPON_DISABLE_FLAGS_ALL )
		return eUseConsumableResult.DENY_NONE

	if ( player.IsTitan() )
		return eUseConsumableResult.DENY_NONE

	if ( consumableType == eConsumableType.SND_BOMB )
	{
		return eUseConsumableResult.ALLOW
	}
	
	if ( consumableType == eConsumableType.ULTIMATE )
	{
		ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
		int count           = SURVIVAL_CountItemsInInventory( player, info.lootData.ref )

		if ( count == 0 )
			return eUseConsumableResult.DENY_NONE

		entity ultimateAbility = player.GetOffhandWeapon( OFFHAND_INVENTORY )
		if ( !IsValid( ultimateAbility ) )
			return eUseConsumableResult.DENY_ULT_NOTREADY
		int ammo    = ultimateAbility.GetWeaponPrimaryClipCount()
		int maxAmmo = ultimateAbility.GetWeaponPrimaryClipCountMax()
		
		if ( ammo >= maxAmmo )
			return eUseConsumableResult.DENY_ULT_FULL
		if ( !ultimateAbility.IsReadyToFire() )
			return eUseConsumableResult.DENY_ULT_NOTREADY
	}
	else
	{
		int currentHealth  = player.GetHealth()
		int currentShields = player.GetShieldHealth()
		int maxHealth  = player.GetMaxHealth()
		int maxShields = player.GetShieldHealthMax()
		bool canHeal       = false
		bool canShield     = false
		bool needHeal      = currentHealth < maxHealth
		bool needShield    = currentShields < maxShields
		
		ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]

		int count = SURVIVAL_CountItemsInInventory( player, info.lootData.ref )
		if ( count == 0 )
		{
			if ( info.healAmount > 0 && info.shieldAmount > 0 )
				return eUseConsumableResult.DENY_NO_PHOENIX_KIT
			if ( info.healAmount > 0 )
				return eUseConsumableResult.DENY_NO_HEALTH_KIT
			if ( info.shieldAmount > 0 )
				return eUseConsumableResult.DENY_NO_SHIELD_KIT
		}

		if ( info.healAmount > 0 && info.shieldAmount == 0 && info.healCap <= 100 )
		{
			if ( !needHeal )
				return eUseConsumableResult.DENY_HEALTH_FULL
		}
		else if ( info.shieldAmount > 0 && info.healAmount == 0 )
		{
			if ( !needShield )
				return maxShields > 0 ? eUseConsumableResult.DENY_SHIELD_FULL : eUseConsumableResult.DENY_NO_SHIELDS
		}
		else
		{
			if ( info.healAmount > 0 && needHeal )
				canHeal = true

			if ( info.shieldAmount > 0 && needShield )
				canShield = true

			if ( info.healAmount > 0 && info.healCap > 100 )
			{
				int targetHealth = currentHealth + info.healAmount
				int overHeal     = targetHealth - maxHealth
				if ( overHeal != 0 && currentShields < maxShields )
					canShield = true
			}

			if ( !canHeal && !canShield )
			{
				if ( currentHealth == player.GetMaxHealth() && currentShields == maxShields )
					return eUseConsumableResult.DENY_FULL

				return eUseConsumableResult.DENY_NO_KITS
			}
		}
	}

	return eUseConsumableResult.ALLOW
}


bool function CanSwitchToWeapon( entity weapon, string modName )
{
	if ( !IsValid( weapon ) )
		return false

	if ( !(modName in file.modNameToConsumableType) )
		return false

	entity player = weapon.GetOwner()

	int consumableType  = file.modNameToConsumableType[ modName ]
	ConsumableInfo info = file.consumableTypeToInfo[ consumableType ]
	string itemName     = info.lootData.ref


	if ( !Consumable_CanUseConsumable( player, consumableType, true ) )
		return false

	if ( player.GetActiveWeapon( eActiveInventorySlot.mainHand ) == weapon )
		return false

	return true
}


string function GetConsumableModOnWeapon( entity weapon )
{
	foreach ( string mod in weapon.GetMods() )
	{
		foreach ( int consumableType, ConsumableInfo info in file.consumableTypeToInfo )
		{
			if ( mod == info.modName )
				return mod
		}
	}

	return ""
}


TargetKitHealthAmounts function Consumable_PredictConsumableUse( entity player, ConsumableInfo kitInfo )
{
	int currentHealth   = player.GetHealth()
	int maxHealth 		= player.GetMaxHealth()
	int currentShields  = player.GetShieldHealth()
	int shieldHealthMax = player.GetShieldHealthMax()

	int resourceHealthRemaining = 0
	int virtualHealth           = minint( currentHealth + resourceHealthRemaining, maxHealth )
	int missingHealth           = maxHealth - virtualHealth
	int missingShields          = shieldHealthMax - currentShields

	TargetKitHealthAmounts targetValues

	float healAmount   = CalculateTotalHealFromItem( player, kitInfo )
	float shieldAmount = CalculateTotalShieldFromItem( player, kitInfo )

	if ( healAmount > 0 )
	{
		int healthToApply = minint( int( healAmount ), missingHealth )
		Assert( virtualHealth + healthToApply <= maxHealth, "Bad math: " + virtualHealth + " + " + healthToApply + " > max health of " + maxHealth )

		if ( healthToApply != 0 || kitInfo.healTime > 0 ) // healTime items can exceed the cap
			targetValues.targetHealth = (healthToApply + resourceHealthRemaining) / float( maxHealth )
	}

	if ( shieldAmount > 0 && shieldHealthMax > 0 )
		targetValues.targetShields = shieldAmount / float( shieldHealthMax )

	return targetValues
}



void function ResetConsumableData( ConsumablePersistentData useData )
{
	useData.useFinished         = false
	useData.healAmount          = 0
	useData.healAmountRemaining = 0
	useData.healthKitResourceId = 0
	useData.shieldStatusHandle  = 0
	useData.healthStatusHandle  = 0
	useData.lastMissingHealth   = -1
	useData.lastMissingShields  = -1
	useData.lastCurrentHealth   = -1
	useData.statusEffectHandles = []
}

bool function Consumable_IsHealthItem( int consumableType )
{
	if ( !( consumableType in file.consumableTypeToInfo ) )
		return false

	if ( file.consumableTypeToInfo[ consumableType ].healAmount > 0 )
		return true

	return false
}

bool function Consumable_IsShieldItem( int consumableType )
{
	if ( !( consumableType in file.consumableTypeToInfo ) )
		return false

	if ( file.consumableTypeToInfo[ consumableType ].shieldAmount > 0 )
		return true

	return false
}
bool function WeaponDrivenConsumablesEnabled()
{
	return (GetCurrentPlaylistVarInt( "weapon_driven_consumables", 1 ) == 1)
}


bool function ShouldPlayUltimateSuperchargedFX( entity player )
{
	if ( PlayerHasPassive( player, ePassives.PAS_BATTERY_POWERED ) )
		return true

	return false
}
