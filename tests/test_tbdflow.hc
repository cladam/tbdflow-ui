import "../src/tbdflow"

// ─── cmd_in ────────────────────────────────────────────────────────────────

test "cmd_in: empty path passes cmd through" {
  assert(cmd_in("", "tbdflow status") == "tbdflow status")
}

test "cmd_in: non-empty path prepends cd" {
  assert(cmd_in("/home/user/repo", "tbdflow status") == "cd \"/home/user/repo\" && tbdflow status")
}

// ─── nth_str ───────────────────────────────────────────────────────────────

test "nth_str: first element" {
  assert(nth_str(["a", "b", "c"], 0) == "a")
}

test "nth_str: middle element" {
  assert(nth_str(["a", "b", "c"], 1) == "b")
}

test "nth_str: last element" {
  assert(nth_str(["a", "b", "c"], 2) == "c")
}

test "nth_str: empty list returns empty string" {
  assert(nth_str([], 0) == "")
}

test "nth_str: out of bounds returns empty string" {
  assert(nth_str(["a"], 5) == "")
}

// ─── types_to_combo_str ───────────────────────────────────────────────────

test "types_to_combo_str: empty list" {
  assert(types_to_combo_str([]) == "")
}

test "types_to_combo_str: single item" {
  assert(types_to_combo_str(["feat"]) == "feat")
}

test "types_to_combo_str: two items joined with newline" {
  assert(types_to_combo_str(["feat", "fix"]) == "feat\nfix")
}

test "types_to_combo_str: three items" {
  assert(types_to_combo_str(["feat", "fix", "chore"]) == "feat\nfix\nchore")
}

// ─── build_commit_cmd ─────────────────────────────────────────────────────

test "build_commit_cmd: minimal" {
  let cmd = build_commit_cmd("feat", "add button", "", "", "", "", false, false)
  assert(cmd == "tbdflow commit -t feat -m \"add button\"")
}

test "build_commit_cmd: with scope" {
  let cmd = build_commit_cmd("fix", "null check", "auth", "", "", "", false, false)
  assert(cmd == "tbdflow commit -t fix -m \"null check\" -s auth")
}

test "build_commit_cmd: with body" {
  let cmd = build_commit_cmd("docs", "update readme", "", "more detail", "", "", false, false)
  assert(cmd == "tbdflow commit -t docs -m \"update readme\" --body \"more detail\"")
}

test "build_commit_cmd: with tag" {
  let cmd = build_commit_cmd("fix", "patch", "", "", "v1.0.1", "", false, false)
  assert(cmd == "tbdflow commit -t fix -m \"patch\" --tag v1.0.1")
}

test "build_commit_cmd: with issue" {
  let cmd = build_commit_cmd("feat", "login page", "", "", "", "PROJ-42", false, false)
  assert(cmd == "tbdflow commit -t feat -m \"login page\" --issue PROJ-42")
}

test "build_commit_cmd: breaking flag" {
  let cmd = build_commit_cmd("refactor", "rename api", "", "", "", "", true, false)
  assert(cmd == "tbdflow commit -t refactor -m \"rename api\" --breaking")
}

test "build_commit_cmd: no-verify flag" {
  let cmd = build_commit_cmd("chore", "bump deps", "", "", "", "", false, true)
  assert(cmd == "tbdflow commit -t chore -m \"bump deps\" --no-verify")
}

test "build_commit_cmd: all flags combined" {
  let cmd = build_commit_cmd("feat", "new thing", "ui", "body text", "v2.0.0", "PROJ-1", true, true)
  assert(cmd == "tbdflow commit -t feat -m \"new thing\" -s ui --body \"body text\" --tag v2.0.0 --issue PROJ-1 --breaking --no-verify")
}

// ─── parse_info ───────────────────────────────────────────────────────────
// Note: \{ and \} escape literal braces inside hica string literals.

fun info_json() {
  "\{\"success\":true,\"data\":\{\"mode\":\"tbd\",\"main_branch_name\":\"main\",\"ci_check_enabled\":true,\"radar\":\{\"enabled\":true\},\"review\":\{\"enabled\":false\},\"git\":\{\"current_branch\":\"feat/auth\",\"remote_url\":\"https://github.com/org/repo\"\},\"allowed_branch_types\":[\"feat\",\"fix\",\"chore\"]\}\}"
}

test "parse_info: parses mode and branch fields" {
  match parse_info(info_json()) {
    None    => assert(false),
    Some(c) => {
      assert(c.mode == "tbd")
      assert(c.main_branch == "main")
      assert(c.current_branch == "feat/auth")
      assert(c.remote_url == "https://github.com/org/repo")
    }
  }
}

test "parse_info: parses feature flags" {
  match parse_info(info_json()) {
    None    => assert(false),
    Some(c) => {
      assert(c.ci_check_enabled == true)
      assert(c.radar_enabled == true)
      assert(c.review_enabled == false)
    }
  }
}

test "parse_info: parses allowed_types from JSON array" {
  match parse_info(info_json()) {
    None    => assert(false),
    Some(c) => {
      assert(length(c.allowed_types) == 3)
      assert(nth_str(c.allowed_types, 0) == "feat")
      assert(nth_str(c.allowed_types, 1) == "fix")
      assert(nth_str(c.allowed_types, 2) == "chore")
    }
  }
}

test "parse_info: falls back to 7 default types when field is absent" {
  let json = "\{\"success\":true,\"data\":\{\"mode\":\"simple\",\"main_branch_name\":\"trunk\",\"ci_check_enabled\":false,\"radar\":\{\"enabled\":false\},\"review\":\{\"enabled\":false\},\"git\":\{\"current_branch\":\"main\",\"remote_url\":\"\"\}\}\}"
  match parse_info(json) {
    None    => assert(false),
    Some(c) => {
      assert(length(c.allowed_types) == 7)
      assert(nth_str(c.allowed_types, 0) == "feat")
    }
  }
}

// ─── parse_status ─────────────────────────────────────────────────────────

fun status_json() {
  "\{\"success\":true,\"data\":\{\"current_branch\":\"main\",\"is_main\":true,\"is_clean\":true,\"ahead\":0,\"behind\":2,\"trunk_ci\":\"green\",\"changed_files\":[]\}\}"
}

test "parse_status: parses clean trunk state" {
  match parse_status(status_json()) {
    None    => assert(false),
    Some(s) => {
      assert(s.current_branch == "main")
      assert(s.is_main == true)
      assert(s.is_clean == true)
      assert(s.ahead == 0)
      assert(s.commits_behind == 2)
      assert(s.trunk_ci == "green")
      assert(s.changed_count == 0)
    }
  }
}

test "parse_status: parses dirty feature branch" {
  let json = "\{\"success\":true,\"data\":\{\"current_branch\":\"feat/ui\",\"is_main\":false,\"is_clean\":false,\"ahead\":3,\"behind\":0,\"trunk_ci\":\"unknown\",\"changed_files\":[\"src/main.hc\",\"src/tbdflow.hc\"]\}\}"
  match parse_status(json) {
    None    => assert(false),
    Some(s) => {
      assert(s.is_main == false)
      assert(s.is_clean == false)
      assert(s.ahead == 3)
      assert(s.changed_count == 2)
    }
  }
}

// ─── parse_sync_commits ───────────────────────────────────────────────────

fun commits_json() {
  "\{\"success\":true,\"data\":\{\"commits\":[\{\"hash\":\"abc1234\",\"subject\":\"feat: add login\",\"author\":\"cladam\",\"relative_time\":\"2 hours ago\"\},\{\"hash\":\"def5678\",\"subject\":\"fix: null check\",\"author\":\"cladam\",\"relative_time\":\"1 day ago\"\}]\}\}"
}

test "parse_sync_commits: parses commit list" {
  let commits = parse_sync_commits(commits_json())
  assert(length(commits) == 2)
  match commits {
    []          => assert(false),
    [c, ..rest] => {
      assert(c.hash == "abc1234")
      assert(c.subject == "feat: add login")
      assert(c.author == "cladam")
      assert(c.when_str == "2 hours ago")
    }
  }
}

test "parse_sync_commits: empty commits array" {
  let commits = parse_sync_commits("\{\"success\":true,\"data\":\{\"commits\":[]\}\}")
  assert(length(commits) == 0)
}

// ─── parse_intent_log ─────────────────────────────────────────────────────

fun intent_log_json() {
  "\{\"success\":true,\"data\":\{\"has_active_task\":true,\"task_description\":\"Refactor auth\",\"branch_context\":\"feat/auth\",\"notes\":[\{\"timestamp\":\"2026-06-19T22:15:00+00:00\",\"text\":\"tried factory pattern\",\"snapshot_hash\":\"abc123\"\}]\}\}"
}

test "parse_intent_log: parses active task and notes" {
  match parse_intent_log(intent_log_json()) {
    None     => assert(false),
    Some(il) => {
      assert(il.has_active_task == true)
      assert(il.task_description == "Refactor auth")
      assert(il.branch_context == "feat/auth")
      assert(length(il.notes) == 1)
      match il.notes {
        []          => assert(false),
        [n, ..rest] => {
          assert(n.text == "tried factory pattern")
          assert(n.snapshot_hash == "abc123")
        }
      }
    }
  }
}

test "parse_intent_log: no active task" {
  let json = "\{\"success\":true,\"data\":\{\"has_active_task\":false,\"task_description\":\"\",\"branch_context\":\"main\",\"notes\":[]\}\}"
  match parse_intent_log(json) {
    None     => assert(false),
    Some(il) => {
      assert(il.has_active_task == false)
      assert(length(il.notes) == 0)
    }
  }
}

// ─── parse_radar ──────────────────────────────────────────────────────────

fun radar_json() {
  "\{\"success\":true,\"data\":\{\"trunk\":\{\"branch_name\":\"main\",\"status\":\"green\",\"last_integrated_minutes_ago\":12\},\"hotspots\":[\{\"file\":\"src/auth/logic.rs\",\"changes_count\":14\}],\"overlaps\":[],\"branches_scanned\":4,\"local_files_count\":3\}\}"
}

test "parse_radar: parses trunk and hotspot fields" {
  match parse_radar(radar_json()) {
    None    => assert(false),
    Some(r) => {
      assert(r.trunk_branch == "main")
      assert(r.trunk_status == "green")
      assert(r.last_integrated_mins == 12)
      assert(r.branches_scanned == 4)
      assert(r.local_files_count == 3)
      assert(r.overlap_count == 0)
      assert(length(r.hotspots) == 1)
      match r.hotspots {
        []          => assert(false),
        [h, ..rest] => {
          assert(h.file == "src/auth/logic.rs")
          assert(h.changes_count == 14)
        }
      }
    }
  }
}

test "parse_radar: counts overlaps correctly" {
  let json = "\{\"success\":true,\"data\":\{\"trunk\":\{\"branch_name\":\"main\",\"status\":\"green\",\"last_integrated_minutes_ago\":5\},\"hotspots\":[],\"branches_scanned\":2,\"local_files_count\":1,\"overlaps\":[\{\"branch\":\"feat/auth\",\"author\":\"@alice\",\"commits_ahead\":2,\"files\":[]\}]\}\}"
  match parse_radar(json) {
    None    => assert(false),
    Some(r) => assert(r.overlap_count == 1)
  }
}
