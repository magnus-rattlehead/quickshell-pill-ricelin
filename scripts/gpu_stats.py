#!/usr/bin/env python3
"""Discover GPUs or collect one device. Only matching DRM fdinfo files are read."""
import glob
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PCI = re.compile(r"^(?:0{4})?([0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7])$", re.I)
GIB = 1024 ** 3


def pci_address(value):
    match = PCI.fullmatch(str(value))
    return match[1].lower() if match else ""


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (ValueError, TypeError):
        return None


def integer(value):
    return int(value) if re.fullmatch(r"[0-9]+", value) else None


def memory_bytes(value):
    parts = value.split()
    if not parts:
        return None
    n = number(parts[0])
    scale = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": GIB}.get(parts[1] if len(parts) > 1 else "B")
    return n * scale if n is not None and scale else None


def discover(sys_root):
    # One lspci invocation supplies names, including NVIDIA devices without a DRM node.
    labels = {}
    try:
        result = subprocess.run(["lspci", "-Dnn"], capture_output=True, text=True, timeout=1,
                                env=dict(os.environ, LC_ALL="C"))
        for line in result.stdout.splitlines():
            address, _, label = line.partition(" ")
            if pci_address(address):
                labels[pci_address(address)] = label
    except (OSError, subprocess.TimeoutExpired):
        pass
    devices = []
    for device in sorted((sys_root / "bus/pci/devices").glob("*")):
        pci = pci_address(device.name)
        vendor = {"0x8086": "intel", "0x10de": "nvidia", "0x1002": "amd"}.get(read_text(device / "vendor"))
        if not pci or not vendor or not read_text(device / "class").startswith("0x03"):
            continue
        nodes = ["/dev/dri/" + node.name for node in sorted((device / "drm").glob("*"))
                 if re.fullmatch(r"(?:card|renderD|controlD)[0-9]+", node.name)]
        hwmon = next(iter(sorted((device / "hwmon").glob("hwmon*"))), None)
        devices.append({"id": pci, "pci": pci, "vendor": vendor,
                        "label": labels.get(pci, vendor.upper() + " GPU"),
                        "devPath": str(device), "deviceId": read_text(device / "device"),
                        "nodes": nodes, "hwmon": str(hwmon) if hwmon else ""})
    # Keep DRM-backed cards first, followed by NVIDIA devices without DRM nodes.
    devices.sort(key=lambda d: (d["vendor"] == "nvidia", d["pci"]))
    sensors = sorted((sys_root / "class/hwmon").glob("hwmon*"))
    temp = ""
    for wanted in ("Tdie", "Package id 0", "Tctl"):
        for sensor in sensors:
            for label in sensor.glob("temp*_label"):
                if read_text(label) == wanted:
                    temp = str(label.with_name(label.name.replace("_label", "_input")))
                    break
            if temp:
                break
        if temp:
            break
    if not temp:
        temp = next((str(sensor / "temp1_input") for sensor in sensors if (sensor / "temp1_input").is_file()), "")
    return {"tempPath": temp, "devices": devices}


def intel_clients(device, proc_root):
    nodes = set(device.get("nodes", []))
    clients = {}
    if not nodes:
        return []
    # readlink is a syscall, not a spawned utility. Ignore PID/FD races and permissions.
    for pid in glob.iglob(str(proc_root / "[0-9]*")):
        try:
            with os.scandir(pid + "/fd") as descriptors:
                for fd in descriptors:
                    try:
                        if os.readlink(fd.path) not in nodes:
                            continue
                        text = Path(pid, "fdinfo", fd.name).read_text()
                    except (OSError, UnicodeError):
                        continue
                    fields = dict(line.split(":", 1) for line in text.splitlines() if ":" in line)
                    fields = {key: value.strip() for key, value in fields.items()}
                    client_id = fields.get("drm-client-id", "")
                    if (fields.get("drm-driver") != "xe" or not client_id.isdecimal()
                            or pci_address(fields.get("drm-pdev", "")) != device["pci"]):
                        continue
                    if client_id in clients:
                        continue
                    engines = []
                    for key, value in fields.items():
                        if not key.startswith("drm-cycles-"):
                            continue
                        engine = key[len("drm-cycles-"):]
                        cycles = integer(value)
                        total = integer(fields.get("drm-total-cycles-" + engine, ""))
                        capacity = integer(fields.get("drm-engine-capacity-" + engine, "1"))
                        if cycles is not None and total is not None and capacity:
                            engines.append({"name": engine, "cycles": cycles, "total": total, "capacity": capacity})
                    # A reported zero resident allocation is meaningful; do not replace it with total.
                    memory = fields.get("drm-resident-vram0", fields.get("drm-total-vram0", ""))
                    clients[client_id] = {"id": client_id, "engines": engines, "vramBytes": memory_bytes(memory)}
        except OSError:
            continue
    return list(clients.values())


def intel_metrics(device):
    metrics = {}
    hwmon = device.get("hwmon", "")
    if not hwmon:
        return metrics
    hwmon = Path(hwmon)
    channels = []
    for label_path in hwmon.glob("temp*_label"):
        label = read_text(label_path)
        value = number(read_text(label_path.with_name(label_path.name.replace("_label", "_input"))))
        if value is None:
            continue
        if label == "pkg":
            metrics["temp"] = value / 1000
        elif label == "vram":
            metrics["vramTemp"] = value / 1000
        elif label.startswith("vram_ch_"):
            channels.append(value / 1000)
    if channels:
        metrics["vramTemp"] = sum(channels) / len(channels)
    if "temp" not in metrics:
        value = number(read_text(hwmon / "temp1_input"))
        if value is not None:
            metrics["temp"] = value / 1000
    energy = integer(read_text(hwmon / "energy1_input"))
    if energy is not None:
        metrics["energyUj"] = energy
    return metrics


def nvidia_metrics(device):
    result = subprocess.run(["nvidia-smi", "--id=" + device["pci"],
                             "--query-gpu=pci.bus_id,utilization.gpu,temperature.gpu,memory.used,memory.total",
                             "--format=csv,noheader,nounits"], capture_output=True, text=True,
                            env=dict(os.environ, LC_ALL="C"), timeout=1.8)
    if result.returncode:
        raise RuntimeError("NVIDIA unavailable")
    for line in result.stdout.splitlines():
        row = [part.strip() for part in line.split(",")]
        if len(row) != 5 or pci_address(row[0]) != device["pci"]:
            continue
        metrics = {}
        for key, value, divisor in zip(("load", "temp", "vramUsedGb", "vramTotalGb"), row[1:], (1, 1, 1024, 1024)):
            n = number(value)
            if n is not None:
                metrics[key] = n / divisor
        return metrics
    raise RuntimeError("NVIDIA returned no matching device")


def amd_metrics(device):
    root = Path(device["devPath"])
    fields = {"load": (root / "gpu_busy_percent", 1),
              "vramUsedGb": (root / "mem_info_vram_used", GIB),
              "vramTotalGb": (root / "mem_info_vram_total", GIB)}
    if device.get("hwmon"):
        fields["temp"] = (Path(device["hwmon"]) / "temp1_input", 1000)
    metrics = {}
    for key, (path, divisor) in fields.items():
        value = number(read_text(path))
        if value is not None:
            metrics[key] = value / divisor
    return metrics


def collect(device, proc_root):
    pci = pci_address(device.get("pci", ""))
    if not pci or pci != device["pci"]:
        raise ValueError("Invalid PCI address")
    clients = []
    if device["vendor"] == "intel":
        metrics = intel_metrics(device)
        clients = intel_clients(device, proc_root)
        memory = [c["vramBytes"] for c in clients if c["vramBytes"] is not None]
        if memory:
            metrics["vramUsedGb"] = sum(memory) / GIB
    elif device["vendor"] == "nvidia":
        metrics = nvidia_metrics(device)
    elif device["vendor"] == "amd":
        metrics = amd_metrics(device)
    else:
        raise ValueError("Unknown GPU vendor")
    return {"pci": pci, "metrics": metrics, "clients": clients,
            "monotonicMs": time.monotonic_ns() / 1_000_000}


def main():
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "discover":
            result = discover(Path(os.environ.get("PILL_SYS_ROOT", "/sys")))
        elif len(sys.argv) == 3 and sys.argv[1] == "sample":
            result = collect(json.loads(sys.argv[2]), Path(os.environ.get("PILL_PROC_ROOT", "/proc")))
        else:
            return 2
        print(json.dumps(result, allow_nan=False, separators=(",", ":")))
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.TimeoutExpired):
        return 1


if __name__ == "__main__":
    sys.exit(main())
