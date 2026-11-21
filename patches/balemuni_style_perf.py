#!/usr/bin/env python3
import re, sys
args=set(sys.argv[1:]); out=[]
def replace(name,path,old,new):
 s=open(path,encoding="utf-8").read()
 if new in s: out.append("OK "+name+": already applied"); return
 if s.count(old)!=1: out.append("NOT APPLIED "+name+": anchor not found uniquely"); return
 open(path,"w",encoding="utf-8").write(s.replace(old,new,1)); out.append("OK "+name+": applied")
if "--gcm" in args: replace("gcm","src/freedreno/ir3/ir3_nir.c",'gcm = debug_get_num_option("GCM", 0);','gcm = debug_get_num_option("GCM", 1);')
if "--zelda" in args:
 p="src/freedreno/vulkan/tu_drirc_gen.py"; s=open(p,encoding="utf-8").read(); t=s
 for o in ("tu_dont_care_as_load","tu_allow_oob_indirect_ubo_loads"):
  t,n=re.subn(r'(B\(\s*"'+o+r'",\s*)(?:False|True)(\s*,)',r"\g<1>True\g<2>",t,count=1)
  if n!=1: out.append("NOT APPLIED zelda: "+o+" anchor missing"); break
 else: compile(t,p,"exec"); open(p,"w",encoding="utf-8").write(t); out.append("OK zelda: both defaults true")
if "--suballoc" in args:
 p="src/freedreno/vulkan/tu_device.cc"; s=open(p,encoding="utf-8").read(); t=s
 for o in ("pipeline_suballoc","kgsl_profiling_suballoc"):
  t,n=re.subn(r"(&device->"+o+r",\s*device,\s*)128 \* 1024(,)",r"\g<1>512 * 1024\g<2>",t,count=1)
  out.append(("OK " if n==1 else "NOT APPLIED ")+ "suballoc "+o)
 open(p,"w",encoding="utf-8").write(t)
if "--cache" in args: replace("cache","src/util/disk_cache.c","max_size = 1024*1024*1024;","max_size = (uint64_t)4 * 1024 * 1024 * 1024;")
for x in ("gcm","zelda","suballoc","cache"):
 if "--"+x not in args: out.append("SKIPPED "+x)
open("balemuni_perf_report.txt","w",encoding="utf-8").write("\n".join(out)+"\n")
print("\n".join(out))
