#!/usr/bin/env bash
#
# Tube Downloader review gate — READ-ONLY.
#
# Runs dart format, flutter analyze and the house forbidden-pattern checks on
# the .dart files changed relative to a base ref (default origin/main), scans
# EVERY changed file for committed credentials and pubspec.yaml for new or
# banned dependencies, then prints findings as BLOCKING / WORTH FIXING / NOTES.
# It never edits a file: a gate that can rewrite code to make itself pass is
# not a gate.
#
# Usage (from anywhere inside the repo):
#   bash .claude/skills/review-gate/scripts/check.sh              # changed vs origin/main
#   bash .claude/skills/review-gate/scripts/check.sh --base main  # other base ref
#   bash .claude/skills/review-gate/scripts/check.sh --tests      # also run flutter test (goldens only on macOS)
#   bash .claude/skills/review-gate/scripts/check.sh --all        # whole lib/ + test/ (debt sweep)
#
# Exit codes: 0 clean (warnings allowed) · 1 blocking findings · 2 could not run.
# CI (.github/workflows/quality.yml) fails the PR on exit 1.
#
# In the default mode the pattern checks look at ADDED lines only, so a legacy
# file touched for another reason does not drag its old debt into the report.
# A BLOCKING pattern is also RATCHETED per file: it blocks only when the file
# now holds more occurrences than it did at the merge-base. A changed line that
# merely carries an old violation along — a formatter reflow, an RTL fix, a
# rename — is reported as WORTH FIXING instead, so fixing one rule on a legacy
# line never trips another. --all scans whole files and is for measuring the
# debt, not for gating.
#
# Every pattern proves itself before it is trusted (section 0): it is declared
# once, beside lines it must catch and lines it must leave alone, and those
# samples go through the same line filter the real scan uses. A pattern that
# stops catching its own known violation — an edit that broke it, a grep that
# reads it differently — is BLOCKING instead of quietly passing everything.
#
# Known limit: pattern checks are line-based, so a constructor split across
# lines (e.g. "SizedBox(\n  height: 8," ) escapes the same-line patterns.
# dart format keeps short calls on one line, which is what makes this workable.
#
# Portable to bash 3.2 (macOS) and GNU/BSD grep: no \b, \s, mapfile or arrays-of-arrays.

set -u

BASE_REF="origin/main"
MODE="diff"
RUN_TESTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --all) MODE="all" ;;
    --base) shift; BASE_REF="${1:-}" ;;
    --tests) RUN_TESTS=1 ;;
    -h|--help) awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review-gate: not inside a git repository" >&2; exit 2; }
cd "$ROOT" || exit 2
command -v dart    >/dev/null 2>&1 || { echo "review-gate: dart is not on PATH" >&2; exit 2; }
command -v flutter >/dev/null 2>&1 || { echo "review-gate: flutter is not on PATH" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BLOCKING="$TMP/blocking"; WORTH="$TMP/worth"; NOTES="$TMP/notes"
: > "$BLOCKING"; : > "$WORTH"; : > "$NOTES"

block() { printf '%s\n' "$1" >> "$BLOCKING"; }
worth() { printf '%s\n' "$1" >> "$WORTH"; }
note()  { printf '%s\n' "$1" >> "$NOTES"; }

# ------------------------------------------------------ 0. self-tested patterns
#
# Each pattern is declared ONCE, here, and every check below reads it from its
# variable — so a sample and the scan it vouches for can never drift apart.
#
# selftest <stream> <label> <ERE> <sample>...  — "+line" must match, "-line" must not.
#   code  the Dart pattern scan: "lineno:text", comment-only lines dropped
#   raw   the same with comment lines kept (TODO/FIXME live in comments)
#   cred  the credential scan: "path:lineno:text", case-insensitive
# A misbehaving sample is BLOCKING: the check it guards would otherwise report
# clean on everything, which is how a broken check stays green for months.

COMMENT_ONLY='^[0-9]+:[[:space:]]*//'

selftest() {
  local stream="$1" label="$2" ere="$3" sample text want rc
  shift 3
  for sample in "$@"; do
    case "$sample" in
      +*) want=hit ;;
      -*) want=miss ;;
      *) block "review-gate self-test: '$label' has a sample with no +/- prefix: $sample"; continue ;;
    esac
    text="${sample#?}"
    case "$stream" in
      code) printf '1:%s\n' "$text" | grep -v -E "$COMMENT_ONLY" | grep -q -E -e "$ere" 2>/dev/null ;;
      raw)  printf '1:%s\n' "$text" | grep -q -E -e "$ere" 2>/dev/null ;;
      cred) printf 'x.dart:1:%s\n' "$text" | grep -q -i -E -e "$ere" 2>/dev/null ;;
    esac
    rc=$?
    if [ $rc -gt 1 ]; then
      block "review-gate self-test: the '$label' pattern does not compile here (grep exit $rc) — that check cannot run"
      return
    fi
    if [ "$want" = hit ] && [ $rc -ne 0 ]; then
      block "review-gate self-test: '$label' no longer catches its known violation: $text"
    elif [ "$want" = miss ] && [ $rc -eq 0 ]; then
      block "review-gate self-test: '$label' now flags a line it must leave alone: $text"
    fi
  done
}

# selftest_fn <label> <function> <sample>... — the same contract for a check
# written as a shell function instead of a regex.
selftest_fn() {
  local label="$1" fn="$2" sample arg got
  shift 2
  for sample in "$@"; do
    arg="${sample#?}"
    if "$fn" "$arg" >/dev/null; then got=hit; else got=miss; fi
    case "$sample" in
      +*) [ "$got" = hit ]  || block "review-gate self-test: '$label' no longer catches: $arg" ;;
      -*) [ "$got" = miss ] || block "review-gate self-test: '$label' now flags: $arg" ;;
    esac
  done
}

# ---- BLOCKING, ratcheted (see ratchet())

# The leading boundary keeps `StatusColors.forState(` and friends out.
P_COLOUR='(^|[^A-Za-z0-9_])(Color\(0x|Colors\.[a-zA-Z])'
selftest code 'raw colour literal' "$P_COLOUR" \
  '+      color: Color(0xFFAABBCC),' \
  '+    final shade = Colors.red;' \
  '-      color: ColorsManager.primary,' \
  '-      color: context.colors.surfaceRaised,' \
  '-      color: StatusColors.forState(task.status),' \
  '-  // color: Color(0xFFAABBCC),'

P_PRINT='(^|[^A-Za-z0-9_.])print\('
selftest code 'bare print()' "$P_PRINT" \
  "+    print('rendering');" \
  "-    debugPrint('rendering');" \
  "-    logger.print('rendering');"

P_LR_PADDING='EdgeInsets\.only\([^)]*(left|right)[[:space:]]*:'
selftest code 'physical left/right padding' "$P_LR_PADDING" \
  '+      padding: EdgeInsets.only(left: 16, right: 8),' \
  '-      padding: EdgeInsetsDirectional.only(start: 16),' \
  '-      padding: EdgeInsets.only(top: 8),'

P_LTRB='EdgeInsets\.fromLTRB\('
selftest code 'EdgeInsets.fromLTRB' "$P_LTRB" \
  '+      padding: EdgeInsets.fromLTRB(1, 2, 3, 4),' \
  '-      padding: EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),'

P_TEXT_DIRECTION='TextDirection\.(ltr|rtl)([^A-Za-z0-9_]|$)'
selftest code 'hard-coded TextDirection' "$P_TEXT_DIRECTION" \
  '+      textDirection: TextDirection.ltr,' \
  '-    final direction = Directionality.of(context);'

P_SCREENUTIL='[0-9)]\.(sp|w|h|r|sw|sh)([^A-Za-z0-9_]|$)'
selftest code 'flutter_screenutil sizing' "$P_SCREENUTIL" \
  '+      height: 12.h,' \
  '+      fontSize: 14.sp,' \
  '-    final width = size.width;' \
  '-      width: MediaQuery.sizeOf(context).width * 0.5,'

P_LAUNCH_URL='(^|[^A-Za-z0-9_])launchUrl\('
selftest code 'launchUrl called directly' "$P_LAUNCH_URL" \
  '+    await launchUrl(uri);' \
  '-    await _fileSystem.open(path);' \
  '-    if (await canLaunchUrl(uri)) {'

# A hand-rolled style drops the app font and the size ladder (CLAUDE.md »
# Text styles go through Styles). `DefaultTextStyle(` and a `TextStyle?` type
# annotation are not constructions and stay out.
P_TEXT_STYLE='(^|[^A-Za-z0-9_])TextStyle\('
selftest code 'bare TextStyle' "$P_TEXT_STYLE" \
  '+      style: TextStyle(fontSize: 14),' \
  '+      style: const TextStyle(color: shade),' \
  '-    return DefaultTextStyle(style: style, child: child);' \
  '-  final TextStyle? titleStyle;' \
  '-      style: Styles.font14Bold.copyWith(color: context.colors.textPrimary),'

P_FONT_WEIGHT='FontWeight\.(w[1-9]00|bold|normal)'
selftest code 'raw FontWeight' "$P_FONT_WEIGHT" \
  '+      fontWeight: FontWeight.w600,' \
  '+      style: base.copyWith(fontWeight: FontWeight.bold),' \
  '-      fontWeight: FontWeightHelper.semiBold,'

# ---- BLOCKING, not ratcheted

# The typed Result makes a raw `failure(e.toString())` a compile error; building
# an AppFailure from the exception text outside FailureMapper is the one way left
# (download-errors skill). The mapper itself is exempt — it is the one place.
P_ERROR_TEXT='AppFailure(\.[a-zA-Z]+)?\([^)]*(toString\(\)|\$e([^A-Za-z0-9_]|$)|\$\{e)'
selftest code 'exception text built into a failure' "$P_ERROR_TEXT" \
  '+      AppFailure(type: FailureType.unknown, debug: e.toString()),' \
  "+      AppFailure(type: FailureType.unknown, debug: 'Failed: \$e')," \
  '-      AppFailure(type: FailureType.storageFull),' \
  '-      Result.failure(FailureMapper.map(e, s)),'

# Clean Architecture (codebase-conventions skill): domain/ is pure Dart and
# logic/ talks to contracts only. Applied to files under */domain/* and
# */logic/* respectively, BLOCKING and not ratcheted — the repo starts clean.
P_DOMAIN_IMPURE="import '(dart:(io|ui)|package:(flutter|drift|youtube_explode_dart|ffmpeg_kit_[a-z_]+|background_downloader|path_provider|file_picker|share_plus|url_launcher)/|package:tube_downloader/.*/(data|logic|presentation)/)"
selftest code 'domain importing a framework / outer layer' "$P_DOMAIN_IMPURE" \
  "+import 'package:flutter/material.dart';" \
  "+import 'package:drift/drift.dart';" \
  "+import 'dart:io';" \
  "+import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';" \
  "-import 'package:freezed_annotation/freezed_annotation.dart';" \
  "-import 'package:tube_downloader/core/error/result.dart';" \
  "-import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';"

P_LOGIC_TO_DATA="import '(dart:io|package:(drift|youtube_explode_dart|ffmpeg_kit_[a-z_]+|background_downloader)/|package:tube_downloader/.*/data/)"
selftest code 'logic importing data / engine packages' "$P_LOGIC_TO_DATA" \
  "+import 'package:tube_downloader/core/download_core/data/repos/download_repo_impl.dart';" \
  "+import 'package:youtube_explode_dart/youtube_explode_dart.dart';" \
  "-import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';" \
  "-import 'package:flutter_bloc/flutter_bloc.dart';"

# ---- WORTH FIXING

# Sizes, speeds, percentages and durations go through formatters.dart, which
# also bidi-isolates them for Arabic (rtl-a11y skill).
P_HAND_FORMAT='toStringAsFixed\('
selftest code 'hand-formatted number' "$P_HAND_FORMAT" \
  '+      Text(megabytes.toStringAsFixed(1)),' \
  '-      Text(formatBytes(context, bytes)),'

P_SIZEDBOX_SPACER='SizedBox\([[:space:]]*(height|width)[[:space:]]*:'
selftest code 'SizedBox spacer' "$P_SIZEDBOX_SPACER" \
  '+      const SizedBox(height: 8),' \
  '-      verticalSpace(8),'

P_PHYSICAL_ALIGN='Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)'
selftest code 'physical Alignment' "$P_PHYSICAL_ALIGN" \
  '+      alignment: Alignment.centerLeft,' \
  '-      alignment: AlignmentDirectional.centerStart,'

P_MULTI_BLOC='(^|[^A-Za-z0-9_])MultiBlocProvider'
selftest code 'MultiBlocProvider' "$P_MULTI_BLOC" \
  '+    return MultiBlocProvider(' \
  '-    return BlocProvider('

P_HAND_ERROR='(showErrorSnackBar|showSnackBar|ErrorDialog\.show)\(.*(failureMessage\(|\.debug)'
selftest code 'failure shown by hand' "$P_HAND_ERROR" \
  '+      showErrorSnackBar(context, failureMessage(context, failure));' \
  '+      messenger.showSnackBar(SnackBar(content: Text(failure.debug ?? "")));' \
  '-      showFailureSnackBar(context, failure);'

P_FROM_JSON='fromJson\(Map<String, dynamic> json\)'
selftest code 'fromJson factory' "$P_FROM_JSON" \
  '+  factory Foo.fromJson(Map<String, dynamic> json) {' \
  '-  Map<String, dynamic> toJson() => _$FooToJson(this);'

P_CORE_TO_FEATURE="import 'package:tube_downloader/features/"
selftest code 'lib/core importing a feature' "$P_CORE_TO_FEATURE" \
  "+import 'package:tube_downloader/features/library/presentation/screens/library_screen.dart';" \
  "-import 'package:tube_downloader/core/theme/styles.dart';"

# ---- NOTES

# Scanned over the RAW stream: a TODO is almost always a comment-only line,
# which the code stream drops.
P_TODO='(TODO|FIXME)'
selftest raw 'TODO/FIXME' "$P_TODO" \
  '+  // TODO(queue): honour the Wi-Fi gate' \
  '+    reload(); // FIXME' \
  '-    final todoList = <String>[];'

P_BUILD_HELPER='Widget _build[A-Za-z0-9_]*\('
selftest code '_buildX() helper' "$P_BUILD_HELPER" \
  '+  Widget _buildHeader(BuildContext context) {' \
  '-  Widget build(BuildContext context) {'

P_SET_STATE='(^|[^A-Za-z0-9_])setState\('
selftest code 'setState' "$P_SET_STATE" \
  '+    setState(() => _expanded = !_expanded);' \
  '-    _refreshState();'

# ---- credentials (every changed file — section 3)
#
# Case-insensitive, and never anchored at the line start: the scan reads
# "path:lineno:text". Five shapes, each with its own sample below:
#   named  a secret-sounding name assigned a quoted literal of 17+ characters
#          that carries a digit (localization keys and field names don't)
#   b64    a 32- or 64-byte base64 literal — the shape of the Ed25519 keys in .env
#   pem    a private-key header, also inside a JSON service-account file
#   url    credentials embedded in a URL (scheme://user:secret@host)
#   env    KEY=value assignments, as in a committed .env or shell script
P_SECRET_VALUE='([a-z0-9_/+=.-]{16,}[0-9][a-z0-9_/+=.-]*|[a-z0-9_/+=.-]*[0-9][a-z0-9_/+=.-]{16,})'
P_SECRET_NAMED="(api[_-]?key|secret|passw(or)?d|private[_-]?key|access[_-]?token|auth[_-]?token|user[_-]?token|refresh[_-]?token)[a-z0-9_]*['\"]?[[:space:]]*(=>|[:=])[[:space:]]*['\"]${P_SECRET_VALUE}['\"]"
P_SECRET_B64="['\"]([a-z0-9+/]{43}=|[a-z0-9+/]{86}==)['\"]"
P_SECRET_PEM='-----begin [a-z ]*private key-----'
P_SECRET_URL="[a-z][a-z0-9+.-]*://[^[:space:]'\"/@:]+:[^[:space:]'\"/@]+@"
P_SECRET_ENV="(key|secret|token|password)[a-z0-9_]*=[^[:space:]'\"\$]{16,}"
P_SECRET="${P_SECRET_NAMED}|${P_SECRET_B64}|${P_SECRET_PEM}|${P_SECRET_URL}|${P_SECRET_ENV}"
selftest cred 'committed credential' "$P_SECRET" \
  "+    final apiKey = 'sk_live_abcdef0123456789';" \
  '+  "client_secret": "a1b2c3d4e5f6a7b8c9d0e1f2",' \
  "+    headers: {'auth_token': 'e3b0c44298fc1c149afbf4c8996fb924'}," \
  "+  static const seed = 'q3MFnkW7x1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r=';" \
  '+-----BEGIN OPENSSH PRIVATE KEY-----' \
  '+  url: https://ci-bot:hunter2secret@example.com/repo.git' \
  '+SIGNING_KEY=q3MFnkW7x1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r=' \
  '-      password: passwordController.text,' \
  "-    'auth_token': token," \
  "-    final key = Platform.environment['SIGNING_KEY'] ?? '';" \
  "-      Text(context.l10n.settingsFileNameTemplate)," \
  "-  static const passwordKey = 'SavedCredentialsPassword';" \
  "-    'Authorization': 'Bearer \$token'," \
  "-    final uri = url.replace(queryParameters: {'range': '\$start-\$end'});" \
  "-  static const playerApi = 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false';" \
  '-  sha256: "5f5bd9d4bd5e5fd2ab27ae8b1bff4f1e5d6c8f8bb2d4d1b3a1e1c0e3c6a7c9f1"'

# Files that hold keys whatever their content. android/.gitignore already
# ignores key.properties and *.jks, so this fires on a force-add or a key
# saved somewhere new. A .pem is left to the content scan: it is as often a
# public certificate as a private key.
is_secret_file() {
  case "$1" in
    *.env.example|*.env.sample|*.env.template) return 1 ;;
    .env|*/.env|.env.*|*/.env.*) return 0 ;;
    key.properties|*/key.properties) return 0 ;;
    *.jks|*.keystore|*.p8|*.p12|*.pfx) return 0 ;;
    id_rsa|*/id_rsa|id_ecdsa|*/id_ecdsa|id_ed25519|*/id_ed25519) return 0 ;;
  esac
  return 1
}
selftest_fn 'key/credential file name' is_secret_file \
  '+.env' '+.env.production' '+android/key.properties' '+android/app/upload-keystore.jks' '+ios/AuthKey_ABC123.p8' \
  '-.env.example' '-lib/core/app_env.dart' '-assets/images/key.png' '-docs/environment.md'

# ---- dependencies (section 4)

# CLAUDE.md » Library conventions: the packages that compete with a house
# choice. Prints why, so the finding carries its own fix.
banned_reason() {
  case "$1" in
    equatable) echo 'cubit states and entities are freezed, which already give value equality' ;;
    dartz|fpdart) echo 'results are the freezed Result<T> union (lib/core/error/)' ;;
    lottie|rive|rive_*) echo 'animations go through flutter_animate' ;;
    riverpod|flutter_riverpod|hooks_riverpod|provider|get|mobx|flutter_hooks) echo 'state is flutter_bloc Cubits, DI is get_it' ;;
    flutter_screenutil) echo 'sizing comes from MediaQuery.sizeOf / LayoutBuilder (adaptive-layout skill)' ;;
    dio|retrofit|http) echo 'there is no backend; the transport uses dart:io HttpClient behind MediaTransport' ;;
    isar|isar_community|hive|hive_ce|sqflite|objectbox|shared_preferences) echo 'persistence (queue, library and settings) is drift' ;;
    ffmpeg_kit_flutter|ffmpeg_kit_flutter_full|ffmpeg_kit_flutter_min|ffmpeg_kit_flutter_new|ffmpeg_kit_flutter_new_full|*_gpl) echo 'FFmpeg is ffmpeg_kit_flutter_new_audio (LGPL, has lame) — the retired or GPL builds change the licence or do not build' ;;
    webview_flutter|webview_flutter_*) echo 'links and files open through FileSystemGateway / url_launcher' ;;
    *) return 1 ;;
  esac
}
selftest_fn 'banned-package list' banned_reason \
  '+equatable' '+dartz' '+lottie' '+rive' '+flutter_riverpod' '+flutter_screenutil' '+dio' '+isar' \
  '+shared_preferences' '+ffmpeg_kit_flutter' '+ffmpeg_kit_flutter_new' '+ffmpeg_kit_flutter_new_https_gpl' '+webview_flutter_android' \
  '-flutter_animate' '-flutter_bloc' '-drift' '-youtube_explode_dart' '-ffmpeg_kit_flutter_new_audio' '-get_it'

# Package names under dependencies / dev_dependencies / dependency_overrides:
# the two-space keys of those top-level blocks, nothing nested, no comments.
dep_names() {
  awk '
    /^[^[:space:]#]/ { block = $0; sub(/:.*/, "", block); next }
    block ~ /^(dependencies|dev_dependencies|dependency_overrides)$/ && /^  [A-Za-z0-9_]+:/ {
      name = $1; sub(/:.*/, "", name); print name
    }'
}
DEP_FIXTURE='name: probe
environment:
  sdk: ^3.9.2
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0
  # lottie: ^3.0.0
  archive: ^4.0.2
dev_dependencies:
  build_runner: ^2.0.0
dependency_overrides:
  path: 1.9.0
flutter:
  uses-material-design: true
  assets:
    - assets/images/'
DEP_GOT="$(printf '%s\n' "$DEP_FIXTURE" | dep_names | LC_ALL=C sort | tr '\n' ' ')"
if [ "$DEP_GOT" != "archive build_runner dio flutter path " ]; then
  block "review-gate self-test: the pubspec dependency parser read [$DEP_GOT] from its fixture, expected [archive build_runner dio flutter path ]"
fi

# ------------------------------------------------------------------ file set
FILES="$TMP/files"
MERGE_BASE=""
if [ "$MODE" = "all" ]; then
  git ls-files -- 'lib/*.dart' 'test/*.dart' > "$FILES.raw"
else
  MERGE_BASE="$(git merge-base HEAD "$BASE_REF" 2>/dev/null)" || {
    echo "review-gate: cannot resolve merge-base with '$BASE_REF' — try --base <ref> or git fetch" >&2; exit 2; }
  {
    git diff --name-only --diff-filter=ACMR "$MERGE_BASE" -- '*.dart'   # committed + staged + unstaged
    git ls-files --others --exclude-standard -- '*.dart'              # untracked
  } | sort -u > "$FILES.raw"
fi

# A moved file must be compared with where it came FROM, or every legacy line in
# it reads as added and blocks. new path <TAB> old path, one per rename.
RENAMES="$TMP/renames"
: > "$RENAMES"
if [ "$MODE" = "diff" ]; then
  git diff -M --name-status --diff-filter=R "$MERGE_BASE" -- '*.dart' \
    | awk -F '\t' '{ print $3 "\t" $2 }' > "$RENAMES"
fi

# The file's path at the merge-base (its old path when it was renamed).
base_path() {
  old="$(awk -F '\t' -v f="$1" '$1 == f { print $2; exit }' "$RENAMES")"
  if [ -n "$old" ]; then printf '%s\n' "$old"; else printf '%s\n' "$1"; fi
}

# True when the file existed at the merge-base, under either path.
in_base() {
  [ -n "$MERGE_BASE" ] && git cat-file -e "$MERGE_BASE:$(base_path "$1")" 2>/dev/null
}

# Generated code is never gated.
grep -v -E '(\.(g|freezed|gr|mocks|config)\.dart|/app_localizations(_[a-z]+)?\.dart)$' "$FILES.raw" | while IFS= read -r f; do
  [ -f "$f" ] && printf '%s\n' "$f"
done > "$FILES"

echo "review-gate: mode=$MODE base=${MERGE_BASE:-n/a} dart-files=$(wc -l < "$FILES" | tr -d ' ')"

# ------------------------------------------------------------------- report
print_section() {
  title="$1"; file="$2"
  count="$(wc -l < "$file" | tr -d ' ')"
  echo
  echo "== $title ($count) =="
  if [ "$count" -eq 0 ]; then echo "  none"; else sed 's/^/  /' "$file"; fi
}

finish() {
  echo
  echo "================ REVIEW GATE ================"
  print_section "BLOCKING"      "$BLOCKING"
  print_section "WORTH FIXING"  "$WORTH"
  print_section "NOTES"         "$NOTES"
  echo
  echo "Still needs a human: failure-path test coverage, whether a device check happened,"
  echo "whether any new dependency was necessary, whether each // ignore: is justified."
  if [ -s "$BLOCKING" ]; then exit 1; fi
  exit 0
}

# ------------------------------------------------------------- 1. credentials
# Every changed file, not only Dart: a key is as leaked from a .yaml, a .plist
# or a shell script. The matched text is never printed — this report is a CI
# log. Carved out: this skill's own folder (the self-test samples above look
# like credentials on purpose).
# A fixture that only LOOKS like a key carries "review-gate: not-a-secret" on
# its line or the line above.
echo "▸ credentials (every changed file, not only Dart)"
SECRET_EXCLUDES_1=':(exclude).claude/skills/review-gate'
SECRET_EXCLUDES_2=':(exclude).claude/skills/review-gate/scripts'
if [ "$MODE" = "all" ]; then
  git grep -I -n -e '' -- . "$SECRET_EXCLUDES_1" "$SECRET_EXCLUDES_2"
else
  # Added lines as "path:lineno:text". File headers are only read between a
  # "diff --git" line and the first hunk, so an added line that happens to
  # start with "++ b/" is still read as content.
  git diff -U0 --no-color --no-ext-diff -M --src-prefix=a/ --dst-prefix=b/ "$MERGE_BASE" \
      -- . "$SECRET_EXCLUDES_1" "$SECRET_EXCLUDES_2" | awk '
    /^diff --git /     { hdr = 1; next }
    hdr && /^\+\+\+ /  { f = (substr($0, 5, 2) == "b/") ? substr($0, 7) : ""; next }
    /^@@/              { hdr = 0; split($3, a, ","); ln = substr(a[1], 2) + 0; next }
    hdr                { next }
    /^\+/              { if (f != "") print f ":" ln ":" substr($0, 2); ln++ }
  '
  git ls-files -z --others --exclude-standard -- . "$SECRET_EXCLUDES_1" "$SECRET_EXCLUDES_2" > "$TMP/untracked"
  if [ -s "$TMP/untracked" ]; then xargs -0 grep -H -I -n -e '' < "$TMP/untracked"; fi
fi | grep -i -E -e "$P_SECRET" > "$TMP/secret_hits"

while IFS= read -r hit; do
  path="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"; text="${rest#*:}"
  case "$text" in *'review-gate: not-a-secret'*) continue ;; esac
  if [ "$ln" -gt 1 ] 2>/dev/null && [ -f "$path" ] \
     && sed -n "$((ln - 1))p" "$path" | grep -q 'review-gate: not-a-secret'; then
    continue
  fi
  block "$path:$ln — looks like a committed credential (line not echoed). Move it to .env / the CI secrets; if it was ever committed, rotate it — deleting the line does not remove it from history"
done < "$TMP/secret_hits"

if [ "$MODE" = "all" ]; then
  git ls-files
else
  git diff --name-only --diff-filter=AR "$MERGE_BASE"
  git ls-files --others --exclude-standard
fi | sort -u | while IFS= read -r p; do
  if is_secret_file "$p"; then
    block "$p — a key/credential file is going into git; keys live only in the gitignored .env and the CI secrets (git rm --cached it, and rotate the key if it was ever pushed)"
  fi
done

# ------------------------------------------------------------ 2. dependencies
# Diff mode: every package that is new since the merge-base — a banned one
# blocks, any other asks for its reason. --all: the whole list against the ban.
echo "▸ pubspec dependencies"
if [ -f pubspec.yaml ]; then
  dep_names < pubspec.yaml | LC_ALL=C sort -u > "$TMP/deps.now"
  if [ "$MODE" = "diff" ]; then
    if git cat-file -e "$MERGE_BASE:pubspec.yaml" 2>/dev/null; then
      git show "$MERGE_BASE:pubspec.yaml" | dep_names | LC_ALL=C sort -u > "$TMP/deps.base"
    else
      : > "$TMP/deps.base"
    fi
    LC_ALL=C comm -13 "$TMP/deps.base" "$TMP/deps.now" > "$TMP/deps.check"
  else
    cp "$TMP/deps.now" "$TMP/deps.check"
  fi
  while IFS= read -r pkg; do
    at="$(grep -n -E "^  $pkg:" pubspec.yaml | head -n 1 | cut -d: -f1)"
    if why="$(banned_reason "$pkg")"; then
      block "pubspec.yaml:$at — '$pkg' is not used in this repo: $why (CLAUDE.md » Library conventions)"
    elif [ "$MODE" = "diff" ]; then
      worth "pubspec.yaml:$at — new dependency '$pkg' — say in the PR why it is needed and that nothing already in pubspec.yaml or the SDK covers it"
    fi
  done < "$TMP/deps.check"
fi

# The two sections above hold for any change; the rest reads Dart only.
if [ ! -s "$FILES" ]; then
  if [ "$MODE" = "all" ]; then echo "review-gate: no .dart files found under lib/ or test/"; else
    echo "review-gate: no .dart files changed vs $BASE_REF — format, analyze and the Dart patterns have nothing to check."; fi
  finish
fi

# Emits "lineno:text" for every line the pattern checks should look at:
# diff mode → lines added since the merge-base (whole file when it is new);
# --all     → every line. Comment-only lines are KEPT here; the loop below
# drops them for the code patterns and keeps them for TODO/FIXME.
scan_lines() {
  f="$1"
  if [ "$MODE" = "all" ] || ! in_base "$f"; then
    awk '{ print NR ":" $0 }' "$f"
  else
    git diff -U0 --no-color -M "$MERGE_BASE" -- "$(base_path "$f")" "$f" | awk '
      /^@@/          { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
      /^\+\+\+ / || /^--- / { next }
      /^\+/          { print ln ":" substr($0, 2); ln++; next }
    '
  fi
}

# ------------------------------------------------------------------ 3. format
echo "▸ dart format"
FMT_OUT="$TMP/fmt"
xargs dart format --output=none --set-exit-if-changed < "$FILES" > "$FMT_OUT" 2>&1
FMT_RC=$?
if [ $FMT_RC -ne 0 ]; then
  grep -E '^Changed ' "$FMT_OUT" | sed 's/^Changed //' | while IFS= read -r f; do
    # The whole tree is dart-formatted from the first commit (CI checks every
    # file), so an unformatted file in the diff is this diff's doing — new file
    # or old. --all is a debt report and never blocks.
    if [ "$MODE" = "diff" ]; then
      block "$f — not dart-formatted (run: dart format $f)"
    else
      worth "$f — not dart-formatted"
    fi
  done
  if ! grep -q -E '^Changed ' "$FMT_OUT"; then
    block "dart format failed to run: $(head -n 3 "$FMT_OUT" | tr '\n' ' ')"
  fi
fi

# ----------------------------------------------------------------- 4. analyze
echo "▸ flutter analyze (whole project; findings filtered to the gated files)"
AN_OUT="$TMP/analyze"
flutter analyze --no-pub > "$AN_OUT" 2>&1
if ! grep -q -E 'Analyzing|No issues found|issue[s]? found' "$AN_OUT"; then
  block "flutter analyze did not run: $(head -n 3 "$AN_OUT" | tr '\n' ' ')"
fi
# Lines look like:  "  error • message • lib/x.dart:12:5 • rule_name"
grep -E '^[[:space:]]*(error|warning|info) • ' "$AN_OUT" | while IFS= read -r line; do
  sev="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*(error|warning|info) • .*/\1/')"
  msg="$(printf '%s' "$line" | awk -F ' • ' '{ print $2 }')"
  loc="$(printf '%s' "$line" | awk -F ' • ' '{ print $3 }')"
  rule="$(printf '%s' "$line" | awk -F ' • ' '{ print $4 }')"
  path="${loc%%:*}"
  if [ "$MODE" = "diff" ] && ! grep -qFx "$path" "$FILES"; then continue; fi
  case "$sev" in
    error)   block "$loc — $msg ($rule)" ;;
    warning) worth "$loc — $msg ($rule)" ;;
    *)       note  "$loc — $msg ($rule)" ;;
  esac
done

# ---------------------------------------------------------------- 5. patterns
echo "▸ house patterns ($([ "$MODE" = "diff" ] && echo 'added lines only' || echo 'whole files'))"

# report <sink> <ERE> <message> [lines-file] — greps the current $LINES stream
# (or the given one) and reports each hit.
report() {
  grep -E "$2" "${4:-$LINES}" | while IFS= read -r hit; do
    "$1" "$f:${hit%%:*} — $3"
  done
}

# Occurrences of <ERE> in the source on stdin, comment-only lines excluded.
# Counts OCCURRENCES, not lines: a call the formatter splits across three lines
# still holds the same number of violations.
count_hits() {
  grep -v -E '^[[:space:]]*//' | grep -o -E "$1" | wc -l | tr -d ' '
}

# ratchet <ERE> <message> — how every BLOCKING house pattern reports. In diff
# mode a hit blocks only when the file now holds MORE occurrences than it did at
# the merge-base; otherwise the changed line merely carries an old violation
# along (a reflow, an RTL fix, a rename) and is reported as WORTH FIXING. The
# trade-off, accepted: removing one violation and adding another in the same
# file nets to zero and does not block.
ratchet() {
  HITS="$TMP/hits"
  grep -E "$1" "$LINES" > "$HITS"
  [ -s "$HITS" ] || return 0
  sink=block
  why=""
  if [ "$MODE" = "diff" ] && in_base "$f"; then
    before="$(git show "$MERGE_BASE:$(base_path "$f")" | count_hits "$1")"
    after="$(count_hits "$1" < "$f")"
    if [ "$after" -le "$before" ]; then
      sink=worth
      why=" [legacy — a changed line carries it; the file's count did not grow: $before → $after]"
    else
      why=" [the file's count grew: $before → $after]"
    fi
  fi
  while IFS= read -r hit; do
    "$sink" "$f:${hit%%:*} — $2$why"
  done < "$HITS"
}

while IFS= read -r f; do
  RAW="$TMP/raw"; LINES="$TMP/lines"
  scan_lines "$f" > "$RAW"
  [ -s "$RAW" ] || continue
  grep -v -E "$COMMENT_ONLY" "$RAW" > "$LINES"

  case "$f" in
    lib/*)
      # ---- BLOCKING (ratcheted — see ratchet())
      case "$f" in
        lib/core/theme/colors_manager.dart) ;;
        *) ratchet "$P_COLOUR" 'raw colour literal — add it to ColorsManager (semantic name) or use context.colors.<token>' ;;
      esac
      ratchet "$P_PRINT" 'bare print() — use debugPrint; the flavour gate mutes it centrally'
      ratchet "$P_LR_PADDING" 'physical left/right padding — EdgeInsetsDirectional.only(start:/end:)'
      ratchet "$P_LTRB" 'EdgeInsets.fromLTRB is physical — EdgeInsetsDirectional.fromSTEB'
      case "$f" in
        # LtrText is the one sanctioned LTR island (URLs, file paths) — rtl-a11y skill.
        lib/core/widgets/ltr_text.dart) ;;
        *) ratchet "$P_TEXT_DIRECTION" 'hard-coded TextDirection — the locale owns direction; use LtrText for URLs/paths, read Directionality.of(context) only to decide' ;;
      esac
      ratchet "$P_SCREENUTIL" 'flutter_screenutil sizing in new code — size from MediaQuery.sizeOf / LayoutBuilder'
      case "$f" in
        lib/core/download_core/data/platform/*) ;;
        *) ratchet "$P_LAUNCH_URL" 'launchUrl called directly — open files/links through FileSystemGateway (open / reveal)' ;;
      esac
      # The style ladder itself (styles.dart, font_weight_helper.dart) is the
      # one place a TextStyle / FontWeight is built.
      case "$f" in
        lib/core/theme/*) ;;
        *) ratchet "$P_TEXT_STYLE" 'bare TextStyle — take a Styles.font<size><Weight> rung and .copyWith(color: context.colors.x); add a missing rung to styles.dart'
           ratchet "$P_FONT_WEIGHT" 'raw FontWeight — FontWeightHelper.<weight>, or a Styles rung that already carries it' ;;
      esac
      case "$f" in
        lib/core/error/failure_mapper.dart) ;;
        *) report block "$P_ERROR_TEXT" 'exception text built into an AppFailure — Result.failure(FailureMapper.map(e, s)) (download-errors skill)' ;;
      esac
      case "$f" in
        */domain/*) report block "$P_DOMAIN_IMPURE" 'domain/ must stay pure Dart — no Flutter, dart:io, drift, plugins or outer layers; depend on a contract instead (codebase-conventions skill)' ;;
        */logic/*)  report block "$P_LOGIC_TO_DATA" 'logic/ depends on domain contracts and use cases only — inject the repo contract, never an Impl, drift, dart:io or an engine package' ;;
      esac

      # ---- WORTH FIXING
      case "$f" in
        lib/core/helpers/formatters.dart) ;;
        *) report worth "$P_HAND_FORMAT" 'number formatted by hand — formatters.dart (formatBytes / formatSpeed / formatPercent / formatDuration) also bidi-isolates it' ;;
      esac
      report worth "$P_SIZEDBOX_SPACER" 'SizedBox spacer — verticalSpace()/horizontalSpace() from spacing.dart'
      report worth "$P_PHYSICAL_ALIGN" 'physical Alignment — AlignmentDirectional'
      report worth "$P_MULTI_BLOC" 'MultiBlocProvider — scope one BlocProvider at the smallest subtree that needs it'
      case "$f" in
        lib/core/helpers/failure_presenter.dart) ;;
        *) report worth "$P_HAND_ERROR" 'failure shown by hand — showFailureSnackBar / showFailureDialog (silent for cancelled, de-duplicated)' ;;
      esac
      grep -E "$P_FROM_JSON" "$LINES" | grep -v '_\$' | while IFS= read -r hit; do
        ln="${hit%%:*}"
        case "$(sed -n "$((ln + 1))p" "$f")" in
          *'_$'*) continue ;;
        esac
        worth "$f:$ln — hand-rolled fromJson — use json_serializable (@JsonSerializable + build_runner)"
      done
      case "$f" in
        # The composition roots wire features together; that is their job.
        lib/core/di/*|lib/core/router/*) ;;
        lib/core/*) report worth "$P_CORE_TO_FEATURE" 'lib/core importing feature code — core must not depend on features (only di/ and router/ may)' ;;
      esac

      # ---- NOTES
      report note "$P_TODO" 'TODO/FIXME added' "$RAW"
      report note "$P_BUILD_HELPER" 'helper method builds a subtree — prefer an extracted widget class (performance skill)'
      report note "$P_SET_STATE" 'setState — fine for purely local UI state only'
      ;;
  esac

  # Cubit liveness is a file-level property: a cubit that awaits and emits with
  # no isClosed anywhere has no guard on any path (state-safety skill).
  case "$f" in
    lib/*cubit*.dart)
      if grep -q 'await ' "$f" && grep -q 'emit(' "$f" && ! grep -q 'isClosed' "$f"; then
        worth "$f — awaits then emits with no isClosed guard anywhere in the file (state-safety skill)"
      fi ;;
  esac
done < "$FILES"

# ------------------------------------------------------------------- 6. tests
if [ $RUN_TESTS -eq 1 ]; then
  # Golden bytes come from the host's font rasterizer and are recorded on
  # macOS; anywhere else they fail on anti-aliasing alone (dart_test.yaml).
  TEST_ARGS=""
  [ "$(uname -s)" = Darwin ] || TEST_ARGS="--exclude-tags golden"
  echo "▸ flutter test ${TEST_ARGS}"
  # shellcheck disable=SC2086  # TEST_ARGS is deliberately word-split
  if ! flutter test $TEST_ARGS > "$TMP/test" 2>&1; then
    block "flutter test failed — $(grep -E '^[0-9:+ -]+.*\[E\]|Some tests failed' "$TMP/test" | head -n 5 | tr '\n' ' ')"
    tail -n 40 "$TMP/test"
  fi
fi

finish
