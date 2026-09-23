#!/usr/bin/env python3
"""Validate and install this local checkout, with a recoverable backup."""
import datetime,json,pathlib,shutil,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((root/'manifest.json').read_text())
assert manifest['id']=='mateus.market-pulse'
subprocess.run(['omarchy','plugin','validate',str(root)],check=True)
parent=pathlib.Path.home()/'.config/omarchy/plugins'
target=parent/manifest['id']
backup=pathlib.Path.home()/'.local/state/omarchy/backups'/('market-pulse-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir(parents=True,exist_ok=False)
config=pathlib.Path.home()/'.config/omarchy/shell.json'
if config.exists(): shutil.copy2(config,backup/'shell.json')
# Stage outside the watched plugins directory; no partial QML files are loaded.
with tempfile.TemporaryDirectory(prefix='market-pulse-stage-',dir=parent.parent) as temp:
    stage=pathlib.Path(temp)/manifest['id']
    shutil.copytree(root,stage,ignore=shutil.ignore_patterns('.git','__pycache__','*.pyc'))
    if target.exists(): target.rename(backup/'plugin')
    try: stage.rename(target)
    except Exception:
        if (backup/'plugin').exists(): (backup/'plugin').rename(target)
        raise
result=subprocess.run(['omarchy-shell','shell','rescanPlugins'],text=True,capture_output=True)
print('Installed:',target,'\nVersion:',manifest['version'],'\nBackup:',backup)
print(result.stdout.strip() or result.stderr.strip())
if result.returncode: print('Plugin installed; the shell rescan could not be confirmed.')
