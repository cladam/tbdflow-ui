import "imgui"
import "./tbdflow-ui_theme"

fun main() {
  var count = 0

  gui_window("My App", 520, 360, () => {
    apply_theme()
    gui_text("Counter: " + show(count))
    if gui_button("Increment") {
      count = count + 1
    }
  })
}