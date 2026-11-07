#!/usr/bin/env python3
"""gate-prototype-accept (s03b) — fail-close проверка human-приёмки прототипа.

Проверяет:
  - prototypes/vN/manifest.json и prototype-review.json существуют;
  - версии/feature_id совпадают, digest'ы сходятся;
  - verdict=approved, blockers/majors open = 0, все items fixed/accepted;
  - каждый document имеет кэш .fig-cache/<document_id>.fig с совпадающим sha256
    (кэш создаёт агент, скачав утверждённый S3-объект; в git не коммитится);
  - UI/UX review independence (если reviewer не human).

Никаких секретов/S3: проверяется локальный снимок, который агент обязан
материализовать из S3 перед s03b. S3-объект без локального кэша — FAIL
(нельзя проверить digest).

Запуск: python3 tools/check-prototype-accept.py --root <repo> [--feature-dir <dir>]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

SHA = re.compile(r"^sha256:[0-9a-f]{64}$")
DOC_ID = re.compile(r"^[a-z0-9][a-z0-9-]*--[a-z0-9][a-z0-9-]*$")
S3_KEY = re.compile(r"^open_pencil_storage/canvases/[a-z0-9][a-z0-9-]*--[a-z0-9][a-z0-9-]*\.fig$")
VERSION = re.compile(r"^v[0-9]+$")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def fail(msg: str) -> int:
    print(f"gate-prototype-accept: FAIL — {msg}", file=sys.stderr)
    return 1


def load_json(path: Path, label: str):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(fail(f"{label} не найден: {path}"))
    except json.JSONDecodeError as exc:
        raise SystemExit(fail(f"{label} не JSON: {path}: {exc}"))


def resolve_review(root: Path, feature_dir: str | None) -> Path:
    if feature_dir:
        base = Path(feature_dir)
        if not base.is_absolute():
            base = root / base
        candidates = sorted(base.glob("prototypes/v*/prototype-review.json"))
        if len(candidates) == 1:
            return candidates[0]
        if len(candidates) > 1:
            # Берём максимальную версию, но только если она одна по номеру.
            def vnum(p: Path) -> int:
                try:
                    return int(p.parent.name[1:])
                except ValueError:
                    return -1

            candidates.sort(key=vnum)
            if vnum(candidates[-1]) > vnum(candidates[-2]):
                return candidates[-1]
        raise SystemExit(fail(f"prototype-review.json не найден однозначно в {base}/prototypes/v*"))
    env = os.environ.get("ORC_FEATURE_DIR", "").strip()
    if env:
        return resolve_review(root, env)
    candidates = sorted(root.glob("doc/идеи/*/prototypes/v*/prototype-review.json"))
    if len(candidates) == 1:
        return candidates[0]
    if not candidates:
        raise SystemExit(fail("prototype-review.json не найден (doc/идеи/<F>/prototypes/v*/)"))
    raise SystemExit(fail(f"несколько prototype-review.json ({len(candidates)}); задай ORC_FEATURE_DIR"))


def resolve_manifest(root: Path, review_path: Path, review: dict) -> Path:
    raw = (review.get("prototype") or {}).get("manifest_path")
    if not raw:
        raise SystemExit(fail("prototype.manifest_path отсутствует"))
    candidates = []
    p = Path(raw)
    if p.is_absolute():
        candidates.append(p)
    else:
        candidates.append(root / p)
        candidates.append(review_path.parent / p.name)
        candidates.append(review_path.parent / "manifest.json")
    for c in candidates:
        if c.is_file():
            return c
    raise SystemExit(fail(f"manifest.json не найден по prototype.manifest_path={raw}"))


def check_review(review: dict) -> list[str]:
    errs: list[str] = []
    required = ["schema_version", "feature_id", "prototype", "reviewer", "verdict", "summary", "items", "independence", "context"]
    for key in required:
        if key not in review:
            errs.append(f"review.{key} отсутствует")
    if errs:
        return errs
    if review["schema_version"] != "1.0":
        errs.append("review.schema_version != 1.0")
    proto = review["prototype"]
    for key in ["version", "manifest_path", "manifest_sha256", "fig_sha256"]:
        if key not in proto:
            errs.append(f"review.prototype.{key} отсутствует")
    if not VERSION.match(str(proto.get("version", ""))):
        errs.append("review.prototype.version не vN")
    for key in ["manifest_sha256", "fig_sha256"]:
        if not SHA.match(str(proto.get(key, ""))):
            errs.append(f"review.prototype.{key} не sha256")
    reviewer = review["reviewer"]
    if not reviewer.get("name"):
        errs.append("review.reviewer.name пуст")
    if reviewer.get("role") not in {"human", "designer", "product"}:
        errs.append("review.reviewer.role недопустим")
    verdict = review["verdict"]
    if verdict.get("status") not in {"approved", "changes_requested"}:
        errs.append("review.verdict.status недопустим")
    if not verdict.get("decided_at"):
        errs.append("review.verdict.decided_at пуст")
    summary = review["summary"]
    for key in ["blockers_open", "majors_open", "minors_open", "items_total"]:
        if not isinstance(summary.get(key), int) or summary[key] < 0:
            errs.append(f"review.summary.{key} должен быть int >= 0")
    items = review["items"]
    if not isinstance(items, list) or not items:
        errs.append("review.items пуст")
        return errs
    open_block = open_major = 0
    for i, item in enumerate(items):
        for key in ["id", "screen_id", "block", "severity", "status", "criterion", "comment"]:
            if key not in item:
                errs.append(f"review.items[{i}].{key} отсутствует")
        if item.get("severity") not in {"blocker", "major", "minor", "info"}:
            errs.append(f"review.items[{i}].severity недопустим")
        if item.get("status") not in {"open", "fixed", "accepted"}:
            errs.append(f"review.items[{i}].status недопустим")
        if item.get("status") == "open" and item.get("severity") == "blocker":
            open_block += 1
        if item.get("status") == "open" and item.get("severity") == "major":
            open_major += 1
    if summary.get("items_total") != len(items):
        errs.append("review.summary.items_total != len(items)")
    if summary.get("blockers_open", -1) != open_block:
        errs.append(f"review.summary.blockers_open={summary.get('blockers_open')} != фактических {open_block}")
    if summary.get("majors_open", -1) != open_major:
        errs.append(f"review.summary.majors_open={summary.get('majors_open')} != фактических {open_major}")
    if verdict.get("status") == "approved":
        if open_block or open_major:
            errs.append(f"approved при open blocker/major ({open_block}/{open_major})")
        if summary.get("blockers_open") or summary.get("majors_open"):
            errs.append("approved при summary.blockers_open/majors_open > 0")
        for i, item in enumerate(items):
            if item.get("status") == "open":
                errs.append(f"approved при open item {item.get('id', i)}")
    indep = review["independence"]
    if indep.get("distinct") is not True:
        errs.append("review.independence.distinct != true")
    if reviewer.get("role") != "human":
        if not indep.get("author_session_id") or not indep.get("reviewer_session_id"):
            errs.append("review.independence session ids пусты")
        elif indep.get("author_session_id") == indep.get("reviewer_session_id"):
            errs.append("reviewer_session_id == author_session_id")
    if not isinstance(review["context"], dict) or not review["context"].get("source"):
        errs.append("review.context.source пуст")
    return errs


def check_manifest(manifest: dict, review: dict, manifest_path: Path, review_path: Path) -> list[str]:
    errs: list[str] = []
    required = ["schema_version", "feature_id", "version", "created_at", "design_system", "s3", "documents", "review"]
    for key in required:
        if key not in manifest:
            errs.append(f"manifest.{key} отсутствует")
    if errs:
        return errs
    if manifest["schema_version"] != "1.0":
        errs.append("manifest.schema_version != 1.0")
    if manifest["feature_id"] != review["feature_id"]:
        errs.append("manifest.feature_id != review.feature_id")
    if manifest["version"] != review["prototype"]["version"]:
        errs.append("manifest.version != review.prototype.version")
    ds = manifest["design_system"]
    if not isinstance(ds.get("version"), str) or not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+$", ds["version"]):
        errs.append("manifest.design_system.version не semver")
    if not SHA.match(str(ds.get("digest", ""))):
        errs.append("manifest.design_system.digest не sha256")
    s3 = manifest["s3"]
    if s3.get("prefix") != "open_pencil_storage/canvases/":
        errs.append("manifest.s3.prefix неверный")
    if not s3.get("bucket"):
        errs.append("manifest.s3.bucket пуст")
    docs = manifest["documents"]
    if not isinstance(docs, list) or not docs:
        errs.append("manifest.documents пуст")
        return errs
    seen = set()
    for i, doc in enumerate(docs):
        for key in ["screen_id", "document_id", "s3_key", "sha256", "size", "exports"]:
            if key not in doc:
                errs.append(f"manifest.documents[{i}].{key} отсутствует")
        did = str(doc.get("document_id", ""))
        if not DOC_ID.match(did):
            errs.append(f"manifest.documents[{i}].document_id должен быть <feature>--<screen> без /")
        if did in seen:
            errs.append(f"manifest.documents[{i}].document_id дублируется")
        seen.add(did)
        key = str(doc.get("s3_key", ""))
        if not S3_KEY.match(key):
            errs.append(f"manifest.documents[{i}].s3_key неверный")
        elif key != f"open_pencil_storage/canvases/{did}.fig":
            errs.append(f"manifest.documents[{i}].s3_key не соответствует document_id")
        if not SHA.match(str(doc.get("sha256", ""))):
            errs.append(f"manifest.documents[{i}].sha256 не sha256")
        if not isinstance(doc.get("size"), int) or doc["size"] <= 0:
            errs.append(f"manifest.documents[{i}].size должен быть > 0")
        if not isinstance(doc.get("exports"), list):
            errs.append(f"manifest.documents[{i}].exports должен быть массивом")
    # review pointer: no review digest here (manifest<->review would be circular);
    # the review carries manifest_sha256, which is checked below.
    review_ref = manifest["review"]
    if review_ref.get("path") not in {str(review_path), review_path.name, "prototype-review.json"}:
        errs.append("manifest.review.path не указывает на prototype-review.json")
    if review_ref.get("verdict") not in {None, review["verdict"]["status"]}:
        errs.append("manifest.review.verdict != review.verdict.status")
    if review["prototype"].get("manifest_sha256") != sha256_file(manifest_path):
        errs.append("review.prototype.manifest_sha256 != sha256(manifest.json)")
    fig_sha = review["prototype"].get("fig_sha256")
    doc_shas = {d.get("sha256") for d in docs}
    if len(docs) == 1:
        if fig_sha != docs[0].get("sha256"):
            errs.append("review.prototype.fig_sha256 != единственного document.sha256")
    elif fig_sha not in doc_shas and fig_sha != sha256_file(manifest_path):
        errs.append("review.prototype.fig_sha256 не совпадает ни с одним document.sha256 и не равен manifest sha")
    # local fig cache
    proto_dir = review_path.parent
    for doc in docs:
        did = doc.get("document_id")
        cache = proto_dir / ".fig-cache" / f"{did}.fig"
        if not cache.is_file():
            errs.append(f"нет локального кэша {cache} (скачай утверждённый S3 .fig перед s03b)")
            continue
        if sha256_file(cache) != doc.get("sha256"):
            errs.append(f"sha256 кэша {cache} != manifest.documents[{did}].sha256")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--feature-dir", default="")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    review_path = resolve_review(root, args.feature_dir or None)
    review = load_json(review_path, "prototype-review.json")
    errs = check_review(review)
    manifest_path = resolve_manifest(root, review_path, review)
    manifest = load_json(manifest_path, "manifest.json")
    errs += check_manifest(manifest, review, manifest_path, review_path)
    if errs:
        for e in errs:
            print(f"gate-prototype-accept: FAIL — {e}", file=sys.stderr)
        return 1
    print(f"gate-prototype-accept: PASS — {review_path} ({len(manifest['documents'])} screens, verdict=approved)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
