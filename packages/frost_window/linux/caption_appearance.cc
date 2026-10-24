#include "caption_appearance.h"

#include <cstring>

namespace frost {

const char* caption_style(GtkSettings* settings) {
  g_autofree gchar* widget_theme = nullptr;
  g_autofree gchar* icon_theme = nullptr;
  g_object_get(settings, "gtk-theme-name", &widget_theme, "gtk-icon-theme-name", &icon_theme, nullptr);
  g_autofree gchar* widget_lower = g_ascii_strdown(widget_theme == nullptr ? "" : widget_theme, -1);
  g_autofree gchar* icon_lower = g_ascii_strdown(icon_theme == nullptr ? "" : icon_theme, -1);
  // Match the selected theme, not the desktop name: KDE can run another theme.
  return strstr(widget_lower, "breeze") != nullptr || strstr(icon_lower, "breeze") != nullptr ? "breeze" : "adwaita";
}

FlValue* caption_icons(GtkIconTheme* theme, int scale) {
  FlValue* icons = fl_value_new_map();
  const char* actions[] = {"minimize", "maximize", "restore", "close"};
  const char* names[] = {"window-minimize-symbolic", "window-maximize-symbolic", "window-restore-symbolic", "window-close-symbolic"};
  const GdkRGBA mask = {1, 1, 1, 1};
  for (guint i = 0; i < G_N_ELEMENTS(names); ++i) {
    g_autoptr(GtkIconInfo) info = gtk_icon_theme_lookup_icon_for_scale(
        theme, names[i], 16, scale, static_cast<GtkIconLookupFlags>(GTK_ICON_LOOKUP_FORCE_SYMBOLIC | GTK_ICON_LOOKUP_FORCE_SIZE));
    if (info == nullptr) continue;
    gboolean symbolic = FALSE;
    g_autoptr(GError) error = nullptr;
    g_autoptr(GdkPixbuf) pixbuf = gtk_icon_info_load_symbolic(info, &mask, &mask, &mask, &mask, &symbolic, &error);
    // Arbitrary colored bitmaps cannot be safely recolored on app backgrounds.
    // The shared vector fallback is intentional, as with Electron's Linux WCO.
    if (pixbuf == nullptr || !symbolic) continue;
    g_autofree gchar* png = nullptr;
    gsize length = 0;
    if (gdk_pixbuf_save_to_buffer(pixbuf, &png, &length, "png", &error, nullptr)) {
      fl_value_set_string_take(icons, actions[i], fl_value_new_uint8_list(reinterpret_cast<const uint8_t*>(png), length));
    }
  }
  return icons;
}

}  // namespace frost
