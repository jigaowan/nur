#!/usr/bin/env python3
"""Exercise built module artifacts without changing a nix-darwin installation."""

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import socket
import subprocess
import tempfile
import threading
import time
import unittest
import urllib.request


def run(*args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, **kwargs)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class CaddyTests(unittest.TestCase):
    def test_plist_and_shell_syntax(self):
        plist = plistlib.loads((ARTIFACTS / "caddy.plist").read_bytes())
        self.assertEqual(plist["UserName"], "_caddy")
        self.assertEqual(plist["Umask"], 0o027)
        for name in ("start.sh", "reload.sh", "activation.sh", "activation-no-reload.sh"):
            result = run("/bin/bash", "-n", str(ARTIFACTS / name))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_generated_configurations(self):
        result = run(str(ARTIFACTS / "caddy"), "adapt", "--config", str(ARTIFACTS / "logging.Caddyfile"))
        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(result.stdout)
        self.assertIn("/tmp/caddy test logs/caddy.log", result.stdout)
        hosts = config["apps"]["http"]["servers"]["srv0"]["routes"][0]["match"][0]["host"]
        self.assertEqual(set(hosts), {"primary.test", "alias.test"})
        result = run(str(ARTIFACTS / "caddy"), "validate", "--config", str(ARTIFACTS / "caddy.json"))
        self.assertEqual(result.returncode, 0, result.stderr)
        dns = (ARTIFACTS / "dns.Caddyfile").read_text()
        self.assertIn("{$ACME_TOKEN}", dns)
        self.assertIn("{$DDNS_TOKEN}", dns)
        self.assertIn("versions ipv6", dns)

    def test_activation_decisions(self):
        # Replace only OS entry points to exercise the actual generated shell
        # branches without managing real system services or identities.
        with tempfile.TemporaryDirectory(prefix="caddy-activation-") as directory:
            root = Path(directory)
            log = root / "calls"
            mock = root / "mock"
            mock.write_text('''#!/bin/bash
set -eu
echo "$*" >> "$CALLS"
case "$1" in
  install) exit 0;;
  cmp) exit "$CMP_STATUS";;
  launchctl)
    if [ "$2" = print ]; then
      case "$STATE" in
        running) printf '\\tpid = 123\\n';;
        stopped) echo 'state = not running';;
        absent) exit 1;;
      esac
    fi;;
  reload) exit "$RELOAD_STATUS";;
esac
''')
            mock.chmod(0o755)
            cases = [
                # reload, same plist, state, reload status, expected action, exit
                (True, True, "running", 0, "reload", 0),
                (True, True, "running", 9, "reload", 9),
                (True, True, "stopped", 0, "launchctl kickstart", 0),
                (True, True, "absent", 0, "launchctl load -w", 0),
                (True, False, "running", 0, None, 0),
                (False, True, "running", 0, None, 0),
                (False, True, "stopped", 0, "launchctl kickstart", 0),
            ]
            for enabled, same, state, status, action, expected_exit in cases:
                with self.subTest(enabled=enabled, same=same, state=state, status=status):
                    source = ARTIFACTS / ("activation.sh" if enabled else "activation-no-reload.sh")
                    script = source.read_text()
                    for path, name in (("/usr/bin/install", "install"), ("/usr/bin/cmp", "cmp"),
                                       ("/bin/launchctl", "launchctl"), ("mock-reload", "reload")):
                        script = script.replace(path, f"'{mock}' {name}")
                    log.write_text("")
                    result = run("/bin/bash", "-e", "-o", "pipefail", "-c", script, env={
                        **os.environ, "CALLS": str(log), "CMP_STATUS": "0" if same else "1",
                        "STATE": state, "RELOAD_STATUS": str(status),
                    })
                    self.assertEqual(result.returncode, expected_exit, result.stderr)
                    calls = log.read_text()
                    if action:
                        self.assertIn(action, calls)
                    else:
                        self.assertNotIn("reload", calls)
                        self.assertNotIn("kickstart", calls)
                        self.assertNotIn("load -w", calls)

    def test_start_reload_and_invalid_config(self):
        self.exercise_server(use_launchd=False)

    @unittest.skipUnless(os.environ.get("CADDY_TEST_LAUNCHD") == "1", "optional temporary launchd job")
    def test_launchd_crash_recovery(self):
        self.exercise_server(use_launchd=True)

    def exercise_server(self, use_launchd):
        with tempfile.TemporaryDirectory(prefix="caddy-runtime-") as directory:
            root = Path(directory)
            port, admin = free_port(), free_port()
            while port == admin:
                admin = free_port()
            config = root / "Caddyfile"
            config.write_text((ARTIFACTS / "Caddyfile").read_text())
            env_file = root / "caddy.env"
            marker = root / "must-not-exist"

            class Upstream(BaseHTTPRequestHandler):
                def do_GET(self):
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"upstream reached")

                def log_message(self, *_args):
                    pass

            upstream = HTTPServer(("127.0.0.1", 0), Upstream)
            thread = threading.Thread(target=upstream.serve_forever, daemon=True)
            thread.start()

            def write_env(response):
                env_file.write_text(f'CADDY_TEST_PORT={port}\nCADDY_TEST_ADMIN_PORT={admin}\n'
                                    f'CADDY_TEST_UPSTREAM_PORT={upstream.server_port}\n'
                                    f'CADDY_TEST_RESPONSE="{response}"\n')
                env_file.chmod(0o600)

            write_env("before")
            # Substitute deployment paths only; run both generated wrappers,
            # including Caddy's real envfile parsing and private reload temp file.
            for name in ("start.sh", "reload.sh"):
                script = (ARTIFACTS / name).read_text()
                script = script.replace("/etc/caddy/caddy_config", str(config))
                script = script.replace("/run/secrets/never-read.env", str(env_file))
                script = script.replace("/var/lib/caddy", str(root / "data"))
                (root / name).write_text(script)
                (root / name).chmod(0o755)
            process = None
            target = None
            stream = (root / "process.log").open("w")

            def response(path="/"):
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                with opener.open(f"http://127.0.0.1:{port}{path}", timeout=1) as reply:
                    return reply.read().decode()

            def wait_response(expected):
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline:
                    try:
                        if response() == expected:
                            return
                    except (OSError, urllib.error.URLError):
                        pass
                    time.sleep(0.1)
                self.fail(f"No response {expected!r}: {(root / 'process.log').read_text()}")

            def job_pid():
                result = run("/bin/launchctl", "print", target)
                match = re.search(r"^\s*pid = (\d+)$", result.stdout, re.MULTILINE)
                return int(match.group(1)) if match else None

            try:
                if use_launchd:
                    plist = plistlib.loads((ARTIFACTS / "caddy.plist").read_bytes())
                    label = f"org.nixos.caddy-test-{os.getpid()}"
                    plist.update(Label=label, ProgramArguments=[str(root / "start.sh")],
                                 WorkingDirectory=str(root), StandardOutPath=str(root / "process.log"),
                                 StandardErrorPath=str(root / "process.log"))
                    for key in ("UserName", "GroupName"):
                        plist.pop(key)
                    plist_path = root / f"{label}.plist"
                    plist_path.write_bytes(plistlib.dumps(plist))
                    domain = f"gui/{os.getuid()}"
                    target = f"{domain}/{label}"
                    result = run("/bin/launchctl", "bootstrap", domain, str(plist_path))
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    process = subprocess.Popen([str(root / "start.sh")], stdout=stream, stderr=stream)
                wait_response("before")
                self.assertEqual(response("/proxy"), "upstream reached")
                pid = job_pid() if use_launchd else process.pid
                self.assertIsNotNone(pid)
                after = f"after $(touch {marker})"
                write_env(after)
                result = run(str(root / "reload.sh"), env={**os.environ, "TMPDIR": str(root)})
                self.assertEqual(result.returncode, 0, result.stderr)
                wait_response(after)
                self.assertFalse(marker.exists(), "Environment file was evaluated by a shell")
                self.assertFalse(list(root.glob("caddy-reload.*")), "Reload leaked its private directory")
                self.assertEqual(job_pid() if use_launchd else process.pid, pid)
                self.assertTrue(use_launchd or process.poll() is None)

                valid = config.read_text()
                config.write_text("{\n not_a_caddy_option\n}\n")
                result = run(str(root / "reload.sh"), env={**os.environ, "TMPDIR": str(root)})
                self.assertNotEqual(result.returncode, 0)
                wait_response(after)
                self.assertFalse(list(root.glob("caddy-reload.*")))
                config.write_text(valid)

                if use_launchd:
                    os.kill(pid, signal.SIGKILL)
                    wait_response(after)
                    self.assertNotEqual(job_pid(), pid)
                else:
                    process.terminate()
                    self.assertEqual(process.wait(timeout=10), 0)
            finally:
                if target:
                    result = run("/bin/launchctl", "bootout", target)
                    if result.returncode == 0:
                        self.assertNotEqual(run("/bin/launchctl", "print", target).returncode, 0)
                if process and process.poll() is None:
                    process.terminate()
                    process.wait(timeout=10)
                stream.close()
                upstream.shutdown()
                upstream.server_close()
                thread.join(timeout=2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("artifacts", type=Path)
    arguments = parser.parse_args()
    ARTIFACTS = arguments.artifacts.resolve()
    unittest.main(argv=[__file__], verbosity=2)
