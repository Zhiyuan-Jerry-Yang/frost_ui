#include "include/frost_window/frost_window_plugin.h"

#include <cmath>
#include <cstring>

struct CaptionRegion {
  double left, top, right, bottom;
};

struct _FrostWindowPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;  // Owned by the messenger; cleared through a weak pointer.
  FlView* view;
  GtkWindow* window;
  GtkSettings* settings;
  GtkGesture* press;
  GtkEventController* motion;
  GArray* regions;
  double resize_border;
  gint64 revision;
  gboolean edge_cursor;
};

G_DEFINE_TYPE(FrostWindowPlugin, frost_window_plugin, G_TYPE_OBJECT)

static double number(FlValue* value) {
  if (value == nullptr) return NAN;
  if (fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(value);
  if (fl_value_get_type(value) == FL_VALUE_TYPE_INT) return fl_value_get_int(value);
  return NAN;
}

static bool fullscreen(FrostWindowPlugin* self) {
  auto* native = gtk_widget_get_window(GTK_WIDGET(self->window));
  return native != nullptr && (gdk_window_get_state(native) & GDK_WINDOW_STATE_FULLSCREEN) != 0;
}

static FlValue* buttons(const gchar* layout, bool resizable) {
  FlValue* result = fl_value_new_list();
  g_auto(GStrv) names = g_strsplit(layout == nullptr ? "" : layout, ",", -1);
  for (gchar** name = names; *name != nullptr; ++name) {
    if (strcmp(*name, "close") == 0 || strcmp(*name, "minimize") == 0 ||
        (resizable && strcmp(*name, "maximize") == 0)) {
      fl_value_append_take(result, fl_value_new_string(*name));
    }
  }
  return result;
}

static FlValue* state(FrostWindowPlugin* self) {
  FlValue* result = fl_value_new_map();
  g_autofree gchar* layout = nullptr;
  g_object_get(self->settings, "gtk-decoration-layout", &layout, nullptr);
  g_auto(GStrv) sides = g_strsplit(layout == nullptr ? ":minimize,maximize,close" : layout, ":", 2);
  const bool resizable = gtk_window_get_resizable(self->window);
  fl_value_set_string_take(result, "captionMode", fl_value_new_string("client"));
  fl_value_set_string_take(result, "leftButtons", buttons(sides[0], resizable));
  fl_value_set_string_take(result, "rightButtons", buttons(sides[0] == nullptr ? nullptr : sides[1], resizable));
  fl_value_set_string_take(result, "maximized", fl_value_new_bool(gtk_window_is_maximized(self->window)));
  fl_value_set_string_take(result, "active", fl_value_new_bool(gtk_window_is_active(self->window)));
  auto* native = gtk_widget_get_window(GTK_WIDGET(self->window));
  fl_value_set_string_take(result, "minimized", fl_value_new_bool(native != nullptr && (gdk_window_get_state(native) & GDK_WINDOW_STATE_ICONIFIED) != 0));
  fl_value_set_string_take(result, "revision", fl_value_new_int(self->revision));
  return result;
}

static void publish(FrostWindowPlugin* self) {
  if (self->window == nullptr || self->channel == nullptr) return;
  ++self->revision;
  g_autoptr(FlValue) value = state(self);
  fl_method_channel_invoke_method(self->channel, "stateChanged", value, nullptr, nullptr, nullptr);
}

static bool caption_at(FrostWindowPlugin* self, double x, double y) {
  for (guint i = 0; i < self->regions->len; ++i) {
    const auto& region = g_array_index(self->regions, CaptionRegion, i);
    if (x >= region.left && x < region.right && y >= region.top && y < region.bottom) return true;
  }
  return false;
}

static bool resize_edge(FrostWindowPlugin* self, double x, double y, GdkWindowEdge* edge) {
  if (gtk_window_is_maximized(self->window) || fullscreen(self) || !gtk_window_get_resizable(self->window)) return false;
  const double border = self->resize_border;
  const int width = gtk_widget_get_allocated_width(GTK_WIDGET(self->view));
  const int height = gtk_widget_get_allocated_height(GTK_WIDGET(self->view));
  const bool left = x < border, right = x >= width - border;
  const bool top = y < border, bottom = y >= height - border;
  if (!left && !right && !top && !bottom) return false;
  *edge = top ? (left ? GDK_WINDOW_EDGE_NORTH_WEST : right ? GDK_WINDOW_EDGE_NORTH_EAST : GDK_WINDOW_EDGE_NORTH)
              : bottom ? (left ? GDK_WINDOW_EDGE_SOUTH_WEST : right ? GDK_WINDOW_EDGE_SOUTH_EAST : GDK_WINDOW_EDGE_SOUTH)
                       : left ? GDK_WINDOW_EDGE_WEST : GDK_WINDOW_EDGE_EAST;
  return true;
}

static void toggle_maximized(FrostWindowPlugin* self) {
  if (gtk_window_is_maximized(self->window)) gtk_window_unmaximize(self->window);
  else gtk_window_maximize(self->window);
}

static bool show_menu(GdkWindow* window, const GdkEvent* event) {
  g_autoptr(GdkEvent) owned = gdk_event_copy(event);
  return gdk_window_show_window_menu(window, owned);
}

static void pressed(GtkGestureMultiPress* gesture, gint count, gdouble x, gdouble y, FrostWindowPlugin* self) {
  if (self->window == nullptr) return;
  const auto* event = gtk_gesture_get_last_event(GTK_GESTURE(gesture), gtk_gesture_single_get_current_sequence(GTK_GESTURE_SINGLE(gesture)));
  if (event == nullptr) return;
  guint button = gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture));
  if (button == 0) button = 1;  // A touch sequence uses the same native device grab.
  GdkWindowEdge edge;
  const bool resizing = button == 1 && resize_edge(self, x, y, &edge);
  if (!resizing && !caption_at(self, x, y)) return;
  auto* native = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (native == nullptr) return;
  if (button == 3) {
    // The compositor receives the original input serial on Wayland.
    if (show_menu(native, event)) gtk_gesture_set_state(GTK_GESTURE(gesture), GTK_EVENT_SEQUENCE_CLAIMED);
    return;
  }
  if (button != 1) return;
  gtk_gesture_set_state(GTK_GESTURE(gesture), GTK_EVENT_SEQUENCE_CLAIMED);
  if (count == 2 && !resizing) {
    g_autofree gchar* action = nullptr;
    g_object_get(self->settings, "gtk-titlebar-double-click", &action, nullptr);
    if (g_strcmp0(action, "toggle-maximize") == 0 && gtk_window_get_resizable(self->window)) toggle_maximized(self);
    else if (g_strcmp0(action, "minimize") == 0) gtk_window_iconify(self->window);
    else if (g_strcmp0(action, "lower") == 0) gdk_window_lower(native);
    else if (g_strcmp0(action, "menu") == 0) show_menu(native, event);
    return;
  }
  gdouble root_x = 0, root_y = 0;
  gdk_event_get_root_coords(event, &root_x, &root_y);
  GdkDevice* device = gdk_event_get_device(event);
  if (resizing) gdk_window_begin_resize_drag_for_device(native, edge, device, button, root_x, root_y, gdk_event_get_time(event));
  else gdk_window_begin_move_drag_for_device(native, device, button, root_x, root_y, gdk_event_get_time(event));
}

static void motion(GtkEventControllerMotion*, gdouble x, gdouble y, FrostWindowPlugin* self) {
  if (self->window == nullptr) return;
  auto* native = gtk_widget_get_window(GTK_WIDGET(self->view));
  if (native == nullptr) return;
  GdkWindowEdge edge;
  if (resize_edge(self, x, y, &edge)) {
    const char* names[] = {"nw-resize", "n-resize", "ne-resize", "w-resize", "e-resize", "sw-resize", "s-resize", "se-resize"};
    g_autoptr(GdkCursor) cursor = gdk_cursor_new_from_name(gtk_widget_get_display(GTK_WIDGET(self->view)), names[edge]);
    gdk_window_set_cursor(native, cursor);
    self->edge_cursor = TRUE;
  } else if (self->edge_cursor) {
    gdk_window_set_cursor(native, nullptr);
    self->edge_cursor = FALSE;
  }
}

static gboolean window_state(GtkWidget*, GdkEventWindowState*, FrostWindowPlugin* self) { publish(self); return FALSE; }
static void changed(GObject*, GParamSpec*, FrostWindowPlugin* self) { publish(self); }

static void attach(FrostWindowPlugin* self) {
  if (self->window != nullptr) return;
  GtkWidget* top = gtk_widget_get_toplevel(GTK_WIDGET(self->view));
  if (!GTK_IS_WINDOW(top)) return;
  self->window = GTK_WINDOW(top);
  g_object_add_weak_pointer(G_OBJECT(top), reinterpret_cast<gpointer*>(&self->window));
  // This is the window's decoration policy, before its first visible frame.
  // GTK/GDK still own compositor moves, resize grabs and window state.
  gtk_window_set_decorated(self->window, FALSE);
  g_signal_connect_object(top, "window-state-event", G_CALLBACK(window_state), self, G_CONNECT_DEFAULT);
  g_signal_connect_object(top, "notify::is-active", G_CALLBACK(changed), self, G_CONNECT_DEFAULT);
  publish(self);
}

static void hierarchy(GtkWidget*, GtkWidget*, FrostWindowPlugin* self) { attach(self); }

static void handle(FrostWindowPlugin* self, FlMethodCall* call) {
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  attach(self);
  if (self->window == nullptr) {
    fl_method_call_respond_error(call, "window_unavailable", "No GTK window is attached.", nullptr, nullptr);
    return;
  }
  if (strcmp(method, "getState") == 0 || strcmp(method, "getDiagnostics") == 0) {
    g_autoptr(FlValue) value = state(self);
    fl_method_call_respond_success(call, value, nullptr);
    return;
  }
  bool valid = true;
  if (strcmp(method, "configure") == 0) {
    valid = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_LIST && fl_value_get_length(args) == 2;
    if (valid) {
      const double width = number(fl_value_get_list_value(args, 0)), height = number(fl_value_get_list_value(args, 1));
      valid = std::isfinite(width) && std::isfinite(height) && width > 0 && height > 0;
      if (valid) {
        GdkGeometry geometry{};
        geometry.min_width = std::ceil(width);
        geometry.min_height = std::ceil(height);
        gtk_window_set_geometry_hints(self->window, nullptr, &geometry, GDK_HINT_MIN_SIZE);
      }
    }
  } else if (strcmp(method, "setRegions") == 0) {
    valid = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_LIST;
    g_autoptr(GArray) next = g_array_new(FALSE, FALSE, sizeof(CaptionRegion));
    for (guint i = 0; valid && i < fl_value_get_length(args); ++i) {
      FlValue* row = fl_value_get_list_value(args, i);
      valid = fl_value_get_type(row) == FL_VALUE_TYPE_LIST && fl_value_get_length(row) == 5;
      if (!valid) break;
      CaptionRegion region{number(fl_value_get_list_value(row, 0)), number(fl_value_get_list_value(row, 1)), number(fl_value_get_list_value(row, 2)), number(fl_value_get_list_value(row, 3))};
      FlValue* kind = fl_value_get_list_value(row, 4);
      valid = std::isfinite(region.left) && std::isfinite(region.top) && std::isfinite(region.right) && std::isfinite(region.bottom) && region.right >= region.left && region.bottom >= region.top && fl_value_get_type(kind) == FL_VALUE_TYPE_STRING;
      if (valid) valid = strcmp(fl_value_get_string(kind), "caption") == 0 || strcmp(fl_value_get_string(kind), "maximize") == 0;
      if (valid && strcmp(fl_value_get_string(kind), "caption") == 0) g_array_append_val(next, region);
    }
    if (valid) { g_array_set_size(self->regions, 0); g_array_append_vals(self->regions, next->data, next->len); }
  } else if (strcmp(method, "setResizeBorder") == 0) {
    const double border = number(args);
    valid = std::isfinite(border) && border > 0 && border < 64;
    if (valid) self->resize_border = border;
  } else if (strcmp(method, "setToolbar") == 0) {
    valid = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP;
    FlValue* title = valid ? fl_value_lookup_string(args, "title") : nullptr;
    valid = title != nullptr && fl_value_get_type(title) == FL_VALUE_TYPE_STRING;
    if (valid) gtk_window_set_title(self->window, fl_value_get_string(title));
  } else if (strcmp(method, "setBackdrop") == 0) {
    // Native Mica is Windows-only; the shared ambient/solid material remains active.
  } else if (strcmp(method, "minimize") == 0) gtk_window_iconify(self->window);
  else if (strcmp(method, "toggleMaximized") == 0) toggle_maximized(self);
  else if (strcmp(method, "close") == 0) gtk_window_close(self->window);
  else { fl_method_call_respond_not_implemented(call, nullptr); return; }
  if (valid) fl_method_call_respond_success(call, nullptr, nullptr);
  else fl_method_call_respond_error(call, "invalid_arguments", "Invalid window request.", nullptr, nullptr);
}

static void method_call(FlMethodChannel*, FlMethodCall* call, gpointer data) { handle(FROST_WINDOW_PLUGIN(data), call); }

static void frost_window_plugin_dispose(GObject* object) {
  auto* self = FROST_WINDOW_PLUGIN(object);
  if (self->channel != nullptr) g_object_remove_weak_pointer(G_OBJECT(self->channel), reinterpret_cast<gpointer*>(&self->channel));
  if (self->window != nullptr) g_object_remove_weak_pointer(G_OBJECT(self->window), reinterpret_cast<gpointer*>(&self->window));
  g_clear_object(&self->press);
  g_clear_object(&self->motion);
  g_clear_pointer(&self->regions, g_array_unref);
  G_OBJECT_CLASS(frost_window_plugin_parent_class)->dispose(object);
}

static void frost_window_plugin_class_init(FrostWindowPluginClass* klass) { G_OBJECT_CLASS(klass)->dispose = frost_window_plugin_dispose; }
static void frost_window_plugin_init(FrostWindowPlugin* self) { self->regions = g_array_new(FALSE, FALSE, sizeof(CaptionRegion)); self->resize_border = 4; }

void frost_window_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(FrostWindowPlugin) self = FROST_WINDOW_PLUGIN(g_object_new(frost_window_plugin_get_type(), nullptr));
  self->view = fl_plugin_registrar_get_view(registrar);
  self->settings = gtk_widget_get_settings(GTK_WIDGET(self->view));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar), "frost_window", FL_METHOD_CODEC(codec));
  self->channel = channel;
  g_object_add_weak_pointer(G_OBJECT(channel), reinterpret_cast<gpointer*>(&self->channel));
  fl_method_channel_set_method_call_handler(channel, method_call, g_object_ref(self), g_object_unref);
  self->press = gtk_gesture_multi_press_new(GTK_WIDGET(self->view));
  gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(self->press), 0);
  gtk_event_controller_set_propagation_phase(GTK_EVENT_CONTROLLER(self->press), GTK_PHASE_CAPTURE);
  g_signal_connect_object(self->press, "pressed", G_CALLBACK(pressed), self, G_CONNECT_DEFAULT);
  self->motion = gtk_event_controller_motion_new(GTK_WIDGET(self->view));
  gtk_event_controller_set_propagation_phase(self->motion, GTK_PHASE_CAPTURE);
  g_signal_connect_object(self->motion, "motion", G_CALLBACK(motion), self, G_CONNECT_DEFAULT);
  g_signal_connect_object(self->view, "hierarchy-changed", G_CALLBACK(hierarchy), self, G_CONNECT_DEFAULT);
  g_signal_connect_object(self->settings, "notify::gtk-decoration-layout", G_CALLBACK(changed), self, G_CONNECT_DEFAULT);
  attach(self);
  fl_method_channel_invoke_method(channel, "registered", nullptr, nullptr, nullptr, nullptr);
}
