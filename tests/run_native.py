#!/usr/bin/env python3
"""Run actual Quickshell/QtTest flows in isolation on the current Wayland session.
No production settings are written; provider requests use a subprocess fixture.
"""
import os,pathlib,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='market-pulse-native-') as directory:
    folder=pathlib.Path(directory)
    for name in ['Commons','Ui','services','plugins']:
        (folder/name).symlink_to(pathlib.Path('/usr/share/omarchy/shell')/name,target_is_directory=True)
    (folder/'Pulse').symlink_to(root,target_is_directory=True)
    (folder/'shell.qml').write_text((root/'tests/native-shell.qml').read_text())
    env=dict(os.environ,MARKET_PULSE_FIXTURE_HELPER=str(root/'tests/fixture_helper.py'),MARKET_PULSE_TEST_STATE=str(folder/'settings.json'))
    result=subprocess.run(['quickshell','-p',str(folder),'--no-color'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
    print(result.stdout)
    if result.returncode or 'NATIVE_CHECKS_PASSED' not in result.stdout or 'NATIVE_CHECKS_FAILED' in result.stdout:
        raise SystemExit(1)
