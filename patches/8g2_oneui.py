#!/usr/bin/env python3
import re, sys
p="src/freedreno/common/freedreno_devices.py"
h="GPUProps(enable_tp_ubwc_flag_hint = True)"
s=open(p,encoding="utf-8").read()
m=re.search(r'GPUId\(chip_id=0xffff43050a01, name="[^"]*"\)',s,re.I)
if not m: sys.exit("FATAL: Adreno 740 GPU ID not found")
e=s.find("add_gpus(",m.end()); e=len(s) if e<0 else e
b=s[m.end():e]
if h in b: print("A740 UBWC hint already enabled"); sys.exit(0)
a=re.search(r"\[a7xx_base, a7xx_gen2\],",b)
if not a: sys.exit("FATAL: A740 properties anchor not found; refusing to build")
i=m.end()+a.start()
s=s[:i]+f"[a7xx_base, a7xx_gen2, {h}],"+s[m.end()+a.end():]
compile(s,p,"exec")
open(p,"w",encoding="utf-8").write(s)
print("A740 One UI UBWC flag enabled")
