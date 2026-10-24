// Exercise the production GTK state/decoration path without showing a window.
#include "../linux/frost_window_plugin.cc"

#include <cstdio>
#include <glib/gstdio.h>

static int checks = 0;
static void check(bool passed, const char* name) {
  if (!passed) { fprintf(stderr, "FAIL: %s\n", name); exit(1); }
  ++checks;
}
static bool actions(FlValue* snapshot, const char* side, const char* expected) {
  g_autofree gchar* description = fl_value_to_string(fl_value_lookup_string(snapshot, side));
  return strcmp(description, expected) == 0;
}

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  g_autoptr(FrostWindowPlugin) plugin = FROST_WINDOW_PLUGIN(g_object_new(frost_window_plugin_get_type(), nullptr));
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  GtkWidget* view = gtk_drawing_area_new();
  gtk_container_add(GTK_CONTAINER(window), view);
  plugin->view = reinterpret_cast<FlView*>(view);
  plugin->settings = gtk_widget_get_settings(view);
  plugin->icon_theme = gtk_icon_theme_get_for_screen(gtk_widget_get_screen(view));
  attach(plugin);
  check(!gtk_window_get_decorated(GTK_WINDOW(window)), "no second system titlebar");
  g_object_set(plugin->settings, "gtk-decoration-layout", "menu:close", nullptr);
  g_autoptr(FlValue) single = state(plugin);
  check(actions(single, "leftButtons", "[]") && actions(single, "rightButtons", "[close]"), "single close button");
  check(strcmp(fl_value_get_string(fl_value_lookup_string(single, "captionStyle")), "adwaita") == 0, "Adwaita baseline");
  g_object_set(plugin->settings, "gtk-decoration-layout", "close:minimize,maximize", nullptr);
  g_autoptr(FlValue) split = state(plugin);
  check(actions(split, "leftButtons", "[close]") && actions(split, "rightButtons", "[minimize, maximize]"), "split button order");
  gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
  gtk_window_set_deletable(GTK_WINDOW(window), FALSE);
  g_autoptr(FlValue) limited = state(plugin);
  check(actions(limited, "leftButtons", "[]") && actions(limited, "rightButtons", "[minimize]"), "window capabilities filter buttons");
  g_object_set(plugin->settings, "gtk-theme-name", "Breeze-Dark", nullptr);
  appearance_changed(nullptr, nullptr, plugin);
  g_autoptr(FlValue) breeze = state(plugin);
  check(strcmp(fl_value_get_string(fl_value_lookup_string(breeze, "captionStyle")), "breeze") == 0, "live Breeze theme selection");

  // A controlled empty theme verifies the missing-resource path without
  // changing the user's settings or depending on installed theme packages.
  g_autofree gchar* empty = g_dir_make_tmp("frost-caption-icons-XXXXXX", nullptr);
  check(empty != nullptr, "temporary theme directory");
  g_autofree gchar* theme_root = g_build_filename(empty, "FrostBrokenIcons", nullptr);
  g_autofree gchar* theme_icons = g_build_filename(theme_root, "scalable", "actions", nullptr);
  g_mkdir_with_parents(theme_icons, 0700);
  g_autofree gchar* index = g_build_filename(theme_root, "index.theme", nullptr);
  g_file_set_contents(index, "[Icon Theme]\nName=FrostBrokenIcons\nDirectories=scalable/actions\n[scalable/actions]\nSize=16\nType=Scalable\nMinSize=1\nMaxSize=128\nContext=Actions\n", -1, nullptr);
  const char* broken_names[] = {"window-minimize-symbolic.svg", "window-maximize-symbolic.svg", "window-restore-symbolic.svg", "window-close-symbolic.svg"};
  for (const char* name : broken_names) {
    g_autofree gchar* file = g_build_filename(theme_icons, name, nullptr);
    g_file_set_contents(file, "invalid SVG", -1, nullptr);
  }
  g_autoptr(GtkIconTheme) missing_theme = gtk_icon_theme_new();
  const gchar* search[] = {empty};
  gtk_icon_theme_set_search_path(missing_theme, search, 1);
  gtk_icon_theme_set_custom_theme(missing_theme, "FrostBrokenIcons");
  g_autoptr(FlValue) missing = frost::caption_icons(missing_theme, 1);
  check(fl_value_get_length(missing) == 0, "missing icons use shared vector fallback");
  for (const char* name : broken_names) {
    g_autofree gchar* file = g_build_filename(theme_icons, name, nullptr);
    g_remove(file);
  }
  g_remove(index);
  g_rmdir(theme_icons);
  g_autofree gchar* scalable = g_build_filename(theme_root, "scalable", nullptr);
  g_rmdir(scalable);
  g_rmdir(theme_root);
  g_rmdir(empty);

  g_autoptr(FlValue) icons = frost::caption_icons(plugin->icon_theme, 2);
  check(fl_value_get_length(icons) > 0, "installed symbolic icons load");
  for (size_t i = 0; i < fl_value_get_length(icons); ++i) {
    FlValue* value = fl_value_get_map_value(icons, i);
    g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new();
    check(gdk_pixbuf_loader_write(loader, fl_value_get_uint8_list(value), fl_value_get_length(value), nullptr), "PNG mask decodes");
    check(gdk_pixbuf_loader_close(loader, nullptr), "PNG mask completes");
    GdkPixbuf* pixbuf = gdk_pixbuf_loader_get_pixbuf(loader);
    check(gdk_pixbuf_get_width(pixbuf) == 32 && gdk_pixbuf_get_height(pixbuf) == 32, "2x theme icon scale");
  }
  gtk_widget_destroy(window);
  printf("PASS: %d native GTK caption checks; window_shown=false\n", checks);
  return 0;
}
