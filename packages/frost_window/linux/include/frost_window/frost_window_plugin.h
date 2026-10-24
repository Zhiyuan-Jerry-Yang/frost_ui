#ifndef FLUTTER_PLUGIN_FROST_WINDOW_PLUGIN_H_
#define FLUTTER_PLUGIN_FROST_WINDOW_PLUGIN_H_
#include <flutter_linux/flutter_linux.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif
G_BEGIN_DECLS
G_DECLARE_FINAL_TYPE(FrostWindowPlugin, frost_window_plugin, FROST, WINDOW_PLUGIN, GObject)
FLUTTER_PLUGIN_EXPORT void frost_window_plugin_register_with_registrar(FlPluginRegistrar* registrar);
G_END_DECLS
#endif
