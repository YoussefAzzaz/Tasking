#include <cstdlib>
#include <cstring>
#include <glib.h>

#include "my_application.h"

// Filter out expected notices such as the software renderer advisory.
static void custom_log_handler(const gchar* log_domain,
                               GLogLevelFlags log_level,
                               const gchar* message,
                               gpointer user_data) {
  if (message != nullptr &&
      (strstr(message, "Using the software renderer") != nullptr ||
       strstr(message, "FLUTTER_LINUX_RENDERER environment variable") != nullptr)) {
    return;
  }
  g_log_default_handler(log_domain, log_level, message, user_data);
}

int main(int argc, char** argv) {
  g_log_set_default_handler(custom_log_handler, nullptr);

  // Use software renderer to bypass upstream Flutter Linux bug (Issue #195885)
  // on NVIDIA GPUs where fl_compositor_opengl miscalculates NDC layer offsets
  // ((2 * x / width) - 1.0), squishing the UI into the bottom-left corner with black margins.
  setenv("FLUTTER_LINUX_RENDERER", "software", 1);
  setenv("GDK_BACKEND", "x11", 1);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}


