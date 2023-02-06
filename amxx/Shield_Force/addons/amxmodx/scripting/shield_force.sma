#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <cstrike>
#include <fakemeta_util>
#include <zombieplague>

#define PLUGIN "[ZP] Extra Item: Force Field Grenade"
#define VERSION "v2.1 (Fixed)"
#define AUTHOR "lucas_7_94 & Accelerator" // Thanks To Users in credits too!.

#define ValidTouch(%1) ( is_user_alive(%1) && ( zp_get_user_zombie(%1) || zp_get_user_nemesis(%1) ) )

/*=============================[Plugin Customization]=============================*/
#define CAMPO_TASK
#define TASK_TIME 60.0

//#define CAMPO_ROUND

#define RANDOM_COLOR
//#define ONE_COLOR

new const NADE_TYPE_CAMPO = 3679

#if defined ONE_COLOR
new Float:CampoColors[3] = { 
	255.0 , // r
	0.0 ,   // g
	0.0     // b
}
#endif

new const model_grenade[] = "models/zombie_plague/v_auragren.mdl"
new const model[] = "models/zombie_plague/aura8.mdl"
new const w_model[] = "models/zombie_plague/w_aura.mdl"
new const gModelGlass[] = "models/glassgibs.mdl"
new const sprite_grenade_trail[] = "sprites/laserbeam.spr"
new const entclas[] = "campo_grenade_forze"
new const recieving_sound[] = "items/9mmclip1.wav"
new const gSoundTouch[] = "debris/beamstart6.wav"
new const gSoundOpen[] = "debris/beamstart1.wav"
new const gSoundClose[] = "debris/beamstart10.wav"

new g_trailSpr, cvar_push, g_SayText, g_msgAmmoPickup, g_itemID, g_maxplayers, gGlass

new bool:g_bomb[33]

const item_cost = 15
/*=============================[End Customization]=============================*/

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	register_event("CurWeapon", "Event_CurWeapon", "be","1=1")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_Touch, "fw_touch")
	register_message(g_msgAmmoPickup, "message_ammopickup")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	
	g_SayText = get_user_msgid("SayText")
	g_msgAmmoPickup = get_user_msgid("AmmoPickup")
	
	#if defined CAMPO_ROUND
	g_itemID = zp_register_extra_item ( "Force Shield" , item_cost * 2 , ZP_TEAM_HUMAN )
	#else 
	g_itemID = zp_register_extra_item ( "Force Shield" , item_cost , ZP_TEAM_HUMAN )
	#endif
	
	// Push cvar, (Only float's numbers)
	cvar_push = register_cvar("zp_forze_push", "7.5")
	
	g_maxplayers = get_maxplayers()
}

public plugin_precache() {
	
	g_trailSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_trail)
	gGlass = engfunc(EngFunc_PrecacheModel, gModelGlass)
	engfunc(EngFunc_PrecacheModel, model_grenade)
	engfunc(EngFunc_PrecacheModel, model)
	engfunc(EngFunc_PrecacheModel, w_model)
	engfunc(EngFunc_PrecacheSound, recieving_sound)
	engfunc(EngFunc_PrecacheSound, gSoundTouch)
	engfunc(EngFunc_PrecacheSound, gSoundOpen)
	engfunc(EngFunc_PrecacheSound, gSoundClose)
}

public event_round_start() 
{
	for (new id=1; id<=g_maxplayers; id++)
		g_bomb[id] = false

	new ent = FM_NULLENT
	static string_class[] = "classname"
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, string_class, entclas))) 
		set_pev(ent, pev_flags, FL_KILLME)
}

public client_disconnect(id) 
	g_bomb[id] = false

public Event_CurWeapon(id) 
{
	if (get_user_weapon(id) == CSW_SMOKEGRENADE && g_bomb[id])
		set_pev(id, pev_viewmodel2, model_grenade)
}
	
public zp_extra_item_selected(player, itemid) {
	
	if(itemid == g_itemID)
	{
		if(g_bomb[player]) 
			Color(player, "!g[Shield]!y You already have a force field")
		else 
		{
			g_bomb[player] = true
			
			// Already own one
			if (user_has_weapon(player, CSW_SMOKEGRENADE))
			{
				// Increase BP ammo on it instead
				cs_set_user_bpammo(player, CSW_SMOKEGRENADE, cs_get_user_bpammo(player, CSW_SMOKEGRENADE) + 1)
				
				// Flash the ammo in hud
				message_begin(MSG_ONE_UNRELIABLE, g_msgAmmoPickup, _, player)
				write_byte(CSW_SMOKEGRENADE)
				write_byte(1)
				message_end()
				
				// Play Clip Purchase Sound
				emit_sound(player, CHAN_ITEM, recieving_sound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
			else
				fm_give_item(player, "weapon_smokegrenade")
			
			
			#if defined CAMPO_ROUND
			Color(player, "!g[Shield]!y You Bought a force field!. This, lasts 1 round complete.")
			#else
			Color(player, "!g[Shield]!y You Bought a force field!. This, lasts very little!")
			#endif
		}
		
		
	}
	
}
public fw_PlayerKilled(victim, attacker, shouldgib)
	g_bomb[victim] = false

public fw_ThinkGrenade(entity)
{    
	if(!pev_valid(entity))
		return HAM_IGNORED
        
	static Float:dmgtime    
	pev(entity, pev_dmgtime, dmgtime)
    
	if (dmgtime > get_gametime())
		return HAM_IGNORED    
    
	if((pev(entity, pev_flTimeStepSound) == NADE_TYPE_CAMPO) && (pev(entity, pev_flags) & FL_ONGROUND))
	{
		crear_ent(entity)
		return HAM_SUPERCEDE
	}
    
	return HAM_IGNORED
} 


public fw_SetModel(entity, const model[]) 
{	
	static Float:dmgtime
	pev(entity, pev_dmgtime, dmgtime)
	
	if (dmgtime == 0.0)
		return FMRES_IGNORED
	
	if (equal(model[7], "w_sm", 4))
	{		
		new owner = pev(entity, pev_owner)		
		
		if(!zp_get_user_zombie(owner) && g_bomb[owner]) 
		{
			g_bomb[owner] = false
		
			fm_set_rendering(entity, kRenderFxGlowShell, 000, 255, 255, kRenderNormal, 16)
			
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMFOLLOW) // TE id
			write_short(entity) // entity
			write_short(g_trailSpr) // sprite
			write_byte(10) // life
			write_byte(10) // width
			write_byte(000) // r
			write_byte(255) // g
			write_byte(255) // b
			write_byte(500) // brightness
			message_end()
			
			set_pev(entity, pev_flTimeStepSound, NADE_TYPE_CAMPO)
			
			set_task(TASK_TIME+0.1, "DeleteEntityGrenade", entity)
			entity_set_model(entity, w_model)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
	
}

public DeleteEntityGrenade(entity) 
{
	if (pev_valid(entity))
		engfunc(EngFunc_RemoveEntity, entity)
}

public crear_ent(id) 
{
	// Create entitity
	new iEntity = fm_create_entity("info_target")
	
	set_pev(iEntity, pev_classname, entclas)
	
	new Float: Origin[3] 
	pev(id, pev_origin, Origin) 
	
	set_pev(iEntity, pev_origin, Origin)
	engfunc(EngFunc_SetModel, iEntity, model)
	set_pev(iEntity, pev_solid, SOLID_TRIGGER)
	engfunc(EngFunc_SetSize, iEntity, Float: {-100.0, -100.0, -100.0}, Float: {100.0, 100.0, 100.0})
	set_pev(iEntity, pev_renderfx, kRenderFxGlowShell)
	set_pev(iEntity, pev_rendermode, kRenderTransAlpha)
	set_pev(iEntity, pev_renderamt, 50.0)
	
	#if defined RANDOM_COLOR
	new Float:vColor[3]
		
	for(new i = 0; i < 3; i++)
		vColor[i] = random_float(0.0, 255.0)
		
	set_pev(iEntity, pev_rendercolor, vColor)
	#endif
	
	#if defined ONE_COLOR
	set_pev(iEntity, pev_rendercolor, CampoColors)
	#endif
	
	#if defined CAMPO_TASK
	set_task(TASK_TIME, "DeleteEntity", iEntity)
	#endif
	
	emit_sound(iEntity, CHAN_AUTO, gSoundOpen, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public zp_user_infected_post(infected, infector) 
{
	if (g_bomb[infected]) 
		g_bomb[infected] = false
}

public fw_touch(toucher, touched)
{
	if (!pev_valid(toucher))
		return FMRES_IGNORED
		
	new classname[32]	
	pev(toucher, pev_classname, classname, 31)
	
	if (!equal(classname, entclas))
		return FMRES_IGNORED
		
	if( ValidTouch(touched) )
	{
		new Float:pos_ptr[3], Float:pos_ptd[3], Float:push_power = get_pcvar_float(cvar_push)
			
		pev(toucher, pev_origin, pos_ptr)
		pev(touched, pev_origin, pos_ptd)
			
		for(new i = 0; i < 3; i++)
		{
			pos_ptd[i] -= pos_ptr[i]
			pos_ptd[i] *= push_power
		}
		set_pev(touched, pev_velocity, pos_ptd)
		set_pev(touched, pev_impulse, pos_ptd)
			
		emit_sound(toucher, CHAN_AUTO, gSoundTouch, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}

	return FMRES_IGNORED
}

public DeleteEntity(entity)
{
	if(!pev_valid(entity))
		return PLUGIN_HANDLED
	
	emit_sound(entity, CHAN_AUTO, gSoundClose, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	static origin[3], Float:originF[3]
	pev(entity, pev_origin, originF)
	FVecIVec(originF, origin)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL);
	write_coord(origin[0]);		// x
	write_coord(origin[1]);		// y
	write_coord(origin[2] + 24);	// z
	write_coord(16);		// size x
	write_coord(16);		// size y
	write_coord(16);		// size z
	write_coord(random_num(-50,50));// velocity x
	write_coord(random_num(-50,50));// velocity y
	write_coord(25);		// velocity z
	write_byte(10);			// random velocity
	write_short(gGlass);		// model
	write_byte(10);			// count
	write_byte(25);			// life
	write_byte(0x01);		// flags: BREAK_GLASS
	message_end();
	
	engfunc(EngFunc_RemoveEntity, entity)
	
	return PLUGIN_HANDLED
}

stock Color(const id, const input[], any:...)
{
	static msg[191]
	vformat(msg, 190, input, 3)
	
	replace_all(msg, 190, "!g", "^4")
	replace_all(msg, 190, "!y", "^1")
	replace_all(msg, 190, "!t", "^3")
	
	message_begin(MSG_ONE_UNRELIABLE, g_SayText, _, id)
	write_byte(id)
	write_string(msg)
	message_end()
}