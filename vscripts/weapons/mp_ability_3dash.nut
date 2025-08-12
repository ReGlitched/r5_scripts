global function MpAbility3Dash_Init

global function OnWeaponActivate_ability_3dash
global function OnWeaponPrimaryAttack_ability_3dash
global function OnWeaponChargeBegin_ability_3dash
global function OnWeaponChargeEnd_ability_3dash

const float PHASE_WALK_PRE_TELL_TIME = 1.5
const asset PHASE_WALK_APPEAR_PRE_FX = $"P_phase_dash_pre_end_mdl"

void function MpAbility3Dash_Init()
{
	PrecacheParticleSystem( PHASE_WALK_APPEAR_PRE_FX )
}


void function OnWeaponActivate_ability_3dash( entity weapon )
{
	if (Flowstate_Is4DMode())
		return
	#if SERVER
		entity player = weapon.GetWeaponOwner()
		EmitSoundOnEntityExceptToPlayer(player, player, "Wraith_PhaseGate_Portal_Open")

		if ( player.GetActiveWeapon( eActiveInventorySlot.mainHand ) != player.GetOffhandWeapon( OFFHAND_INVENTORY ) )
			PlayBattleChatterLineToSpeakerAndTeam( player, "bc_skydive" )
	#endif
}


var function OnWeaponPrimaryAttack_ability_3dash( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

bool function OnWeaponChargeBegin_ability_3dash( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	#if SERVER
		player.p.last3dashtime = Time()
		thread DashPlayer(player, chargeTime)
		PlayerUsedOffhand( player, weapon )
	#endif
	return true
}

#if SERVER

void function DashPlayer(entity player, float chargeTime)
{
	if (Flowstate_Is4DMode())
	{
		if (player.GetOrigin().x > 0)
		{
			player.SetOrigin(player.GetOrigin() - <30000,0,0>)
		}
		else
		{
			player.SetOrigin(player.GetOrigin() + <30000,0,0>)
		}
		return
	}
	player.Zipline_Stop()
	if ( MapName() == eMaps.mp_rr_ashs_redemption ) return
	player.Zipline_Stop()
	vector yes
	if(player.GetInputAxisForward() || player.GetInputAxisRight()) yes = Normalize(player.GetInputAxisForward() * player.GetViewForward() + player.GetInputAxisRight() * player.GetViewRight())
	else yes = Normalize(player.GetVelocity())

	TraceResults result = TraceLine(player.GetOrigin(), player.GetOrigin() + 320 * yes, [player], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_PLAYER)
	vector originalPos = player.GetOrigin()

	player.SetOrigin(result.endPos)
	if(PutEntityInSafeSpot( player, null, null, player.GetOrigin(), player.GetOrigin() ))
	{
		player.SetVelocity(player.GetVelocity() + 400 * yes)
	}
	else
	{
		player.SetOrigin(originalPos)
	}
}

#endif
void function OnWeaponChargeEnd_ability_3dash( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	if (Flowstate_Is4DMode())
	{
		weapon.EmitWeaponSound_1p3p( "Pilot_PhaseShift_End_1P", "Pilot_PhaseShift_End_3P" )
	}
	#if SERVER
		foreach ( effect in weapon.w.statusEffects )
		{
			StatusEffect_Stop( player, effect )
		}
		if ( player.IsMantling() || player.IsWallRunning() || player.p.isSkydiving )
			weapon.SetWeaponPrimaryClipCount( 0 ) //Defensive fix for the fact that primary fire isn't triggered when climbing.

	#endif
}