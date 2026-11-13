#!/usr/bin/env bash
# Sinh tài liệu tham chiếu tự động (docs/generated/) từ DTB đã build + cây kernel + DT gốc của Google:
#   driver-map.md     : mọi node DT đang "okay" -> compatible -> file driver -> Kconfig -> y/m/không bật
#   stock-c1-overlay.dts : overlay gốc C1 DVT1.1 (id 0x115) của Google, giải mã — nguồn số liệu phần cứng
#   mainline-crosshatch.dts : DTB đang chạy, giải mã
#   firmware.sha256   : firmware đang cài
# Dùng: scripts/96-hw-facts.sh
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$REPO/docs/generated"
"$REPO/scripts/20-build-env.sh" run bash -s <<'INNER'
set -euo pipefail
OUT=/tmp/gen; rm -rf $OUT; mkdir -p $OUT
K=/work/kernel/linux; CFG=/work/out/kernel/config
DTB=/work/out/kernel/sdm845-google-crosshatch.dtb
dtc -I dtb -O dts $DTB 2>/dev/null > $OUT/mainline-crosshatch.dts
python3 - "$K" "$CFG" "$OUT/mainline-crosshatch.dts" > $OUT/driver-map.md <<'PY'
import re,sys,os,subprocess
K,CFG,DTS=sys.argv[1:4]
cfg={}
for l in open(CFG):
    m=re.match(r'(CONFIG_\w+)=(.*)',l)
    if m: cfg[m.group(1)]=m.group(2)
# Thu các node có compatible + trạng thái (status vắng = okay)
nodes=[]; stack=[]; cur=None
for line in open(DTS):
    s=line.strip()
    m=re.match(r'([\w@,.\-]+)\s*\{$',s)
    if m:
        stack.append({'name':m.group(1),'compat':None,'status':'okay'}); continue
    if s.startswith('};'):
        n=stack.pop() if stack else None
        if n and n['compat']:
            n['path']='/'.join(x['name'] for x in stack[1:]+[n])
            nodes.append(n)
        continue
    if stack:
        m=re.match(r'compatible = (.*);',s)
        if m: stack[-1]['compat']=re.findall(r'"([^"]+)"',m.group(1).replace('\\0','" "'))
        m=re.match(r'status = "(\w+)";',s)
        if m: stack[-1]['status']=m.group(1)
# MỘT lượt git grep cho mọi compatible (mỗi node một lượt qua virtiofs mất >30 phút)
_index={}
def build_index(compats):
    pats='\n'.join('"%s"'%c for c in sorted(compats))
    r=subprocess.run(['git','-C',K,'grep','-F','-f','-','--','drivers/*.c','sound/*.c'],input=pats,capture_output=True,text=True)
    for line in r.stdout.splitlines():
        f,_,txt=line.partition(':')
        for m in re.findall(r'"([^"]+)"',txt):
            _index.setdefault(m,[])
            if f not in _index[m]: _index[m].append(f)
def find_driver(compat):
    return _index.get(compat,[])[:2]
def kconfig_for(cfile):
    d=os.path.dirname(cfile); base=os.path.basename(cfile)[:-2]
    mk=os.path.join(K,d,'Makefile')
    if not os.path.exists(mk): return None
    txt=open(mk).read().replace('\\\n',' ')
    for m in re.finditer(r'obj-\$\((CONFIG_\w+)\)\s*\+?=\s*(.*)',txt):
        if re.search(r'(^|\s)%s\.o(\s|$)'%re.escape(base),m.group(2)): return m.group(1)
    # file nằm trong đối tượng ghép (foo-y += bar.o)
    for m in re.finditer(r'([\w\-]+)-(?:y|objs)\s*[+:]?=\s*(.*)',txt):
        if re.search(r'(^|\s)%s\.o(\s|$)'%re.escape(base),m.group(2)):
            obj=m.group(1)
            for m2 in re.finditer(r'obj-\$\((CONFIG_\w+)\)\s*\+?=\s*(.*)',txt):
                if re.search(r'(^|\s)%s\.o(\s|$)'%re.escape(obj),m2.group(2)): return m2.group(1)
    return None
build_index({c for n in nodes for c in n['compat']})
print("# Bản đồ driver (tự sinh bởi scripts/96-hw-facts.sh — KHÔNG sửa tay)\n")
print("Nguồn: DTB `sdm845-google-crosshatch.dtb` đang chạy + cây kernel `pixel3` + `out/kernel/config`.")
print("Cột *Trạng thái*: `y` built-in, `m` module, `-` chưa bật (thiết bị sẽ không có driver).\n")
print("| Node DT | compatible | File driver | Kconfig | Trạng thái |")
print("|---|---|---|---|---|")
seen=set()
for n in nodes:
    if n['status'] not in ('okay','ok'): continue
    c=n['compat'][0]
    key=(c,n['path'].split('@')[0])
    drv=[]; kc=None
    for cc in n['compat']:
        drv=find_driver(cc)
        if drv: break
    if drv: kc=kconfig_for(drv[0])
    st=cfg.get(kc,'-') if kc else '?'
    path=n['path'][-60:]
    print(f"| `{path}` | `{', '.join(n['compat'][:2])}` | {'<br>'.join('`'+d+'`' for d in drv) or '—'} | {('`'+kc+'`') if kc else '—'} | {st} |")
PY
python3 - /work/factory/crosshatch-sp1a.210812.016.c2/img/dtbo.img $OUT/stock-c1.dtbo <<'PY'
import struct,sys
d=open(sys.argv[1],"rb").read(); m,t,h,es,cnt,eo,ps,v=struct.unpack_from(">8I",d,0)
for i in range(cnt):
    sz,off,id_,rev,*_=struct.unpack_from(">8I",d,eo+i*es)
    if id_==0x115: open(sys.argv[2],"wb").write(d[off:off+sz])
PY
dtc -I dtb -O dts $OUT/stock-c1.dtbo 2>/dev/null > $OUT/stock-c1-overlay.dts
( cd /work/firmware/rootfs-overlay/lib/firmware && find . -type f | sort | xargs sha256sum ) > $OUT/firmware.sha256
mkdir -p /work/home/gen && cp $OUT/* /work/home/gen/
wc -l $OUT/*
INNER
cp /Volumes/pixelwork/home/gen/{driver-map.md,stock-c1-overlay.dts,mainline-crosshatch.dts,firmware.sha256} "$REPO/docs/generated/"
ls -la "$REPO/docs/generated/"
