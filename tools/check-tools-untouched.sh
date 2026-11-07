#!/usr/bin/env bash
# gate-tools-untouched (F12/E6513; RQ-12 F-PATH10-RELIABILITY) — исполнитель НЕ
# имеет права править verification plane. В ветке прогона tools/, deploy/ и
# .orc-trust/ обязаны совпадать с базой (origin/main) ИЛИ быть покрыты
# подписанным allowlist процесс-владельца, взятым из origin/main.
#
# Fail-close: любая ошибка проверки (нет сети/ключа/approvalctl/подписи/поля) — FAIL.
# Единственное исключение — allowlist отсутствует И diff пуст: это поведение
# гейта до RQ-12 (PASS). Как только в tools/deploy/.orc-trust есть изменения,
# отсутствие allowlist = FAIL.
#
# Allowlist (см. .orc-trust/README.md):
#   .nexus/trust/approval.pub                  — pinned Nexus public key (trust root)
#   .orc-trust/tools-allowlist.yaml            — payload (точные байты)
#   .orc-trust/tools-allowlist.assertion.json  — nexus.approval/v1 (подпись Nexus)
#
# Hard denylist: tools/check-tools-untouched.sh и .orc-trust/** не могут быть
# разрешены allowlist'ом ни при какой подписи.
#
# A2-exclude (kit-provisioned untracked): ORC провижинит kit-тулсет в eval-
# worktree (orc/gatetools): каталоги — symlink'ом внутрь $ORC_GATE_TOOLS_ROOT,
# top-level файлы — byte-identical копией, __pycache__ — generated .pyc/.pyo.
# Такие untracked-пути не считаются правкой verification plane, НО только по
# строгому доказательству происхождения (см. §1a): symlink с целью внутри
# kit-root либо byte-identical копия (каталог — рекурсивно по набору и
# содержимому). Symlink проверяется по канонической цели ДО generated-ветки,
# поэтому provisioned tools/__pycache__ (symlink в kit-root) не ложная грязь.
# Prefix-ignore запрещён: лишний/отличающийся файл — FAIL.
# Без доступного ORC_GATE_TOOLS_ROOT исключение не применяется (fail-close).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# RQ-5 (pinned read-only bundle): при запуске из bundle DIR/.. — не репозиторий.
# ORC_GATE_ROOT задаёт проверяемое дерево явно; без него — прежнее поведение.
ROOT="${ORC_GATE_ROOT:-$(cd "$DIR/.." && pwd)}"
fail() { echo "gate-tools-untouched: FAIL — $1" >&2; exit 1; }
# audit-строка об ignored provisioned путях печатается только на успехе
pass() {
  [ -n "${TRUST_AUDIT:-}" ] && echo "$TRUST_AUDIT"
  [ -n "${IGNORED_AUDIT:-}" ] && echo "$IGNORED_AUDIT"
  echo "gate-tools-untouched: OK — $1"
  exit 0
}

# ── 0. База: GATE_BASE_REF (execution-scoped, только с привязкой к подписи) ──
# ORC инжектит РОВНО одну переменную GATE_BASE_REF из типизированного
# gate.base_ref / context.gate_base_ref. Сама переменная НЕ авторитетна:
# при непустом changed её значение обязано совпасть с entry.base_ref подписанной
# записи allowlist, а явно выбранная база — быть предком HEAD. Пустой protected
# diff при доказанном предке завершает гейт PASS до allowlist (контракт гейта).
# Пусто → origin/main.
GATE_BASE_REF_VALUE="$(printf '%s' "${GATE_BASE_REF:-}" | tr -d '\r\n')"
GATE_BASE_REF_SET=0
if [ -n "$GATE_BASE_REF_VALUE" ]; then GATE_BASE_REF_SET=1; fi

# ORC_BASE_SHA — base_sha исполнения из allowlisted gate-env ORC (не
# произвольный env агента). Нужен, когда eval-worktree материализован
# detached от base_sha и в нём нет ref origin/main: проверка «ветка не
# меняла tools/deploy/.orc-trust относительно СВОЕЙ базы» не требует сети.
# Это НЕ ослабление: значение обязано быть предком HEAD, а непустой diff
# по-прежнему требует подписанного allowlist (см. §2+).
ORC_BASE_SHA_VALUE="$(printf '%s' "${ORC_BASE_SHA:-}" | tr -d '\r\n')"
if [ -z "$ORC_BASE_SHA_VALUE" ] && [ -s "$ROOT/.orc-eval-base-sha" ]; then
  ORC_BASE_SHA_VALUE="$(tr -d '\r\n' < "$ROOT/.orc-eval-base-sha" 2>/dev/null || true)"
fi
if [ -z "$ORC_BASE_SHA_VALUE" ] && [ -s "$(dirname "$ROOT")/base-sha" ]; then
  ORC_BASE_SHA_VALUE="$(tr -d '\r\n' < "$(dirname "$ROOT")/base-sha" 2>/dev/null || true)"
fi
if [ -z "$ORC_BASE_SHA_VALUE" ]; then
  _d="$ROOT"
  while [ "$_d" != "/" ] && [ -n "$_d" ]; do
    if [ -s "$_d/.orc-base-sha" ]; then
      ORC_BASE_SHA_VALUE="$(tr -d '\r\n' < "$_d/.orc-base-sha" 2>/dev/null || true)"
      break
    fi
    _d="$(dirname "$_d")"
  done
fi

# .orc-trust/ тоже protected: ветка не может подменить allowlist/pubkey/guard.
# Verification plane скоупится базой: для kit-репо tools/deploy/.orc-trust есть
# в base и защита не меняется; в app-репо (notebook) их в base нет — app deploy/
# это код фичи, а платформенные гейты исполняются из pinned ORC_GATE_TOOLS_ROOT,
# поэтому защищать нечего (см. scope_protected_paths).
PROTECTED_ALL=(tools deploy .orc-trust)
PROTECTED=("${PROTECTED_ALL[@]}")
BASE_REF=""
BASE_SHA=""
changed=""

# protected_diff <base> — diff по PROTECTED, пустой PROTECTED → пустой diff
# (иначе git трактует отсутствие pathspec как «весь репозиторий»).
protected_diff() {
  local base="$1"
  [ "${#PROTECTED[@]}" -gt 0 ] || return 0
  git -C "$ROOT" -c core.quotepath=false diff --name-only --no-renames \
    "${base}...HEAD" -- "${PROTECTED[@]}" 2>/dev/null || true
}

# scope_protected_paths <base> — оставить в PROTECTED только пути, реально
# существующие в базе. Fail-safe: если базу проверить нельзя, остаётся полный
# набор (защита не ослабляется).
scope_protected_paths() {
  local base="$1" p out=()
  for p in "${PROTECTED_ALL[@]}"; do
    # .orc-trust — trust root: защищается ВСЕГДА (сверяется с origin/main,
    # а не с base), иначе stale base/old «прячет» allowlist/pubkey.
    if [ "$p" = ".orc-trust" ]; then
      out+=("$p")
      continue
    fi
    if git -C "$ROOT" cat-file -e "${base}:${p}" 2>/dev/null; then
      out+=("$p")
    fi
  done
  PROTECTED=("${out[@]}")
}

# Скоупим verification plane базой. Явная подписанная база приоритетнее
# execution base_sha. Нет resolvable базы → PROTECTED_ALL (fail-safe, не
# ослабляем защиту).
_SCOPE_BASE=""
if [ "$GATE_BASE_REF_SET" = 1 ]; then _SCOPE_BASE="$GATE_BASE_REF_VALUE"; fi
if [ -z "$_SCOPE_BASE" ] && [ -n "$ORC_BASE_SHA_VALUE" ]; then _SCOPE_BASE="$ORC_BASE_SHA_VALUE"; fi
if [ -n "$_SCOPE_BASE" ] && git -C "$ROOT" rev-parse --verify "${_SCOPE_BASE}^{commit}" >/dev/null 2>&1; then
  scope_protected_paths "$_SCOPE_BASE"
fi

# assert_ancestor — база обязана быть предком HEAD: иначе "base...HEAD" не
# доказывает, что ветка не обошла проверку (rebase на чужую/будущую базу).
# Проверяется для ЯВНО выбранной базы (GATE_BASE_REF / entry.base_ref).
assert_ancestor() {
  git -C "$ROOT" merge-base --is-ancestor "$BASE_SHA" HEAD 2>/dev/null \
    || fail "base_ref_not_ancestor: $BASE_REF ($BASE_SHA) не является предком HEAD ($(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo '?'))"
}

# protected_clean — контракт гейта: allowlist отсутствует И protected diff пуст
# → PASS. Условие «база — предок HEAD» обязательно: без него base...HEAD может
# быть пустым относительно чужой/будущей базы, и PASS ничего не доказывает.
# Используется ДО любых проверок allowlist; при непустом changed — как раньше.
protected_clean() {
  [ -z "$changed" ] || return 1
  [ -n "$BASE_SHA" ] || return 1
  git -C "$ROOT" merge-base --is-ancestor "$BASE_SHA" HEAD 2>/dev/null
}

# resolve_base <ref> — SHA базы + diff tools/deploy/.orc-trust от неё.
resolve_base() {
  BASE_REF="$1"
  git -C "$ROOT" rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1 \
    || fail "base_ref_unavailable: нет базовой ссылки $BASE_REF (нельзя доказать неизменность гейтов)"
  BASE_SHA="$(git -C "$ROOT" rev-parse --verify "$BASE_REF^{commit}")"
  changed="$(protected_diff "$BASE_SHA")"
}

# check_denylist — hard denylist (ДО подписи: подпись не разрешает эти пути).
check_denylist() {
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      tools/check-tools-untouched.sh|.orc-trust|.orc-trust/*)
        fail "protected_path: $p (hard denylist; allowlist не применяется)" ;;
    esac
  done <<< "$changed"
}

# filter_trust_from_main — `.orc-trust/**` сравнивается с origin/main (ANCHOR)
# по blob/tree sha, а НЕ с базой исполнения. Причина (E8267): base_sha манифеста
# 05dbb637 старше trust-root, а origin/main b387bcd7 уже содержит подписанный
# allowlist; merge main в feature давал `.orc-trust/tools-allowlist.yaml` в diff
# и ложно валил гейт. Влитый main-allowlist — не правка feature: три trust-файла
# с теми же blob sha игнорируются. Любое реальное изменение (новый, удалённый
# или иной blob) остаётся в changed и падает на hard denylist: allowlist для
# `.orc-trust/**` не применяется. Проверка «файл есть в main» недостаточна —
# сверяется именно содержимое (sha), иначе новый файл с тем же именем прошёл бы.
TRUST_IGNORED=()
filter_trust_from_main() {
  local p head_sha main_sha kept=""
  TRUST_IGNORED=()
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      .orc-trust|.orc-trust/*) ;;
      *) kept+="$p"$'\n'; continue ;;
    esac
    # blob (файл) или tree (каталог) sha; отсутствие пути → пустой sha.
    head_sha="$(git -C "$ROOT" rev-parse --verify "HEAD:$p" 2>/dev/null || true)"
    main_sha="$(git -C "$ROOT" rev-parse --verify "${ANCHOR}:$p" 2>/dev/null || true)"
    if [ -n "$head_sha" ] && [ "$head_sha" = "$main_sha" ]; then
      TRUST_IGNORED+=("$p")
      continue
    fi
    fail "protected_path: $p (feature изменяет .orc-trust относительно origin/main; allowlist не применяется)"
  done <<< "$changed"
  changed="$kept"
  TRUST_AUDIT=""
  if [ "${#TRUST_IGNORED[@]}" -gt 0 ]; then
    local tlist
    tlist="$(printf '%s,' "${TRUST_IGNORED[@]}")"
    tlist="${tlist%,}"
    TRUST_AUDIT="gate-tools-untouched: ignored ${#TRUST_IGNORED[@]} .orc-trust path(s) identical to origin/main (${ANCHOR:0:12}): $tlist"
  fi
}

# Порядок выбора базы:
#   1) GATE_BASE_REF (execution-scoped, привязан к подписи allowlist);
#   2) ORC_BASE_SHA — база исполнения (offline-safe, ancestor-check ниже);
#   3) локальные main-refs (без сети);
#   4) origin/main через remote (последний шанс, прежнее поведение).
# Пустой diff по protected-путям завершает гейт ДО сетевого анкора: это
# доказывает неизменность относительно выбранной базы, а не «делает вид».
BASE_FROM_BASE_SHA=0
if [ "$GATE_BASE_REF_SET" = 1 ]; then
  resolve_base "$GATE_BASE_REF_VALUE"
  # Явная база (GATE_BASE_REF / entry.base_ref) обязана быть предком HEAD:
  # иначе base...HEAD доказывает неизменность не относительно того коммита,
  # к которому привязана подпись allowlist.
  assert_ancestor
elif [ -n "$ORC_BASE_SHA_VALUE" ]; then
  BASE_FROM_BASE_SHA=1
  BASE_REF="base_sha:${ORC_BASE_SHA_VALUE:0:12}"
  BASE_SHA="$(git -C "$ROOT" rev-parse --verify "${ORC_BASE_SHA_VALUE}^{commit}" 2>/dev/null || true)"
  [ -n "$BASE_SHA" ] || fail "base_ref_unavailable: ORC_BASE_SHA=$ORC_BASE_SHA_VALUE не материализован в eval-worktree"
  changed="$(protected_diff "$BASE_SHA")"
  assert_ancestor
else
  for _ref in origin/main refs/remotes/origin/main refs/heads/main main; do
    if git -C "$ROOT" rev-parse --verify "${_ref}^{commit}" >/dev/null 2>&1; then
      resolve_base "$_ref"
      break
    fi
  done
  if [ -z "$BASE_SHA" ]; then
    resolve_base origin/main
  fi
fi

# ── 1a. Kit-provisioned untracked (A2-exclude) ──────────────────────────────
# ORC_GATE_TOOLS_ROOT — корень kit-тулсета (каталог tools архкита). Значение
# не авторитетно само по себе: оно лишь ограничивает область, внутри которой
# symlink может считаться provisioned. Не задан/не существует/не канонизируется
# → исключение не применяется вовсе (fail-close: любой untracked = изменение).
PROV_ROOT=""
PROV_DISPLAY=""
if [ -n "${ORC_GATE_TOOLS_ROOT:-}" ] && [ -d "${ORC_GATE_TOOLS_ROOT}" ]; then
  PROV_ROOT="$(readlink -f -- "${ORC_GATE_TOOLS_ROOT}" 2>/dev/null || true)"
  if [ -n "$PROV_ROOT" ] && [ -d "$PROV_ROOT" ]; then
    PROV_DISPLAY="${ORC_GATE_TOOLS_ROOT%/}"
  else
    PROV_ROOT=""
  fi
fi

path_has_pycache() { case "/$1/" in */__pycache__/*) return 0 ;; esac; return 1; }
is_generated_name() { case "$1" in *.pyc|*.pyo) return 0 ;; esac; return 1; }
# prov_inside <canonical> — цель symlink'а строго внутри kit-root (не сам root).
prov_inside() { case "$1" in "$PROV_ROOT"/*) return 0 ;; esac; return 1; }

# dir_provisioned <tools/...> — рекурсивно совпадают НАБОР и СОДЕРЖИМОЕ с
# kit-root. Лишний файл (в дереве или в kit-root) → FAIL: каталог сам по себе
# права игнорировать содержимое не даёт. Generated .pyc/.pyo в __pycache__
# исключаются с обеих сторон.
dir_provisioned() {
  local abs="$ROOT/$1" kit="$PROV_ROOT/${1#tools/}" f rel tgt leaves=$'\n'
  [ -d "$kit" ] || return 1
  while IFS= read -r f; do
    rel="${f#"$abs"/}"
    if [ -L "$f" ]; then
      # Symlink внутрь kit-root — provisioned независимо от имени (в т.ч.
      # вложенный __pycache__).
      tgt="$(readlink -f -- "$f" 2>/dev/null)" || return 1
      { [ -n "$tgt" ] && [ -e "$tgt" ] && prov_inside "$tgt"; } || return 1
    elif path_has_pycache "$rel"; then
      { [ -f "$f" ] && is_generated_name "$rel"; } || return 1
      continue
    elif [ -f "$f" ]; then
      { [ -f "$kit/$rel" ] && cmp -s -- "$f" "$kit/$rel"; } || return 1
    else
      return 1
    fi
    leaves+="$rel"$'\n'
  done < <(find "$abs" -mindepth 1 \( -type f -o -type l \) -print 2>/dev/null)
  while IFS= read -r f; do
    rel="${f#"$kit"/}"
    path_has_pycache "$rel" && continue
    case "$leaves" in *$'\n'"$rel"$'\n'*) ;; *) return 1 ;; esac
  done < <(find "$kit" -mindepth 1 \( -type f -o -type l \) -print 2>/dev/null)
  return 0
}

# provisioned_reason <path> — печатает причину и возвращает 0, если путь
# доказуемо provisioned. Любое сомнение → ненулевой код (fail-close).
provisioned_reason() {
  local dpath="${1%/}" abs tgt
  abs="$ROOT/$dpath"
  [ -n "$PROV_ROOT" ] || return 1
  case "$dpath" in tools/*) ;; *) return 1 ;; esac
  # Symlink проверяется ДО __pycache__: provisioning линкует kit-каталоги
  # (включая tools/__pycache__) внутрь kit-root. Такой symlink доказуемо
  # kit-owned — тот же критерий, что для любого другого provisioned-пути.
  # Иначе `?? tools/__pycache__` ложно считался правкой гейтов (F12).
  if [ -L "$abs" ]; then
    # 1a: symlink, цель существует и (канонизированная) лежит внутри kit-root.
    tgt="$(readlink -f -- "$abs" 2>/dev/null)" || return 1
    { [ -n "$tgt" ] && [ -e "$tgt" ] && prov_inside "$tgt"; } || return 1
    printf 'symlink->%s/%s' "$PROV_DISPLAY" "${tgt#"$PROV_ROOT"/}"
    return 0
  fi
  if path_has_pycache "$dpath"; then
    if [ -f "$abs" ] && [ ! -L "$abs" ]; then
      is_generated_name "$dpath" || return 1
      printf 'generated'; return 0
    fi
    if [ -d "$abs" ] && [ ! -L "$abs" ]; then
      local f seen=0
      while IFS= read -r f; do
        seen=1
        { [ -f "$f" ] && [ ! -L "$f" ] && is_generated_name "$f"; } || return 1
      done < <(find "$abs" -mindepth 1 \
        \( -type f -o -type l -o -type d -o -type p -o -type s -o -type b -o -type c \) \
        -print 2>/dev/null)
      [ "$seen" = 1 ] || return 1
      printf 'generated'; return 0
    fi
    return 1
  fi
  if [ -f "$abs" ]; then
    # 1b: regular file, byte-identical копия соответствующего файла kit-root.
    { [ -f "$PROV_ROOT/${dpath#tools/}" ] \
      && cmp -s -- "$abs" "$PROV_ROOT/${dpath#tools/}"; } || return 1
    printf 'identical'; return 0
  fi
  if [ -d "$abs" ]; then
    # 1b: каталог — рекурсивно совпадают набор и содержимое.
    dir_provisioned "$dpath" || return 1
    printf 'identical'; return 0
  fi
  return 1
}

dirty_raw=""
if [ "${#PROTECTED[@]}" -gt 0 ]; then
  dirty_raw="$(git -C "$ROOT" -c core.quotepath=false status --porcelain \
    -- "${PROTECTED[@]}" 2>/dev/null || true)"
fi
dirty=""
IGNORED_ITEMS=()
IGNORED_COUNT=0
IGNORED_AUDIT=""
while IFS= read -r dline; do
  [ -n "$dline" ] || continue
  st="${dline:0:2}"
  dpath="${dline:3}"
  dpath="${dpath%/}"
  # Только untracked может быть kit-provisioned: tracked-правки всегда FAIL
  # (diff-логика выше не меняется).
  if [ "$st" = "??" ] && reason="$(provisioned_reason "$dpath")"; then
    IGNORED_ITEMS+=("$dpath ($reason)")
    IGNORED_COUNT=$((IGNORED_COUNT + 1))
    continue
  fi
  dirty+="$dline"$'\n'
done <<< "$dirty_raw"
if [ "$IGNORED_COUNT" -gt 0 ]; then
  joined=""
  for it in "${IGNORED_ITEMS[@]}"; do
    [ -n "$joined" ] && joined+=", "
    joined+="$it"
  done
  IGNORED_AUDIT="gate-tools-untouched: ignored $IGNORED_COUNT provisioned path(s): $joined"
fi
if [ -n "$dirty" ]; then
  echo "$dirty" >&2
  fail "в рабочем дереве изменены гейты/тулинг (F12): $(echo "$dirty" | tr '\n' ' ')"
fi
# Быстрый выход до сети: пустой protected diff при доказанном предке — PASS по
# контракту гейта (allowlist отсутствует И diff пуст), в том числе для явного
# GATE_BASE_REF. Ancestor-check уже выполнен assert_ancestor для явной базы и
# повторяется здесь для любой выбранной базы. Allowlist читается только при
# непустом changed.
if protected_clean; then
  pass "tools/, deploy/ и .orc-trust/ не изменены относительно $BASE_REF (base — предок HEAD)"
fi

# ── 2. Анкор: main из remote, а не локальный refs/remotes/* ─────────────────
# Локальную ссылку исполнитель может переписать (git update-ref). Поэтому SHA
# main берётся у remote (ls-remote) и объект подтягивается в FETCH_HEAD, не
# переписывая refs. Нет сети/remote → FAIL (никакого офлайн-прохода).
TRUST_REMOTE="${ORC_TRUST_REMOTE_URL:-$(git -C "$ROOT" config --get remote.origin.url 2>/dev/null || true)}"
[ -n "$TRUST_REMOTE" ] || fail "anchor_unavailable: не задан origin / ORC_TRUST_REMOTE_URL"
ANCHOR="$(git -C "$ROOT" ls-remote --exit-code "$TRUST_REMOTE" refs/heads/main 2>/dev/null \
  | awk 'NR==1{print $1}')"
[ -n "$ANCHOR" ] || fail "anchor_unavailable: origin/main недоступен ($TRUST_REMOTE)"
if ! git -C "$ROOT" cat-file -e "${ANCHOR}^{commit}" 2>/dev/null; then
  git -C "$ROOT" fetch --no-tags --quiet "$TRUST_REMOTE" refs/heads/main >/dev/null 2>&1 \
    || fail "anchor_unavailable: не удалось получить origin/main"
  ANCHOR="$(git -C "$ROOT" rev-parse FETCH_HEAD 2>/dev/null || true)"
  [ -n "$ANCHOR" ] || fail "anchor_unavailable: пустой FETCH_HEAD"
fi

# ── 2a. База protected-diff — авторитетный origin/main, не устаревший ref ────
# Локальный refs/remotes/origin/main может отставать: E8267 base_sha=05dbb637
# (до trust-root), origin/main=b387bcd7 (подписанный allowlist). Diff от
# устаревшей базы показывал влитый из main allowlist как «правку feature».
# Сравниваем tools/deploy/.orc-trust с merge-base(ANCHOR, HEAD): изменения,
# уже влитые из main, в diff не попадают. Явно выбранная подписанная база
# (GATE_BASE_REF / entry.base_ref), отличная от origin/main, сохраняется —
# allowlist-контракт адресует именно её; но и для неё `.orc-trust/**` ниже
# сверяется с origin/main.
if [ "$GATE_BASE_REF_SET" = 0 ] \
   || [ "$GATE_BASE_REF_VALUE" = "origin/main" ] \
   || [ "$GATE_BASE_REF_VALUE" = "refs/remotes/origin/main" ]; then
  BASE_REF="origin/main"
  BASE_SHA="$ANCHOR"
  changed="$(protected_diff "$ANCHOR")"
fi

# ── 2b. `.orc-trust/**`: влитый main-allowlist ≠ правка feature ─────────────
# blob-сверка с origin/main; allowlist для .orc-trust не применяется (hard
# denylist), см. filter_trust_from_main.
filter_trust_from_main
check_denylist

if protected_clean; then
  pass "tools/, deploy/ и .orc-trust/ не изменены feature относительно origin/main (${ANCHOR:0:12}); base — предок HEAD"
fi

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t orc-trust)" || fail "tempdir_unavailable"
trap 'rm -rf "$TMP"' EXIT
# Payload — предмет подписи; нужен в ЛЮБОМ trust-режиме (assertion или owner-sig).
git -C "$ROOT" cat-file -e "${ANCHOR}:.orc-trust/tools-allowlist.yaml" 2>/dev/null \
  || fail "allowlist_missing: .orc-trust/tools-allowlist.yaml @ $ANCHOR"
git -C "$ROOT" show "${ANCHOR}:.orc-trust/tools-allowlist.yaml" > "$TMP/payload.yaml" 2>/dev/null \
  || fail "allowlist_missing: tools-allowlist.yaml"

# ── 5. Payload: schema/branch/TTL/paths/denylist/max_files/digest ───────────
# ORC создаёт eval-worktree с `git worktree add --detach`, поэтому HEAD не
# указывает на ветку и `rev-parse --abbrev-ref HEAD` = HEAD. Для allowlist
# резолвим рабочую ветку так: ORC_WORK_BRANCH (если исполнение его задало) →
# attached HEAD → единственный origin-ref, содержащий HEAD. Неоднозначность —
# fail-close (нельзя молча принять чужую ветку).
BRANCH="${ORC_WORK_BRANCH:-}"
if [ -z "$BRANCH" ]; then
  BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$HEAD_SHA" ] || fail "wrong_branch: cannot resolve HEAD"
  BRANCH="$(git -C "$ROOT" for-each-ref --format='%(refname:strip=3)' \
    --contains "$HEAD_SHA" refs/remotes/origin 2>/dev/null \
    | sed '/^$/d;/^HEAD$/d' | LC_ALL=C sort -u || true)"
  n="$(printf '%s\n' "$BRANCH" | sed '/^$/d' | wc -l | tr -d ' ')"
  [ "$n" = "1" ] || fail "wrong_branch: detached HEAD, origin refs containing $HEAD_SHA: ${n} (${BRANCH//$'\n'/,})"
fi
[ -n "$BRANCH" ] || fail "wrong_branch: detached HEAD"

# ── 4a. Trust: Nexus assertion ПРЕДПОЧТИТЕЛЬНО; owner-sig — явный fallback ──
# Решение owner/process-владельца (E8267, 2026-11-02):
#   * assertion (nexus.approval/v1) присутствует в origin/main → используется
#     ТОЛЬКО он; его ошибка НЕ откатывается на owner-sig (no downgrade);
#   * assertion отсутствует → проверяется ТОЛЬКО pinned owner-key подпись
#     `.orc-trust/allowlist.pub` над точными байтами payload;
#   * нет assertion И нет/битая sig → FAIL. Fallback не silent: печатается
#     явная TRUST-строка и режим попадает в audit-строку гейта.
# Hard denylist выше не меняется: allowlist никогда не разрешает
# tools/check-tools-untouched.sh и `.orc-trust/**`.
TRUST_MODE=""
TRUST_KEY_ID=""
if git -C "$ROOT" cat-file -e "${ANCHOR}:.orc-trust/tools-allowlist.assertion.json" 2>/dev/null; then
  # Assertion — nexus.approval/v1 в .orc-trust/tools-allowlist.assertion.json:
  # verify (подпись, TTL, project/branch/paths, payload_sha256, tree_digest)
  # через тот же верификатор, что у ORC. Consume делает gate
  # (tools/check-tools-approval.sh); здесь проверка не потребляет, чтобы гейт
  # был идемпотентным до приёмки.
  git -C "$ROOT" show "${ANCHOR}:.orc-trust/tools-allowlist.assertion.json" > "$TMP/assertion.json" 2>/dev/null \
    || fail "allowlist_missing: tools-allowlist.assertion.json"
  APPROVALCTL="${APPROVALCTL:-approvalctl}"
  command -v "$APPROVALCTL" >/dev/null 2>&1 \
    || fail "verifier_unavailable: approvalctl не найден (Dockerfile.orc собирает его в PATH)"
  PROJECT_ID="${NEXUS_PROJECT_ID:-}"
  if [ -z "$PROJECT_ID" ] && git -C "$ROOT" cat-file -e "${ANCHOR}:.nexus/project_id" 2>/dev/null; then
    PROJECT_ID="$(git -C "$ROOT" show "${ANCHOR}:.nexus/project_id" | tr -d '[:space:]')"
  fi
  [ -n "$PROJECT_ID" ] || fail "project_unbound: задайте NEXUS_PROJECT_ID или .nexus/project_id (F198)"
  if git -C "$ROOT" cat-file -e "${ANCHOR}:.nexus/trust/approval.pub" 2>/dev/null; then
    git -C "$ROOT" show "${ANCHOR}:.nexus/trust/approval.pub" > "$TMP/bundle.pub"
  else
    [ -n "${NEXUS_APPROVAL_TRUST_BUNDLE:-}" ] && [ -f "${NEXUS_APPROVAL_TRUST_BUNDLE}" ] \
      || fail "trust_bundle_missing: .nexus/trust/approval.pub @ ${ANCHOR:0:12} или NEXUS_APPROVAL_TRUST_BUNDLE"
    cp "${NEXUS_APPROVAL_TRUST_BUNDLE}" "$TMP/bundle.pub"
  fi
  python3 - "$TMP/assertion.json" <<'PYGUARD' || fail "assertion_invalid: artifact_digest is required (tree_digest)"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
a = d.get("assertion") or {}
if d.get("schema") != "nexus.approval-signature/v1" or a.get("schema") != "nexus.approval/v1":
    raise SystemExit("unexpected schema")
if not str(a.get("artifact_digest") or "").startswith("sha256:"):
    raise SystemExit("artifact_digest missing")
PYGUARD
  "$APPROVALCTL" verify -assertion "$TMP/assertion.json" -bundle "$TMP/bundle.pub" \
    -project "$PROJECT_ID" -subject allowlist -branch "$BRANCH" \
    -repo "$ROOT" -base "$ANCHOR" -source HEAD \
    -allowlist "$TMP/payload.yaml" >/dev/null 2>"$TMP/verr" \
    || { cat "$TMP/verr" >&2 2>/dev/null || true; fail "assertion_rejected"; }
  TRUST_MODE="nexus-assertion"
else
  # Явный fallback (не silent): assertion отсутствует, доверяем только
  # pinned owner-key подписи над точными байтами payload.
  echo "gate-tools-untouched: TRUST — assertion отсутствует @ ${ANCHOR:0:12}; owner-sig fallback (pinned allowlist.pub)" >&2
  for f in .orc-trust/allowlist.pub .orc-trust/tools-allowlist.yaml.sig; do
    git -C "$ROOT" cat-file -e "${ANCHOR}:$f" 2>/dev/null \
      || fail "allowlist_missing: $f @ $ANCHOR (assertion отсутствует; owner-sig fallback неполон)"
  done
  git -C "$ROOT" show "${ANCHOR}:.orc-trust/allowlist.pub" > "$TMP/pub.json" 2>/dev/null \
    || fail "allowlist_missing: allowlist.pub"
  git -C "$ROOT" show "${ANCHOR}:.orc-trust/tools-allowlist.yaml.sig" > "$TMP/sig.b64" 2>/dev/null \
    || fail "allowlist_missing: tools-allowlist.yaml.sig"
  # raw Ed25519 (32 B) → SPKI PEM
  python3 - "$TMP/pub.json" "$TMP/pub.pem" <<'PY' || fail "pubkey_invalid"
import base64, json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    if d.get("schema") != "orc.trust.pubkey/v1" or str(d.get("alg", "")).lower() != "ed25519":
        raise ValueError("schema/alg")
    raw = base64.b64decode(str(d["public_key"]), validate=True)
    if len(raw) != 32:
        raise ValueError("public_key must be 32 bytes")
except Exception as e:
    print(f"pubkey_invalid: {e}", file=sys.stderr)
    sys.exit(1)
der = bytes.fromhex("302a300506032b6570032100") + raw  # SubjectPublicKeyInfo(Ed25519)
b64 = base64.b64encode(der).decode()
pem = "-----BEGIN PUBLIC KEY-----\n" + "\n".join(b64[i:i+64] for i in range(0, len(b64), 64)) + "\n-----END PUBLIC KEY-----\n"
open(sys.argv[2], "w", encoding="ascii").write(pem)
PY
  # base64 → 64-byte signature
  python3 - "$TMP/sig.b64" "$TMP/sig.bin" <<'PY' || fail "signature_invalid"
import base64, re, sys
try:
    s = re.sub(r"\s+", "", open(sys.argv[1], encoding="ascii").read())
    raw = base64.b64decode(s, validate=True)
    if len(raw) != 64:
        raise ValueError("signature must be 64 bytes")
except Exception as e:
    print(f"signature_invalid: {e}", file=sys.stderr)
    sys.exit(1)
open(sys.argv[2], "wb").write(raw)
PY
  command -v openssl >/dev/null 2>&1 \
    || fail "verifier_unavailable: openssl не установлен в образе (Dockerfile.orc) — owner-sig проверить нельзя"
  openssl pkeyutl -verify -pubin -inkey "$TMP/pub.pem" -rawin \
    -in "$TMP/payload.yaml" -sigfile "$TMP/sig.bin" >/dev/null 2>&1 \
    || fail "signature_invalid: Ed25519(payload) не совпала с pinned allowlist.pub"
  TRUST_KEY_ID="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1], encoding="utf-8")).get("key_id") or "").strip())' "$TMP/pub.json" 2>/dev/null || true)"
  TRUST_MODE="owner-sig"
fi

# ── 4b. base_ref: execution-scoped база привязана к подписи (fail-close) ────
# GATE_BASE_REF (если задан) обязан быть объявлен в ТОЙ ЖЕ подписанной записи,
# что разрешает ветку. Значение из env без привязки к подписи не принимается:
# иначе исполнитель выбрал бы базу, на которой его tools-diff «пуст».
ENTRY_BASE_REF="$(python3 - "$TMP/payload.yaml" "$BRANCH" "${ORC_FEATURE_ID:-}" 2>"$TMP/err" <<'PY'
import sys
try:
    import yaml
except Exception as e:
    print(f"allowlist_unparseable: pyyaml unavailable: {e}", file=sys.stderr); sys.exit(2)
payload, branch, feature = sys.argv[1:4]
try:
    d = yaml.safe_load(open(payload, encoding="utf-8"))
except Exception as e:
    print(f"allowlist_unparseable: {e}", file=sys.stderr); sys.exit(2)
if not isinstance(d, dict) or d.get("schema") != "orc.tools-allowlist/v1":
    print("allowlist_unparseable: schema != orc.tools-allowlist/v1", file=sys.stderr); sys.exit(2)
entries = d.get("entries")
if not isinstance(entries, list):
    print("allowlist_unparseable: entries must be a list", file=sys.stderr); sys.exit(2)
match = [e for e in entries if isinstance(e, dict) and str(e.get("work_branch", "")).strip() == branch]
if len(match) != 1:
    print(f"wrong_branch: ожидалась ровно 1 запись для {branch!r}, найдено {len(match)}", file=sys.stderr); sys.exit(3)
e = match[0]
if feature and str(e.get("feature_id", "")).strip() != feature:
    print(f"wrong_feature: {e.get('feature_id')!r} != {feature!r}", file=sys.stderr); sys.exit(4)
print(str(e.get("base_ref") or "").strip())
PY
)" || {
  code="$(sed -n '1s/:.*//p' "$TMP/err" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  cat "$TMP/err" >&2 2>/dev/null || true
  fail "${code:-allowlist_rejected}"
}

if [ "$GATE_BASE_REF_SET" = 1 ]; then
  [ -n "$ENTRY_BASE_REF" ] \
    || fail "base_ref_unbound: GATE_BASE_REF=$GATE_BASE_REF_VALUE, но entry.base_ref отсутствует в подписанной записи"
  [ "$GATE_BASE_REF_VALUE" = "$ENTRY_BASE_REF" ] \
    || fail "base_ref_mismatch: GATE_BASE_REF=$GATE_BASE_REF_VALUE != entry.base_ref=$ENTRY_BASE_REF"
fi

# Эффективная база: GATE_BASE_REF → entry.base_ref → origin/main. При смене
# базы diff (и, следовательно, paths/max_files/tree_digest) пересчитывается
# от ТОЙ ЖЕ базы. Явно выбранная база (env или подпись) обязана быть предком
# HEAD; для НЕявного origin/main сохраняется прежняя merge-base семантика
# (регресс «ветку форкнули до движения main» не вводится).
EXPLICIT_BASE=0
if [ "$GATE_BASE_REF_SET" = 1 ] || [ -n "$ENTRY_BASE_REF" ] || [ "$BASE_FROM_BASE_SHA" = 1 ]; then
  EXPLICIT_BASE=1
fi
EFF_BASE="${GATE_BASE_REF_VALUE:-${ENTRY_BASE_REF:-$BASE_REF}}"
if [ "$EFF_BASE" != "$BASE_REF" ]; then
  resolve_base "$EFF_BASE"
  # Подписанная база не должна «возвращать» влитый main-allowlist в diff.
  filter_trust_from_main
  check_denylist
fi
if [ "$EXPLICIT_BASE" = 1 ]; then
  assert_ancestor
fi
[ -n "$changed" ] || pass "tools/, deploy/ и .orc-trust/ не изменены относительно $BASE_REF"

META="$(python3 - "$TMP/payload.yaml" "$changed" "$BRANCH" "${ORC_FEATURE_ID:-}" 2>"$TMP/err" <<'PY'
import fnmatch, sys
from datetime import datetime, timedelta, timezone

payload, changed_raw, branch, feature = sys.argv[1:5]
try:
    import yaml
except Exception as e:  # py3-yaml есть в образе ORC; без него — fail-close
    print(f"allowlist_unparseable: pyyaml unavailable: {e}", file=sys.stderr); sys.exit(2)
try:
    d = yaml.safe_load(open(payload, encoding="utf-8"))
except Exception as e:
    print(f"allowlist_unparseable: {e}", file=sys.stderr); sys.exit(2)
if not isinstance(d, dict) or d.get("schema") != "orc.tools-allowlist/v1":
    print("allowlist_unparseable: schema != orc.tools-allowlist/v1", file=sys.stderr); sys.exit(2)
entries = d.get("entries")
if not isinstance(entries, list):
    print("allowlist_unparseable: entries must be a list", file=sys.stderr); sys.exit(2)
match = [e for e in entries if isinstance(e, dict) and str(e.get("work_branch", "")).strip() == branch]
if len(match) != 1:
    print(f"wrong_branch: ожидалась ровно 1 запись для {branch!r}, найдено {len(match)}", file=sys.stderr); sys.exit(3)
e = match[0]
if feature and str(e.get("feature_id", "")).strip() != feature:
    print(f"wrong_feature: {e.get('feature_id')!r} != {feature!r}", file=sys.stderr); sys.exit(4)
now = datetime.now(timezone.utc)
def ts(v):
    if not isinstance(v, str) or not v.strip():
        return None
    try:
        return datetime.fromisoformat(v.strip().replace("Z", "+00:00"))
    except Exception:
        return None
exp = ts(e.get("expires_at") or d.get("expires_at"))
if exp is None or now > exp:
    print(f"allowlist_expired: expires_at={e.get('expires_at') or d.get('expires_at')!r}", file=sys.stderr); sys.exit(5)
issued = ts(e.get("issued_at") or d.get("issued_at"))
if issued is not None and now < issued - timedelta(minutes=10):
    print(f"allowlist_expired: issued_at в будущем ({e.get('issued_at') or d.get('issued_at')!r})", file=sys.stderr); sys.exit(5)
paths = e.get("paths")
if not isinstance(paths, list) or not paths:
    print("paths_missing: paths обязателен и непуст", file=sys.stderr); sys.exit(6)
for p in paths:
    if not isinstance(p, str) or not (p.startswith("tools/") or p.startswith("deploy/")):
        print(f"path_not_allowed: {p!r} вне tools/|deploy/", file=sys.stderr); sys.exit(6)
    if p == "tools/check-tools-untouched.sh" or p.startswith(".orc-trust/"):
        print(f"protected_path: {p!r} в hard denylist", file=sys.stderr); sys.exit(6)
    if fnmatch.fnmatchcase("tools/check-tools-untouched.sh", p):
        print(f"protected_path: glob {p!r} покрывает guard", file=sys.stderr); sys.exit(6)
changed = [p for p in changed_raw.split("\n") if p.strip()]
if not changed:
    print("path_not_allowed: нет изменённых путей", file=sys.stderr); sys.exit(6)
try:
    max_files = int(e.get("max_files", 32))
except Exception:
    max_files = 32
if max_files < 1 or len(changed) > max_files:
    print(f"max_files: изменено {len(changed)} > max_files={max_files}", file=sys.stderr); sys.exit(7)
for p in changed:
    if p == "tools/check-tools-untouched.sh" or p.startswith(".orc-trust/"):
        print(f"protected_path: {p}", file=sys.stderr); sys.exit(6)
    if not any(fnmatch.fnmatchcase(p, pat) for pat in paths):
        print(f"path_not_allowed: {p}", file=sys.stderr); sys.exit(6)
digest = str(e.get("tree_digest") or "").strip()
if not digest:
    print("digest_required: tree_digest обязателен (иначе содержимое файлов не связано с подписью)", file=sys.stderr); sys.exit(8)
print(str(e.get("id") or "?"))
print(str(e.get("feature_id") or ""))
print(digest)
print(str(e.get("base_tools_tree") or ""))
PY
)" || {
  code="$(sed -n '1s/:.*//p' "$TMP/err" 2>/dev/null | head -n1 | tr -d '[:space:]')"
  cat "$TMP/err" >&2 2>/dev/null || true
  fail "${code:-allowlist_rejected}"
}
ENTRY_ID="$(printf '%s\n' "$META" | sed -n '1p')"
ENTRY_FEATURE="$(printf '%s\n' "$META" | sed -n '2p')"
ENTRY_DIGEST="$(printf '%s\n' "$META" | sed -n '3p')"

# ── 6. tree_digest: sha256( path\0mode\0sha256(content)\0 ... ) ─────────────
# Точная спецификация — в .orc-trust/README.md; та же команда у оператора.
got="$(while IFS= read -r p; do
  [ -n "$p" ] || continue
  if git -C "$ROOT" cat-file -e "HEAD:$p" 2>/dev/null; then
    mode="$(git -C "$ROOT" ls-tree HEAD -- "$p" | awk '{print $1}')"
    sum="$(git -C "$ROOT" cat-file blob "HEAD:$p" | sha256sum | awk '{print $1}')"
  else
    mode="DELETED"; sum="DELETED"
  fi
  printf '%s\0%s\0%s\0' "$p" "$mode" "$sum"
done < <(printf '%s\n' "$changed" | LC_ALL=C sort) | sha256sum | awk '{print $1}')"
want="${ENTRY_DIGEST#sha256:}"
[ -n "$want" ] || fail "digest_required: tree_digest пуст"
[ "$want" = "$got" ] || fail "digest_mismatch: allowlist=$want actual=$got"

# Опциональный base_tools_tree: содержимое tools/+deploy/ на базе. Если поле
# указано — оно обязано совпасть; rebase на другую main-базу с иным tools-tree
# требует перевыпуска записи.
BASE_DECL="$(printf '%s\n' "$META" | sed -n '4p')"
if [ -n "$BASE_DECL" ]; then
  want_base="${BASE_DECL#sha256:}"
  BASE_TREE="$(git -C "$ROOT" ls-tree -r --format='%(objectmode) %(objectname) %(path)' \
    "$BASE_SHA" -- tools deploy 2>/dev/null | LC_ALL=C sort | sha256sum | awk '{print $1}')"
  [ "$want_base" = "$BASE_TREE" ] \
    || fail "base_drift: allowlist=$want_base actual=$BASE_TREE"
fi

# ── 7. Аудит: строка уходит в stdout гейта (ORC сохраняет вывод приёмки) ────
echo "gate-tools-untouched: ALLOWLIST id=$ENTRY_ID feature=${ENTRY_FEATURE:-?} branch=$BRANCH anchor=$ANCHOR trust=$TRUST_MODE${TRUST_KEY_ID:+ key=$TRUST_KEY_ID} digest=sha256:$got paths=$(printf '%s' "$changed" | tr '\n' ',')"
pass "tools/, deploy/ и .orc-trust/ покрыты подписанным allowlist $ENTRY_ID (trust=$TRUST_MODE, branch=$BRANCH, anchor=${ANCHOR:0:12})"
