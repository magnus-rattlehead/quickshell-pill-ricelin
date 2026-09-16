import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gpu_stats', ROOT / 'scripts/gpu_stats.py')
gpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu)
PCI = '0000:0e:00.0'

class CollectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.device = dict(pci=PCI,vendor='intel',nodes=['/dev/dri/renderD128'])

    def tearDown(self):
        self.tmp.cleanup()

    def fd(self, pid, fd, target, client='1', pci=PCI, driver='xe'):
        p = self.base / str(pid)
        (p/'fd').mkdir(parents=True,exist_ok=True)
        (p/'fdinfo').mkdir(exist_ok=True)
        (p/'fd'/str(fd)).symlink_to(target)
        (p/'fdinfo'/str(fd)).write_text(f'drm-driver: {driver}\ndrm-pdev: {pci}\ndrm-client-id: {client}\ndrm-cycles-render: 20\ndrm-total-cycles-render: 100\ndrm-engine-capacity-render: 2\ndrm-resident-vram0: 0 KiB\ndrm-total-vram0: 100 MiB\n')

    def test_selective_reads_deduplication_and_device_identity(self):
        self.fd(10,3,'/dev/dri/renderD128')
        self.fd(11,4,'/dev/dri/renderD128')
        self.fd(10,5,'/dev/dri/renderD128',client='2',pci='0000:01:00.0')
        self.fd(10,6,'/dev/dri/renderD128',client='3',driver='i915')
        self.fd(10,7,'/tmp/unrelated',client='4')
        original = Path.read_text
        reads = []
        def read(path, *args, **kwargs):
            reads.append(path)
            return original(path,*args,**kwargs)
        with patch.object(Path,'read_text',read):
            clients = gpu.intel_clients(self.device,self.base)
        self.assertNotIn(self.base/'10/fdinfo/7',reads)
        self.assertEqual(clients,[dict(id='1',engines=[dict(name='render',cycles=20,total=100,capacity=2)],vramBytes=0)])

    def test_fd_disappearance_and_permission_failure(self):
        self.fd(10,3,'/dev/dri/renderD128')
        (self.base/'10/fdinfo/3').unlink()
        self.assertEqual(gpu.intel_clients(self.device,self.base),[])
        with patch.object(os,'scandir',side_effect=PermissionError):
            self.assertEqual(gpu.intel_clients(self.device,self.base),[])

    def test_discovery_maps_nodes_sensors_and_nvidia_without_drm(self):
        for pci,vendor in [(PCI,'0x8086'),('0000:0b:00.0','0x10de')]:
            p = self.base/'bus/pci/devices'/pci
            p.mkdir(parents=True)
            (p/'vendor').write_text(vendor)
            (p/'class').write_text('0x030000')
            (p/'device').write_text('0xe20b')
        intel=self.base/'bus/pci/devices'/PCI
        (intel/'drm/renderD128').mkdir(parents=True)
        (intel/'drm/card0-DP-1').mkdir()
        (intel/'hwmon/hwmon5').mkdir(parents=True)
        with patch.object(subprocess,'run',side_effect=FileNotFoundError):
            result = gpu.discover(self.base)['devices']
        self.assertEqual([d['pci'] for d in result],[PCI,'0000:0b:00.0'])
        self.assertEqual(result[0]['nodes'],['/dev/dri/renderD128'])
        self.assertEqual(result[0]['hwmon'],str(intel/'hwmon/hwmon5'))
        self.assertEqual(result[1]['nodes'],[])

    def test_sensor_mapping_and_amd_units(self):
        hw=self.base/'hwmon5';hw.mkdir()
        for name,value in {'temp1_label':'pkg','temp1_input':'42000','temp2_label':'vram_ch_0','temp2_input':'50000','temp3_label':'vram_ch_1','temp3_input':'60000','energy1_input':'1000'}.items():
            (hw/name).write_text(value)
        self.assertEqual(gpu.intel_metrics(dict(hwmon=str(hw))),dict(temp=42,vramTemp=55,energyUj=1000))
        for name,value in {'gpu_busy_percent':'25','mem_info_vram_used':str(gpu.GIB),'mem_info_vram_total':str(8*gpu.GIB)}.items():
            (self.base/name).write_text(value)
        self.assertEqual(gpu.amd_metrics(dict(devPath=str(self.base),hwmon=str(hw))),dict(load=25,vramUsedGb=1,vramTotalGb=8,temp=42))

    def test_nvidia_single_direct_query_and_unavailable_values(self):
        device=dict(pci='0000:0b:00.0')
        result=subprocess.CompletedProcess([],0,'00000000:0B:00.0, 20, N/A, 1024, 24576\n','')
        with patch.object(subprocess,'run',return_value=result) as run:
            self.assertEqual(gpu.nvidia_metrics(device),dict(load=20,vramUsedGb=1,vramTotalGb=24))
            run.assert_called_once()
            args=run.call_args.args[0]
            self.assertIn('--id=0000:0b:00.0',args)
            self.assertNotIn('-L',args)
            self.assertNotIn('shell',run.call_args.kwargs)
        with patch.object(subprocess,'run',return_value=subprocess.CompletedProcess([],1,'')):
            with self.assertRaises(RuntimeError): gpu.nvidia_metrics(device)
        with self.assertRaises(ValueError): gpu.collect(dict(pci='$(touch bad)'),self.base)

    @unittest.skipUnless(shutil.which('quickshell'), 'quickshell not installed')
    def test_independent_polling_warmup_cancel_and_timeout(self):
        worker=self.base/'worker.py'
        worker.write_text("""import fcntl,json,os,signal,sys,time
from pathlib import Path
name,pci,delay=sys.argv[1:]
base=Path(__file__).parent
lock=(base/(name+'.lock')).open('w')
try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:
    (base/'OVERLAP').touch()
    sys.exit(1)
count=base/(name+'.count')
n=int(count.read_text())+1 if count.exists() else 1
count.write_text(str(n))
if name in ('hung','cancel'): signal.signal(signal.SIGTERM,signal.SIG_IGN)
time.sleep(float(delay))
print(json.dumps(dict(pci=pci,metrics=dict(load=n),clients=[dict(id='1',engines=[dict(name='render',cycles=n*50,total=n*100,capacity=1)])],monotonicMs=time.monotonic()*1000)))
""")
        config=(ROOT/'tests/gpu-smoke.qml').read_text().replace('@PILL@',ROOT.as_uri()).replace('@WORKER@',str(worker))
        shell=self.base/'shell.qml';shell.write_text(config)
        runtime=self.base/'runtime';runtime.mkdir(mode=0o700)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',
                 XDG_RUNTIME_DIR=str(runtime),XDG_CACHE_HOME=str(self.base/'cache'),
                 DBUS_SESSION_BUS_ADDRESS='unix:path='+str(self.base/'no-bus'))
        try:
            result=subprocess.run(['quickshell','-p',str(shell)],env=env,capture_output=True,text=True,timeout=10)
        except subprocess.TimeoutExpired as exc:
            self.fail(str(exc.stdout) + str(exc.stderr))
        output=result.stdout+result.stderr
        for message in ['TypeError:', 'ReferenceError:', 'Binding loop', 'Failed to load configuration', 'Unable to assign']:
            self.assertNotIn(message,output,output)
        samples={name:[] for name in ['quickNvidia','slowIntel','quickIntel','slowNvidia','cancel','hung']}
        for line in output.splitlines():
            if 'GPU_SAMPLE ' in line:
                item=json.loads(line.split('GPU_SAMPLE ',1)[1])
                samples[item['name']].append(item)
        self.assertTrue(all(samples.values()),output)
        self.assertLess(samples['quickNvidia'][0]['ms'],samples['slowIntel'][0]['ms'])
        self.assertLess(samples['quickIntel'][1]['ms'],samples['slowNvidia'][0]['ms'])
        self.assertEqual(samples['quickIntel'][0]['load'],-1)
        self.assertEqual(samples['quickIntel'][1]['load'],50)
        self.assertGreaterEqual(samples['quickIntel'][1]['ms']-samples['quickIntel'][0]['ms'],190)
        self.assertEqual(samples['cancel'][0]['load'],2,output)
        self.assertTrue(all(s['ms']<3200 for s in samples['cancel']))
        self.assertEqual(len(samples['hung']),1)
        self.assertEqual(samples['hung'][0]['status'],'offline')
        self.assertLess(samples['hung'][0]['ms'],3800)
        self.assertFalse((self.base/'OVERLAP').exists())

if __name__ == '__main__': unittest.main()
