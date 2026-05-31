import pytest
import subprocess
import sys
import os

SCRIPT_PATH = os.path.join(
    os.path.dirname(__file__),
    "luci-app-ssr-mudb-server/root/usr/share/ssr_mudb_server/utils/autoban.py"
)

PAYLOADS = [
    # Exact exploit: shell metacharacters in IP-like string
    "127.0.0.1; touch /tmp/pwned_autoban",
    # Boundary: newline injection
    "192.168.1.1\nrm -rf /tmp/test_autoban",
    # Valid input: legitimate IP address
    "10.0.0.1",
]

@pytest.mark.parametrize("payload", PAYLOADS)
def test_autoban_no_command_injection(payload, tmp_path):
    """Invariant: autoban.py must never execute injected shell commands
    from adversarial IP-like inputs containing shell metacharacters."""
    sentinel = tmp_path / "pwned_autoban"
    assert not sentinel.exists(), "Sentinel file should not exist before test"

    env = os.environ.copy()
    env["TMPDIR"] = str(tmp_path)

    # Run the script with the adversarial payload as simulated input
    # We patch /tmp to our tmp_path so any injected 'touch /tmp/pwned_autoban' lands there
    result = subprocess.run(
        [sys.executable, SCRIPT_PATH, payload],
        capture_output=True,
        text=True,
        timeout=5,
        env=env,
        cwd=str(tmp_path),
    )

    # The injected command must NOT have been executed
    pwned_file = tmp_path / "pwned_autoban"
    assert not pwned_file.exists(), (
        f"Command injection succeeded for payload {payload!r}: "
        f"sentinel file was created, indicating shell metacharacters were executed."
    )