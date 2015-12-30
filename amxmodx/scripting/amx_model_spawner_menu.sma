#include < amxmodx >
#include < amxmisc >
#include < engine >
#include < cellarray >

#define PLUGIN "AMX Model Spawner Menu"
#define VERSION "1.0"
#define AUTHOR "AurZum"

new const NAME_CONFIG_FILE[] = "%s/spawn_models.ini";
new const CLASS_NAME[] = "env_tree";
new const NAME_FOLD_MAP_MODELS[] = "%s/map_spawn_models";

new Array:model_list;  
new g_szConfigFile[ 128 ];

public plugin_init( ) {
    register_plugin(PLUGIN, VERSION, AUTHOR);  
    register_clcmd("amx_model_spawner_menu", "show_model_spawner_menu", ADMIN_LEVEL_E, "");
}

public show_model_spawner_menu(id) {
    new menu = menu_create("AMX Model Spawner Menu", "menuHandel_model_spawner_menu");

    menu_additem(menu, "Add model",     "", 0);
    menu_additem(menu, "Remove model",  "", 0); 
    //menu_additem(menu, "Remove all models",  "", 0); 
    
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_setprop(menu, MPROP_NUMBER_COLOR, "\w");
    
    menu_display(id, menu, 0);
    return PLUGIN_HANDLED;
}

public menuHandel_model_spawner_menu(id, menu, item) {
    if(item == MENU_EXIT) {
        menu_cancel(id);
        return PLUGIN_HANDLED;
    }

    new command[6], name[64], access, callback;

    menu_item_getinfo(menu, item, access, command, charsmax(command), name, charsmax(name), callback);
    
    switch(item) {
        case 0: show_list_model_menu(id);
        case 1: CmdSpawnRemove(id);
        //case 2: client_print(id, print_chat, "You have selected RAM");       
    }

    menu_destroy(menu);

    return PLUGIN_HANDLED;
}

public show_list_model_menu(id) {
    new menu = menu_create("List of model : ", "menuHandel_list_model_menu");
      
    new buffer[64];
    new size = ArraySize (model_list);
    for(new i=0;i < size;i++) {
        ArrayGetString(model_list, i, buffer,charsmax(buffer));
        menu_additem(menu, buffer, "", 0);       
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_setprop(menu, MPROP_NUMBER_COLOR, "\w");

    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public menuHandel_list_model_menu(id, menu, item) {
    if(item == MENU_EXIT) {
        menu_cancel(id);
        return PLUGIN_HANDLED;
    }

    new command[6], name[64], access, callback;

    menu_item_getinfo(menu, item, access, command, charsmax(command), name, charsmax(name), callback);

    
    new buffer[64];
    ArrayGetString(model_list, item, buffer,charsmax(buffer));
    CmdSpawnTree(id,buffer);
    

    menu_destroy(menu);

    return PLUGIN_HANDLED;
}

public plugin_precache( ) {
    model_list = ArrayCreate(64,1);
    new configsdir[128], configFile [128];
    get_configsdir(configsdir,charsmax(configsdir));
    formatex(configFile,charsmax(configFile),NAME_CONFIG_FILE,configsdir);
    if (!file_exists(configFile)) 
        return;
    
    new buffer_line[64], len, i;
    new index = read_file(configFile, 0, buffer_line, charsmax(buffer_line),len);
    
    while (index != 0) {
        if(!equali(buffer_line[4],"")) {                  
            if (file_exists(buffer_line)) {
                precache_model(buffer_line);
                ArrayPushString(model_list,buffer_line);
                i++;              
            }           
        }
        index = read_file(configFile, index, buffer_line, charsmax(buffer_line),len);
    }     
}
    
public plugin_cfg( ) {
    new szMapName[ 32 ];
    get_mapname( szMapName, charsmax (szMapName) );
    strtolower( szMapName );  
    
    new datadir[128], dataFolder [128];
    get_datadir(datadir,charsmax(datadir));
    formatex(dataFolder,charsmax(dataFolder),NAME_FOLD_MAP_MODELS,datadir);
    
    formatex( g_szConfigFile, charsmax (g_szConfigFile), dataFolder );
    
    if( !dir_exists( g_szConfigFile ) ) {
        mkdir( g_szConfigFile );      
        format( g_szConfigFile, charsmax (g_szConfigFile), "%s/%s.txt", g_szConfigFile, szMapName );     
        return;
    }
    
    format( g_szConfigFile, charsmax (g_szConfigFile), "%s/%s.txt", g_szConfigFile, szMapName );
    
    if( !file_exists( g_szConfigFile ) )
        return;
    
    new iFile = fopen( g_szConfigFile, "rt" );
    
    if( !iFile )
        return;
    
    new model[64];
    new Float:vOrigin[ 3 ], x[ 16 ], y[ 16 ], z[ 16 ], szData[sizeof (model) + sizeof( x ) + sizeof( y ) + sizeof( z ) + 4 ];
    
    while( !feof( iFile ) ) {
        fgets( iFile, szData, charsmax( szData ) );
        trim( szData );
        
        if( !szData[ 0 ] )
            continue;
        
        parse(szData, model, charsmax(model), x, charsmax(x), y, charsmax(y), z, charsmax(z) );
        
        vOrigin[ 0 ] = str_to_float( x );
        vOrigin[ 1 ] = str_to_float( y );
        vOrigin[ 2 ] = str_to_float( z );
        
        if (-1 != ArrayFindString(model_list, model)) 
            CreateTree( vOrigin , model);
    }
    
    fclose( iFile );
}

CmdSpawnTree( const id, const model[]) {
    
    new Float:vOrigin[ 3 ];
    entity_get_vector( id, EV_VEC_origin, vOrigin );
    
    if( CreateTree( vOrigin,model) )
        SaveTrees();
    
    return PLUGIN_HANDLED;
}

CmdSpawnRemove(const id) {   
    new Float:vOrigin[ 3 ], szClassName[ 10 ], iEntity = -1, iDeleted;
    entity_get_vector( id, EV_VEC_origin, vOrigin );
    
    while( ( iEntity = find_ent_in_sphere( iEntity, vOrigin, 100.0 ) ) > 0 ) {
        entity_get_string( iEntity, EV_SZ_classname, szClassName, charsmax(szClassName) );
        
        if( equal( szClassName, CLASS_NAME ) ) {
            remove_entity( iEntity );
            
            iDeleted++;
        }
    }
    
    if( iDeleted > 0 )
        SaveTrees();
    
    console_print( id, "[AMXX] Deleted %i trees.%s", iDeleted, iDeleted == 0 ? " You need to stand in tree to remove it" : "" );
    
    return PLUGIN_HANDLED;
}

CreateTree( const Float:vOrigin[ 3 ], const model[] ) {
    new iEntity = create_entity( "info_target" );
    
    if( !iEntity )
        return 0;
    
    entity_set_string( iEntity, EV_SZ_classname, CLASS_NAME );
    entity_set_int( iEntity, EV_INT_solid, SOLID_NOT );
    entity_set_int( iEntity, EV_INT_movetype, MOVETYPE_NONE );
    
    entity_set_size( iEntity, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 36.0 } );
    entity_set_origin( iEntity, vOrigin );
    entity_set_model( iEntity, model );
    
    drop_to_floor( iEntity );
    return iEntity;
}

SaveTrees() {
    if( file_exists( g_szConfigFile ) )
        delete_file( g_szConfigFile );
    
    new iFile = fopen( g_szConfigFile, "wt" );
    
    if( !iFile )
        return;
    
    new Float:vOrigin[ 3 ], iEntity;
    new model[64];
    
    while( ( iEntity = find_ent_by_class( iEntity, CLASS_NAME ) ) > 0 ) {
        entity_get_vector( iEntity, EV_VEC_origin, vOrigin );
        entity_get_string( iEntity, EV_SZ_model, model, charsmax(model));
             
        fprintf( iFile, "%s %f %f %f^n", model, vOrigin[ 0 ], vOrigin[ 1 ], vOrigin[ 2 ] );
    }
    
    fclose( iFile );
}