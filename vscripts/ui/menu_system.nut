global function InitSystemMenu
global function InitSystemPanelMain
global function InitSystemPanel
global function UpdateSystemPanel
global function ToggleSetHunter
global function OpenSystemMenu

global function UI_Callback_MOTD
global function SetMotdText
global function OpenMOTD


global function ShouldDisplayOptInOptions

struct ButtonData
{
	string             label
	void functionref() activateFunc
}

struct
{
	var                    menu

	table<var, array<var> >            buttons
	table<var, array<ButtonData> > buttonDatas

	table<var, ButtonData > settingsButtonData
	table<var, ButtonData > leaveMatchButtonData
	table<var, ButtonData > exitButtonData
	table<var, ButtonData > lobbyReturnButtonData
	table<var, ButtonData > nullButtonData
	table<var, ButtonData > leavePartyData
	table<var, ButtonData > abandonMissionButtonData
	table<var, ButtonData > changeCharacterButtonData
	table<var, ButtonData > friendlyFireButtonData
	table<var, ButtonData > thirdPersonButtonData
	table<var, ButtonData > ExitChallengeButtonData
	table<var, ButtonData > TDM_ChangeWeapons
	table<var, ButtonData > endmatchButtonData
	table<var, ButtonData > spectateButtonData
	table<var, ButtonData > respawnButtonData
	table<var, ButtonData > hubButtonData
	table<var, ButtonData > MGsettingsButtonData
	table<var, ButtonData > SetHunterButtonData
	table<var, ButtonData > ToggleScoreboardFocus
	table<var, ButtonData > Toggle1v1ScoreboardFocus
	table<var, ButtonData > OpenLGDuelsSettingsData
	table<var, ButtonData > OpenValkSimulatorSettingsData
	table<var, ButtonData > LockCurrent1v1Enemy
	table<var, ButtonData > ToggleRest
	table<var, ButtonData > DestroyDummies
	table<var, ButtonData > DestroyDummiesAdmin
	table<var, ButtonData > OpenWeaponsMenu
	table<var, ButtonData > OpenRecordingsMenu
	table<var, ButtonData > OpenMOTD
	table<var, ButtonData > OpenScenariosStandings

	InputDef& qaFooter
	
	bool SETHUNTERALLOWED
	
	string motdText = ""
	table<string,bool> seenMotdForServer = {}
	
} file

void function InitSystemMenu( var newMenuArg ) //
{
	var menu = GetMenu( "SystemMenu" )
	Hud_SetAboveBlur( menu, true )
	file.menu = menu

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnSystemMenu_Open )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnSystemMenu_Close )
	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnSystemMenu_NavigateBack )

	AddUICallback_LevelShutdown
	(
		void function()
		{
			file.motdText = ""
		}
	)
}

void function InitSystemPanelMain( var panel )
{
	InitSystemPanel( panel )

	AddPanelFooterOption( panel, LEFT, BUTTON_B, true, "#B_BUTTON_BACK", "#B_BUTTON_BACK" )
	AddPanelFooterOption( panel, LEFT, BUTTON_Y, true, "#Y_BUTTON_DEV_MENU", "#DEV_MENU", OpenDevMenu, ShouldShowDevMenu )

	if ( Dev_CommandLineHasParm( "-showoptinmenu" ) )
		file.qaFooter = AddPanelFooterOption( panel, LEFT, BUTTON_X, true, "#X_BUTTON_QA", "QA", ToggleOptIn, ShouldDisplayOptInOptions )

	#if CONSOLE_PROG
		AddPanelFooterOption( panel, RIGHT, BUTTON_BACK, false, "#BUTTON_RETURN_TO_MAIN", "", ReturnToMain_OnActivate )
	#endif
	AddPanelFooterOption( panel, RIGHT, BUTTON_STICK_RIGHT, true, "#BUTTON_VIEW_CINEMATIC", "#VIEW_CINEMATIC", ViewCinematic, IsLobby )
}

void function ViewCinematic( var button )
{
	CloseActiveMenu()
	thread PlayVideoMenu( false, "intro", "Apex_Opening_Movie", eVideoSkipRule.INSTANT )
}

void function TryChangeCharacters()
{
	RunClientScript( "UICallback_OpenCharacterSelectNewMenu" )
}

void function ToggleFriendlyFire()
{
	ClientCommand( "firingrange_toggle_friendlyfire" )
}

void function ToggleThirdPerson()
{
	ClientCommand( "ToggleThirdPerson" )
}

void function SignalExitChallenge()
{
	RunClientScript("ExitChallengeClient")
}

void function SetHunterFunct()
{
	ClientCommand( "sethunter" )
}

void function OpenWeaponSelector()
{
	var menu = GetMenu("FRChallengesSettingsWpnSelector")
	var child = Hud_GetChild( menu , "Title" )
	Hud_SetColor( menu, 255, 255, 0, 255 )
	thread FancyLabelFadeIn( menu, child, 200, 1000, true, .40, false, 0, "", false )
	Hud_SetColorBG( menu, 0, 0, 0, 0 )		
	RunClientScript("OpenTDMWeaponSelectorUI")
	thread PulsateElem( menu, child, 255, 25, 2.0 )
}

void function OpenRecordingsMenu()
{
	UI_Open1v1CoachingMenu()
}

void function InitSystemPanel( var panel )
{	
	var menu = Hud_GetParent( panel )
	file.buttons[ panel ] <- GetElementsByClassname( menu, "SystemButtonClass" )
	file.buttonDatas[ panel ] <- []
	file.buttonDatas[ panel ].resize( file.buttons[ panel ].len() )

	ButtonData data

	file.nullButtonData[ panel ] <- clone data

	foreach ( index, button in file.buttons[ panel ] )
	{
		SetButtonData( panel, index, file.nullButtonData[ panel ] )
		Hud_AddEventHandler( button, UIE_CLICK, OnButton_Activate )
	}

	file.settingsButtonData[ panel ] <- clone data
	file.leaveMatchButtonData[ panel ] <- clone data
	file.exitButtonData[ panel ] <- clone data
	file.lobbyReturnButtonData[ panel ] <- clone data
	file.leavePartyData[ panel ] <- clone data
	file.abandonMissionButtonData[ panel ] <- clone data
	file.changeCharacterButtonData[ panel ] <- clone data
	file.friendlyFireButtonData[ panel ] <- clone data
	file.thirdPersonButtonData[ panel ] <- clone data
	file.endmatchButtonData[ panel ] <- clone data
	file.ExitChallengeButtonData[ panel ] <- clone data
	file.spectateButtonData[ panel ] <- clone data
	file.respawnButtonData[ panel ] <- clone data
	file.hubButtonData[ panel ] <- clone data
	file.MGsettingsButtonData[ panel ] <- clone data
	file.TDM_ChangeWeapons[ panel ] <- clone data
	file.SetHunterButtonData[ panel ] <- clone data
	file.ToggleScoreboardFocus[ panel ] <- clone data
	file.Toggle1v1ScoreboardFocus[ panel ] <- clone data
	file.OpenLGDuelsSettingsData[ panel ] <- clone data
	file.OpenValkSimulatorSettingsData[ panel ] <- clone data
	file.LockCurrent1v1Enemy[ panel ] <- clone data
	file.ToggleRest[ panel ] <- clone data
	file.DestroyDummies[ panel ] <- clone data
	file.DestroyDummiesAdmin[ panel ] <- clone data
	file.OpenWeaponsMenu[ panel ] <- clone data
	file.OpenRecordingsMenu[ panel ] <- clone data
	file.OpenMOTD[ panel ] <- clone data
	file.OpenScenariosStandings[ panel ] <- clone data

	file.ExitChallengeButtonData[ panel ].label = "#FS_FINISH_CHALLENGE"
	file.ExitChallengeButtonData[ panel ].activateFunc = SignalExitChallenge

	file.settingsButtonData[ panel ].label = "#SETTINGS"
	file.settingsButtonData[ panel ].activateFunc = OpenSettingsMenu
	
	file.SetHunterButtonData[ panel ].label = "#FS_SET_HUNTER"
	file.SetHunterButtonData[ panel ].activateFunc = SetHunterFunct
		
	file.TDM_ChangeWeapons[ panel ].label = "#FS_CHANGE_WEAPON"
	file.TDM_ChangeWeapons[ panel ].activateFunc = OpenWeaponSelector
	
	file.leaveMatchButtonData[ panel ].label = "#LEAVE_MATCH"
	file.leaveMatchButtonData[ panel ].activateFunc = LeaveDialog

	file.exitButtonData[ panel ].label = "#EXIT_TO_DESKTOP"
	file.exitButtonData[ panel ].activateFunc = OpenConfirmExitToDesktopDialog

	file.lobbyReturnButtonData[ panel ].label = "#RETURN_TO_LOBBY"
	file.lobbyReturnButtonData[ panel ].activateFunc = LeaveDialog

	file.leavePartyData[ panel ].label = "#LEAVE_PARTY"
	file.leavePartyData[ panel ].activateFunc = LeavePartyDialog

	file.abandonMissionButtonData[ panel ].label = "#ABANDON_MISSION"
	file.abandonMissionButtonData[ panel ].activateFunc = LeaveDialog

	file.changeCharacterButtonData[ panel ].label = "#BUTTON_CHARACTER_CHANGE"
	file.changeCharacterButtonData[ panel ].activateFunc = TryChangeCharacters

	file.friendlyFireButtonData[ panel ].label = "#BUTTON_FRIENDLY_FIRE_TOGGLE"
	file.friendlyFireButtonData[ panel ].activateFunc = ToggleFriendlyFire
	
	file.thirdPersonButtonData[ panel ].label = "#FS_TOGGLE_THIRD_PERSON"
	file.thirdPersonButtonData[ panel ].activateFunc = ToggleThirdPerson

	file.endmatchButtonData[ panel ].label = "#FS_END_GAME_LOBBY"
	file.endmatchButtonData[ panel ].activateFunc = HostEndMatch
	
	file.hubButtonData[ panel ].label = "#FS_HUB"
	file.hubButtonData[ panel ].activateFunc = RunHub

	file.MGsettingsButtonData[ panel ].label = "#FS_GYM_SETTINGS"
	file.MGsettingsButtonData[ panel ].activateFunc = RunMGsettings

	file.spectateButtonData[ panel ].label = "#DEATH_SCREEN_SPECTATE"
	file.spectateButtonData[ panel ].activateFunc = RunSpectateCommand
	
	file.respawnButtonData[ panel ].label = "#PROMPT_PING_RESPAWN_STATION_SHORT"
	file.respawnButtonData[ panel ].activateFunc = RunKillSelf

	file.ToggleScoreboardFocus[ panel ].label = "#FS_TOGGLE_SCOREBOARD"
	file.ToggleScoreboardFocus[ panel ].activateFunc = ShowScoreboard_System
	
	file.Toggle1v1ScoreboardFocus[ panel ].label = "#FS_TOGGLE_VS_UI"
	file.Toggle1v1ScoreboardFocus[ panel ].activateFunc = Toggle1v1Scoreboard_System

	file.OpenLGDuelsSettingsData[ panel ].label = "#FS_LG_DUELS_SETTINGS"
	file.OpenLGDuelsSettingsData[ panel ].activateFunc = OpenLGDuelsSettings_System

	file.OpenValkSimulatorSettingsData[ panel ].label = "#FS_VALK_ULT_SIM_SETTINGS"
	file.OpenValkSimulatorSettingsData[ panel ].activateFunc = OpenValkSimulatorSettings_System
	
	file.LockCurrent1v1Enemy[ panel ].label = "TOGGLE ENEMY LOCK" //set by server, not used here
	file.LockCurrent1v1Enemy[ panel ].activateFunc = OpenLockCurrent1v1Enemy_System
	
	file.ToggleRest[ panel ].label = "#FS_TOGGLE_REST"
	file.ToggleRest[ panel ].activateFunc = ToggleRest_1v1
	
	file.DestroyDummies[ panel ].label = "#FS_DESTROY_DUMMIES"
	file.DestroyDummies[ panel ].activateFunc = DestroyDummys_MovementRecorder
	
	file.DestroyDummiesAdmin[ panel ].label = "#FS_ADMIN_DESTROY_DUMMIES"
	file.DestroyDummiesAdmin[ panel ].activateFunc = AdminDestroyDummys_MovementRecorder
	
	file.OpenWeaponsMenu[ panel ].label = "#FS_WEAPONS_MENU"
	file.OpenWeaponsMenu[ panel ].activateFunc = OpenWeaponSelector

	file.OpenRecordingsMenu[ panel ].label = "1v1 RECORDINGS MENU"
	file.OpenRecordingsMenu[ panel ].activateFunc = OpenRecordingsMenu
	
	file.OpenMOTD[ panel ].label = "#FS_SERVER_MOTD"
	file.OpenMOTD[ panel ].activateFunc = OpenMOTD	
	
	file.OpenScenariosStandings[ panel ].label = "#FS_SCENARIOS_STANDINGS"
	file.OpenScenariosStandings[ panel ].activateFunc = UI_OpenScenariosStandingsMenu	
	
	AddPanelEventHandler( panel, eUIEvent.PANEL_SHOW, SystemPanelShow )
}

void function SystemPanelShow( var panel )
{
	UpdateSystemPanel( panel )
}

void function OnSystemMenu_Open()
{
	SetBlurEnabled( true )
	ShowPanel( Hud_GetChild( file.menu, "SystemPanel" ) )
	UpdateOptInFooter()
}


void function UpdateSystemPanel( var panel )
{	
	//entity player = GetLocalClientPlayer()
	
	//temp workaround, not the best place for this tbh
	if( IsConnected() && Playlist() != ePlaylists.fs_aimtrainer )
		file.lobbyReturnButtonData[ panel ].label = "#RETURN_TO_LOBBY"
	else if( IsConnected() && Playlist() == ePlaylists.fs_aimtrainer )
		file.lobbyReturnButtonData[ panel ].label = "#FS_EXIT_AIM_TRAINER"
	file.lobbyReturnButtonData[ panel ].activateFunc = LeaveDialog

	foreach ( index, button in file.buttons[ panel ] )
		SetButtonData( panel, index, file.nullButtonData[ panel ] )

	int buttonIndex = 0
	if ( IsConnected() && !IsLobby() )
	{
		RunClientScript( "FS_RegisterAdmin" )
		
		UISize screenSize = GetScreenSize()
		SetCursorPosition( <1920.0 * 0.5, 1080.0 * 0.5, 0> )

		SetButtonData( panel, buttonIndex++, file.settingsButtonData[ panel ] )
		
		if( Playlist() == ePlaylists.fs_dm || Playlist() == ePlaylists.fs_realistic_ttv )
			SetButtonData( panel, buttonIndex++, file.ToggleScoreboardFocus[ panel ] )

		if( uiGlobal.is1v1GameType && Playlist() != ePlaylists.fs_1v1_coaching ) //initialized after level load
		{
			SetButtonData( panel, buttonIndex++, file.Toggle1v1ScoreboardFocus[ panel ] )
			SetButtonData( panel, buttonIndex++, file.ToggleRest[ panel ] )
			SetButtonData( panel, buttonIndex++, file.OpenWeaponsMenu[ panel ] )
		} else if( Playlist() == ePlaylists.fs_1v1_coaching )
		{
			SetButtonData( panel, buttonIndex++, file.OpenRecordingsMenu[ panel ] )
			SetButtonData( panel, buttonIndex++, file.OpenWeaponsMenu[ panel ] )
		}
		else if( Playlist() == ePlaylists.fs_movementrecorder || Playlist() == ePlaylists.fs_realistic_ttv )
		{
			SetButtonData( panel, buttonIndex++, file.OpenWeaponsMenu[ panel ] )
		}
		else if( Playlist() == ePlaylists.fs_scenarios )
		{
			SetButtonData( panel, buttonIndex++, file.ToggleRest[ panel ] )
		}

		if( Playlist() == ePlaylists.fs_lgduels_1v1 || Playlist() == ePlaylists.fs_dm_fast_instagib )		
			SetButtonData( panel, buttonIndex++, file.OpenLGDuelsSettingsData[ panel ] )
		
		if ( IsFiringRangeGameMode() && !uiGlobal.isAimTrainer )
		{
			SetButtonData( panel, buttonIndex++, file.changeCharacterButtonData[ panel ] ) // !FIXME
			//SetButtonData( panel, buttonIndex++, file.thirdPersonButtonData[ panel ] )
		
			if ( (GetTeamSize( GetTeam() ) > 1) && FiringRangeHasFriendlyFire() )
				SetButtonData( panel, buttonIndex++, file.friendlyFireButtonData[ panel ] )
		}
		if( Playlist() == ePlaylists.fs_dm && !uiGlobal.playlistbool_flowstate_1v1mode )
		{
			SetButtonData( panel, buttonIndex++, file.spectateButtonData[ panel ] )
			SetButtonData( panel, buttonIndex++, file.respawnButtonData[ panel ] )
		}
		if( Playlist() == ePlaylists.fs_movementgym )
		{
			SetButtonData( panel, buttonIndex++, file.MGsettingsButtonData[ panel ] )
			SetButtonData( panel, buttonIndex++, file.hubButtonData[ panel ] )
		}
		if( Playlist() == ePlaylists.fs_movementrecorder )
		{
			SetButtonData( panel, buttonIndex++, file.DestroyDummies[ panel ] )
			
			if( uiGlobal.bIsServerAdmin )
			{	
				SetButtonData( panel, buttonIndex++, file.DestroyDummiesAdmin[ panel ] )
			}
		}
		if( Playlist() == ePlaylists.fs_scenarios )
		{
			SetButtonData( panel, buttonIndex++, file.OpenScenariosStandings[ panel ] )
		}

		if( GetCurrentPlaylistVarBool( "enable_motd", true ) && Playlist() != ePlaylists.fs_1v1_coaching && Playlist() != ePlaylists.fs_haloMod_survival )
			SetButtonData( panel, buttonIndex++, file.OpenMOTD[ panel ] )
		
		// if( GetCurrentPlaylistName() == "fs_duckhunt" && IsConnected() && file.SETHUNTERALLOWED )
		// {
			// SetButtonData( panel, buttonIndex++, file.SetHunterButtonData[ panel ] )
		// }
		
		if( Playlist() != ePlaylists.fs_aimtrainer )
		{
			if ( IsSurvivalTraining() || IsFiringRangeGameMode() )
				SetButtonData( panel, buttonIndex++, file.lobbyReturnButtonData[ panel ] )
			else
				SetButtonData( panel, buttonIndex++, file.leaveMatchButtonData[ panel ] )
		} 
		else
		{
			if(ISAIMTRAINER)
				SetButtonData( panel, buttonIndex++, file.lobbyReturnButtonData[ panel ] )
			else
			{
				// SetButtonData( panel, buttonIndex++, file.OpenValkSimulatorSettingsData[ panel ] )
				SetButtonData( panel, buttonIndex++, file.ExitChallengeButtonData[ panel ] )
			}
		}
	}
	else
	{
		if ( AmIPartyMember() || AmIPartyLeader() && GetPartySize() > 1 )
			SetButtonData( panel, buttonIndex++, file.leavePartyData[ panel ] )
		SetButtonData( panel, buttonIndex++, file.settingsButtonData[ panel ] )
		#if PC_PROG
			SetButtonData( panel, buttonIndex++, file.exitButtonData[ panel ] )
		#endif
	}

	const int maxNumButtons = 5;
	for( int i = 0; i < maxNumButtons; i++ )
	{
		if( i > 0 && i < buttonIndex)
			Hud_SetNavUp( file.buttons[ panel ][i], file.buttons[ panel ][i - 1] )
		else
			Hud_SetNavUp( file.buttons[ panel ][i], null )

		if( i < (buttonIndex - 1) )
			Hud_SetNavDown( file.buttons[ panel ][i], file.buttons[ panel ][i + 1] )
		else
			Hud_SetNavDown( file.buttons[ panel ][i], null )
	}

	string msgonbottom = ""
	
	if( IsConnected() )
	{
		switch( Playlist() )
		{
			case ePlaylists.fs_haloMod_survival:
			msgonbottom = "Halo Mod Battle Royale - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_aimtrainer:
			msgonbottom = "Flowstate Aim Trainer by @CafeFPS"
			break

			case ePlaylists.fs_scenarios:
			msgonbottom = "Flowstate Zone Wars - Ping: " + MyPing() + " ms."
			break

			case ePlaylists.fs_1v1:
			case ePlaylists.fs_vamp_1v1:
			case ePlaylists.fs_1v1_headshots_only:
			msgonbottom = "Flowstate 1V1 - Ping: " + MyPing() + " ms."
			break

			case ePlaylists.fs_movementrecorder:
			msgonbottom = "FS Movement Recorder - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_snd:
			msgonbottom = "Flowstate S&D - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.winterexpress:
			msgonbottom = "FS Winter Express - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_dm:
			msgonbottom = "FS DM - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_dm:
			msgonbottom = "Realistic TTV - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_lgduels_1v1:
			msgonbottom = "Flowstate LGDuels - Ping: " + MyPing() + " ms."
			break
			
			case ePlaylists.fs_dm_fast_instagib:
			msgonbottom = "Cafe's Instagib - Ping: " + MyPing() + " ms."
			break

			case ePlaylists.fs_haloMod:
			case ePlaylists.fs_haloMod_ctf:
			case ePlaylists.fs_haloMod_oddball:
			msgonbottom = "FS Halo Mod - Ping: " + MyPing() + " ms."
			break
		}
		
		if( IsConnected() && GetCurrentPlaylistVarBool( "is_practice_map", false ) )
			msgonbottom = "Practice Map - Ping: " + MyPing() + " ms."
	}
	else
		msgonbottom = "R5Reloaded Server: Ping: " + MyPing() + " ms."
		
	var dataCenterElem = Hud_GetChild( panel, "DataCenter" )
	Hud_SetText( dataCenterElem, msgonbottom)
}


void function ToggleSetHunter(bool enable)
{
	file.SETHUNTERALLOWED = enable
}

void function SetButtonData( var panel, int buttonIndex, ButtonData buttonData )
{
	file.buttonDatas[ panel ][buttonIndex] = buttonData

	var rui = Hud_GetRui( file.buttons[ panel ][buttonIndex] )
	RHud_SetText( file.buttons[ panel ][buttonIndex], buttonData.label )

	if ( buttonData.label == "" )
		Hud_SetVisible( file.buttons[ panel ][buttonIndex], false )
	else
		Hud_SetVisible( file.buttons[ panel ][buttonIndex], true )
}


void function OnSystemMenu_Close()
{
	if( ISAIMTRAINER && IsConnected() && Playlist() == ePlaylists.fs_aimtrainer ){
		CloseAllMenus()
		RunClientScript("ServerCallback_OpenFRChallengesMainMenu", PlayerKillsForChallengesUI)
	}
}


void function OnSystemMenu_NavigateBack()
{
	Assert( GetActiveMenu() == file.menu )
	CloseActiveMenu()
	if( ISAIMTRAINER && IsConnected() && Playlist() == ePlaylists.fs_aimtrainer ){
		CloseAllMenus()
		RunClientScript("ServerCallback_OpenFRChallengesMainMenu", PlayerKillsForChallengesUI)
	}
}


void function OnButton_Activate( var button )
{
	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()

	var panel = Hud_GetParent( button )

	int buttonIndex = int( Hud_GetScriptID( button ) )

	file.buttonDatas[ panel ][buttonIndex].activateFunc()
}

void function OpenSystemMenu()
{
	AdvanceMenu( file.menu )
}

void function OpenSettingsMenu()
{
	AdvanceMenu( GetMenu( "MiscMenu" ) )
}

void function HostEndMatch()
{
	#if LISTEN_SERVER
	CreateServer( GetPlayerName() + " Lobby", "", "mp_lobby", "menufall", eServerVisibility.OFFLINE )
	#endif // LISTEN_SERVER
}

void function RunSpectateCommand()
{
	ClientCommand( "spectate" )
}

void function ShowScoreboard_System()
{
	ClientCommand( "scoreboard_toggle_focus" )
}

void function Toggle1v1Scoreboard_System()
{
	RunClientScript( "Toggle1v1Scoreboard" )
}

void function OpenLGDuelsSettings_System()
{
	OpenLGDuelsSettings()
}

void function OpenValkSimulatorSettings_System()
{
	OpenValkSimulatorSettings()
}

void function OpenLockCurrent1v1Enemy_System()
{
	ClientCommand( "lockenemy_1v1" )
}

void function RunKillSelf()
{
	ClientCommand( "kill_self" )
}

void function RunHub()
{
	ClientCommand( "hub" )
}

void function RunMGsettings()
{
	RunClientScript("MG_Settings_UI")
}

void function ToggleRest_1v1()
{
	ClientCommand( "rest" )
}

void function DestroyDummys_MovementRecorder()
{
	ClientCommand( "DestroyDummys" )
}

void function AdminDestroyDummys_MovementRecorder()
{
	ClientCommand( "DestroyDummys Admin" )
}

#if CONSOLE_PROG
void function ReturnToMain_OnActivate( var button )
{
	ConfirmDialogData data
	data.headerText = "#EXIT_TO_MAIN"
	data.messageText = ""
	data.resultCallback = OnReturnToMainMenu
	//data.yesText = ["YES_RETURN_TO_TITLE_MENU", "#YES_RETURN_TO_TITLE_MENU"]

	OpenConfirmDialogFromData( data )
	AdvanceMenu( GetMenu( "ConfirmDialog" ) )
}

void function OnReturnToMainMenu( int result )
{
	if ( result == eDialogResult.YES )
		ClientCommand( "disconnect" )
}
#endif


void function ToggleOptIn( var button )
{
	uiGlobal.isOptInEnabled = !uiGlobal.isOptInEnabled

	if ( GetActiveMenu() == file.menu )
		CloseActiveMenu()
}


bool function ShouldDisplayOptInOptions()
{
	if ( !IsFullyConnected() )
		return false

	// if ( GRX_IsInventoryReady() && (GRX_HasItem( GRX_DEV_ITEM ) || GRX_HasItem( GRX_QA_ITEM )) )
		return true

	return GetGlobalNetBool( "isOptInServer" )
}

void function UI_Callback_MOTD()
{
	SetMotdText( "" )
}

void function SetMotdText( string text )
{
	file.motdText = text
	
	// auto-opening motd disabled as per amos request

	if( !GetConVarInt( "show_motd_on_server_first_join" ) )
		return

	// note(amos): GetServerID() cannot be used on the client
	// it is a server only function that was accidentally
	// registered for client too. Calling this here returns
	// the server ID of your own listen server, so it will
	// only show the message once during the duration of the
	// process. in the future we need to work on the ability
	// to send the server id to the client. commented, and
	// directly calling OpenMOTD() for now.
	OpenMOTD()

	// string server = GetServerID()
	
	// if( !( server in file.seenMotdForServer ) )
	// {
	// 	OpenMOTD()
	// 	file.seenMotdForServer[ server ] <- true
	// }
}

void function OpenMOTD()
{
	if ( IsLobby() )
		return
		
	if ( file.motdText != "" )
	{ 
		OpenServerMOTD( file.motdText )
		return
	}
	
	string motd = ""
	string motdLocalized = Localize( "#FS_PLAYLIST_MOTD" )
	string motdLocaliziedContinue = Localize( "#FS_PLAYLIST_MOTD_CONTINUE" )
	
	if( motdLocalized != "" && motdLocalized != "#FS_PLAYLIST_MOTD" )
	{
		motd = motdLocalized
		
		if( motdLocaliziedContinue != "" && motdLocaliziedContinue != "#FS_PLAYLIST_MOTD_CONTINUE" )
		{
			motd = motd + motdLocaliziedContinue	
		}
		
		file.motdText = motd //save for repeat opens
	}
	
	OpenServerMOTD( motd )
}

void function UpdateOptInFooter()
{
	if ( uiGlobal.isOptInEnabled )
	{
		file.qaFooter.gamepadLabel = "#X_BUTTON_HIDE_OPT_IN"
		file.qaFooter.mouseLabel = "#HIDE_OPT_IN"
	}
	else
	{
		file.qaFooter.gamepadLabel = "#X_BUTTON_SHOW_OPT_IN"
		file.qaFooter.mouseLabel = "#SHOW_OPT_IN"
	}

	UpdateFooterOptions()
}

bool function ShouldShowDevMenu()
{
	if(IsLobby())
		return false
	
	return true
}



