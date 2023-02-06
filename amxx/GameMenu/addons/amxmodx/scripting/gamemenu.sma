#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Game Menu"
#define VERSION "1.2a"
#define AUTHOR "DJ_WEST & Lukmanov Ildar & Accelerator"

#define GAMEMENU_FILE "resource/GameMenu.res"
#define MAX_SIZE 1012

new g_Text[MAX_SIZE], g_Text_Def[MAX_SIZE]
new g_Files[][] = {"gamemenu", "gamemenu_default"}

public plugin_init() 
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    register_clcmd("say /setmenu", "cmd_setmenu")
    register_clcmd("say_team /setmenu", "cmd_setmenu")
    register_clcmd("say /servers", "cmd_setmenu")
    register_clcmd("say_team /servers", "cmd_setmenu")
    register_clcmd("say /resmenu", "cmd_resmenu")
    register_clcmd("say_team /resmenu", "cmd_resmenu")

    register_dictionary("gm.txt")
}

public plugin_cfg()
{
    new configsdir[64], s_File[128], i_File
    
    // Получаем путь к директории с конфигами AMXX в s_File.
    get_configsdir(configsdir, charsmax(configsdir))

    for (new i = 0; i < sizeof g_Files; i++)
	{
        // Формируем путь к gamemenu.txt файлу, используя путь к конфигам, и сохраняем в s_File.
        format(s_File, charsmax(s_File), "%s/%s.txt", configsdir, g_Files[i])
    
        // Открываем файл для чтения
        i_File = fopen(s_File, "r")
        
        if (!equal(g_Files[i], "gamemenu_default"))
            fgets(i_File, g_Text, MAX_SIZE)
        else
            fgets(i_File, g_Text_Def, MAX_SIZE)
    
        // Закрываем файл
        fclose(i_File)
    }
}

public cmd_setmenu(id)
    GMUpdate(id, true)

public cmd_resmenu(id)
    GMUpdate(id, false)

public GMUpdate(id, opt)
{
    // Указываем путь к файлу resource/GameMenu.res
    client_cmd(id, "motdfile %s", GAMEMENU_FILE)
    
    if (opt)
        client_cmd(id, "motd_write %s", g_Text)
	else
        client_cmd(id, "motd_write %s", g_Text_Def)
    
    // Возвращаем значение команды по умолчанию
    client_cmd(id, "motdfile motd.txt") 

    client_print(id, print_chat, "[AMXX] %L", id, "OK")
}

public client_putinserver(id)
   set_task(20.0, "info", id)
	
public info(id)
{
    client_print(id, print_chat, "[AMXX] %L", id, "SETMENUCMD")
    client_print(id, print_chat, "[AMXX] %L", id, "DEFAULT")
}

public plugin_precache()
{
    precache_generic("resource/GameMenu.tga");
    return PLUGIN_HANDLED
}