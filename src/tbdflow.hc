// Integration with tbdflow CLI
pub import "json"

pub struct Config {
  mode: string,
  main_branch: string,
  current_branch: string,
  ci_check_enabled: bool
}

pub fun load_info() {
  match exec("tbdflow --json info") {
    Err(_) => None,
    Ok(raw) => parse_info(raw)
  }
}

pub fun parse_info(text: string) {
  let data = parse_json(text) |> json_ok |> at("data")
  let mode = str_or(data |> at("mode"), "unknown")
  let branch = str_or(data |> at("main_branch_name"), "main")
  let current = str_or(data |> at("git") |> at("current_branch"), "unknown")
  let ci = bool_or(data |> at("ci_check_enabled"), false)
  Some(Config { mode: mode, main_branch: branch, current_branch: current, ci_check_enabled: ci })
}
