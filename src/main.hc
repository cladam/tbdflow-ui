import "imgui"
import "std/datetime"
import "./tbdflow-ui_theme"
import "./tbdflow"

// Dim label header — stands in for gui_text_disabled (not in API)
fun label(text: string) {
  gui_text_colored(text, 0.55, 0.60, 0.65, 1.0)
}

fun format_mins(mins: int) {
  if mins < 60 {
    show(mins) + " min ago"
  } else {
    show(mins / 60) + "h ago"
  }
}

fun truncate(s: string, n: int) {
  if length(s) > n { s[0:n] + "…" } else { s }
}

fun short_time(ts: string) {
  match datetime_time(ts) {
    Ok(t)  => t[0:5],
    Err(_) => ts
  }
}

fun render_sidebar_context(i: Config, s: Status) {
  label("Branch")
  gui_text(s.current_branch)
  gui_spacing()

  label("Mode")
  gui_text(i.mode)
  gui_spacing()

  label("Trunk target")
  gui_text(i.main_branch)
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
  gui_text(truncate(c.subject, 72))
  label(c.author + " · " + c.when_str)
  gui_spacing()
}

fun render_intent_log(il: IntentLog) {
  if il.has_active_task {
    gui_text_colored("● Task: " + il.task_description, 0.23, 0.51, 0.96, 1.0)
    gui_spacing()
  }
  if length(il.notes) == 0 {
    label("no notes yet")
  } else {
    for n in il.notes {
      label(short_time(n.timestamp))
      gui_same_line()
      gui_text_wrapped(n.text)
    }
  }
}

fun render_awareness(i: Config, s: Status, r: Radar) {
  label("Trunk")
  gui_text(r.trunk_branch)
  gui_same_line()
  if r.trunk_status == "green" {
    gui_text_colored("● " + r.trunk_status, 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("● " + r.trunk_status, 0.94, 0.33, 0.31, 1.0)
  }
  label("Last integrated")
  gui_text(format_mins(r.last_integrated_mins))
  gui_spacing()

  label("CI")
  gui_same_line()
  if i.ci_check_enabled {
    gui_text_colored("● Enabled", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("○ Disabled", 0.94, 0.33, 0.31, 1.0)
  }
  if s.trunk_ci != "unknown" && s.trunk_ci != "" {
    gui_text_wrapped(s.trunk_ci)
  }
  gui_spacing()

  label("Ahead / Behind")
  gui_text(show(s.ahead) + " / " + show(s.behind))
  gui_spacing()
  gui_separator()
  gui_spacing()

  label("Branches scanned")
  gui_text(show(r.branches_scanned))
  gui_spacing()
  label("Overlaps")
  gui_text(show(r.overlap_count))
  gui_spacing()
  label("Hotspots")
  if length(r.hotspots) == 0 {
    gui_text("none")
  } else {
    for h in r.hotspots {
      gui_bullet_text(h.file + " (" + show(h.changes_count) + ")")
    }
  }

  if !s.is_clean {
    gui_spacing()
    gui_separator()
    gui_spacing()
    gui_text_colored("⚠ WIP Changes", 0.94, 0.33, 0.31, 1.0)
    gui_spacing()
    for f in s.changed_files {
      gui_text(f)
    }
  }
}

fun main() {
  var info   = None
  var status = None
  var log    = []
  var last_loaded_path = "__never__"
  var last_output  = ""
  var show_advanced = false
  var opt_scope     = ""
  var opt_body      = ""
  var opt_tag       = ""
  var opt_issue     = ""
  var opt_breaking  = false
  var opt_no_verify = false
  var repo_path = ""
  var note_text = ""
  var note_input_id = 0
  var notes_log = ""
  var intent_log = None
  var radar = None

  gui_window("tbdflow-ui", 1100, 720, () => {
    apply_theme()

    if repo_path != last_loaded_path {
      info      = load_info(repo_path)
      status    = load_status(repo_path)
      log       = load_log(repo_path)
      notes_log = ""
      intent_log = load_intent_log(repo_path)
      radar     = load_radar(repo_path)
      last_loaded_path = repo_path
    }

    // ── Left: Context ───
    gui_child("##left", 200.0, 430.0, () => {
      gui_text_colored("tbdflow-ui", 0.23, 0.51, 0.96, 1.0)
      gui_separator()
      gui_spacing()
      label("Repository")
      if repo_path == "" {
        gui_text("(current directory)")
      } else {
        gui_text_wrapped(repo_path)
      }
      gui_spacing()
      if gui_button("Browse…") {
        match exec("osascript -e 'POSIX path of (choose folder)'") {
          Ok(picked) => {
            let parts = split(picked, "\n")
            let p = match parts { [] => "", [h, ..] => h }
            if p != "" {
              repo_path = p
              last_loaded_path = "__reload__"
            }
          },
          Err(_) => { }
        }
      }
      gui_same_line()
      if gui_button("Refresh") {
        last_loaded_path = "__reload__"
      }
      gui_spacing()

      match info {
        None    => gui_text("No data"),
        Some(i) => match status {
          None    => gui_text("No status"),
          Some(s) => render_sidebar_context(i, s)
        }
      }
    })

    gui_same_line()

    // ── Centre: Workflow ──
    gui_child("##center", 500.0, 430.0, () => {
      gui_spacing()

      if gui_button("Sync Workspace & Pull Trunk") {
        match exec(cmd_in(repo_path, "tbdflow --json sync")) {
          Ok(raw) => {
            log    = parse_sync_commits(raw)
            status = load_status(repo_path)
          },
          Err(_) => { }
        }
      }

      gui_spacing()
      gui_separator()
      gui_spacing()

      label("Intent Log")
      gui_spacing()
      note_text = gui_input_text("##note" + show(note_input_id), 256)
      gui_same_line()
      if gui_button("Add Note") {
        if note_text != "" {
          match exec(cmd_in(repo_path, "tbdflow note \"" + note_text + "\"")) {
            Ok(_) => {
              note_input_id = note_input_id + 1
              intent_log = load_intent_log(repo_path)
            },
            Err(_) => { }
          }
        }
      }
      if notes_log != "" {
        gui_spacing()
        gui_text_wrapped(notes_log)
      }
      match intent_log {
        None     => { },
        Some(il) => {
          gui_spacing()
          render_intent_log(il)
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
    })

    gui_same_line()

    // ── Right: Awareness ──
    gui_child("##right", 0.0, 430.0, () => {
      label("AWARENESS")
      gui_separator()
      gui_spacing()
      match info {
        None    => gui_text("No data"),
        Some(i) => match status {
          None    => gui_text("Loading…"),
          Some(s) => match radar {
            None    => gui_text("Loading…"),
            Some(r) => render_awareness(i, s, r)
          }
        }
      }
    })

    // ── Bottom: Recent Commits (full width) ──
    gui_child("##bottom", 0.0, 0.0, () => {
      label("Recent Commits")
      gui_separator()
      gui_spacing()
      let repo_url = match info { None => "", Some(i) => i.remote_url }
      for c in log {
        render_log_entry(c, repo_url)
      }
    })
  })
}
