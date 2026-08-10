/**************************************************************************/
/*  notif_plugin_gdext.cpp                                                */
/*                                                                        */
/*  GDExtension entry point. Registers NotifPluginIOS as a class and a    */
/*  singleton at SCENE level so GDScript autoloads can pick it up via     */
/*  Engine.get_singleton("NotifPluginIOS") during their _ready.           */
/**************************************************************************/

#include <gdextension_interface.h>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/godot.hpp>

#include "notif_plugin.h"

using namespace godot;

// SCENE-level lifecycle. CORE / SERVERS are reserved for engine internals,
// and EDITOR only fires inside the editor process — neither matches a
// gameplay singleton.
static void initialize_notif_plugin(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	GDREGISTER_CLASS(NotifPluginIOS);

	// Plain `Engine::register_singleton(name, instance)`; ownership is
	// shared with the plugin (we memdelete in the terminator).
	NotifPluginIOS *plugin = memnew(NotifPluginIOS);
	Engine::get_singleton()->register_singleton("NotifPluginIOS", plugin);
}

static void uninitialize_notif_plugin(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	NotifPluginIOS *plugin = NotifPluginIOS::get_singleton();
	if (plugin != nullptr) {
		Engine::get_singleton()->unregister_singleton("NotifPluginIOS");
		memdelete(plugin);
	}
}

extern "C" {

// Matches the `entry_symbol` field in notif_plugin.gdextension. Renaming
// either side requires updating the other.
GDExtensionBool GDE_EXPORT notif_plugin_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(
			p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_notif_plugin);
	init_obj.register_terminator(uninitialize_notif_plugin);
	init_obj.set_minimum_library_initialization_level(
			MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}
