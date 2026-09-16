"""Integration fixtures: no live session actions or real network connections."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='pill-test-')
        self.base = Path(self.tmp.name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        XDG_CACHE_HOME=str(self.base / 'cache'), PILL_TEST_LOG=str(self.base / 'calls.jsonl'))

    def tearDown(self):
        self.tmp.cleanup()

    def stub(self, name, code):
        p = self.bin / name
        p.write_text('#!/usr/bin/python3\n' + code)
        p.chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(['sh', str(ROOT / 'scripts' / name), *args], env=self.env,
                              text=True, capture_output=True, timeout=15)

    def test_shell_syntax(self):
        for path in (ROOT / 'scripts').glob('*.sh'):
            result = subprocess.run(['sh', '-n', str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_sysmon_cpu_memory_network_and_literal_sensor_path(self):
        proc = self.base / 'proc'
        (proc / 'net').mkdir(parents=True)
        (proc / 'stat').write_text('cpu 10 20 30 40 50 60 70 80 90 100\n')
        (proc / 'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 250 kB\nSwapTotal: 100 kB\nSwapFree: 75 kB\n')
        (proc / 'net/dev').write_text('header\nheader\n lo: 900 0 0 0 0 0 0 0 800\n eth0: 100 0 0 0 0 0 0 0 200\n')
        self.env['PILL_PROC_ROOT'] = str(proc)
        sensor = self.base / "sensor $(touch SHOULD_NOT_EXIST) ' quote"
        sensor.write_text('42000\n')
        result = self.run_script('sysmon-fast.sh', str(sensor))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['CPU 360 90', 'MEM 1000 250 100 75', 'NET 100 200', 'TMP 42000'])
        self.assertFalse((ROOT / 'SHOULD_NOT_EXIST').exists())

    def test_clipboard_validates_ids_and_uses_private_work_files(self):
        self.stub('cliphist', '''import sys
if sys.argv[1] == 'list':
    print('123\\t[[ binary data 1 KiB png 10x10 ]]')
    print('../escape\\t[[ binary data 1 KiB png 10x10 ]]')
    print('$(touch injected)\\t[[ binary data 1 KiB png 10x10 ]]')
else:
    assert sys.stdin.read() == '123'
    sys.stdout.write('fixture')
''')
        self.stub('magick', '''import os,sys
from pathlib import Path
raw = Path(sys.argv[1][:-3])
assert raw.parent.stat().st_mode & 0o777 == 0o700
assert Path(os.environ['MAGICK_CONFIGURE_PATH'], 'policy.xml').exists()
Path(sys.argv[-1][4:]).write_bytes(b'PNG fixture')
''')
        cache = self.base / 'cache/cliphist-thumbs'
        cache.mkdir(parents=True)
        (cache / '999.png').write_bytes(b'stale')
        result = self.run_script('cliphist-thumbs.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([p.name for p in cache.iterdir()], ['123.png'])
        self.assertEqual((cache / '123.png').stat().st_mode & 0o777, 0o600)
        self.assertEqual(cache.stat().st_mode & 0o777, 0o700)

    def test_clipboard_rejects_symlink_cache(self):
        outside = self.base / 'outside'
        outside.mkdir()
        cache = self.base / 'cache'
        cache.mkdir()
        (cache / 'cliphist-thumbs').symlink_to(outside, target_is_directory=True)
        self.assertNotEqual(self.run_script('cliphist-thumbs.sh').returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    @unittest.skipUnless(shutil.which('quickshell'), 'quickshell not installed')
    def test_qml_smoke_with_stubbed_services(self):
        code = '''import json,os,sys,time
from pathlib import Path
name=Path(sys.argv[0]).name
args=sys.argv[1:]
record={'name':name,'args':args}
if name=='nmcli' and '--ask' in args: record['stdin']=sys.stdin.read()
with open(os.environ['PILL_TEST_LOG'],'a') as f: f.write(json.dumps(record)+'\\n')
if name=='hyprctl': print('[]')
if name=='nvidia-smi': print('00000000:0B:00.0, 37, 40, 1024, 24576')
if name=='nmcli':
    if 'UUID,TYPE' in args: print('00000000-0000-0000-0000-000000000001:802-11-wireless')
    elif 'SSID,SECURITY' in args: print(r'Cafe\\: back\\\\slash:WPA2')
    elif '802-11-wireless.ssid' in args: print(r'Cafe\\: back\\\\slash')
    elif '-s' in args: time.sleep(.2); print('test-secret')
if name=='curl':
    time.sleep(.15)
    if '-G' in args:
        new='name=New' in args
        print(json.dumps({'results':[{'name':'New' if new else 'Old','latitude':46 if new else 45,'longitude':-73}]}))
    else: print(json.dumps({'current':{'temperature_2m':20,'weather_code':1,'relative_humidity_2m':50,'is_day':1}}))
'''
        for name in ['hyprctl','nmcli','bluetoothctl','wl-paste','wl-copy','cliphist','curl','loginctl','systemd-inhibit','lspci','nvidia-smi']:
            self.stub(name, code)
        for name in ['state', 'cache', 'runtime', 'config', 'data']:
            (self.base / name).mkdir(mode=0o700, exist_ok=True)
        self.env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                        DBUS_SESSION_BUS_ADDRESS='unix:path='+str(self.base / 'no-session'),
                        DBUS_SYSTEM_BUS_ADDRESS='unix:path='+str(self.base / 'no-system'),
                        HYPRLAND_INSTANCE_SIGNATURE='', WAYLAND_DISPLAY='',
                        XDG_STATE_HOME=str(self.base / 'state'), XDG_RUNTIME_DIR=str(self.base / 'runtime'),
                        XDG_CONFIG_HOME=str(self.base / 'config'), XDG_DATA_HOME=str(self.base / 'data'))
        gpu = self.base / 'sys/bus/pci/devices/0000:0b:00.0'
        gpu.mkdir(parents=True)
        (gpu / 'vendor').write_text('0x10de')
        (gpu / 'class').write_text('0x030000')
        self.env['PILL_SYS_ROOT'] = str(self.base / 'sys')
        config = (ROOT / 'tests/smoke.qml').read_text().replace('@PILL@', ROOT.as_uri()).replace('@SHELL@', (ROOT / 'shell.qml').as_uri())
        (self.base / 'shell.qml').write_text(config)
        result = subprocess.run(['quickshell','-p',str(self.base / 'shell.qml')], env=self.env,
                                text=True, capture_output=True, timeout=15)
        output = result.stdout + result.stderr
        self.assertIn('PILL_SMOKE_OK', output, output)
        self.assertNotIn('PILL_SMOKE_FAIL', output)
        for message in ['TypeError:', 'ReferenceError:', 'Binding loop', 'Failed to load configuration', 'Unable to assign']:
            self.assertNotIn(message, output, output)
        calls=[json.loads(line) for line in (self.base/'calls.jsonl').read_text().splitlines()]
        power=[c for c in calls if c['name']=='loginctl']
        self.assertEqual([c['args'] for c in power], [['poweroff']])
        connect=[c for c in calls if '--ask' in c['args']]
        self.assertEqual(len(connect),1)
        self.assertEqual(connect[0]['stdin'], "literal'$(not-a-command)\n")
        self.assertNotIn("literal'$(not-a-command)", str(connect[0]['args']))
        self.assertFalse(any('delete' in c['args'] for c in calls))
        forecasts=[c for c in calls if c['name']=='curl' and '-G' not in c['args']]
        self.assertTrue(forecasts)
        self.assertTrue(all('latitude=46&' in c['args'][-1] for c in forecasts))

if __name__ == '__main__':
    unittest.main()
