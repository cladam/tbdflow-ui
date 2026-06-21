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

pub fun load_log(path: string) {
  match exec(cmd_in(path, "git log --pretty=format:\"%h|%s|%an|%ar\" -25")) {
    Err(_) => [],
    Ok(raw) => parse_log_lines(split(trim(raw), "\n"))
  }
}

pub fun cmd_in(path: string, cmd: string) {
  if path != "" { "cd \"" + path + "\" && " + cmd } else { cmd }
}

pub fun parse_log_lines(lines: list<string>) {
  match lines {
    [] => [],
    [line, ..rest] =>
      if line == "" {
        parse_log_lines(rest)
      } else {
        [parse_commit_line(line)] + parse_log_lines(rest)
      }
  }
}

pub fun parse_commit_line(line: string) {
  let parts = split(line, "|")
  Commit {
    hash:     nth_str(parts, 0),
    subject:  nth_str(parts, 1),
    author:   nth_str(parts, 2),
    when_str: nth_str(parts, 3)
  }
}
