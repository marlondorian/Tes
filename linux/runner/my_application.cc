#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <cmath>

#if __has_include(<handy.h>)
#include <handy.h>
#define HAVE_LIBHANDY 1
#endif

#include "flutter/generated_plugin_registrant.h"
#include "native_control_manager.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  NativeControlManager* native_control_manager;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Callback to clip rounded corners using Cairo for a modern GTK / Libhandy aesthetic
static gboolean on_window_content_draw(GtkWidget* widget, cairo_t* cr, gpointer user_data) {
  GtkWidget* toplevel_widget = gtk_widget_get_toplevel(widget);
  gboolean is_maximized = (toplevel_widget != nullptr && GTK_IS_WINDOW(toplevel_widget))
                              ? gtk_window_is_maximized(GTK_WINDOW(toplevel_widget))
                              : FALSE;

  if (!is_maximized) {
    GtkAllocation allocation;
    gtk_widget_get_allocation(widget, &allocation);

    double width = allocation.width;
    double height = allocation.height;
    double radius = 12.0;

    cairo_new_sub_path(cr);
    cairo_arc(cr, width - radius, radius, radius, -M_PI_2, 0);
    cairo_arc(cr, width - radius, height - radius, radius, 0, M_PI_2);
    cairo_arc(cr, radius, height - radius, radius, M_PI_2, M_PI);
    cairo_arc(cr, radius, radius, radius, M_PI, 3 * M_PI_2);
    cairo_close_path(cr);

    cairo_clip(cr);
  }

  return FALSE;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // HdyWindow is a CSD window: the WM does NOT draw a separate titlebar.
  // We DO NOT call gtk_window_set_titlebar() (not supported by HdyWindow).
  // Instead, GtkHeaderBar is packed as the first child of main_box so it acts
  // as the native title bar inside the client-side-decorated HdyWindow frame.
#if HAVE_LIBHANDY
  hdy_init();
  GtkWindow* window = GTK_WINDOW(hdy_window_new());
  gtk_window_set_application(window, GTK_APPLICATION(application));
#else
  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  // Remove WM titlebar on non-libhandy builds since we draw our own header bar.
  gtk_window_set_decorated(window, FALSE);
#endif

  // Enable RGBA visual for alpha channel window compositing and rounded corner transparency
  GdkScreen* screen = gdk_screen_get_default();
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr && gdk_screen_is_composited(screen)) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
  }
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);

  // Apply global custom GTK CSS rules
  GtkCssProvider* css_provider = gtk_css_provider_new();
  gtk_css_provider_load_from_data(css_provider, "menubar { opacity: 0; padding: 0; height: 0; border: 0; }", -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      screen,
      GTK_STYLE_PROVIDER(css_provider),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(css_provider);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Transparent background so Flutter doesn't paint opaque black over rounded corners
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);

  // GtkHeaderBar packed as first child of main_box — CSD window has no WM titlebar,
  // so this IS the only header bar. No gtk_window_set_titlebar() needed.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_header_bar_set_title(header_bar, "macos_native_widgets");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  // Note: window dragging is handled by HdyWindowHandle wrapping the header_bar below.

  GtkWidget* main_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

  GtkWidget* overlay = gtk_overlay_new();
  GtkWidget* fixed = gtk_fixed_new();
  GtkWidget* action_bar = gtk_action_bar_new();

  gtk_container_add(GTK_CONTAINER(overlay), GTK_WIDGET(view));

  // GtkFixed layer for native controls overlaid on FlView (pass-through for pointer events)
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), fixed);
  gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(overlay), fixed, TRUE);

  // GtkActionBar overlaid on top of FlView & native controls at the bottom
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), action_bar);
  gtk_widget_set_halign(action_bar, GTK_ALIGN_FILL);
  gtk_widget_set_valign(action_bar, GTK_ALIGN_END);

  // GtkHeaderBar overlaid on top of FlView & native controls at the top
#if HAVE_LIBHANDY
  GtkWidget* window_handle = hdy_window_handle_new();
  gtk_container_add(GTK_CONTAINER(window_handle), GTK_WIDGET(header_bar));
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), window_handle);
  gtk_widget_set_halign(window_handle, GTK_ALIGN_FILL);
  gtk_widget_set_valign(window_handle, GTK_ALIGN_START);
  gtk_widget_show(window_handle);
#else
  gtk_overlay_add_overlay(GTK_OVERLAY(overlay), GTK_WIDGET(header_bar));
  gtk_widget_set_halign(GTK_WIDGET(header_bar), GTK_ALIGN_FILL);
  gtk_widget_set_valign(GTK_WIDGET(header_bar), GTK_ALIGN_START);
#endif

  // Connect Cairo rounded corner clipping signal
  g_signal_connect(GTK_WIDGET(view), "draw", G_CALLBACK(on_window_content_draw), NULL);
  g_signal_connect(overlay, "draw", G_CALLBACK(on_window_content_draw), NULL);

  gtk_box_pack_start(GTK_BOX(main_box), overlay, TRUE, TRUE, 0);

  gtk_container_add(GTK_CONTAINER(window), main_box);

  FlEngine* engine = fl_view_get_engine(view);
  FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);

  self->native_control_manager = new NativeControlManager(
      GTK_FIXED(fixed),
      GTK_WIDGET(view),
      header_bar,
      GTK_ACTION_BAR(action_bar));
  self->native_control_manager->SetupChannels(messenger);

  // Register plugins BEFORE showing window and view (required by handy_window)
  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_widget_show(main_box);
  gtk_widget_show(fixed);
  gtk_widget_show(overlay);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));
  gtk_widget_show(GTK_WIDGET(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
  gtk_widget_show(GTK_WIDGET(window));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  if (self->native_control_manager != nullptr) {
    delete self->native_control_manager;
    self->native_control_manager = nullptr;
  }
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
