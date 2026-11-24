#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <sys/stat.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Ensure synthesized/window-manager GdkEvents carry a valid pointer device so
// FlView axis lookups do not log GDK_IS_DEVICE(device) critical assertions.
static gboolean ensure_event_device_cb(GtkWidget* widget,
                                       GdkEvent* event,
                                       gpointer user_data) {
  if (event == nullptr) {
    return FALSE;
  }
  const gboolean missing_device = gdk_event_get_device(event) == nullptr;
  const gboolean missing_source = gdk_event_get_source_device(event) == nullptr;
  if (!missing_device && !missing_source) {
    return FALSE;
  }
  GdkDisplay* display = gdk_display_get_default();
  GdkSeat* seat = display ? gdk_display_get_default_seat(display) : nullptr;
  GdkDevice* pointer = seat ? gdk_seat_get_pointer(seat) : nullptr;
  if (pointer != nullptr) {
    if (missing_device) {
      gdk_event_set_device(event, pointer);
    }
    if (missing_source) {
      gdk_event_set_source_device(event, pointer);
    }
  }
  return FALSE;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Ensures the application launcher entry and desktop icons are installed in
// ~/.local/share/applications and ~/.local/share/icons/hicolor so Axis is always
// listed with its official icon in the GNOME / Ubuntu "Show Applications" menu.
static void ensure_desktop_integration(const gchar* exe_path, const gchar* exe_dir) {
  if (exe_path == nullptr || exe_dir == nullptr) {
    return;
  }

  const gchar* data_home = g_get_user_data_dir();
  if (data_home == nullptr) {
    return;
  }

  // 1. Ensure desktop entry exists in ~/.local/share/applications/com.axis.axis.desktop
  g_autofree gchar* apps_dir = g_build_filename(data_home, "applications", nullptr);
  g_mkdir_with_parents(apps_dir, 0755);

  g_autofree gchar* desktop_path = g_build_filename(apps_dir, "com.axis.axis.desktop", nullptr);
  gboolean needs_desktop_write = TRUE;

  if (g_file_test(desktop_path, G_FILE_TEST_EXISTS)) {
    gchar* existing_content = nullptr;
    if (g_file_get_contents(desktop_path, &existing_content, nullptr, nullptr)) {
      if (strstr(existing_content, exe_path) != nullptr) {
        needs_desktop_write = FALSE;
      }
      g_free(existing_content);
    }
  }

  if (needs_desktop_write) {
    gchar* desktop_content = g_strdup_printf(
        "[Desktop Entry]\n"
        "Version=1.0\n"
        "Type=Application\n"
        "Name=Axis\n"
        "GenericName=Productivity Cockpit\n"
        "Comment=Next-generation personal productivity cockpit, task matrix, and habit tracker\n"
        "Exec=%s\n"
        "Icon=com.axis.axis\n"
        "Terminal=false\n"
        "Categories=Office;ProjectManagement;\n"
        "Keywords=Task;Todo;Axis;Productivity;Habits;Calendar;Cockpit;\n"
        "StartupWMClass=com.axis.axis\n"
        "StartupNotify=true\n",
        exe_path);
    g_file_set_contents(desktop_path, desktop_content, -1, nullptr);
    g_free(desktop_content);
    chmod(desktop_path, 0755);
  }

  // 2. Ensure high-resolution icons are installed in ~/.local/share/icons/hicolor/
  g_autofree gchar* source_png = g_build_filename(exe_dir, "com.axis.axis.png", nullptr);
  if (!g_file_test(source_png, G_FILE_TEST_EXISTS)) {
    g_free(source_png);
    source_png = g_build_filename(exe_dir, "data", "flutter_assets", "assets", "logo.png", nullptr);
  }

  if (g_file_test(source_png, G_FILE_TEST_EXISTS)) {
    const gchar* icon_sizes[] = {"512x512", "256x256", "128x128", "64x64", "48x48", "32x32", "16x16"};
    gchar* img_data = nullptr;
    gsize img_len = 0;
    if (g_file_get_contents(source_png, &img_data, &img_len, nullptr)) {
      for (const char* sz : icon_sizes) {
        g_autofree gchar* icon_dir = g_build_filename(data_home, "icons", "hicolor", sz, "apps", nullptr);
        g_mkdir_with_parents(icon_dir, 0755);
        g_autofree gchar* dest_icon = g_build_filename(icon_dir, "com.axis.axis.png", nullptr);
        if (!g_file_test(dest_icon, G_FILE_TEST_EXISTS)) {
          g_file_set_contents(dest_icon, img_data, img_len, nullptr);
        }
      }
      g_free(img_data);
    }
  }

  // Copy scalable SVG icon if bundled
  g_autofree gchar* source_svg = g_build_filename(exe_dir, "com.axis.axis.svg", nullptr);
  if (g_file_test(source_svg, G_FILE_TEST_EXISTS)) {
    g_autofree gchar* svg_dir = g_build_filename(data_home, "icons", "hicolor", "scalable", "apps", nullptr);
    g_mkdir_with_parents(svg_dir, 0755);
    g_autofree gchar* dest_svg = g_build_filename(svg_dir, "com.axis.axis.svg", nullptr);
    if (!g_file_test(dest_svg, G_FILE_TEST_EXISTS)) {
      gchar* svg_data = nullptr;
      gsize svg_len = 0;
      if (g_file_get_contents(source_svg, &svg_data, &svg_len, nullptr)) {
        g_file_set_contents(dest_svg, svg_data, svg_len, nullptr);
        g_free(svg_data);
      }
    }
  }

  if (needs_desktop_write) {
    g_spawn_command_line_async("update-desktop-database ~/.local/share/applications", nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "axis");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "axis");
  }

  gtk_window_set_default_size(window, 1440, 900);

  // Set Linux window/taskbar icon from theme or bundled Flutter asset
  gtk_window_set_default_icon_name(APPLICATION_ID);
  gtk_window_set_icon_name(window, APPLICATION_ID);

  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);

    // Prefer high-resolution bundled icon, fallback to Flutter assets logo
    g_autofree gchar* icon_path = g_build_filename(exe_dir, "com.axis.axis.png", nullptr);
    if (!g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      g_free(icon_path);
      icon_path = g_build_filename(
          exe_dir, "data", "flutter_assets", "assets", "logo.png", nullptr);
    }
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
      gtk_window_set_default_icon_from_file(icon_path, nullptr);
    }

    // Ensure desktop entry and icons are registered in the "Show Applications" menu
    ensure_desktop_integration(exe_path, exe_dir);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);
  fl_dart_project_set_enable_impeller(project, FALSE);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  g_signal_connect(window, "event", G_CALLBACK(ensure_event_device_cb), nullptr);
  g_signal_connect(view, "event", G_CALLBACK(ensure_event_device_cb), nullptr);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
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
