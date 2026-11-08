#!/usr/bin/env python3
"""Verify host-run l1/l2 evidence against trusted git history (R-S22B-02).

Evidence JSON requires: code_commit, evidence_commit (full 40-hex), log_path,
log_sha256, failed[], new_red[].
Rules: code_commit != HEAD; both ancestors of HEAD; evidence files unchanged
since evidence_commit; log sha256 recomputed from the committed blob; failed
set recomputed from the log and equal to the shared allowlist; no Go changes
between code_commit and HEAD. argv only, no shell.
"""
import hashlib, json, re, subprocess, sys

def fail(msg):
    print("host-evidence: FAIL — " + msg, file=sys.stderr)
    sys.exit(1)

def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], capture_output=True)

def main() -> int:
    if len(sys.argv) != 3:
        fail("usage: verify-host-evidence.py <evidence.json> <allowlist.txt>")
    ev_path, allow_path = sys.argv[1], sys.argv[2]
    ev = json.load(open(ev_path, encoding="utf-8"))
    allowed = sorted({l.strip() for l in open(allow_path, encoding="utf-8") if l.strip()})
    hexre = re.compile(r"^[0-9a-f]{40}$")
    code = ev.get("code_commit", "")
    evidence = ev.get("evidence_commit", "")
    if not hexre.match(code) or not hexre.match(evidence):
        fail("code_commit/evidence_commit must be full 40-hex")
    head = git("rev-parse", "HEAD").stdout.decode().strip()
    if code == head:
        fail("code_commit == HEAD (no HEAD bypass)")
    if git("merge-base", "--is-ancestor", code, "HEAD").returncode != 0:
        fail("code_commit is not an ancestor of HEAD")
    if git("merge-base", "--is-ancestor", evidence, "HEAD").returncode != 0:
        fail("evidence_commit is not an ancestor of HEAD")
    logrel = ev.get("log_path", "")
    r = git("diff", "--name-only", evidence + "..HEAD", "--", logrel)
    if r.returncode != 0 or r.stdout.strip():
        fail("evidence/log changed after evidence_commit")
    r = git("diff", "--name-only", code + "..HEAD", "--", "*.go")
    if r.returncode != 0 or r.stdout.strip():
        fail("Go changes after code_commit")
    r = git("show", evidence + ":" + logrel)
    if r.returncode != 0:
        fail("log not found at evidence_commit")
    log_bytes = r.stdout
    if hashlib.sha256(log_bytes).hexdigest() != ev.get("log_sha256"):
        fail("log_sha256 mismatch (recomputed from committed blob)")
    log = log_bytes.decode("utf-8", "replace")
    failed = sorted({m.group(1) for m in re.finditer(r"^(?:--- FAIL: |FAILED: )(\S+)", log, re.M)})
    if failed != allowed:
        fail("recomputed failed set != allowlist: %s" % ", ".join(failed))
    if sorted(ev.get("failed", [])) != failed:
        fail("self-declared failed[] != recomputed set")
    if ev.get("new_red"):
        fail("new_red must be empty")
    sig = ev.get("signature_path", "")
    if not sig:
        fail("missing host signature (signature_path)")
    canon = json.dumps({"code_commit": code, "log_sha256": ev.get("log_sha256", ""), "failed": failed}, sort_keys=True, separators=(",", ":")).encode()
    ver = subprocess.run(
        ["ssh-keygen", "-Y", "verify", "-f", "tools/host-evidence-allowed-signers",
         "-I", "host-runner", "-n", "orc-evidence", "-s", sig],
        input=canon, capture_output=True,
    )
    if ver.returncode != 0:
        fail("host signature verification failed: " + ver.stderr.decode("utf-8", "replace").strip())
    print("host-evidence: OK (%d baseline failures, no new red)" % len(failed))
    return 0

if __name__ == "__main__":
    sys.exit(main())
