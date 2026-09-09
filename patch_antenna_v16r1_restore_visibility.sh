#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
SRC="$PUBLIC/trfmc_antenna_system_explorer_v16_metrology_premium.html"
DST="$PUBLIC/trfmc_antenna_system_explorer_v16r1_visible_antenna.html"

if [ ! -f "$SRC" ]; then
  echo "ERRORE: manca $SRC"
  exit 1
fi

cp -f "$SRC" "$DST"

python3 - <<'PY'
from pathlib import Path

p = Path("frontend/public/trfmc_antenna_system_explorer_v16r1_visible_antenna.html")
s = p.read_text(errors="ignore")

s = s.replace(
    "TRFMC Antenna System Explorer V1.6 Metrology Premium",
    "TRFMC Antenna System Explorer V1.6R1 Metrology Premium Visible Antenna"
)
s = s.replace(
    "<title>TRFMC Antenna System Explorer V1.6 Metrology Premium</title>",
    "<title>TRFMC Antenna System Explorer V1.6R1 Visible Antenna</title>"
)

css = r'''
/* === V1.6R1 RESTORE ANTENNA VISIBILITY === */
#v16Scope{
  top:54px !important;
  left:8px !important;
  right:auto !important;
  width:318px !important;
  grid-template-columns:1fr !important;
  pointer-events:none !important;
  opacity:.94 !important;
}
#v16Scope .v16Glass{
  margin-bottom:6px !important;
}
#v16Scope .v16Glass:nth-child(2){
  display:none !important;
}
#v16Scope .v16Glass:nth-child(3){
  display:none !important;
}
#icMeasureOverlay{
  top:206px !important;
  width:318px !important;
  opacity:.92 !important;
}
#icMatrix{
  top:54px !important;
  right:8px !important;
  width:300px !important;
  opacity:.92 !important;
}
#v16BottomBar{
  bottom:52px !important;
  left:340px !important;
  right:320px !important;
  grid-template-columns:repeat(4,1fr) !important;
  opacity:.92 !important;
}
#icCenterDock{
  bottom:8px !important;
}
#icStatusLine{
  bottom:38px !important;
}
#siteFrame::after{
  content:"ANTENNA VISIBILITY SAFE MODE · V1.6R1";
  position:absolute;
  top:7px;
  right:12px;
  z-index:9;
  color:#7dff4f;
  font:11px ui-monospace,monospace;
  pointer-events:none;
}
'''
s = s.replace("</style>", css + "\n</style>")

p.write_text(s)
print("CREATED", p)
PY

python3 - <<'PY'
from pathlib import Path
files=[
"frontend/public/trfmc_master_console_v4.html",
"frontend/public/trfmc_antenna_system_explorer_v16_metrology_premium.html",
"frontend/public/trfmc_antenna_system_explorer_v15_instrument_center.html",
"frontend/public/trfmc_enterprise_prime_portal_v1.html",
"frontend/public/api/portal/index"
]
link='<a href="/trfmc_antenna_system_explorer_v16r1_visible_antenna.html">Antenna V1.6R1 Visible</a>'
for f in files:
    p=Path(f)
    if not p.exists():
        continue
    s=p.read_text(errors="ignore")
    if "trfmc_antenna_system_explorer_v16r1_visible_antenna.html" not in s:
        if "<nav" in s:
            i=s.find("<nav"); gt=s.find(">",i)
            s=s[:gt+1]+"\n"+link+s[gt+1:]
        elif "<ul>" in s:
            s=s.replace("<ul>","<ul>\n<li>"+link+"</li>",1)
        p.write_text(s)
        print("PATCHED",p)
PY

curl -I --max-time 5 http://127.0.0.1:5173/trfmc_antenna_system_explorer_v16r1_visible_antenna.html
