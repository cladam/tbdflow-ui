import "imgui"
import "./tbdflow-ui_theme"
import "./tbdflow"

fun main() {
  var info = None

  gui_window("tbdflow-ui", 520, 400, () => {
    apply_theme()
    gui_text("tbdflow Dashboard")
    gui_separator()

    if gui_button("Refresh") {
      info = load_info()
    }

    gui_spacing()

    match info {
      None => gui_text("Press Refresh to load tbdflow info"),
      Some(i) => {
        gui_text("Branch:  " + i.current_branch)
        gui_text("Mode:    " + i.mode)
        gui_text("Trunk:   " + i.main_branch)
        gui_text("CI:      " + (if i.ci_check_enabled { "enabled" } else { "disabled" }))
      }
    }
  })
}