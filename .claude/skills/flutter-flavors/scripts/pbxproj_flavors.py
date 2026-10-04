#!/usr/bin/env python3
"""Flavour edits for a Flutter app's iOS Runner target, made surgically.

project.pbxproj is an old-style plist that Xcode writes in a fixed layout.
This edits it as text and touches only the lines it means to, so the diff
stays reviewable and Xcode keeps the file as-is. Every write is checked with
`plutil -lint` and rolled back if the result does not parse.

Usage (from anywhere inside the Flutter project):
  pbxproj_flavors.py show
  pbxproj_flavors.py set   <Configuration> KEY=VALUE [KEY=VALUE ...]
  pbxproj_flavors.py unset <Configuration> KEY [KEY ...]
  pbxproj_flavors.py add-guard [--configuration Release-production]
                               [--entry main_prod.dart] [--flavor production]
  pbxproj_flavors.py scheme <scheme-name> Action=Configuration [...]
        Action: Test, Launch, Profile, Analyze or Archive

Options (before the command):
  --pbxproj FILE   default <git root>/ios/Runner.xcodeproj/project.pbxproj
  --target NAME    the app target, default Runner

`set` / `unset` change TARGET-level build settings of one configuration of the
app target — the level that beats Flutter's Generated.xcconfig.
"""
import argparse
import os
import random
import re
import subprocess
import sys

GUARD_NAME = "Archive Only Production"
SHOW_KEYS = ["FLUTTER_TARGET", "FLAVOR", "PRODUCT_BUNDLE_IDENTIFIER",
             "APP_DISPLAY_NAME", "PRODUCT_NAME", "IPHONEOS_DEPLOYMENT_TARGET"]
SCHEME_ACTIONS = ["Test", "Launch", "Profile", "Analyze", "Archive"]
KEY_LINE = re.compile(r'^\t\t\t\t("?)(.+?)\1 = ')


def die(msg):
    sys.exit(f"error: {msg}")


def project_root():
    try:
        return subprocess.check_output(["git", "rev-parse", "--show-toplevel"],
                                       stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return os.getcwd()


def pbx_quote(value):
    """Quote like Xcode does: bare only for plain word/path characters."""
    if re.fullmatch(r"[A-Za-z0-9_./]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def pbx_unquote(raw):
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return raw[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    return raw


class Project:
    def __init__(self, path, target):
        self.path = path
        self.target = target
        with open(path) as f:
            self.text = f.read()
        self.original = self.text

    # --- locating objects ---------------------------------------------------
    def target_block(self):
        m = re.search(r"\t\t([0-9A-F]{24}) /\* " + re.escape(self.target) +
                      r" \*/ = \{\n\t\t\tisa = PBXNativeTarget;.*?\n\t\t\};",
                      self.text, re.S)
        if not m:
            die(f"no native target named {self.target!r} in {self.path}")
        return m

    def configurations(self):
        """[(id, name)] of the app target's build configurations, in order."""
        list_id = re.search(r"buildConfigurationList = ([0-9A-F]{24})",
                            self.target_block().group(0)).group(1)
        m = re.search(r"\t\t" + list_id + r" /\* .*? \*/ = \{\n\t\t\tisa = XCConfigurationList;"
                      r"\n\t\t\tbuildConfigurations = \((.*?)\);", self.text, re.S)
        return re.findall(r"([0-9A-F]{24}) /\* (.+?) \*/", m.group(1))

    def config_block(self, name):
        for cid, cname in self.configurations():
            if cname == name:
                m = re.search(r"\t\t" + cid + r" /\* " + re.escape(name) +
                              r" \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};",
                              self.text, re.S)
                return m
        names = ", ".join(n for _, n in self.configurations())
        die(f"target {self.target} has no configuration {name!r} (has: {names})")

    @staticmethod
    def settings_span(block_text):
        m = re.search(r"\t\t\tbuildSettings = \{\n(.*?)\n\t\t\t\};", block_text, re.S)
        if not m:
            die("configuration has no buildSettings block")
        return m

    def settings(self, name):
        """{KEY: value} of the target-level, single-line settings."""
        body = self.settings_span(self.config_block(name).group(0)).group(1)
        out = {}
        for line in body.split("\n"):
            k = KEY_LINE.match(line)
            if k and line.rstrip().endswith(";"):
                out[k.group(2)] = pbx_unquote(line.split(" = ", 1)[1].rstrip()[:-1])
        return out

    # --- edits ----------------------------------------------------------------
    def _rewrite_settings(self, name, edit):
        block = self.config_block(name)
        span = self.settings_span(block.group(0))
        lines = span.group(1).split("\n")
        lines = edit(lines)
        new_block = (block.group(0)[:span.start(1)] + "\n".join(lines) +
                     block.group(0)[span.end(1):])
        self.text = self.text[:block.start()] + new_block + self.text[block.end():]

    def set(self, name, key, value):
        key_txt = key if re.fullmatch(r"[A-Za-z0-9_]+", key) else f'"{key}"'
        new_line = f"\t\t\t\t{key_txt} = {pbx_quote(value)};"

        def edit(lines):
            for i, line in enumerate(lines):
                k = KEY_LINE.match(line)
                if k and k.group(2) == key:
                    if not line.rstrip().endswith(";"):
                        die(f"{key} in {name} is a multi-line value; edit it in Xcode")
                    lines[i] = new_line
                    return lines
            # Xcode keeps keys sorted by their unquoted name: insert in place.
            for i, line in enumerate(lines):
                k = KEY_LINE.match(line)
                if k and k.group(2) > key:
                    lines.insert(i, new_line)
                    return lines
            lines.append(new_line)
            return lines
        self._rewrite_settings(name, edit)

    def unset(self, name, key):
        def edit(lines):
            keep = []
            for line in lines:
                k = KEY_LINE.match(line)
                if k and k.group(2) == key:
                    if not line.rstrip().endswith(";"):
                        die(f"{key} in {name} is a multi-line value; edit it in Xcode")
                    continue
                keep.append(line)
            return keep
        self._rewrite_settings(name, edit)

    def add_guard(self, script):
        escaped = script.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        existing = re.search(r'(\t\t[0-9A-F]{24} /\* ' + GUARD_NAME +
                             r' \*/ = \{.*?\n\t\t\tshellScript = ")(.*?)(";\n)', self.text, re.S)
        if existing:
            self.text = (self.text[:existing.start(2)] + escaped + self.text[existing.end(2):])
            return "updated the existing phase's script"
        marker = "/* Begin PBXShellScriptBuildPhase section */\n"
        if marker not in self.text:
            die("no PBXShellScriptBuildPhase section (not a standard Flutter project?)")
        while True:
            new_id = "".join(random.choice("0123456789ABCDEF") for _ in range(24))
            if new_id not in self.text:
                break
        phase = (f"\t\t{new_id} /* {GUARD_NAME} */ = {{\n"
                 "\t\t\tisa = PBXShellScriptBuildPhase;\n"
                 "\t\t\talwaysOutOfDate = 1;\n"
                 "\t\t\tbuildActionMask = 2147483647;\n"
                 "\t\t\tfiles = (\n\t\t\t);\n"
                 "\t\t\tinputPaths = (\n\t\t\t);\n"
                 f'\t\t\tname = "{GUARD_NAME}";\n'
                 "\t\t\toutputPaths = (\n\t\t\t);\n"
                 "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
                 "\t\t\tshellPath = /bin/sh;\n"
                 f'\t\t\tshellScript = "{escaped}";\n'
                 "\t\t};\n")
        self.text = self.text.replace(marker, marker + phase, 1)
        tb = self.target_block()
        block = tb.group(0)
        if "\t\t\tbuildPhases = (\n" not in block:
            die(f"target {self.target} has no buildPhases list")
        block = block.replace("\t\t\tbuildPhases = (\n",
                              f"\t\t\tbuildPhases = (\n\t\t\t\t{new_id} /* {GUARD_NAME} */,\n", 1)
        self.text = self.text[:tb.start()] + block + self.text[tb.end():]
        return f"added as the first build phase of {self.target} ({new_id})"

    def save(self):
        if self.text == self.original:
            print("no change")
            return
        with open(self.path, "w") as f:
            f.write(self.text)
        lint = subprocess.run(["plutil", "-lint", self.path], capture_output=True, text=True)
        if lint.returncode != 0:
            with open(self.path, "w") as f:
                f.write(self.original)
            die("result failed plutil -lint; file restored:\n" + lint.stdout + lint.stderr)
        print(f"saved {self.path} (plutil -lint OK)")


def guard_script(configuration, entry, flavor):
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "archive-guard.sh")) as f:
        text = f.read()
    body = text.split("# ----- phase script below -----\n", 1)[1]
    body = re.sub(r'^PROD_CONFIGURATION=".*"$', f'PROD_CONFIGURATION="{configuration}"', body, flags=re.M)
    body = re.sub(r'^PROD_ENTRY=".*"$', f'PROD_ENTRY="{entry}"', body, flags=re.M)
    body = re.sub(r'^PROD_FLAVOR=".*"$', f'PROD_FLAVOR="{flavor}"', body, flags=re.M)
    header = ("# Archive Only Production: TestFlight / the App Store get the production\n"
              "# release only. Installed from the flutter-ios-flavors skill.\n")
    return header + body


def cmd_show(p):
    configs = p.configurations()
    width = max(len(n) for _, n in configs) + 2
    print(f"Target {p.target}: TARGET-level settings ('-' = not set here, inherited "
          "from the xcconfig / project level)")
    print("".ljust(width) + "  ".join(k.ljust(26) for k in SHOW_KEYS))
    for _, name in configs:
        s = p.settings(name)
        print(name.ljust(width) + "  ".join(s.get(k, "-").ljust(26) for k in SHOW_KEYS))
    phases = re.search(r"buildPhases = \((.*?)\);", p.target_block().group(0), re.S).group(1)
    names = re.findall(r"/\* (.+?) \*/", phases)
    print("\nBuild phases, in order: " + " > ".join(names))
    print(f"Archive guard: {'present' if GUARD_NAME in names else 'MISSING'}"
          + (" (first)" if names and names[0] == GUARD_NAME else ""))


def cmd_scheme(root, scheme, pairs):
    path = os.path.join(root, "ios/Runner.xcodeproj/xcshareddata/xcschemes", scheme + ".xcscheme")
    if not os.path.exists(path):
        die(f"no shared scheme {path}")
    with open(path) as f:
        text = original = f.read()
    for pair in pairs:
        action, _, config = pair.partition("=")
        if action not in SCHEME_ACTIONS or not config:
            die(f"bad pair {pair!r}; use Action=Configuration with Action in {SCHEME_ACTIONS}")
        pat = re.compile(r'(<' + action + r'Action\s+buildConfiguration = ")([^"]+)(")')
        if len(pat.findall(text)) != 1:
            die(f"{scheme}: expected exactly one {action}Action")
        text = pat.sub(lambda m: m.group(1) + config + m.group(3), text)
    if text == original:
        print("no change")
        return
    with open(path, "w") as f:
        f.write(text)
    print(f"saved {path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pbxproj")
    ap.add_argument("--target", default="Runner")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("show")
    s = sub.add_parser("set"); s.add_argument("configuration"); s.add_argument("pairs", nargs="+")
    u = sub.add_parser("unset"); u.add_argument("configuration"); u.add_argument("keys", nargs="+")
    g = sub.add_parser("add-guard")
    g.add_argument("--configuration", default="Release-production")
    g.add_argument("--entry", default="main_prod.dart")
    g.add_argument("--flavor", default="production")
    sc = sub.add_parser("scheme"); sc.add_argument("scheme"); sc.add_argument("pairs", nargs="+")
    a = ap.parse_args()

    root = project_root()
    if a.cmd == "scheme":
        return cmd_scheme(root, a.scheme, a.pairs)
    p = Project(a.pbxproj or os.path.join(root, "ios/Runner.xcodeproj/project.pbxproj"), a.target)
    if a.cmd == "show":
        return cmd_show(p)
    if a.cmd == "set":
        for pair in a.pairs:
            key, sep, value = pair.partition("=")
            if not sep:
                die(f"bad pair {pair!r}; use KEY=VALUE")
            p.set(a.configuration, key, value)
    elif a.cmd == "unset":
        for key in a.keys:
            p.unset(a.configuration, key)
    elif a.cmd == "add-guard":
        print(p.add_guard(guard_script(a.configuration, a.entry, a.flavor)))
    p.save()


if __name__ == "__main__":
    main()
