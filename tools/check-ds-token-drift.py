#!/usr/bin/env python3
"""gate ds-token-drift — implementation tokens must match design/tokens.json.

Deterministic, fail-close check (no LLM):
  * :root CSS custom properties match the released colour/radius/focus tokens;
  * typography used by the feature (body/h1/.brand) matches font tokens;
  * control heights (input/button 44px, textarea 88px) match control tokens;
  * rem values are resolved against the 16px root font size.

Run: python3 tools/check-ds-token-drift.py --root <repo>
Exit: 0 = PASS, 1 = drift/missing token, 2 = usage error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT_FONT_PX = 16.0
TOLERANCE = 0.01

# token key -> CSS custom property in web/app.css :root
COLOR_VARS = {
    "bg": "--bg",
    "card": "--card",
    "text": "--text",
    "muted": "--muted",
    "border": "--border",
    "border_subtle": "--border-subtle",
    "accent": "--accent",
    "accent_hover": "--accent-dark",
    "danger": "--danger",
    "danger_bg": "--danger-bg",
    "focus": "--focus",
}

LENGTH_RE = re.compile(r"^\s*(-?\d+(?:\.\d+)?)\s*(px|rem|em)?\s*$")


def fail(msgs: list[str]) -> int:
    for m in msgs:
        print(f"ds-token-drift: FAIL — {m}", file=sys.stderr)
    return 1


def load_tokens(root: Path) -> dict:
    p = root / "design" / "tokens.json"
    if not p.is_file():
        raise SystemExit(2, f"ds-token-drift: tokens not found: {p}")
    return json.loads(p.read_text(encoding="utf-8"))


def read_css(root: Path) -> str:
    p = root / "web" / "app.css"
    if not p.is_file():
        raise SystemExit(2, f"ds-token-drift: code path not found: {p}")
    return p.read_text(encoding="utf-8")


def root_vars(css: str) -> dict[str, str]:
    block = re.search(r":root\s*\{(.*?)\}", css, re.S)
    if not block:
        return {}
    return {m.group(1).strip(): m.group(2).strip()
            for m in re.finditer(r"--([a-z0-9-]+)\s*:\s*([^;]+);", block.group(1))}


def decl_for(css: str, selector: str, prop: str) -> str | None:
    """Return the first declaration of `prop` in any block of `selector`.

    A selector may appear in several blocks (e.g. the grouped
    ``html, body { margin }`` rule and the standalone ``body { font-size }``
    rule), so scan every match rather than only the first one.
    """
    pattern = r"(?m)^\s*" + re.escape(selector) + r"\s*\{([^}]*)\}"
    values: list[str] = []
    for block in re.finditer(pattern, css):
        m = re.search(r"(?m)(?:^|;)\s*" + re.escape(prop) + r"\s*:\s*([^;]+)", block.group(1))
        if m:
            values.append(m.group(1).strip())
    # A grouped rule (``input, textarea { min-height: var(...) }``) and a
    # standalone rule (``textarea { min-height: 88px }``) can both match at
    # line start; the concrete value is the feature's actual token usage.
    for value in values:
        if not value.lower().startswith("var("):
            return value
    return values[0] if values else None


def norm_color(value: str | None) -> str | None:
    if value is None:
        return None
    v = value.strip().lower()
    if re.fullmatch(r"#[0-9a-f]{3}", v):
        return "#" + "".join(ch * 2 for ch in v[1:])
    return v


def to_px(value: str | None) -> float | None:
    if value is None:
        return None
    # take the first length from shorthands such as "0 0 0 3px" (not used here)
    m = LENGTH_RE.match(value)
    if not m:
        return None
    n = float(m.group(1))
    unit = m.group(2) or "px"
    if unit in {"rem", "em"}:
        return n * ROOT_FONT_PX
    return n


def approx(a: float | None, b: float | None) -> bool:
    return a is not None and b is not None and abs(a - b) <= TOLERANCE


def check(root: Path) -> tuple[list[str], int]:
    tokens = load_tokens(root)
    css = read_css(root)
    errors: list[str] = []
    checks = 0

    version = str(tokens.get("version", ""))
    manifest = root / "design" / "releases" / version / "manifest.json"
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append(f"tokens.version is not semver: {version!r}")
    if not manifest.is_file():
        errors.append(f"release manifest missing for tokens.version={version}: {manifest}")

    variables = root_vars(css)
    if not variables:
        errors.append("web/app.css has no :root custom properties")
        return errors, checks

    colors = tokens.get("color") or {}
    for key, var in COLOR_VARS.items():
        checks += 1
        expected = norm_color(colors.get(key))
        actual = norm_color(variables.get(var.lstrip("-")))
        if expected is None:
            errors.append(f"design/tokens.json color.{key} missing")
        elif actual is None:
            errors.append(f"web/app.css :root missing {var}")
        elif actual != expected:
            errors.append(f"{var}={actual} != color.{key}={expected}")

    radius = tokens.get("radius") or {}
    checks += 1
    expected_radius = to_px(radius.get("md"))
    actual_radius = to_px(variables.get("radius"))
    if not approx(actual_radius, expected_radius):
        errors.append(f"--radius={variables.get('radius')} != radius.md={radius.get('md')}")
    checks += 1
    sm_px = to_px(radius.get("sm"))
    if sm_px is None or not re.search(r"border-radius\s*:\s*" + re.escape(f"{sm_px:g}px"), css):
        errors.append(f"radius.sm={radius.get('sm')} is not used as border-radius in web/app.css")

    focus = tokens.get("focus") or {}
    checks += 1
    outline = re.search(r"outline\s*:\s*([^;]+);", css)
    if not outline:
        errors.append("outline declaration missing (focus token)")
    else:
        parts = outline.group(1).split()
        width = to_px(next((p for p in parts if p.endswith("px")), ""))
        if not approx(width, to_px(focus.get("width"))):
            errors.append(f"outline width {outline.group(1)!r} != focus.width={focus.get('width')}")
    checks += 1
    offset = re.search(r"outline-offset\s*:\s*([^;]+);", css)
    if not offset or not approx(to_px(offset.group(1)), to_px(focus.get("offset"))):
        errors.append(f"outline-offset != focus.offset={focus.get('offset')}")

    font = tokens.get("font") or {}
    checks += 1
    body_size = to_px(decl_for(css, "body", "font-size"))
    if not approx(body_size, to_px(font.get("body"))):
        errors.append(f"body font-size {body_size}px != font.body={font.get('body')}")
    checks += 1
    h1_size = to_px(decl_for(css, "h1", "font-size"))
    if not approx(h1_size, to_px(font.get("h1"))):
        errors.append(f"h1 font-size {h1_size}px != font.h1={font.get('h1')}")
    checks += 1
    brand_size = to_px(decl_for(css, ".brand", "font-size"))
    if not approx(brand_size, to_px(font.get("brand"))):
        errors.append(f".brand font-size {brand_size}px != font.brand={font.get('brand')}")

    control = tokens.get("control") or {}
    checks += 1
    control_height = to_px(variables.get("control-height"))
    if not approx(control_height, to_px(control.get("height"))):
        errors.append(f"--control-height={variables.get('control-height')} != control.height={control.get('height')}")
    checks += 1
    textarea_height = to_px(decl_for(css, "textarea", "min-height"))
    if not approx(textarea_height, to_px(control.get("textarea"))):
        errors.append(f"textarea min-height {textarea_height}px != control.textarea={control.get('textarea')}")

    return errors, checks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    errors, checks = check(root)
    if errors:
        return fail(errors)
    print(f"ds-token-drift: PASS — {checks} token checks against design/tokens.json (web/app.css)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
