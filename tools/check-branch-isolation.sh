#!/usr/bin/env bash
# =============================================================================
# check-branch-isolation — U15 isolamento/evidence/secrets oracle.
#
# Modes (--mode, comma-separated):
#   branch             одна ветка — один worktree + живой durable lock владельца
#   commit             + commit достижим от refs/heads/<branch>, writer тот же
#   evidence-retention ORC_EVIDENCE_ROOT вне репо/worktree, MANIFEST.json/sha256,
#                      retention window и внешний backup
#   gate-bundle        pinned ORC_GATE_BUNDLE_DIGEST (JCS sha256 {version,files})
#   host-secrets       .git/config без URL-кредов/PAT, credential helper,
#                      .env 600/untracked, нет tracked .env/*.pem/*.key/*.dump
#   secret-refs        deploy/stands, templates/default, .env.example — только
#                      secret_ref/dsn_ref/${VAR}, без литеральных значений
#   all                branch,commit,evidence-retention,gate-bundle,secret-refs
#                      (host-secrets — только явно: в CI .git/config содержит
#                       checkout-креды и дал бы false positive)
#
# Fail-close: нарушение изоляции писателя — код shared_worktree_commit.
# Печатаются только имена файлов/путей/ветки; значения секретов НЕ покидают
# скрипт (ни в stdout, ни в JSON, ни в stderr).
#
# Usage:
#   bash tools/check-branch-isolation.sh --mode branch --repo . --execution E123
#   bash tools/check-branch-isolation.sh --self-test
#   bash tools/check-branch-isolation.sh --self-test --mode branch,commit
#   bash tools/check-branch-isolation.sh --mode all --repo . --json
# =============================================================================

set -uo pipefail

MODE="branch,commit"
REPO=""
EXECUTION=""
BRANCH=""
COMMIT=""
JSON=0
STRICT=0
SELFTEST=0
RETENTION_DAYS=0
EVIDENCE_ROOT="${ORC_EVIDENCE_ROOT:-}"
BACKUP_DIR=""
GATE_BUNDLE="${ORC_GATE_BUNDLE:-}"
GATE_DIGEST="${ORC_GATE_BUNDLE_DIGEST:-}"

RES_MODE=()
RES_STATUS=()
RES_CODE=()
RES_DETAIL=()

last_code=""
last_detail=""

usage() {
    sed -n '2,34p' "$0"
}

die_usage() {
    echo "FAIL[check-branch-isolation]: $*" >&2
    exit 2
}

add_result() { # mode status code detail
    RES_MODE+=("$1")
    RES_STATUS+=("$2")
    RES_CODE+=("$3")
    local detail="${4//$'\t'/ }"
    detail="${detail//$'\n'/ }"
    RES_DETAIL+=("$detail")
}

pass_mode() {
    add_result "$1" "pass" "" "$2"
    [[ "$JSON" -eq 1 ]] || echo "PASS[$1]: $2"
}

fail_mode() {
    add_result "$1" "fail" "$2" "$3"
    FAILED=1
    [[ "$JSON" -eq 1 ]] || echo "FAIL[$1]: $2 — $3" >&2
}

skip_mode() {
    add_result "$1" "skip" "$2" "$3"
    [[ "$JSON" -eq 1 ]] || echo "SKIP[$1]: $2 — $3"
}

# ─── helpers ────────────────────────────────────────────────────────────────

sha256_stdin() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    else
        python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
    fi
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"
    fi
}

realpath_dir() {
    ( cd "$1" 2>/dev/null && pwd -P )
}

is_within() { # parent child
    local parent child
    parent="$(realpath_dir "$1" || printf '%s' "$1")"
    child="$(realpath_dir "$2" || printf '%s' "$2")"
    [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

execution_id_from_branch() {
    local b="$1"
    if [[ "$b" == orc-exec-* ]]; then
        printf '%s' "${b#orc-exec-}"
    fi
}

resolve_repo() {
    local r="${REPO:-.}"
    if ! git -C "$r" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi
    realpath_dir "$r"
}

git_common_dir() { # repo
    local common
    common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common=""
    if [[ -z "$common" ]]; then
        common="$(realpath_dir "$1/.git" 2>/dev/null || printf '%s/.git' "$1")"
    fi
    printf '%s' "$common"
}

worktree_porcelain() { # repo -> path<TAB>branch
    git -C "$1" worktree list --porcelain 2>/dev/null | awk '
        /^worktree / { p = substr($0, 10); b = "" }
        /^branch /   { b = substr($0, 8); print p "\t" b }
        /^detached/  { print p "\t(detached)" }
    '
}

# ─── branch/commit ──────────────────────────────────────────────────────────

# check_writer validates: exactly one worktree registration for branch, that
# worktree is <repo>/.orc-worktrees/<execution>, HEAD on branch, durable lock
# exists and is live and owned by execution.
check_writer() {
    last_code=""
    last_detail=""
    local repo exec_id branch
    repo="$(resolve_repo)" || { last_code="shared_worktree_commit"; last_detail="kind=not_a_git_repo"; return 1; }
    exec_id="$EXECUTION"
    branch="$BRANCH"
    [[ -z "$exec_id" ]] && exec_id="$(execution_id_from_branch "$branch")"
    [[ -z "$branch" && -n "$exec_id" ]] && branch="orc-exec-$exec_id"
    if [[ -z "$exec_id" && -z "$branch" ]]; then
        last_code="no_execution"; last_detail="branch/commit checks require --execution or --branch"; return 2
    fi
    [[ -z "$exec_id" || -z "$branch" ]] && { last_code="shared_worktree_commit"; last_detail="kind=invalid_input need --execution/--branch"; return 1; }

    local common lock_hash lock_file
    common="$(git_common_dir "$repo")"
    lock_hash="$(printf '%s' "$branch" | sha256_stdin)"
    lock_file="$common/orc-branch-locks/$lock_hash.lock"
    if [[ ! -f "$lock_file" ]]; then
        last_code="shared_worktree_commit"; last_detail="kind=lock_not_held branch=$branch"; return 1
    fi
    local owner_fields owner_exec owner_branch owner_pid owner_host
    owner_fields="$(python3 - "$lock_file" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(3)
print("\t".join(str(d.get(k, "")) for k in ("execution_id", "branch", "pid", "host")))
PY
)" || { last_code="shared_worktree_commit"; last_detail="kind=lock_owner_unreadable"; return 1; }
    IFS=$'\t' read -r owner_exec owner_branch owner_pid owner_host <<<"$owner_fields"
    if [[ "$owner_exec" != "$exec_id" || "$owner_branch" != "$branch" ]]; then
        last_code="shared_worktree_commit"
        last_detail="kind=lock_owner_mismatch owner=$owner_exec branch=$owner_branch"
        return 1
    fi
    if [[ "$owner_host" != "$(hostname 2>/dev/null || echo unknown)" ]] || ! kill -0 "$owner_pid" 2>/dev/null; then
        last_code="shared_worktree_commit"
        last_detail="kind=lock_not_held branch=$branch (stale owner requires flock takeover)"
        return 1
    fi

    local count=0 wt_path="" wt_branch=""
    while IFS=$'\t' read -r p b; do
        [[ -z "$p" ]] && continue
        if [[ "$b" == "refs/heads/$branch" ]]; then
            count=$((count + 1)); wt_path="$p"; wt_branch="$b"
        fi
    done < <(worktree_porcelain "$repo")
    case "$count" in
        0) last_code="shared_worktree_commit"; last_detail="kind=branch_not_checked_out branch=$branch"; return 1 ;;
        1) ;;
        *) last_code="shared_worktree_commit"; last_detail="kind=worktree_shared branch=$branch registrations=$count"; return 1 ;;
    esac
    local want got
    want="$repo/.orc-worktrees/$exec_id"
    got="$wt_path"
    [[ -d "$got" ]] && got="$(realpath_dir "$got")"
    [[ -d "$want" ]] && want="$(realpath_dir "$want")"
    if [[ "$got" != "$want" ]]; then
        last_code="shared_worktree_commit"
        last_detail="kind=worktree_path_mismatch branch=$branch got=$got want=$want"
        return 1
    fi
    local head
    head="$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)" || head=""
    if [[ "$head" != "$branch" || "$wt_branch" != "refs/heads/$branch" ]]; then
        last_code="shared_worktree_commit"
        last_detail="kind=head_mismatch branch=$branch head=$head"
        return 1
    fi
    last_detail="branch=$branch worktree=$wt_path lock=$lock_file"
    return 0
}

check_commit() {
    check_writer
    local wrc=$?
    if [[ "$wrc" -eq 2 ]]; then
        return 2
    fi
    if [[ "$wrc" -ne 0 ]]; then
        return 1
    fi
    local repo branch commit sha
    repo="$(resolve_repo)" || { last_code="shared_worktree_commit"; last_detail="kind=not_a_git_repo"; return 1; }
    branch="$BRANCH"
    [[ -z "$branch" ]] && branch="orc-exec-$EXECUTION"
    commit="${COMMIT:-HEAD}"
    sha="$(git -C "$repo" rev-parse --verify --quiet "${commit}^{commit}" 2>/dev/null)" || sha=""
    if [[ -z "$sha" ]]; then
        last_code="shared_worktree_commit"; last_detail="kind=commit_unreachable commit=$commit"; return 1
    fi
    if ! git -C "$repo" merge-base --is-ancestor "$sha" "refs/heads/$branch" 2>/dev/null; then
        last_code="shared_worktree_commit"
        last_detail="kind=commit_unreachable commit=$sha branch=$branch"
        return 1
    fi
    last_detail="branch=$branch commit=$sha reachable=1"
    return 0
}

# ─── evidence retention/backup ──────────────────────────────────────────────

check_evidence() {
    last_code=""
    last_detail=""
    local repo root retention backup strict
    repo="$(resolve_repo)" || { last_code="evidence_root_missing"; last_detail="not a git repo"; return 1; }
    root="${EVIDENCE_ROOT:-}"
    retention="${RETENTION_DAYS:-0}"
    backup="${BACKUP_DIR:-}"
    strict="${STRICT:-0}"
    if [[ -z "$root" ]]; then
        if [[ "$strict" == "1" ]]; then
            last_code="evidence_root_missing"; last_detail="ORC_EVIDENCE_ROOT is not configured"; return 1
        fi
        last_code="evidence_root_unconfigured"; last_detail="skipped (non-strict)"; return 2
    fi
    if [[ "$root" != /* ]]; then
        last_code="evidence_root_not_absolute"; last_detail="root=$root"; return 1
    fi
    if [[ ! -d "$root" ]]; then
        last_code="evidence_root_missing"; last_detail="root=$root"; return 1
    fi
    root="$(realpath_dir "$root")"
    if is_within "$repo" "$root"; then
        last_code="evidence_root_inside_repo"; last_detail="root=$root repo=$repo"; return 1
    fi

    local py_out
    py_out="$(python3 - "$root" "$repo" "$retention" "$backup" "$strict" <<'PY'
import hashlib, json, os, sys, time

root, repo, retention, backup, strict = sys.argv[1], os.path.realpath(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5] == "1"
errors = []          # (code, detail)
manifests = []
for dirpath, _dirs, names in os.walk(root):
    for n in names:
        if n == "MANIFEST.json":
            manifests.append(os.path.join(dirpath, n))
manifests.sort()

if not manifests:
    if strict:
        print("evidence_manifest_missing\tno MANIFEST.json under evidence root")
        sys.exit(1)
    print("evidence_manifest_missing\tno MANIFEST.json (non-strict)")
    sys.exit(2)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()

def safe_rel(p):
    p = str(p).replace("\\", "/").strip()
    if not p or p.startswith("/") or p.startswith("~") or (len(p) > 1 and p[1] == ":"):
        return None
    norm = os.path.normpath(p).replace(os.sep, "/")
    if norm == ".." or norm.startswith("../") or norm.startswith("/"):
        return None
    return norm

run_dirs = []
for man_path in manifests:
    run_dir = os.path.dirname(man_path)
    run_dirs.append(run_dir)
    try:
        man = json.load(open(man_path, encoding="utf-8"))
    except Exception:
        errors.append(("evidence_manifest_invalid", os.path.relpath(man_path, root)))
        continue
    files = man.get("files")
    if not isinstance(files, list) or not files:
        errors.append(("evidence_manifest_invalid", os.path.relpath(man_path, root)))
        continue
    for f in files:
        rel = safe_rel(f.get("path", ""))
        if rel is None:
            errors.append(("evidence_absolute_ref", os.path.relpath(man_path, root)))
            continue
        target = os.path.join(run_dir, rel)
        if not os.path.isfile(target):
            errors.append(("evidence_ref_missing", os.path.join(os.path.relpath(run_dir, root), rel)))
            continue
        got = sha256(target)
        want = str(f.get("sha256", "")).strip().lower()
        if want and got != want:
            errors.append(("evidence_digest_mismatch", os.path.join(os.path.relpath(run_dir, root), rel)))

if retention > 0:
    now = time.time()
    for run_dir in run_dirs:
        newest = 0.0
        for dirpath, _dirs, names in os.walk(run_dir):
            for n in names:
                try:
                    newest = max(newest, os.path.getmtime(os.path.join(dirpath, n)))
                except OSError:
                    pass
        if newest and (now - newest) / 86400.0 > retention:
            errors.append(("evidence_retention_expired", os.path.relpath(run_dir, root)))

if backup:
    if not os.path.isabs(backup):
        errors.append(("evidence_backup_invalid", "backup dir is not absolute"))
    elif not os.path.isdir(backup):
        if strict:
            errors.append(("evidence_backup_missing", backup))
    else:
        rb = os.path.realpath(backup)
        if rb == root or rb.startswith(root + os.sep) or rb == repo or rb.startswith(repo + os.sep):
            errors.append(("evidence_backup_invalid", "backup dir overlaps repo/evidence root"))
        else:
            for run_dir in run_dirs:
                name = os.path.basename(run_dir)
                if not os.path.exists(os.path.join(rb, name)):
                    if strict:
                        errors.append(("evidence_backup_missing", os.path.join(rb, name)))
                    break
elif strict:
    errors.append(("evidence_backup_missing", "backup dir is not configured"))

if errors:
    code, detail = errors[0]
    print(code + "\t" + detail)
    sys.exit(1)
print("ok\tmanifests=%d" % len(manifests))
PY
)" || {
        local rc=$?
        last_code="$(printf '%s' "$py_out" | cut -f1)"
        last_detail="$(printf '%s' "$py_out" | cut -f2-)"
        [[ -z "$last_code" ]] && last_code="evidence_check_failed"
        if [[ "$rc" -eq 2 ]]; then
            return 2
        fi
        return 1
    }
    if [[ "$strict" == "1" && -f "$repo/tools/check-evidence-durable.py" ]]; then
        if ! python3 "$repo/tools/check-evidence-durable.py" --root "$repo" >/dev/null 2>&1; then
            last_code="evidence_durable_failed"
            last_detail="tools/check-evidence-durable.py rejected repo evidence"
            return 1
        fi
    fi
    last_detail="root=$root $(printf '%s' "$py_out" | cut -f2-)"
    return 0
}

# ─── pinned gate bundle ─────────────────────────────────────────────────────

compute_bundle_digest() { # root
    python3 - "$1" <<'PY'
import hashlib, json, os, sys

root = sys.argv[1]
man_path = os.path.join(root, "bundle.json")
try:
    man = json.load(open(man_path, encoding="utf-8"))
except Exception as exc:
    print("invalid manifest: %s" % exc.__class__.__name__, file=sys.stderr)
    sys.exit(3)
version = str(man.get("version", "")).strip()
files = []
for f in man.get("files", []) or []:
    p = str(f.get("path", "")).strip()
    while p.startswith("./"):
        p = p[2:]
    p = os.path.normpath(p).replace(os.sep, "/")
    sha = str(f.get("sha256", "")).strip().lower()
    if not p or p in (".", "..") or p.startswith("../") or os.path.isabs(p):
        print("invalid path", file=sys.stderr)
        sys.exit(3)
    if len(sha) != 64 or any(c not in "0123456789abcdef" for c in sha):
        print("invalid sha256", file=sys.stderr)
        sys.exit(3)
    files.append({"path": p, "sha256": sha})
files.sort(key=lambda x: x["path"])
body = {"version": version, "files": files}
canon = json.dumps(body, separators=(",", ":"), ensure_ascii=False)
print("sha256:" + hashlib.sha256(canon.encode("utf-8")).hexdigest())
PY
}

bundle_manifest_files() { # root -> path<TAB>sha
    python3 - "$1" <<'PY'
import json, os, sys
root = sys.argv[1]
man = json.load(open(os.path.join(root, "bundle.json"), encoding="utf-8"))
for f in man.get("files", []) or []:
    p = str(f.get("path", "")).strip()
    while p.startswith("./"):
        p = p[2:]
    p = os.path.normpath(p).replace(os.sep, "/")
    print(p + "\t" + str(f.get("sha256", "")).strip().lower())
PY
}

check_gate_bundle() {
    last_code=""
    last_detail=""
    local root digest enforce
    root="${GATE_BUNDLE:-}"
    digest="${GATE_DIGEST:-}"
    enforce="${ORC_GATE_BUNDLE_ENFORCE:-0}"
    if [[ -z "$root" ]]; then
        if [[ "$enforce" == "1" ]]; then
            last_code="gate_bundle_unavailable"
            last_detail="ORC_GATE_BUNDLE_ENFORCE=1 but ORC_GATE_BUNDLE is empty"
            return 1
        fi
        last_code="gate_bundle_unconfigured"; last_detail="skipped (non-enforce)"; return 2
    fi
    if [[ ! -d "$root" || ! -f "$root/bundle.json" ]]; then
        last_code="gate_bundle_unavailable"; last_detail="root=$root"
        return 1
    fi
    if [[ "$enforce" == "1" && -z "$digest" ]]; then
        last_code="gate_bundle_unpinned"
        last_detail="ORC_GATE_BUNDLE_ENFORCE=1 without ORC_GATE_BUNDLE_DIGEST"
        return 1
    fi
    local computed
    computed="$(compute_bundle_digest "$root" 2>/dev/null)" || {
        last_code="gate_bundle_unavailable"; last_detail="manifest invalid root=$root"; return 1
    }
    if [[ -n "$digest" && "$digest" != "$computed" ]]; then
        last_code="gate_bundle_digest_mismatch"
        last_detail="computed=$computed pinned=$digest"
        return 1
    fi
    if [[ -n "${ORC_GATE_BUNDLE_VERSION:-}" ]]; then
        local version
        version="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1],encoding="utf-8")).get("version","")).strip())' "$root/bundle.json" 2>/dev/null)" || version=""
        if [[ "$version" != "${ORC_GATE_BUNDLE_VERSION}" ]]; then
            last_code="gate_bundle_digest_mismatch"
            last_detail="version=$version pinned=${ORC_GATE_BUNDLE_VERSION}"
            return 1
        fi
    fi
    local p sha abs got
    while IFS=$'\t' read -r p sha; do
        [[ -z "$p" ]] && continue
        abs="$root/$p"
        if [[ ! -f "$abs" ]]; then
            last_code="gate_bundle_unavailable"; last_detail="missing pinned file $p"; return 1
        fi
        got="$(sha256_file "$abs")"
        if [[ "$got" != "$sha" ]]; then
            last_code="gate_bundle_digest_mismatch"
            last_detail="pinned file $p digest mismatch"
            return 1
        fi
    done < <(bundle_manifest_files "$root")
    last_detail="root=$root digest=$computed"
    return 0
}

# ─── host secrets ───────────────────────────────────────────────────────────

check_host_secrets() {
    last_code=""
    last_detail=""
    local repo common cfg
    repo="$(resolve_repo)" || { last_code="host_secrets_invalid"; last_detail="not a git repo"; return 1; }
    common="$(git_common_dir "$repo")"
    cfg="$common/config"

    if [[ -f "$cfg" ]] && grep -Eq 'https?://[^/@[:space:]]+:[^/@[:space:]]+@' "$cfg"; then
        last_code="git_config_credentials"
        last_detail="URL-embedded credentials in $cfg"
        return 1
    fi
    if [[ -f "$cfg" ]] && grep -Eq '(gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{32,}|xox[baprs]-[A-Za-z0-9-]{10,})' "$cfg"; then
        last_code="git_config_pat"
        last_detail="PAT-like token in $cfg"
        return 1
    fi

    local helper
    helper="$(git -C "$repo" config --get credential.helper 2>/dev/null)" || helper=""
    if [[ -z "$helper" ]]; then
        last_code="credential_helper_missing"
        last_detail="no credential.helper configured (host action B3)"
        return 1
    fi

    local tracked
    tracked="$(git -C "$repo" ls-files -z | python3 -c '
import os, sys
names = sys.stdin.buffer.read().split(b"\0")
bad = []
for raw in names:
    if not raw:
        continue
    p = raw.decode("utf-8", "replace")
    base = os.path.basename(p)
    if base == ".env" or base.endswith((".pem", ".key", ".dump")):
        bad.append(p)
print("\n".join(sorted(bad)))
')"
    if [[ -n "$tracked" ]]; then
        last_code="tracked_secret_file"
        last_detail="tracked: $(printf '%s' "$tracked" | tr '\n' ' ')"
        return 1
    fi

    if [[ -f "$repo/.env" ]]; then
        local mode
        mode="$(stat -c '%a' "$repo/.env" 2>/dev/null || stat -f '%Lp' "$repo/.env" 2>/dev/null)" || mode=""
        if [[ "$mode" != "600" ]]; then
            last_code="env_permissions"
            last_detail="$repo/.env mode=$mode (want 600)"
            return 1
        fi
        if git -C "$repo" ls-files --error-unmatch .env >/dev/null 2>&1; then
            last_code="env_tracked"
            last_detail="$repo/.env is tracked"
            return 1
        fi
    fi
    last_detail="repo=$repo credential_helper=set"
    return 0
}

# ─── secret refs ────────────────────────────────────────────────────────────

check_secret_refs() {
    last_code=""
    last_detail=""
    local repo
    repo="$(resolve_repo)" || { last_code="secret_refs_invalid"; last_detail="not a git repo"; return 1; }
    local -a files=()
    local d
    for d in deploy/stands templates/default; do
        [[ -d "$repo/$d" ]] || continue
        while IFS= read -r -d '' f; do
            case "$f" in
                *.md|*.json|*.png|*.jpg|*.gif|*.svg|*.woff|*.woff2|*.ttf|*.lock|*.sum) continue ;;
            esac
            files+=("$f")
        done < <(find "$repo/$d" -type f -print0 2>/dev/null)
    done
    [[ -f "$repo/templates/default/.env.example" ]] && files+=("$repo/templates/default/.env.example")
    if [[ "${#files[@]}" -eq 0 ]]; then
        last_code="secret_refs_no_targets"; last_detail="no deploy/stands or templates/default files"
        return 2
    fi

    local vy rc
    vy="$(python3 - "${files[@]}" <<'PY'
import re
import sys

SECRET_RE = re.compile(r"(gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{32,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)")
URL_CREDS_RE = re.compile(r"[a-zA-Z][a-zA-Z0-9+.-]*://[^/@\s:]+:[^/@\s]+@")
KEY_RE = re.compile(
    r"^\s*(?:export\s+)?([A-Za-z0-9_]*(?:PASSWORD|PASSWD|PASS|SECRET|TOKEN|API[_-]?KEY|"
    r"PRIVATE[_-]?KEY|ACCESS[_-]?KEY|CREDENTIAL|DSN|DATABASE_URL)[A-Za-z0-9_]*)\s*[=:]\s*(.*)$",
    re.I,
)
YAML_SECRET_WORDS = {
    "password", "passwd", "secret", "token", "api_key", "private_key",
    "access_key", "credential", "dsn", "database_url",
}
SNAKE_SECRET_RE = re.compile(
    r"(^|_)(password|passwd|secret|token|api_key|private_key|access_key|credential|dsn|database_url)($|_)"
)
PLACEHOLDER = (
    "change-this", "replace-with", "replace_me", "example", "placeholder",
    "your_", "your-", "changeme", "redacted", "dummy", "min-16", "test-",
)


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and ((v[0] == v[-1] == "'") or (v[0] == v[-1] == '"')):
        return v[1:-1]
    return v


for path in sys.argv[1:]:
    try:
        lines = open(path, encoding="utf-8", errors="replace").readlines()
    except OSError:
        continue
    for line in lines:
        rule = ""
        if SECRET_RE.search(line):
            rule = "high_confidence_secret"
        else:
            m = KEY_RE.match(line)
            if m:
                key = m.group(1)
                env_style = re.fullmatch(r"[A-Z][A-Z0-9_]*", key) is not None
                snake_style = (
                    re.fullmatch(r"[a-z0-9_]+", key) is not None
                    and SNAKE_SECRET_RE.search(key) is not None
                )
                if not (env_style or snake_style or key.lower() in YAML_SECRET_WORDS):
                    # e.g. systemd LoadCredential=... is a directive, not a value.
                    continue
                value = unquote(m.group(2).split("#", 1)[0].strip())
                low = value.lower()
                # Shell command substitution / variable references are not literal
                # secrets (e.g. `secret="$(curl ...)"` or `PASS="$PW"`).
                probe = value.lstrip("\"'")
                if probe.startswith(("$(", "`", "$")):
                    continue
                # Интерполяция compose/shell (${VAR}) — ссылка, не литерал.
                if "${" in value:
                    continue
                if (
                    value
                    and not value.startswith(("${", "$", "@{"))
                    and not any(tag in low for tag in PLACEHOLDER)
                    and not low.startswith(("secret_ref", "dsn_ref", "env:", "file:", "vault:", "sops:", "secretref:"))
                    and not re.fullmatch(r"\d+", value)
                ):
                    rule = "url_credentials" if URL_CREDS_RE.search(value) else "literal_secret_value"
        if rule:
            # Emit rule and file name only: the matched value never leaves Python.
            print("%s:%s" % (rule, path))
            sys.exit(1)
PY
)"
    rc=$?
    if [[ "$rc" -ne 0 ]]; then
        last_code="${vy%%:*}"
        last_detail="${vy#*:}"
        if [[ -z "$last_code" || "$last_code" == "$vy" ]]; then
            last_code="secret_ref_violation"
            last_detail="$vy"
        fi
        return 1
    fi
    last_detail="files=${#files[@]} secret_refs_only=1"
    return 0
}

# ─── mode dispatch ──────────────────────────────────────────────────────────

mode_list() {
    local mode="$1"
    if [[ "$mode" == "all" ]]; then
        printf '%s' "branch,commit,evidence-retention,gate-bundle,secret-refs"
    else
        printf '%s' "$mode"
    fi
}

run_mode() {
    local mode="$1" rc=0
    case "$mode" in
        branch) check_writer || rc=$? ;;
        commit) check_commit || rc=$? ;;
        evidence|evidence-retention) check_evidence || rc=$? ;;
        gate-bundle) check_gate_bundle || rc=$? ;;
        host-secrets) check_host_secrets || rc=$? ;;
        secret-refs) check_secret_refs || rc=$? ;;
        "") return 0 ;;
        *) fail_mode "$mode" "unknown_mode" "$mode"; return 1 ;;
    esac
    if [[ "$rc" -eq 0 ]]; then
        pass_mode "$mode" "${last_detail:-ok}"
    elif [[ "$rc" -eq 2 ]]; then
        skip_mode "$mode" "${last_code:-skipped}" "${last_detail:-}"
    else
        fail_mode "$mode" "${last_code:-failed}" "${last_detail:-}"
    fi
    return 0
}

emit_json() {
    local i
    for i in "${!RES_MODE[@]}"; do
        printf '%s\t%s\t%s\t%s\n' "${RES_MODE[$i]}" "${RES_STATUS[$i]}" "${RES_CODE[$i]}" "${RES_DETAIL[$i]}"
    done | python3 -c '
import json, sys
results = []
for line in sys.stdin:
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 4:
        continue
    mode, status, code, detail = parts[0], parts[1], parts[2], "\t".join(parts[3:])
    item = {"mode": mode, "status": status}
    if code:
        item["code"] = code
    if detail:
        item["detail"] = detail
    results.append(item)
print(json.dumps({"ok": all(r["status"] != "fail" for r in results), "results": results}, ensure_ascii=False))
'
}

# ─── self-test ──────────────────────────────────────────────────────────────

selftest() {
    local ST
    ST="$(mktemp -d "${TMPDIR:-/tmp}/orc-u15-selftest.XXXXXX")" || { echo "FAIL[selftest]: mktemp" >&2; return 1; }
    cleanup_selftest() { rm -rf "$ST"; }
    trap cleanup_selftest RETURN

    local GIT=(git -c user.name=u15 -c user.email=u15@example.invalid)
    "${GIT[@]}" init -q -b main "$ST/seed" 2>/dev/null || { echo "FAIL[selftest]: git init" >&2; return 1; }
    printf 'seed\n' >"$ST/seed/README.md"
    "${GIT[@]}" -C "$ST/seed" add README.md
    "${GIT[@]}" -C "$ST/seed" commit -qm init
    "${GIT[@]}" init -q --bare -b main "$ST/origin.git"
    "${GIT[@]}" -C "$ST/seed" remote add origin "$ST/origin.git"
    "${GIT[@]}" -C "$ST/seed" push -q origin main
    "${GIT[@]}" clone -q "$ST/origin.git" "$ST/primary"
    "${GIT[@]}" -C "$ST/primary" config user.name u15
    "${GIT[@]}" -C "$ST/primary" config user.email u15@example.invalid
    mkdir -p "$ST/primary/.orc-worktrees"
    local id
    for id in EA EB; do
        "${GIT[@]}" -C "$ST/primary" branch "orc-exec-$id"
        "${GIT[@]}" -C "$ST/primary" worktree add -q "$ST/primary/.orc-worktrees/$id" "orc-exec-$id"
    done

    local primary="$ST/primary"
    local common
    common="$(git -C "$primary" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || common="$primary/.git"

    write_lock() { # branch exec pid host worktree
        local branch="$1" exec_id="$2" pid="$3" host="$4" wt="$5"
        local hash file
        hash="$(printf '%s' "$branch" | sha256_stdin)"
        file="$common/orc-branch-locks/$hash.lock"
        mkdir -p "$common/orc-branch-locks"
        python3 - "$file" "$exec_id" "$branch" "$wt" "$pid" "$host" <<'PY'
import json, sys, datetime
path, exec_id, branch, wt, pid, host = sys.argv[1:7]
json.dump({
    "execution_id": exec_id, "branch": branch, "worktree": wt,
    "pid": int(pid), "host": host,
    "acquired_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}, open(path, "w", encoding="utf-8"))
PY
    }

    local total=0 failed=0
    expect_pass() { # name (last_code must be empty)
        total=$((total + 1))
        if [[ -z "$last_code" ]]; then
            echo "SELFTEST PASS: $1"
        else
            echo "SELFTEST FAIL: $1 (code=$last_code detail=$last_detail)" >&2
            failed=$((failed + 1))
        fi
    }
    expect_fail() { # name expected-substring
        total=$((total + 1))
        if [[ "$last_code" == "shared_worktree_commit" || "$last_code" == "$2" ]] && [[ "$last_detail" == *"$3"* ]]; then
            echo "SELFTEST PASS: $1"
        else
            echo "SELFTEST FAIL: $1 (code=$last_code detail=$last_detail, want $2/$3)" >&2
            failed=$((failed + 1))
        fi
    }

    local host
    host="$(hostname 2>/dev/null || echo unknown)"
    REPO="$primary"
    EXECUTION="EA"
    BRANCH="orc-exec-EA"

    # branch: positive
    write_lock "orc-exec-EA" "EA" "$$" "$host" "$primary/.orc-worktrees/EA"
    check_writer; local rc=$?
    if [[ $rc -eq 0 ]]; then expect_pass "branch writer (live lock)"; else echo "SELFTEST FAIL: branch writer code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # branch: lock owner mismatch (second writer)
    write_lock "orc-exec-EA" "EX" "$$" "$host" "$primary/.orc-worktrees/EA"
    check_writer || true
    expect_fail "branch second writer rejected" "shared_worktree_commit" "lock_owner_mismatch"

    # branch: stale lock (dead pid) is not trusted
    write_lock "orc-exec-EA" "EA" "999999" "$host" "$primary/.orc-worktrees/EA"
    check_writer || true
    expect_fail "branch stale lock rejected until takeover" "shared_worktree_commit" "lock_not_held"

    # branch: foreign/missing branch
    write_lock "orc-exec-EA" "EA" "$$" "$host" "$primary/.orc-worktrees/EA"
    write_lock "orc-exec-EC" "EA" "$$" "$host" "$primary/.orc-worktrees/EA"
    EXECUTION="EA"; BRANCH="orc-exec-EC"
    check_writer || true
    expect_fail "branch foreign branch rejected" "shared_worktree_commit" "branch_not_checked_out"

    # branch: shared worktree (expected path of EB but branch EA)
    write_lock "orc-exec-EA" "EB" "$$" "$host" "$primary/.orc-worktrees/EA"
    BRANCH="orc-exec-EA"; EXECUTION="EB"
    check_writer || true
    expect_fail "branch shared worktree rejected" "shared_worktree_commit" "worktree_path_mismatch"

    # restore own lock for subsequent commit checks
    write_lock "orc-exec-EA" "EA" "$$" "$host" "$primary/.orc-worktrees/EA"
    EXECUTION="EA"; BRANCH="orc-exec-EA"

    # commit: positive
    printf 'ea\n' >"$primary/.orc-worktrees/EA/ea.md"
    "${GIT[@]}" -C "$primary/.orc-worktrees/EA" add ea.md
    "${GIT[@]}" -C "$primary/.orc-worktrees/EA" commit -qm "ea"
    local ea_sha
    ea_sha="$("${GIT[@]}" -C "$primary/.orc-worktrees/EA" rev-parse HEAD)"
    EXECUTION="EA"; BRANCH="orc-exec-EA"; COMMIT="$ea_sha"
    check_commit || true
    if [[ -z "$last_code" ]]; then expect_pass "commit reachable from own branch"; else echo "SELFTEST FAIL: commit positive code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # commit: negative — EB commit not reachable from EA branch
    printf 'eb\n' >"$primary/.orc-worktrees/EB/eb.md"
    "${GIT[@]}" -C "$primary/.orc-worktrees/EB" add eb.md
    "${GIT[@]}" -C "$primary/.orc-worktrees/EB" commit -qm "eb"
    local eb_sha
    eb_sha="$("${GIT[@]}" -C "$primary/.orc-worktrees/EB" rev-parse HEAD)"
    COMMIT="$eb_sha"
    check_commit || true
    expect_fail "commit from foreign branch rejected" "shared_worktree_commit" "commit_unreachable"

    # evidence: positive
    local evid="$ST/evidence" backup="$ST/backup"
    mkdir -p "$evid/run-EA" "$backup/run-EA"
    printf 'artifact\n' >"$evid/run-EA/artifact.txt"
    cp "$evid/run-EA/artifact.txt" "$backup/run-EA/artifact.txt"
    python3 - "$evid/run-EA" <<'PY'
import hashlib, json, os, sys
d = sys.argv[1]
rel = "artifact.txt"
h = hashlib.sha256(open(os.path.join(d, rel), "rb").read()).hexdigest()
json.dump({"execution_id": "EA", "files": [{"path": rel, "sha256": h}]},
          open(os.path.join(d, "MANIFEST.json"), "w", encoding="utf-8"))
PY
    EVIDENCE_ROOT="$evid"; BACKUP_DIR="$backup"; RETENTION_DAYS=30; STRICT=1
    check_evidence || true
    if [[ -z "$last_code" ]]; then expect_pass "evidence manifest+sha256+backup"; else echo "SELFTEST FAIL: evidence positive code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # evidence: tamper
    printf 'tampered\n' >"$evid/run-EA/artifact.txt"
    check_evidence || true
    expect_fail "evidence digest mismatch rejected" "evidence_digest_mismatch" "artifact.txt"

    # evidence: root inside repo
    EVIDENCE_ROOT="$primary"; BACKUP_DIR=""
    check_evidence || true
    expect_fail "evidence root inside repo rejected" "evidence_root_inside_repo" "$primary"

    # gate bundle: positive
    local gate="$ST/gate"
    mkdir -p "$gate"
    printf '#!/bin/sh\nexit 0\n' >"$gate/gate.sh"
    local gsha
    gsha="$(sha256_file "$gate/gate.sh")"
    python3 - "$gate" "$gsha" <<'PY'
import json, sys
root, sha = sys.argv[1], sys.argv[2]
json.dump({"version": "u15-selftest", "files": [{"path": "gate.sh", "sha256": sha}]},
          open(root + "/bundle.json", "w", encoding="utf-8"))
PY
    GATE_BUNDLE="$gate"; GATE_DIGEST="$(compute_bundle_digest "$gate")"
    check_gate_bundle || true
    if [[ -z "$last_code" ]]; then expect_pass "gate bundle digest pinned"; else echo "SELFTEST FAIL: gate positive code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # gate bundle: enforce without pin
    GATE_DIGEST=""
    ORC_GATE_BUNDLE_ENFORCE=1 check_gate_bundle || true
    expect_fail "gate bundle enforce without pin rejected" "gate_bundle_unpinned" "ORC_GATE_BUNDLE_DIGEST"

    # gate bundle: tampered file
    ORC_GATE_BUNDLE_ENFORCE=0
    GATE_DIGEST="$(compute_bundle_digest "$gate")"
    printf '#!/bin/sh\nexit 1\n' >"$gate/gate.sh"
    check_gate_bundle || true
    expect_fail "gate bundle tampered file rejected" "gate_bundle_digest_mismatch" "gate.sh"

    # secret refs: positive
    mkdir -p "$primary/deploy/stands"
    cat >"$primary/deploy/stands/ok.env" <<'EOF'
STAND_DSN=secret_ref:stand_dsn
API_TOKEN=${API_TOKEN}
EOF
    REPO="$primary"; EVIDENCE_ROOT=""; BACKUP_DIR=""; STRICT=0
    check_secret_refs || true
    if [[ -z "$last_code" ]]; then expect_pass "secret-refs placeholders accepted"; else echo "SELFTEST FAIL: secret-refs positive code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # secret refs: literal token (built dynamically so this script holds no token)
    local fake_token
    fake_token="$(printf 'ghp_%s' "$(printf 'A%.0s' $(seq 1 36))")"
    printf 'API_TOKEN=%s\n' "$fake_token" >"$primary/deploy/stands/lit.env"
    check_secret_refs || true
    expect_fail "secret-refs high-confidence secret rejected" "high_confidence_secret" "lit.env"
    if [[ "$last_detail" == *"$fake_token"* ]]; then
        echo "SELFTEST FAIL: secret value leaked to output" >&2
        total=$((total+1)); failed=$((failed+1))
    fi
    rm -f "$primary/deploy/stands/lit.env"

    # secret refs: literal value without a high-confidence shape
    printf 'POSTGRES_PASSWORD=hunter2\n' >"$primary/deploy/stands/literal.env"
    check_secret_refs || true
    expect_fail "secret-refs literal value rejected" "literal_secret_value" "literal.env"
    rm -f "$primary/deploy/stands/literal.env"

    # host secrets: positive (credential helper + untracked .env 600)
    "${GIT[@]}" -C "$primary" config credential.helper store
    printf 'TOKEN=placeholder\n' >"$primary/.env"
    chmod 600 "$primary/.env"
    REPO="$primary"
    check_host_secrets || true
    if [[ -z "$last_code" ]]; then expect_pass "host secrets clean"; else echo "SELFTEST FAIL: host positive code=$last_code detail=$last_detail" >&2; total=$((total+1)); failed=$((failed+1)); fi

    # host secrets: .env mode
    chmod 644 "$primary/.env"
    check_host_secrets || true
    expect_fail "host .env mode !=600 rejected" "env_permissions" ".env"
    chmod 600 "$primary/.env"

    # host secrets: tracked .env
    "${GIT[@]}" -C "$primary" add -f .env
    "${GIT[@]}" -C "$primary" commit -qm "track env"
    check_host_secrets || true
    expect_fail "host tracked .env rejected" "tracked_secret_file" ".env"
    "${GIT[@]}" -C "$primary" rm -q --cached .env
    "${GIT[@]}" -C "$primary" commit -qm "untrack env"

    # host secrets: URL credentials in .git/config
    "${GIT[@]}" -C "$primary" config remote.origin.url 'https://user:pw@example.invalid/repo.git'
    check_host_secrets || true
    expect_fail "host git config URL credentials rejected" "git_config_credentials" "config"

    echo "SELFTEST: total=$total failed=$failed"
    [[ "$failed" -eq 0 ]]
}

# ─── args ───────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) [[ $# -ge 2 ]] || die_usage "--mode requires a value"; MODE="$2"; shift 2 ;;
        --repo) [[ $# -ge 2 ]] || die_usage "--repo requires a value"; REPO="$2"; shift 2 ;;
        --execution) [[ $# -ge 2 ]] || die_usage "--execution requires a value"; EXECUTION="$2"; shift 2 ;;
        --branch) [[ $# -ge 2 ]] || die_usage "--branch requires a value"; BRANCH="$2"; shift 2 ;;
        --commit) [[ $# -ge 2 ]] || die_usage "--commit requires a value"; COMMIT="$2"; shift 2 ;;
        --evidence-root) [[ $# -ge 2 ]] || die_usage "--evidence-root requires a value"; EVIDENCE_ROOT="$2"; shift 2 ;;
        --retention-days) [[ $# -ge 2 ]] || die_usage "--retention-days requires a value"; RETENTION_DAYS="$2"; shift 2 ;;
        --backup-dir) [[ $# -ge 2 ]] || die_usage "--backup-dir requires a value"; BACKUP_DIR="$2"; shift 2 ;;
        --gate-bundle) [[ $# -ge 2 ]] || die_usage "--gate-bundle requires a value"; GATE_BUNDLE="$2"; shift 2 ;;
        --gate-bundle-digest) [[ $# -ge 2 ]] || die_usage "--gate-bundle-digest requires a value"; GATE_DIGEST="$2"; shift 2 ;;
        --json) JSON=1; shift ;;
        --strict|--release) STRICT=1; shift ;;
        --selftest|--self-test) SELFTEST=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die_usage "unknown argument: $1" ;;
    esac
done

if [[ "$SELFTEST" -eq 1 ]]; then
    [[ "$JSON" -eq 0 ]] || die_usage "--json is not supported with --self-test"
    if [[ "$MODE" == "branch,commit" ]]; then
        MODE="all"
    fi
    selftest
    exit $?
fi

FAILED=0
IFS=',' read -r -a MODES <<<"$(mode_list "$MODE")"
for m in "${MODES[@]}"; do
    m="$(printf '%s' "$m" | tr -d '[:space:]')"
    [[ -z "$m" ]] && continue
    run_mode "$m"
done

if [[ "$JSON" -eq 1 ]]; then
    emit_json
fi

if [[ "$FAILED" -ne 0 ]]; then
    exit 1
fi
exit 0
