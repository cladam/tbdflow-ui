import "imgui"
import "./tbdflow-ui_theme"
import "./tbdflow"

// Dim label header — stands in for gui_text_disabled (not in API)
fun label(text: string) {
  gui_text_colored(text, 0.55, 0.60, 0.65, 1.0)
}

fun render_sidebar_context(i: Config, s: Status) {
  label("Branch")
  gui_text(s.current_branch)
  gui_spacing()

  label("Mode")
  gui_text(i.mode)
  gui_spacing()

  label("Trunk Target")
  gui_text(i.main_branch)
  gui_spacing()
  gui_separator()
  gui_spacing()

  label("CI Status:")
  gui_same_line()
  if i.ci_check_enabled {
    gui_text_colored("● Enabled", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("○ Disabled", 0.94, 0.33, 0.31, 1.0)
  }

  label("Radar:")
  gui_same_line()
  if i.radar_enabled {
    gui_text_colored("● Active", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("○ Off", 0.94, 0.33, 0.31, 1.0)
  }
}

fun render_radar_panel(s: Status) {
  label("Trunk Proximity")
  gui_text(" Ahead:  " + show(s.ahead) + " commits")
  gui_text(" Behind: " + show(s.behind) + " commits")
  gui_spacing()
  gui_separator()
  gui_spacing()

  label("Trunk CI")
  gui_text_wrapped(s.trunk_ci)
  gui_spacing()
  gui_separator()
  gui_spacing()

  if s.is_clean {
    gui_text_colored("✓ Tree Synced & Pure", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("⚠ WIP Change Alert", 0.94, 0.33, 0.31, 1.0)
    gui_text(show(s.changed_count) + " altered files")
    label("Run sync to audit collision vectors.")
  }
}

fun main() {
  var info   = None
  var status = None
  var last_output = ""

  gui_window("tbdflow", 1100, 720, () => {
    apply_theme()

    // ── Left: Context ────────────────────────────────────────────────────
    gui_child("##left", 220.0, 0.0, () => {
      gui_text_colored("tbdflow-ui", 0.23, 0.51, 0.96, 1.0)
      gui_separator()
      gui_spacing()

      match info {
        None    => gui_text("No data"),
        Some(i) => match status {
          None    => gui_text("No status"),
          Some(s) => render_sidebar_context(i, s)
        }
      }

      gui_spacing()
      gui_separator()
      gui_spacing()
      if gui_button("Refresh") {
        info   = load_info()
        status = load_status()
      }
    })

    gui_same_line()

    // ── Center: Action & Safety ──────────────────────────────────────────
    gui_child("##center", 440.0, 0.0, () => {
      label("CORE ENGINE OPERATIONS")
      gui_spacing()

      if gui_button("Sync Workspace & Pull Trunk") {
        match exec("tbdflow sync") {
          Ok(out) => last_output = out,
          Err(e)  => last_output = "Sync failed: " + e
        }
      }

      gui_spacing()
      gui_separator()
      gui_spacing()

      label("Commit to Trunk")
      gui_spacing()
      let default_types = ["feat", "fix", "chore", "docs", "refactor", "ci", "test"]
      let types = match info {
        None    => default_types,
        Some(i) => i.allowed_types
      }
      let combo_str = types_to_combo_str(types)
      let type_idx  = gui_combo("Type##ctype", combo_str, 0)
      let ctype     = nth_str(types, type_idx)
      let cmsg      = gui_input_text("Message##cmsg", 256)
      gui_spacing()

      if gui_button("Verify & Commit") {
        if cmsg != "" && ctype != "" {
          match exec("tbdflow commit -t " + ctype + " -m \"" + cmsg + "\"") {
            Ok(out) => last_output = out,
            Err(e)  => last_output = "Commit rejected: " + e
          }
        } else {
          last_output = "Type and message are required."
        }
      }

      gui_spacing()
      gui_separator()
      gui_spacing()
      label("Engine Output Console")
      gui_child("##console", 0.0, 180.0, () => {
        gui_text_wrapped(last_output)
      })
    })

    gui_same_line()

    // ── Right: Radar & Hotspots ──────────────────────────────────────────
    gui_child("##right", 0.0, 0.0, () => {
      label("RADAR & OVERLAP MATRIX")
      gui_separator()
      gui_spacing()
      match status {
        None    => gui_text("No telemetry loaded."),
        Some(s) => render_radar_panel(s)
      }
    })
  })
}
