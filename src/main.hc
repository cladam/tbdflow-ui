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
    gui_spacing()
    for f in s.changed_files {
      gui_text(f)
    }
    gui_spacing()
    label("Run sync to audit collision vectors.")
  }
}

fun render_log_entry(c: Commit, repo_url: string) {
  if gui_selectable(c.hash, false) {
    if repo_url != "" {
      match exec("open " + repo_url + "/commit/" + c.hash) {
        Ok(_) => { },
        Err(_) => { }
      }
    }
  }
  gui_same_line()
  gui_text(c.subject)
  label(c.author + " · " + c.when_str)
  gui_spacing()
}

fun main() {
  var info   = None
  var status = None
  var log    = []
  var loaded = false
  var last_output  = ""
  var show_advanced = false
  var opt_scope     = ""
  var opt_body      = ""
  var opt_tag       = ""
  var opt_issue     = ""
  var opt_breaking  = false
  var opt_no_verify = false
  var repo_path = ""

  gui_window("tbdflow", 1100, 720, () => {
    apply_theme()

    if !loaded {
      info   = load_info(repo_path)
      status = load_status(repo_path)
      log    = load_log(repo_path)
      loaded = true
    }

    // ── Left: Context ───
    gui_child("##left", 220.0, 0.0, () => {
      gui_text_colored("tbdflow-ui", 0.23, 0.51, 0.96, 1.0)
      gui_separator()
      gui_spacing()
      label("Repository")
      repo_path = gui_input_text("##rpath", 512)
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
        info   = load_info(repo_path)
        status = load_status(repo_path)
        log    = load_log(repo_path)
      }
    })

    gui_same_line()

    // ── Center: Action & Safety ──-
    gui_child("##center", 440.0, 0.0, () => {
      label("CORE ENGINE OPERATIONS")
      gui_spacing()

      if gui_button("Sync Workspace & Pull Trunk") {
        match exec(cmd_in(repo_path, "tbdflow sync")) {
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

      show_advanced = gui_checkbox("Advanced options", show_advanced)
      if show_advanced {
        gui_spacing()
        opt_scope     = gui_input_text("Scope (-s)##scope", 64)
        opt_body      = gui_input_text("Body (--body)##body", 512)
        opt_tag       = gui_input_text("Tag (--tag)##tag", 64)
        opt_issue     = gui_input_text("Issue (--issue)##issue", 64)
        opt_breaking  = gui_checkbox("Breaking change (-b)", opt_breaking)
        opt_no_verify = gui_checkbox("Skip DoD checklist (--no-verify)", opt_no_verify)
        gui_spacing()
      }

      if gui_button("Verify & Commit") {
        if cmsg != "" && ctype != "" {
          let cmd = cmd_in(repo_path, build_commit_cmd(ctype, cmsg, opt_scope, opt_body, opt_tag, opt_issue, opt_breaking, opt_no_verify))
          match exec(cmd) {
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
      label("RECENT COMMITS")
      gui_spacing()
      gui_child("##log", 0.0, 0.0, () => {
        let repo_url = match info { None => "", Some(i) => i.remote_url }
        for c in log {
          render_log_entry(c, repo_url)
        }
      })
    })

    gui_same_line()

    // ── Right: Radar & Hotspots ──
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
