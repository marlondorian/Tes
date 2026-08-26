#include "native_control_manager.h"
#include <iostream>

static FlValue* lookup_map_value(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) return nullptr;
  return fl_value_lookup_string(map, key);
}

static std::string get_string_val(FlValue* map, const char* key) {
  FlValue* v = lookup_map_value(map, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
    return fl_value_get_string(v);
  }
  return "";
}

static double get_double_val(FlValue* map, const char* key) {
  FlValue* v = lookup_map_value(map, key);
  if (v == nullptr) return 0.0;
  if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(v);
  if (fl_value_get_type(v) == FL_VALUE_TYPE_INT) return static_cast<double>(fl_value_get_int(v));
  return 0.0;
}

static bool get_bool_val(FlValue* map, const char* key) {
  FlValue* v = lookup_map_value(map, key);
  if (v != nullptr && fl_value_get_type(v) == FL_VALUE_TYPE_BOOL) {
    return fl_value_get_bool(v);
  }
  return false;
}


NativeControlManager::NativeControlManager(GtkFixed* fixed_container,
                                           GtkWidget* fl_view_widget,
                                           GtkHeaderBar* header_bar,
                                           GtkActionBar* action_bar)
    : fixed_container_(fixed_container),
      fl_view_widget_(fl_view_widget),
      header_bar_(header_bar),
      action_bar_(action_bar) {
}

NativeControlManager::~NativeControlManager() {
  if (button_channel_ != nullptr) {
    g_object_unref(button_channel_);
    button_channel_ = nullptr;
  }
  if (native_channel_ != nullptr) {
    g_object_unref(native_channel_);
    native_channel_ = nullptr;
  }
  if (scaffold_channel_ != nullptr) {
    g_object_unref(scaffold_channel_);
    scaffold_channel_ = nullptr;
  }
  if (header_bar_css_provider_ != nullptr) {
    g_object_unref(header_bar_css_provider_);
    header_bar_css_provider_ = nullptr;
  }
  if (action_bar_css_provider_ != nullptr) {
    g_object_unref(action_bar_css_provider_);
    action_bar_css_provider_ = nullptr;
  }
}

void NativeControlManager::SetupChannels(FlBinaryMessenger* messenger) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  button_channel_ = fl_method_channel_new(messenger,
                                          "com.example.macos_native_widgets/button",
                                          FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(button_channel_,
                                            OnButtonMethodCall,
                                            this,
                                            nullptr);

  native_channel_ = fl_method_channel_new(messenger,
                                          "com.example.macos_native_widgets/native",
                                          FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(native_channel_,
                                            OnNativeMethodCall,
                                            this,
                                            nullptr);

  scaffold_channel_ = fl_method_channel_new(messenger,
                                             "com.example.macos_native_widgets/scaffold",
                                             FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(scaffold_channel_,
                                            OnScaffoldMethodCall,
                                            this,
                                            nullptr);

  AttachScrollHandler(GTK_WIDGET(fixed_container_));
}

void NativeControlManager::GrabFlutterFocus() {
  if (fl_view_widget_ != nullptr && GTK_IS_WIDGET(fl_view_widget_)) {
    gtk_widget_set_can_focus(fl_view_widget_, TRUE);
    gtk_widget_grab_focus(fl_view_widget_);
  }
}

void NativeControlManager::AttachScrollHandler(GtkWidget* widget) {
  if (widget == nullptr) return;
  gtk_widget_add_events(widget, GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK);
  g_signal_connect(widget, "scroll-event", G_CALLBACK(OnWidgetScrollEvent), this);
}

gboolean NativeControlManager::OnWidgetScrollEvent(GtkWidget* widget, GdkEventScroll* event, gpointer user_data) {
  auto* self = static_cast<NativeControlManager*>(user_data);
  if (self == nullptr || self->fl_view_widget_ == nullptr) {
    return FALSE;
  }

  GtkWidget* fl_view = self->fl_view_widget_;

  gint fl_x = 0;
  gint fl_y = 0;
  gtk_widget_translate_coordinates(widget, fl_view, static_cast<gint>(event->x), static_cast<gint>(event->y), &fl_x, &fl_y);

  GdkEvent* event_copy = gdk_event_copy(reinterpret_cast<GdkEvent*>(event));
  if (event_copy->scroll.window != nullptr) {
    g_object_unref(event_copy->scroll.window);
  }
  GdkWindow* fl_win = gtk_widget_get_window(fl_view);
  event_copy->scroll.window = fl_win != nullptr ? GDK_WINDOW(g_object_ref(fl_win)) : nullptr;
  event_copy->scroll.x = static_cast<gdouble>(fl_x);
  event_copy->scroll.y = static_cast<gdouble>(fl_y);

  gboolean handled = FALSE;
  g_signal_emit_by_name(fl_view, "scroll-event", event_copy, &handled);

  if (GTK_IS_CONTAINER(fl_view)) {
    gtk_container_forall(GTK_CONTAINER(fl_view), [](GtkWidget* child, gpointer data) {
      gboolean child_handled = FALSE;
      g_signal_emit_by_name(child, "scroll-event", static_cast<GdkEvent*>(data), &child_handled);
    }, event_copy);
  }

  gdk_event_free(event_copy);

  return FALSE;
}

void NativeControlManager::OnButtonMethodCall(FlMethodChannel* channel,
                                               FlMethodCall* method_call,
                                               gpointer user_data) {
  auto* self = static_cast<NativeControlManager*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "createButton") == 0) {
    response = self->HandleCreateButton(args);
  } else if (g_strcmp0(method, "updatePosition") == 0) {
    response = self->HandleUpdateButtonPosition(args);
  } else if (g_strcmp0(method, "removeButton") == 0) {
    response = self->HandleRemoveButton(args);
  } else if (g_strcmp0(method, "setVisibility") == 0) {
    response = self->HandleSetButtonVisibility(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

void NativeControlManager::OnNativeMethodCall(FlMethodChannel* channel,
                                               FlMethodCall* method_call,
                                               gpointer user_data) {
  auto* self = static_cast<NativeControlManager*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "createSwitch") == 0) {
    response = self->HandleCreateSwitch(args);
  } else if (g_strcmp0(method, "updateSwitchValue") == 0) {
    response = self->HandleUpdateSwitchValue(args);
  } else if (g_strcmp0(method, "removeSwitch") == 0) {
    response = self->HandleRemoveSwitch(args);
  } else if (g_strcmp0(method, "createInput") == 0) {
    response = self->HandleCreateInput(args);
  } else if (g_strcmp0(method, "removeInput") == 0) {
    response = self->HandleRemoveInput(args);
  } else if (g_strcmp0(method, "updatePosition") == 0) {
    response = self->HandleUpdateNativePosition(args);
  } else if (g_strcmp0(method, "setVisibility") == 0) {
    response = self->HandleSetNativeVisibility(args);
  } else if (g_strcmp0(method, "raiseWindow") == 0) {
    response = self->HandleRaiseWindow(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

void NativeControlManager::OnScaffoldMethodCall(FlMethodChannel* channel,
                                                 FlMethodCall* method_call,
                                                 gpointer user_data) {
  auto* self = static_cast<NativeControlManager*>(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "updateHeaderBar") == 0) {
    response = self->HandleUpdateHeaderBar(args);
  } else if (g_strcmp0(method, "setHeaderBarVisibility") == 0) {
    response = self->HandleSetHeaderBarVisibility(args);
  } else if (g_strcmp0(method, "setHeaderActions") == 0) {
    response = self->HandleSetHeaderActions(args);
  } else if (g_strcmp0(method, "setupBottomNav") == 0) {
    response = self->HandleSetupBottomNav(args);
  } else if (g_strcmp0(method, "updateBottomNavIndex") == 0) {
    response = self->HandleUpdateBottomNavIndex(args);
  } else if (g_strcmp0(method, "setBottomNavVisibility") == 0) {
    response = self->HandleSetBottomNavVisibility(args);
  } else if (g_strcmp0(method, "applyCustomCss") == 0) {
    response = self->HandleApplyCustomCss(args);
  } else if (g_strcmp0(method, "getHeaderBarHeight") == 0) {
    response = self->HandleGetHeaderBarHeight(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

GtkWidget* NativeControlManager::FindWidget(const std::string& id) {
  auto it_btn = buttons_.find(id);
  if (it_btn != buttons_.end()) return it_btn->second->widget;

  auto it_sw = switches_.find(id);
  if (it_sw != switches_.end()) return it_sw->second->widget;

  auto it_in = inputs_.find(id);
  if (it_in != inputs_.end()) return it_in->second->widget;

  return nullptr;
}

void NativeControlManager::RemoveAnyWidget(const std::string& id) {
  auto it_btn = buttons_.find(id);
  if (it_btn != buttons_.end()) {
    gtk_widget_destroy(it_btn->second->widget);
    buttons_.erase(it_btn);
    return;
  }
  auto it_sw = switches_.find(id);
  if (it_sw != switches_.end()) {
    gtk_widget_destroy(it_sw->second->widget);
    switches_.erase(it_sw);
    return;
  }
  auto it_in = inputs_.find(id);
  if (it_in != inputs_.end()) {
    gtk_widget_destroy(it_in->second->widget);
    inputs_.erase(it_in);
    return;
  }
}

// ---------------------- BUTTON HANDLERS ----------------------

FlMethodResponse* NativeControlManager::HandleCreateButton(FlValue* args) {
  std::string id = get_string_val(args, "id");
  std::string title = get_string_val(args, "title");
  double x = get_double_val(args, "x");
  double y = get_double_val(args, "y");

  if (id.empty()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGS", "Missing id", nullptr));
  }

  auto it = buttons_.find(id);
  if (it != buttons_.end()) {
    gtk_button_set_label(GTK_BUTTON(it->second->widget), title.c_str());
    gtk_fixed_move(fixed_container_, it->second->widget, static_cast<gint>(x), static_cast<gint>(y));

    GtkRequisition req;
    gtk_widget_get_preferred_size(it->second->widget, nullptr, &req);

    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "width", fl_value_new_float(req.width));
    fl_value_set_string_take(result, "height", fl_value_new_float(req.height));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GtkWidget* button_widget = gtk_button_new_with_label(title.c_str());
  gtk_widget_set_can_focus(button_widget, FALSE);
  gtk_widget_set_focus_on_click(button_widget, FALSE);
  auto info = std::make_shared<WidgetInfo>();
  info->id = id;
  info->widget = button_widget;
  info->manager = this;

  info->signal_handler_id = g_signal_connect(button_widget, "clicked", G_CALLBACK(OnButtonClicked), info.get());
  AttachScrollHandler(button_widget);

  buttons_[id] = info;

  gtk_fixed_put(fixed_container_, button_widget, static_cast<gint>(x), static_cast<gint>(y));
  gtk_widget_show(button_widget);

  GtkRequisition req;
  gtk_widget_get_preferred_size(button_widget, nullptr, &req);

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "width", fl_value_new_float(req.width));
  fl_value_set_string_take(result, "height", fl_value_new_float(req.height));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* NativeControlManager::HandleUpdateButtonPosition(FlValue* args) {
  std::string id = get_string_val(args, "id");
  double x = get_double_val(args, "x");
  double y = get_double_val(args, "y");

  auto it = buttons_.find(id);
  if (it != buttons_.end()) {
    gtk_fixed_move(fixed_container_, it->second->widget, static_cast<gint>(x), static_cast<gint>(y));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleRemoveButton(FlValue* args) {
  std::string id = get_string_val(args, "id");
  auto it = buttons_.find(id);
  if (it != buttons_.end()) {
    gtk_widget_destroy(it->second->widget);
    buttons_.erase(it);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleSetButtonVisibility(FlValue* args) {
  std::string id = get_string_val(args, "id");
  bool visible = get_bool_val(args, "visible");

  auto it = buttons_.find(id);
  if (it != buttons_.end()) {
    gtk_widget_set_visible(it->second->widget, visible);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::OnButtonClicked(GtkButton* button, gpointer user_data) {
  auto* info = static_cast<WidgetInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr) return;

  info->manager->GrabFlutterFocus();

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));

  fl_method_channel_invoke_method(info->manager->button_channel_,
                                  "onButtonPressed",
                                  args,
                                  nullptr, nullptr, nullptr);
}

// ---------------------- SWITCH HANDLERS ----------------------

FlMethodResponse* NativeControlManager::HandleCreateSwitch(FlValue* args) {
  std::string id = get_string_val(args, "id");
  bool value = get_bool_val(args, "value");
  double x = get_double_val(args, "x");
  double y = get_double_val(args, "y");

  if (id.empty()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGS", "Missing id", nullptr));
  }

  auto it = switches_.find(id);
  if (it != switches_.end()) {
    it->second->ignore_signals = true;
    gtk_switch_set_active(GTK_SWITCH(it->second->widget), value);
    it->second->ignore_signals = false;

    gtk_fixed_move(fixed_container_, it->second->widget, static_cast<gint>(x), static_cast<gint>(y));

    GtkRequisition req;
    gtk_widget_get_preferred_size(it->second->widget, nullptr, &req);

    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "width", fl_value_new_float(req.width));
    fl_value_set_string_take(result, "height", fl_value_new_float(req.height));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GtkWidget* switch_widget = gtk_switch_new();
  gtk_widget_set_can_focus(switch_widget, FALSE);
  gtk_widget_set_focus_on_click(switch_widget, FALSE);
  gtk_switch_set_active(GTK_SWITCH(switch_widget), value);

  auto info = std::make_shared<WidgetInfo>();
  info->id = id;
  info->widget = switch_widget;
  info->manager = this;

  info->signal_handler_id = g_signal_connect(switch_widget, "notify::active", G_CALLBACK(OnSwitchActiveChanged), info.get());
  AttachScrollHandler(switch_widget);

  switches_[id] = info;

  gtk_fixed_put(fixed_container_, switch_widget, static_cast<gint>(x), static_cast<gint>(y));
  gtk_widget_show(switch_widget);

  GtkRequisition req;
  gtk_widget_get_preferred_size(switch_widget, nullptr, &req);

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "width", fl_value_new_float(req.width));
  fl_value_set_string_take(result, "height", fl_value_new_float(req.height));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* NativeControlManager::HandleUpdateSwitchValue(FlValue* args) {
  std::string id = get_string_val(args, "id");
  bool value = get_bool_val(args, "value");

  auto it = switches_.find(id);
  if (it != switches_.end()) {
    it->second->ignore_signals = true;
    gtk_switch_set_active(GTK_SWITCH(it->second->widget), value);
    it->second->ignore_signals = false;
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleRemoveSwitch(FlValue* args) {
  std::string id = get_string_val(args, "id");
  auto it = switches_.find(id);
  if (it != switches_.end()) {
    gtk_widget_destroy(it->second->widget);
    switches_.erase(it);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::OnSwitchActiveChanged(GObject* object, GParamSpec* pspec, gpointer user_data) {
  auto* info = static_cast<WidgetInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->ignore_signals) return;

  info->manager->GrabFlutterFocus();

  gboolean active = gtk_switch_get_active(GTK_SWITCH(object));

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "value", fl_value_new_bool(active));

  fl_method_channel_invoke_method(info->manager->native_channel_,
                                  "onSwitchChanged",
                                  args,
                                  nullptr, nullptr, nullptr);
}

// ---------------------- INPUT HANDLERS ----------------------

FlMethodResponse* NativeControlManager::HandleCreateInput(FlValue* args) {
  std::string id = get_string_val(args, "id");
  std::string text = get_string_val(args, "text");
  double x = get_double_val(args, "x");
  double y = get_double_val(args, "y");
  double width = get_double_val(args, "width");
  double height = get_double_val(args, "height");

  if (id.empty()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARGS", "Missing id", nullptr));
  }

  auto it = inputs_.find(id);
  if (it != inputs_.end()) {
    it->second->ignore_signals = true;
    gtk_entry_set_text(GTK_ENTRY(it->second->widget), text.c_str());
    it->second->ignore_signals = false;

    if (width > 0 && height > 0) {
      gtk_widget_set_size_request(it->second->widget, static_cast<gint>(width), static_cast<gint>(height));
    }
    gtk_fixed_move(fixed_container_, it->second->widget, static_cast<gint>(x), static_cast<gint>(y));

    GtkRequisition req;
    gtk_widget_get_preferred_size(it->second->widget, nullptr, &req);
    double ret_w = (width > 0) ? width : (req.width < 80 ? 80 : req.width);
    double ret_h = (height > 0) ? height : req.height;

    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "width", fl_value_new_float(ret_w));
    fl_value_set_string_take(result, "height", fl_value_new_float(ret_h));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GtkWidget* entry_widget = gtk_entry_new();
  gtk_entry_set_text(GTK_ENTRY(entry_widget), text.c_str());

  if (width > 0 && height > 0) {
    gtk_widget_set_size_request(entry_widget, static_cast<gint>(width), static_cast<gint>(height));
  }

  auto info = std::make_shared<WidgetInfo>();
  info->id = id;
  info->widget = entry_widget;
  info->manager = this;

  info->signal_handler_id = g_signal_connect(GTK_EDITABLE(entry_widget), "changed", G_CALLBACK(OnEntryChanged), info.get());
  info->activate_handler_id = g_signal_connect(GTK_ENTRY(entry_widget), "activate", G_CALLBACK(OnEntryActivate), info.get());
  info->focus_out_handler_id = g_signal_connect(entry_widget, "focus-out-event", G_CALLBACK(OnEntryFocusOut), info.get());
  AttachScrollHandler(entry_widget);

  inputs_[id] = info;

  gtk_fixed_put(fixed_container_, entry_widget, static_cast<gint>(x), static_cast<gint>(y));
  gtk_widget_show(entry_widget);

  GtkRequisition req;
  gtk_widget_get_preferred_size(entry_widget, nullptr, &req);
  double ret_w = (width > 0) ? width : (req.width < 80 ? 80 : req.width);
  double ret_h = (height > 0) ? height : req.height;

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "width", fl_value_new_float(ret_w));
  fl_value_set_string_take(result, "height", fl_value_new_float(ret_h));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* NativeControlManager::HandleRemoveInput(FlValue* args) {
  std::string id = get_string_val(args, "id");
  auto it = inputs_.find(id);
  if (it != inputs_.end()) {
    gtk_widget_destroy(it->second->widget);
    inputs_.erase(it);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::OnEntryChanged(GtkEditable* editable, gpointer user_data) {
  auto* info = static_cast<WidgetInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->ignore_signals) return;

  const gchar* text = gtk_entry_get_text(GTK_ENTRY(editable));

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "value", fl_value_new_string(text));

  fl_method_channel_invoke_method(info->manager->native_channel_,
                                  "onInput",
                                  args,
                                  nullptr, nullptr, nullptr);
}

void NativeControlManager::OnEntryActivate(GtkEntry* entry, gpointer user_data) {
  auto* info = static_cast<WidgetInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->ignore_signals) return;

  if (GTK_IS_EDITABLE(entry)) {
    gtk_editable_select_region(GTK_EDITABLE(entry), 0, 0);
  }
  info->manager->GrabFlutterFocus();

  const gchar* text = gtk_entry_get_text(entry);

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "value", fl_value_new_string(text));

  fl_method_channel_invoke_method(info->manager->native_channel_,
                                  "onSubmit",
                                  args,
                                  nullptr, nullptr, nullptr);
}

gboolean NativeControlManager::OnEntryFocusOut(GtkWidget* widget, GdkEventFocus* event, gpointer user_data) {
  auto* info = static_cast<WidgetInfo*>(user_data);
  if (info != nullptr && info->manager != nullptr) {
    if (GTK_IS_EDITABLE(widget)) {
      gtk_editable_select_region(GTK_EDITABLE(widget), 0, 0);
    }
    info->manager->GrabFlutterFocus();
  }
  return FALSE;
}

// ---------------------- COMMON POSITION & VISIBILITY ----------------------

FlMethodResponse* NativeControlManager::HandleUpdateNativePosition(FlValue* args) {
  std::string id = get_string_val(args, "id");
  double x = get_double_val(args, "x");
  double y = get_double_val(args, "y");
  double width = get_double_val(args, "width");
  double height = get_double_val(args, "height");

  GtkWidget* widget = FindWidget(id);
  if (widget != nullptr) {
    gtk_fixed_move(fixed_container_, widget, static_cast<gint>(x), static_cast<gint>(y));
    if (width > 0 && height > 0) {
      gtk_widget_set_size_request(widget, static_cast<gint>(width), static_cast<gint>(height));
    }
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleSetNativeVisibility(FlValue* args) {
  std::string id = get_string_val(args, "id");
  bool visible = get_bool_val(args, "visible");

  GtkWidget* widget = FindWidget(id);
  if (widget != nullptr) {
    gtk_widget_set_visible(widget, visible);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleRaiseWindow(FlValue* args) {
  if (fl_view_widget_ != nullptr) {
    GtkWidget* toplevel = gtk_widget_get_toplevel(fl_view_widget_);
    if (toplevel != nullptr && GTK_IS_WINDOW(toplevel)) {
      gtk_window_deiconify(GTK_WINDOW(toplevel));
      gtk_window_present(GTK_WINDOW(toplevel));
    }
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

// ---------------------- SCAFFOLD HANDLERS ----------------------

FlMethodResponse* NativeControlManager::HandleUpdateHeaderBar(FlValue* args) {
  if (header_bar_ == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  std::string title = get_string_val(args, "title");
  std::string subtitle = get_string_val(args, "subtitle");
  bool show_back = get_bool_val(args, "showBackButton");
  std::string bg_color = get_string_val(args, "backgroundColor");

  gtk_header_bar_set_title(header_bar_, title.c_str());
  if (!subtitle.empty()) {
    gtk_header_bar_set_subtitle(header_bar_, subtitle.c_str());
  } else {
    gtk_header_bar_set_subtitle(header_bar_, nullptr);
  }

  GtkStyleContext* context = gtk_widget_get_style_context(GTK_WIDGET(header_bar_));
  if (header_bar_css_provider_ != nullptr) {
    gtk_style_context_remove_provider(context, GTK_STYLE_PROVIDER(header_bar_css_provider_));
    g_object_unref(header_bar_css_provider_);
    header_bar_css_provider_ = nullptr;
  }

  if (!bg_color.empty()) {
    header_bar_css_provider_ = gtk_css_provider_new();
    std::string css = "headerbar { background-image: none; background-color: " + bg_color + "; }";
    gtk_css_provider_load_from_data(header_bar_css_provider_, css.c_str(), -1, nullptr);
    gtk_style_context_add_provider(context, GTK_STYLE_PROVIDER(header_bar_css_provider_), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  if (show_back) {
    if (back_button_ == nullptr) {
      back_button_ = gtk_button_new_from_icon_name("go-previous-symbolic", GTK_ICON_SIZE_BUTTON);
      gtk_widget_set_can_focus(back_button_, FALSE);
      gtk_widget_set_focus_on_click(back_button_, FALSE);
      g_signal_connect(back_button_, "clicked", G_CALLBACK(OnHeaderBackClicked), this);
      gtk_header_bar_pack_start(header_bar_, back_button_);
    }
    gtk_widget_show(back_button_);
  } else {
    if (back_button_ != nullptr) {
      gtk_widget_hide(back_button_);
    }
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleSetHeaderBarVisibility(FlValue* args) {
  if (header_bar_ == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  bool visible = get_bool_val(args, "visible");
  if (visible) {
    gtk_widget_show(GTK_WIDGET(header_bar_));
  } else {
    gtk_widget_hide(GTK_WIDGET(header_bar_));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::OnHeaderBackClicked(GtkButton* button, gpointer user_data) {
  auto* self = static_cast<NativeControlManager*>(user_data);
  if (self == nullptr || self->scaffold_channel_ == nullptr) return;

  self->GrabFlutterFocus();

  fl_method_channel_invoke_method(self->scaffold_channel_,
                                  "onHeaderBack",
                                  nullptr,
                                  nullptr, nullptr, nullptr);
}

FlMethodResponse* NativeControlManager::HandleSetHeaderActions(FlValue* args) {
  if (header_bar_ == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  for (auto& item : header_actions_) {
    if (item->widget != nullptr) {
      gtk_widget_destroy(item->widget);
    }
  }
  header_actions_.clear();

  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_LIST) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  size_t count = fl_value_get_length(args);
  for (size_t i = 0; i < count; ++i) {
    FlValue* item_val = fl_value_get_list_value(args, i);
    if (item_val == nullptr || fl_value_get_type(item_val) != FL_VALUE_TYPE_MAP) continue;

    std::string id = get_string_val(item_val, "id");
    std::string type = get_string_val(item_val, "type");
    if (type.empty()) type = "action";
    std::string position = get_string_val(item_val, "position");

    GtkWidget* item_widget = nullptr;

    if (type == "search") {
      std::string placeholder = get_string_val(item_val, "placeholder");
      std::string value = get_string_val(item_val, "value");

      GtkWidget* entry = gtk_search_entry_new();
      if (!placeholder.empty()) {
        gtk_entry_set_placeholder_text(GTK_ENTRY(entry), placeholder.c_str());
      }
      if (!value.empty()) {
        gtk_entry_set_text(GTK_ENTRY(entry), value.c_str());
      }

      auto info = std::make_shared<HeaderActionInfo>();
      info->id = id;
      info->type = "search";
      info->widget = entry;
      info->manager = this;

      g_signal_connect(entry, "search-changed", G_CALLBACK(OnHeaderSearchChanged), info.get());
      g_signal_connect(entry, "activate", G_CALLBACK(OnHeaderSearchActivate), info.get());
      header_actions_.push_back(info);
      item_widget = entry;

    } else if (type == "tabbar") {
      FlValue* tabs_val = fl_value_lookup_string(item_val, "tabs");
      int selected_index = static_cast<int>(get_double_val(item_val, "selectedIndex"));

      GtkWidget* box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
      GtkStyleContext* context = gtk_widget_get_style_context(box);
      gtk_style_context_add_class(context, "linked");

      if (tabs_val != nullptr && fl_value_get_type(tabs_val) == FL_VALUE_TYPE_LIST) {
        size_t num_tabs = fl_value_get_length(tabs_val);
        GtkWidget* group = nullptr;
        for (size_t t = 0; t < num_tabs; ++t) {
          FlValue* tab_title_val = fl_value_get_list_value(tabs_val, t);
          std::string tab_title = fl_value_get_type(tab_title_val) == FL_VALUE_TYPE_STRING
              ? fl_value_get_string(tab_title_val) : "";

          GtkWidget* tab_btn = nullptr;
          if (t == 0) {
            tab_btn = gtk_radio_button_new_with_label(nullptr, tab_title.c_str());
            group = tab_btn;
          } else {
            tab_btn = gtk_radio_button_new_with_label_from_widget(GTK_RADIO_BUTTON(group), tab_title.c_str());
          }
          gtk_toggle_button_set_mode(GTK_TOGGLE_BUTTON(tab_btn), FALSE);
          if (static_cast<int>(t) == selected_index) {
            gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(tab_btn), TRUE);
          }

          auto info = std::make_shared<HeaderActionInfo>();
          info->id = id;
          info->type = "tabbar";
          info->tab_index = static_cast<int>(t);
          info->widget = tab_btn;
          info->manager = this;

          g_signal_connect(tab_btn, "clicked", G_CALLBACK(OnHeaderTabClicked), info.get());
          header_actions_.push_back(info);

          gtk_container_add(GTK_CONTAINER(box), tab_btn);
          gtk_widget_show(tab_btn);
        }
      }
      item_widget = box;

    } else if (type == "title") {
      std::string title = get_string_val(item_val, "title");
      std::string subtitle = get_string_val(item_val, "subtitle");

      GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
      gtk_widget_set_valign(vbox, GTK_ALIGN_CENTER);

      GtkWidget* lbl_title = gtk_label_new(title.c_str());
      GtkStyleContext* ctx_title = gtk_widget_get_style_context(lbl_title);
      gtk_style_context_add_class(ctx_title, "title");
      gtk_container_add(GTK_CONTAINER(vbox), lbl_title);
      gtk_widget_show(lbl_title);

      if (!subtitle.empty()) {
        GtkWidget* lbl_sub = gtk_label_new(subtitle.c_str());
        GtkStyleContext* ctx_sub = gtk_widget_get_style_context(lbl_sub);
        gtk_style_context_add_class(ctx_sub, "subtitle");
        gtk_container_add(GTK_CONTAINER(vbox), lbl_sub);
        gtk_widget_show(lbl_sub);
      }

      auto info = std::make_shared<HeaderActionInfo>();
      info->id = id;
      info->type = "title";
      info->widget = vbox;
      info->manager = this;
      header_actions_.push_back(info);
      item_widget = vbox;

    } else { // "action"
      std::string label = get_string_val(item_val, "label");
      std::string icon_name = get_string_val(item_val, "iconName");

      GtkWidget* btn = nullptr;
      if (!icon_name.empty()) {
        btn = gtk_button_new_from_icon_name(icon_name.c_str(), GTK_ICON_SIZE_BUTTON);
        if (!label.empty()) {
          gtk_widget_set_tooltip_text(btn, label.c_str());
        }
      } else if (!label.empty()) {
        btn = gtk_button_new_with_label(label.c_str());
      } else {
        btn = gtk_button_new();
      }
      gtk_widget_set_can_focus(btn, FALSE);
      gtk_widget_set_focus_on_click(btn, FALSE);

      auto info = std::make_shared<HeaderActionInfo>();
      info->id = id;
      info->type = "action";
      info->widget = btn;
      info->manager = this;

      g_signal_connect(btn, "clicked", G_CALLBACK(OnHeaderActionClicked), info.get());
      header_actions_.push_back(info);
      item_widget = btn;
    }

    if (item_widget != nullptr) {
      if (position == "start") {
        gtk_header_bar_pack_start(header_bar_, item_widget);
      } else if (position == "center") {
        gtk_header_bar_set_custom_title(header_bar_, item_widget);
      } else {
        gtk_header_bar_pack_end(header_bar_, item_widget);
      }
      gtk_widget_show(item_widget);
    }
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::OnHeaderActionClicked(GtkButton* button, gpointer user_data) {
  auto* info = static_cast<HeaderActionInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->manager->scaffold_channel_ == nullptr) return;

  info->manager->GrabFlutterFocus();

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));

  fl_method_channel_invoke_method(info->manager->scaffold_channel_,
                                  "onHeaderActionPressed",
                                  args,
                                  nullptr, nullptr, nullptr);
}

void NativeControlManager::OnHeaderSearchChanged(GtkSearchEntry* entry, gpointer user_data) {
  auto* info = static_cast<HeaderActionInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->manager->scaffold_channel_ == nullptr) return;

  const gchar* text = gtk_entry_get_text(GTK_ENTRY(entry));
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "text", fl_value_new_string(text ? text : ""));

  fl_method_channel_invoke_method(info->manager->scaffold_channel_,
                                  "onHeaderSearchChanged",
                                  args, nullptr, nullptr, nullptr);
}

void NativeControlManager::OnHeaderSearchActivate(GtkEntry* entry, gpointer user_data) {
  auto* info = static_cast<HeaderActionInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->manager->scaffold_channel_ == nullptr) return;

  const gchar* text = gtk_entry_get_text(entry);
  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "text", fl_value_new_string(text ? text : ""));

  fl_method_channel_invoke_method(info->manager->scaffold_channel_,
                                  "onHeaderSearchSubmitted",
                                  args, nullptr, nullptr, nullptr);
}

void NativeControlManager::OnHeaderTabClicked(GtkButton* button, gpointer user_data) {
  auto* info = static_cast<HeaderActionInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->manager->scaffold_channel_ == nullptr) return;

  if (GTK_IS_TOGGLE_BUTTON(button) && !gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(button))) {
    return;
  }

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));
  fl_value_set_string_take(args, "index", fl_value_new_int(info->tab_index));

  fl_method_channel_invoke_method(info->manager->scaffold_channel_,
                                  "onHeaderTabSelected",
                                  args, nullptr, nullptr, nullptr);
}

FlMethodResponse* NativeControlManager::HandleSetupBottomNav(FlValue* args) {
  if (action_bar_ == nullptr) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  bottom_nav_items_.clear();
  if (bottom_nav_box_ != nullptr) {
    gtk_widget_destroy(bottom_nav_box_);
    bottom_nav_box_ = nullptr;
  }

  FlValue* items_val = lookup_map_value(args, "items");
  current_bottom_nav_index_ = static_cast<int>(get_double_val(args, "selectedIndex"));
  std::string bg_color = get_string_val(args, "backgroundColor");

  GtkStyleContext* context = gtk_widget_get_style_context(GTK_WIDGET(action_bar_));
  if (action_bar_css_provider_ != nullptr) {
    gtk_style_context_remove_provider(context, GTK_STYLE_PROVIDER(action_bar_css_provider_));
    g_object_unref(action_bar_css_provider_);
    action_bar_css_provider_ = nullptr;
  }

  if (!bg_color.empty()) {
    action_bar_css_provider_ = gtk_css_provider_new();
    std::string css = "actionbar { background-image: none; background-color: " + bg_color + "; }";
    gtk_css_provider_load_from_data(action_bar_css_provider_, css.c_str(), -1, nullptr);
    gtk_style_context_add_provider(context, GTK_STYLE_PROVIDER(action_bar_css_provider_), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  if (items_val == nullptr || fl_value_get_type(items_val) != FL_VALUE_TYPE_LIST) {
    gtk_widget_hide(GTK_WIDGET(action_bar_));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  size_t count = fl_value_get_length(items_val);
  if (count == 0) {
    gtk_widget_hide(GTK_WIDGET(action_bar_));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }

  bottom_nav_box_ = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
  gtk_style_context_add_class(gtk_widget_get_style_context(bottom_nav_box_), "linked");

  for (size_t i = 0; i < count; ++i) {
    FlValue* item_val = fl_value_get_list_value(items_val, i);
    if (item_val == nullptr || fl_value_get_type(item_val) != FL_VALUE_TYPE_MAP) continue;

    std::string id = get_string_val(item_val, "id");
    std::string label = get_string_val(item_val, "label");
    std::string icon_name = get_string_val(item_val, "iconName");

    GtkWidget* btn = nullptr;
    if (!icon_name.empty() && !label.empty()) {
      GtkWidget* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
      GtkWidget* icon = gtk_image_new_from_icon_name(icon_name.c_str(), GTK_ICON_SIZE_BUTTON);
      GtkWidget* lbl = gtk_label_new(label.c_str());
      gtk_widget_set_halign(icon, GTK_ALIGN_CENTER);
      gtk_widget_set_halign(lbl, GTK_ALIGN_CENTER);
      gtk_box_pack_start(GTK_BOX(box), icon, FALSE, FALSE, 0);
      gtk_box_pack_start(GTK_BOX(box), lbl, FALSE, FALSE, 0);
      btn = gtk_button_new();
      gtk_container_add(GTK_CONTAINER(btn), box);
    } else if (!icon_name.empty()) {
      btn = gtk_button_new_from_icon_name(icon_name.c_str(), GTK_ICON_SIZE_BUTTON);
    } else {
      btn = gtk_button_new_with_label(label.c_str());
    }
    gtk_widget_set_can_focus(btn, FALSE);
    gtk_widget_set_focus_on_click(btn, FALSE);

    auto info = std::make_shared<BottomNavItemInfo>();
    info->id = id;
    info->index = static_cast<int>(i);
    info->button = btn;
    info->manager = this;

    g_signal_connect(btn, "clicked", G_CALLBACK(OnBottomNavItemClicked), info.get());
    bottom_nav_items_.push_back(info);

    gtk_box_pack_start(GTK_BOX(bottom_nav_box_), btn, FALSE, FALSE, 0);
  }

  gtk_action_bar_set_center_widget(action_bar_, bottom_nav_box_);
  UpdateBottomNavStyles();

  gtk_widget_show_all(GTK_WIDGET(action_bar_));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void NativeControlManager::UpdateBottomNavStyles() {
  for (auto& item : bottom_nav_items_) {
    GtkStyleContext* context = gtk_widget_get_style_context(item->button);
    if (item->index == current_bottom_nav_index_) {
      gtk_style_context_add_class(context, "suggested-action");
    } else {
      gtk_style_context_remove_class(context, "suggested-action");
    }
  }
}

void NativeControlManager::OnBottomNavItemClicked(GtkButton* button, gpointer user_data) {
  auto* info = static_cast<BottomNavItemInfo*>(user_data);
  if (info == nullptr || info->manager == nullptr || info->manager->scaffold_channel_ == nullptr) return;

  info->manager->GrabFlutterFocus();

  info->manager->current_bottom_nav_index_ = info->index;
  info->manager->UpdateBottomNavStyles();

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "index", fl_value_new_float(info->index));
  fl_value_set_string_take(args, "id", fl_value_new_string(info->id.c_str()));

  fl_method_channel_invoke_method(info->manager->scaffold_channel_,
                                  "onBottomNavSelected",
                                  args,
                                  nullptr, nullptr, nullptr);
}

FlMethodResponse* NativeControlManager::HandleUpdateBottomNavIndex(FlValue* args) {
  int index = static_cast<int>(get_double_val(args, "index"));
  current_bottom_nav_index_ = index;
  UpdateBottomNavStyles();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleSetBottomNavVisibility(FlValue* args) {
  if (action_bar_ != nullptr) {
    bool visible = get_bool_val(args, "visible");
    gtk_widget_set_visible(GTK_WIDGET(action_bar_), visible);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleApplyCustomCss(FlValue* args) {
  std::string css = get_string_val(args, "css");
  if (!css.empty()) {
    GtkCssProvider* provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider, css.c_str(), -1, nullptr);
    gtk_style_context_add_provider_for_screen(
        gdk_screen_get_default(),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

FlMethodResponse* NativeControlManager::HandleGetHeaderBarHeight(FlValue* /*args*/) {
  int height = 0;
  if (header_bar_ != nullptr) {
    // gtk_widget_get_preferred_height gives the natural height before allocation
    int min_h = 0, nat_h = 0;
    gtk_widget_get_preferred_height(GTK_WIDGET(header_bar_), &min_h, &nat_h);
    height = nat_h > 0 ? nat_h : gtk_widget_get_allocated_height(GTK_WIDGET(header_bar_));
  }
  g_autoptr(FlValue) result = fl_value_new_int(height);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

