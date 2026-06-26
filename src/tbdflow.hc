// Integration with tbdflow CLI
pub import "json"

pub struct Config {
  mode: string,
  main_branch: string,
  current_branch: string,
  remote_url: string,
  ci_check_enabled: bool,
  radar_enabled: bool,
  review_enabled: bool,
  allowed_types: list<string>
}

pub struct Status {
  current_branch: string,
  is_main: bool,
  is_clean: bool,
  ahead: int,
  behind: int,
  trunk_ci: string,
  changed_count: int,
  changed_files: list<string>
}

pub fun load_info(path: string) {
  match exec(cmd_in(path, "tbdflow --json info")) {
    Err(_) => None,
    Ok(raw) => parse_info(raw)
  }
}

pub fun parse_info(text: string) {
  let data = parse_json(text).json_ok.at("data")
  let types = extract_types(data.at("allowed_branch_types"))
  Some(Config {
    mode:             data.at("mode").str_or("unknown"),
    main_branch:      data.at("main_branch_name").str_or("main"),
    current_branch:   data.at("git").at("current_branch").str_or("unknown"),
    remote_url:       data.at("git").at("remote_url").str_or(""),
    ci_check_enabled: data.at("ci_check_enabled").bool_or(false),
    radar_enabled:    data.at("radar").at("enabled").bool_or(false),
    review_enabled:   data.at("review").at("enabled").bool_or(false),
    allowed_types:    types
  })
}

pub fun extract_string_array(arr: maybe<Json>) {
  match arr {
    None => [],
    Some(j) => match json_array(j) {
      None => [],
      Some(items) => collect_strings(items)
    }
  }
}

pub fun extract_types(arr: maybe<Json>) {
  let items = extract_string_array(arr)
  if length(items) == 0 { ["feat", "fix", "chore", "docs", "refactor", "ci", "test"] } else { items }
}

pub fun collect_strings(items: list<Json>) {
  match items {
    [] => [],
    [x, ..rest] => match json_str(x) {
      None    => collect_strings(rest),
      Some(s) => [s] + collect_strings(rest)
    }
  }
}

pub fun types_to_combo_str(types: list<string>) {
  match types {
    [] => "",
    [x] => x,
    [x, ..rest] => x + "\n" + types_to_combo_str(rest)
  }
}

pub fun nth_str(items: list<string>, i: int) {
  match items {
    [] => "",
    [x, ..rest] => if i == 0 { x } else { nth_str(rest, i - 1) }
  }
}

// Build a tbdflow commit command string from parts.
// Empty optional strings are omitted.
pub fun build_commit_cmd(ctype: string, msg: string, scope: string, body: string, tag: string, issue: string, breaking: bool, no_verify: bool) {
  let base = "tbdflow commit -t " + ctype + " -m \"" + msg + "\""
  let s1 = if scope != ""   { base  + " -s " + scope }          else { base }
  let s2 = if body  != ""   { s1    + " --body \"" + body + "\"" } else { s1 }
  let s3 = if tag   != ""   { s2    + " --tag " + tag }           else { s2 }
  let s4 = if issue != ""   { s3    + " --issue " + issue }        else { s3 }
  let s5 = if breaking      { s4    + " --breaking" }              else { s4 }
  let s6 = if no_verify     { s5    + " --no-verify" }             else { s5 }
  s6
}

pub fun load_status(path: string) {
  match exec(cmd_in(path, "tbdflow --json status")) {
    Err(_) => None,
    Ok(raw) => parse_status(raw)
  }
}

pub fun parse_status(text: string) {
  let data = parse_json(text).json_ok.at("data")
  Some(Status {
    current_branch: data.at("current_branch").str_or("unknown"),
    is_main:        data.at("is_main").bool_or(false),
    is_clean:       data.at("is_clean").bool_or(true),
    ahead:          data.at("ahead").int_or(0),
    behind:         data.at("behind").int_or(0),
    trunk_ci:       data.at("trunk_ci").str_or("unknown"),
    changed_count:  data.at("changed_files").json_length,
    changed_files:  extract_string_array(data.at("changed_files"))
  })
}

pub struct Commit {
  hash: string,
  subject: string,
  author: string,
  when_str: string
}

pub struct Hotspot {
  file: string,
  changes_count: int
}

pub struct Radar {
  trunk_branch: string,
  trunk_status: string,
  last_integrated_mins: int,
  branches_scanned: int,
  local_files_count: int,
  overlap_count: int,
  hotspots: list<Hotspot>
}

pub struct Note {
  timestamp: string,
  text: string,
  snapshot_hash: string
}

pub struct IntentLog {
  has_active_task: bool,
  task_description: string,
  branch_context: string,
  notes: list<Note>
}

pub fun load_log(path: string) {
  match exec(cmd_in(path, "tbdflow --json sync")) {
    Err(_) => [],
    Ok(raw) => parse_sync_commits(raw)
  }
}

pub fun parse_sync_commits(text: string) {
  let data = parse_json(text).json_ok.at("data")
  extract_commits(data.at("commits"))
}

pub fun extract_commits(arr: maybe<Json>) {
  match arr {
    None    => [],
    Some(j) => match json_array(j) {
      None        => [],
      Some(items) => parse_commit_items(items)
    }
  }
}

pub fun parse_commit_items(items: list<Json>) {
  match items {
    [] => [],
    [x, ..rest] => [parse_commit_item(x)] + parse_commit_items(rest)
  }
}

pub fun parse_commit_item(j: Json) {
  Commit {
    hash:     Some(j).at("hash").str_or(""),
    subject:  Some(j).at("subject").str_or(""),
    author:   Some(j).at("author").str_or(""),
    when_str: Some(j).at("relative_time").str_or("")
  }
}

pub fun load_intent_log(path: string) {
  match exec(cmd_in(path, "tbdflow --json note --show")) {
    Ok(raw) => parse_intent_log(raw),
    Err(_)  => None
  }
}

pub fun parse_intent_log(text: string) {
  let data = parse_json(text).json_ok.at("data")
  Some(IntentLog {
    has_active_task:  data.at("has_active_task").bool_or(false),
    task_description: data.at("task_description").str_or(""),
    branch_context:   data.at("branch_context").str_or(""),
    notes:            extract_notes(data.at("notes"))
  })
}

pub fun extract_notes(arr: maybe<Json>) {
  match arr {
    None    => [],
    Some(j) => match json_array(j) {
      None        => [],
      Some(items) => parse_notes(items)
    }
  }
}

pub fun parse_notes(items: list<Json>) {
  match items {
    [] => [],
    [x, ..rest] => [parse_note(x)] + parse_notes(rest)
  }
}

pub fun parse_note(j: Json) {
  Note {
    timestamp:     Some(j).at("timestamp").str_or(""),
    text:          Some(j).at("text").str_or(""),
    snapshot_hash: Some(j).at("snapshot_hash").str_or("")
  }
}

pub fun load_radar(path: string) {
  match exec(cmd_in(path, "tbdflow --json radar")) {
    Ok(raw) => parse_radar(raw),
    Err(_)  => None
  }
}

pub fun parse_radar(text: string) {
  let data  = parse_json(text).json_ok.at("data")
  let trunk = data.at("trunk")
  Some(Radar {
    trunk_branch:         trunk.at("branch_name").str_or("unknown"),
    trunk_status:         trunk.at("status").str_or("unknown"),
    last_integrated_mins: trunk.at("last_integrated_minutes_ago").int_or(0),
    branches_scanned:     data.at("branches_scanned").int_or(0),
    local_files_count:    data.at("local_files_count").int_or(0),
    overlap_count:        count_json_array(data.at("overlaps")),
    hotspots:             extract_hotspots(data.at("hotspots"))
  })
}

pub fun extract_hotspots(arr: maybe<Json>) {
  match arr {
    None    => [],
    Some(j) => match json_array(j) {
      None        => [],
      Some(items) => parse_hotspots(items)
    }
  }
}

pub fun parse_hotspots(items: list<Json>) {
  match items {
    [] => [],
    [x, ..rest] => [parse_hotspot(x)] + parse_hotspots(rest)
  }
}

pub fun parse_hotspot(j: Json) {
  Hotspot {
    file:          Some(j).at("file").str_or(""),
    changes_count: Some(j).at("changes_count").int_or(0)
  }
}

pub fun count_json_array(arr: maybe<Json>) {
  match arr {
    None    => 0,
    Some(j) => match json_array(j) {
      None        => 0,
      Some(items) => length(items)
    }
  }
}

pub fun cmd_in(path: string, cmd: string) {
  if path != "" { "cd \"" + path + "\" && " + cmd } else { cmd }
}
