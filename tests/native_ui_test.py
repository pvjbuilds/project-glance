#!/usr/bin/env python3
"""Runs an isolated AppKit self-test; it briefly maps a test window."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/Viewer.swift').read_text()
tests = (root / 'tests/native_ui_check.swift').read_text()
source = source.replace('UserDefaults.standard', 'testDefaults')
source = source.replace('struct TokenUsage', 'let testDomain = "local.glance.qa." + UUID().uuidString\nlet testDefaults = UserDefaults(suiteName: testDomain)!\nstruct TokenUsage', 1)
marker = 'if let i = CommandLine.arguments.firstIndex(of: "--preview")'
assert marker in source
source = source.replace(marker, tests + '\nif CommandLine.arguments.contains("--test-ui") { runNativeChecks() } else ' + marker, 1)
with tempfile.TemporaryDirectory(prefix='glance-native-check-') as tmp:
    tmp = Path(tmp); source_path = tmp / 'main.swift'; source_path.write_text(source)
    binary = tmp / 'ui-check'; cache = root / 'build/module-cache'; cache.mkdir(parents=True, exist_ok=True)
    subprocess.run(['swiftc', '-module-cache-path', str(cache), str(source_path), '-o', str(binary)], check=True)
    subprocess.run([str(binary), '--store', str(tmp / 'missing-store'), '--test-ui'], check=True)
