import "imgui"
import "std/datetime"
import "./tbdflow-ui_theme"
import "./tbdflow"

fun apply_default_theme() {
  // Colors — from hica website CSS
  gui_set_color_text(0.118, 0.161, 0.231)      // #1e293b --primary-text
  gui_set_color_bg(0.902, 0.914, 0.933)         // #E6E9EE window background
  gui_set_color_surface(0.973, 0.976, 0.980)    // #f8f9fa --sidebar-bg
  gui_set_color_border(0.886, 0.910, 0.941)     // #e2e8f0 --border-color
  gui_set_color_accent(0.310, 0.275, 0.898)     // #4f46e5 --accent-indigo
  gui_set_color_plot(0.031, 0.569, 0.698)       // #0891b2 --accent-cyan
  gui_set_color_plot_bar(0.918, 0.345, 0.047)   // #ea580c variable orange
  gui_set_color_modal_dim(0.20)
  // Geometry
  gui_set_style_rounding(8.0, 5.0, 5.0)
  gui_set_style_padding(10.0, 5.0)
  gui_set_style_window_padding(14.0, 12.0)
  gui_set_style_spacing(8.0, 6.0, 18.0)
  gui_set_style_borders(1.0, 0.0)
}

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
  if length(s) > n { s[0:n] + "..." } else { s }
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
  gui_spacing()
  gui_separator()
  gui_spacing()

  label("CI Status:")
  gui_same_line()
  if i.ci_check_enabled {
    gui_text_colored("- Enabled", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("o Disabled", 0.94, 0.33, 0.31, 1.0)
  }

  label("Radar:")
  gui_same_line()
  if i.radar_enabled {
    gui_text_colored("- Active", 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("o Off", 0.94, 0.33, 0.31, 1.0)
  }
}

fun render_log_entry(c: Commit, repo_url: string) {
  if gui_selectable(c.hash, false) {
    if repo_url != "" {
      gui_open_url(repo_url + "/commit/" + c.hash)
    }
  }
  gui_same_line()
  gui_text(truncate(c.subject, 72))
  gui_hyperlink(c.author + "##auth_" + c.hash, "https://github.com/" + c.author)
  gui_same_line()
  label("· " + c.when_str)
  gui_spacing()
}

// Returns true if this note is an automated pre-sync safety snapshot.
fun is_snapshot(n: Note) {
  n.text == "Pre-sync safety snapshot"
}

// Returns true if any note in the list is a snapshot.
fun any_snapshot(notes: list<Note>) {
  match notes {
    []           => false,
    [n, ..rest]  => if is_snapshot(n) { true } else { any_snapshot(rest) }
  }
}

// Keeps only the last snapshot entry; removes all earlier duplicates.
fun dedup_snapshots(notes: list<Note>) {
  match notes {
    [] => [],
    [n, ..rest] =>
      if is_snapshot(n) && any_snapshot(rest) {
        dedup_snapshots(rest)
      } else {
        [n] + dedup_snapshots(rest)
      }
  }
}

fun render_intent_log(il: IntentLog) {
  if il.has_active_task {
    gui_text_colored("Task: " + il.task_description, 0.23, 0.51, 0.96, 1.0)
    gui_spacing()
  }
  let notes = dedup_snapshots(il.notes)
  if length(notes) == 0 {
    label("no notes yet")
  } else {
    for n in notes {
      label(short_time(n.timestamp))
      gui_same_line()
      gui_text_wrapped(n.text)
    }
  }
}

// Red to yellow gradient based on change count.
// 1 change = yellow, 5+ changes = red.
fun render_hotspot_entry(h: Hotspot) {
  let text = "• " + h.file + " (" + show(h.changes_count) + ")"
  if h.changes_count >= 5 {
    gui_text_colored(text, 0.94, 0.20, 0.20, 1.0)
  } else if h.changes_count == 4 {
    gui_text_colored(text, 0.96, 0.45, 0.10, 1.0)
  } else if h.changes_count == 3 {
    gui_text_colored(text, 0.97, 0.65, 0.07, 1.0)
  } else if h.changes_count == 2 {
    gui_text_colored(text, 0.98, 0.80, 0.05, 1.0)
  } else {
    gui_text_colored(text, 0.97, 0.93, 0.08, 1.0)
  }
}

fun render_awareness(s: Status, r: Radar) {
  label("Trunk")
  gui_text(r.trunk_branch)
  gui_same_line()
  if r.trunk_status == "green" {
    gui_text_colored("● " + r.trunk_status, 0.06, 0.71, 0.65, 1.0)
  } else {
    gui_text_colored("● " + r.trunk_status, 0.94, 0.33, 0.31, 1.0)
  }
  gui_spacing()

  label("Hotspots")
  if length(r.hotspots) == 0 {
    gui_text("none")
  } else {
    for h in r.hotspots {
      render_hotspot_entry(h)
    }
  }

  if !s.is_clean {
    gui_spacing()
    gui_separator()
    gui_spacing()
    gui_text_colored("WIP Changes", 0.94, 0.33, 0.31, 1.0)
    gui_spacing()
    for f in s.changed_files {
      gui_text(f)
    }
  }
}

fun take_commits(items: list<Commit>, n: int) {
  if n == 0 { [] }
  else {
    match items {
      []           => [],
      [c, ..rest]  => [c] + take_commits(rest, n - 1)
    }
  }
}

fun str_in_list(xs: list<string>, s: string) {
  match xs {
    []          => false,
    [h, ..rest] => if h == s { true } else { str_in_list(rest, s) }
  }
}

fun unique_authors(cs: list<Commit>) {
  match cs {
    []          => [],
    [c, ..rest] =>
      let others = unique_authors(rest)
      if str_in_list(others, c.author) { others } else { [c.author] + others }
  }
}

fun render_author_buttons(authors: list<string>) {
  match authors {
    [] => { }
    [a, ..rest] => {
      gui_same_line()
      gui_hyperlink(a + "##aw_" + a, "https://github.com/" + a)
      render_author_buttons(rest)
    }
  }
}

fun render_right_panel(s: Status, r: Radar, commits: list<Commit>) {
  render_awareness(s, r)
  if length(commits) > 0 {
    gui_spacing()
    gui_separator()
    gui_spacing()
    label("Recent Commits")
    gui_spacing()
    let recent = take_commits(commits, 5)
    let authors = unique_authors(recent)
    if length(authors) > 0 {
      gui_text("Latest commits by")
      render_author_buttons(authors)
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
  var theme_idx = 0

  gui_window("tbdflow-ui", 1100, 720, () => {
    if theme_idx == 0 { apply_theme() }
    else if theme_idx == 1 { apply_default_theme() }
    else { apply_one_dark_theme() }

    gui_main_menu(() => {
      gui_menu("Settings", () => {
        if gui_menu_item("Edit .tbdflow.yml") {
          match exec(cmd_in(repo_path, "open .tbdflow.yml")) {
            Ok(_) => { },
            Err(_) => { }
          }
        }
        gui_separator()
        let m0 = if theme_idx == 0 { "\u2713 " } else { "  " }
        if gui_menu_item(m0 + "tbdflow Theme") {
          theme_idx = 0
        }
        let m1 = if theme_idx == 1 { "\u2713 " } else { "  " }
        if gui_menu_item(m1 + "Default hica Theme") {
          theme_idx = 1
        }
        let m2 = if theme_idx == 2 { "\u2713 " } else { "  " }
        if gui_menu_item(m2 + "One Dark Pro") {
          theme_idx = 2
        }
      })
    })

    if repo_path != last_loaded_path {
      info      = load_info(repo_path)
      status    = load_status(repo_path)
      log       = load_log(repo_path)
      notes_log = ""
      intent_log = load_intent_log(repo_path)
      radar     = load_radar(repo_path)
      last_loaded_path = repo_path
    }

    // Push content below the main menu bar overlay.
    gui_dummy(0.0, 12.0)

    // Left: Context
    gui_child("##left", 200.0, 418.0, () => {
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
      if gui_button("Browse...") {
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

    // Centre: Workflow
    gui_child("##center", 500.0, 418.0, () => {
      gui_spacing()

      if gui_button("Sync Workspace & Pull Trunk") {
        match exec(cmd_in(repo_path, "tbdflow --json sync")) {
          Ok(raw) => {
            log    = parse_sync_commits(raw)
            status = load_status(repo_path)
          },
          Err(e) => last_output = "Sync failed: " + e
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

    // Right: Awareness
    gui_child("##right", 0.0, 418.0, () => {
      label("AWARENESS")
      gui_separator()
      gui_spacing()
      match info {
        None    => gui_text("No data"),
        Some(_) => match status {
          None    => gui_text("Loading..."),
          Some(s) => match radar {
            None    => gui_text("Loading..."),
            Some(r) => render_right_panel(s, r, log)
          }
        }
      }
    })

    // Bottom: Recent Commits (full width)
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
