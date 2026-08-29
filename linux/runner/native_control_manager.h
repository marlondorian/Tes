#ifndef NATIVE_CONTROL_MANAGER_H_
#define NATIVE_CONTROL_MANAGER_H_

#include <gtk/gtk.h>
#include <flutter_linux/flutter_linux.h>
#include <string>
#include <vector>
#include <unordered_map>
#include <memory>

class NativeControlManager {
 public:
  NativeControlManager(GtkFixed* fixed_container,
                       GtkWidget* fl_view_widget,
                       GtkHeaderBar* header_bar,
                       GtkActionBar* action_bar);
  ~NativeControlManager();

  void SetupChannels(FlBinaryMessenger* messenger);
  void GrabFlutterFocus();
  void UnfocusAllInputs();

 private:
  struct WidgetInfo {
    std::string id;
    GtkWidget* widget;
    NativeControlManager* manager;
    gulong signal_handler_id{0};
    gulong activate_handler_id{0};
    gulong focus_out_handler_id{0};
    bool ignore_signals{false};
  };

  struct HeaderActionInfo {
    std::string id;
    std::string type;
    int tab_index{0};
    GtkWidget* widget{nullptr};
    NativeControlManager* manager{nullptr};
  };

  struct BottomNavItemInfo {
    std::string id;
    int index;
    GtkWidget* button;
    NativeControlManager* manager;
  };

  GtkFixed* fixed_container_{nullptr};
  GtkWidget* fl_view_widget_{nullptr};
  GtkHeaderBar* header_bar_{nullptr};
  GtkActionBar* action_bar_{nullptr};
  GtkCssProvider* header_bar_css_provider_{nullptr};
  GtkCssProvider* action_bar_css_provider_{nullptr};

  GtkWidget* back_button_{nullptr};
  GtkWidget* bottom_nav_box_{nullptr};

  FlMethodChannel* button_channel_{nullptr};
  FlMethodChannel* native_channel_{nullptr};
  FlMethodChannel* scaffold_channel_{nullptr};

  std::unordered_map<std::string, std::shared_ptr<WidgetInfo>> buttons_;
  std::unordered_map<std::string, std::shared_ptr<WidgetInfo>> switches_;
  std::unordered_map<std::string, std::shared_ptr<WidgetInfo>> inputs_;

  std::vector<std::shared_ptr<HeaderActionInfo>> header_actions_;
  std::vector<std::shared_ptr<BottomNavItemInfo>> bottom_nav_items_;

  int current_bottom_nav_index_{0};

  static void OnButtonMethodCall(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data);

  static void OnNativeMethodCall(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data);

  static void OnScaffoldMethodCall(FlMethodChannel* channel,
                                   FlMethodCall* method_call,
                                   gpointer user_data);

  // Button channel handlers
  FlMethodResponse* HandleCreateButton(FlValue* args);
  FlMethodResponse* HandleUpdateButtonPosition(FlValue* args);
  FlMethodResponse* HandleRemoveButton(FlValue* args);
  FlMethodResponse* HandleSetButtonVisibility(FlValue* args);

  // Native channel handlers (Switch & Input)
  FlMethodResponse* HandleCreateSwitch(FlValue* args);
  FlMethodResponse* HandleUpdateSwitchValue(FlValue* args);
  FlMethodResponse* HandleRemoveSwitch(FlValue* args);
  FlMethodResponse* HandleCreateInput(FlValue* args);
  FlMethodResponse* HandleRemoveInput(FlValue* args);
  FlMethodResponse* HandleUpdateNativePosition(FlValue* args);
  FlMethodResponse* HandleSetNativeVisibility(FlValue* args);
  FlMethodResponse* HandleRaiseWindow(FlValue* args);

  // Scaffold channel handlers
  FlMethodResponse* HandleUpdateHeaderBar(FlValue* args);
  FlMethodResponse* HandleSetHeaderBarVisibility(FlValue* args);
  FlMethodResponse* HandleSetHeaderActions(FlValue* args);
  FlMethodResponse* HandleSetupBottomNav(FlValue* args);
  FlMethodResponse* HandleUpdateBottomNavIndex(FlValue* args);
  FlMethodResponse* HandleSetBottomNavVisibility(FlValue* args);
  FlMethodResponse* HandleApplyCustomCss(FlValue* args);
  FlMethodResponse* HandleGetHeaderBarHeight(FlValue* args);

  // GTK signal callbacks
  static void OnButtonClicked(GtkButton* button, gpointer user_data);
  static void OnSwitchActiveChanged(GObject* object, GParamSpec* pspec, gpointer user_data);
  static void OnEntryChanged(GtkEditable* editable, gpointer user_data);
  static void OnEntryActivate(GtkEntry* entry, gpointer user_data);
  static gboolean OnEntryFocusOut(GtkWidget* widget, GdkEventFocus* event, gpointer user_data);
  static gboolean OnWidgetScrollEvent(GtkWidget* widget, GdkEventScroll* event, gpointer user_data);

  static void OnHeaderBackClicked(GtkButton* button, gpointer user_data);
  static void OnHeaderActionClicked(GtkButton* button, gpointer user_data);
  static void OnHeaderSearchChanged(GtkSearchEntry* entry, gpointer user_data);
  static void OnHeaderSearchActivate(GtkEntry* entry, gpointer user_data);
  static void OnHeaderTabClicked(GtkButton* button, gpointer user_data);
  static void OnBottomNavItemClicked(GtkButton* button, gpointer user_data);

  void AttachScrollHandler(GtkWidget* widget);
  GtkWidget* FindWidget(const std::string& id);
  void RemoveAnyWidget(const std::string& id);
  void UpdateBottomNavStyles();

  // GTK Theme extraction
  void SubscribeToThemeChanges();
  void UnsubscribeFromThemeChanges();
  void SendGtkThemeToFlutter();
  FlValue* BuildGtkThemeValue();
  static void OnGtkThemeChanged(GObject* object, GParamSpec* pspec, gpointer user_data);

  gulong theme_name_signal_id_{0};
  gulong prefer_dark_signal_id_{0};
};

#endif  // NATIVE_CONTROL_MANAGER_H_
