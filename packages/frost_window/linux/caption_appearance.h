#ifndef FROST_WINDOW_CAPTION_APPEARANCE_H_
#define FROST_WINDOW_CAPTION_APPEARANCE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

namespace frost {
const char* caption_style(GtkSettings* settings);
// Owned result. Entries are symbolic PNG masks; missing icons stay absent.
FlValue* caption_icons(GtkIconTheme* theme, int scale);
}  // namespace frost

#endif
