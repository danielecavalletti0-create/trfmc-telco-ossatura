(function(){
  const API="";
  function ready(fn){document.readyState==="loading"?document.addEventListener("DOMContentLoaded",fn):fn();}
  function set(id,v){const e=document.getElementById(id);if(e)e.textContent=v;}
  async function getJson(path){const r=await fetch(API+path,{cache:"no-store"});if(!r.ok)throw new Error(path+" "+r.status);return await r.json();}
  function state(cls){document.body.classList.remove("v65-telemetry-ok","v65-telemetry-warn","v65-telemetry-critical");document.body.classList.add(cls);}
  async function refresh(){
    try{
      const h=await getJson("/api/health");
      let m=null; try{m=await getJson("/api/observability/health-matrix");}catch(e){}
      const ok=h.status==="ok";
      set("v65_backend",ok?"ONLINE":"DEGRADED");
      set("v65_mode",h.operational_mode||"—");
      set("v65_persistence",h.persistence||"—");
      set("v65_stream",h.event_stream||"—");
      set("v65_checks",m&&Array.isArray(m.checks)?m.checks.length:"—");
      set("v65_overall",m&&m.overall_status?m.overall_status:(ok?"OK":"WARN"));
      set("v65_state",ok?"TELEMETRY READY":"TELEMETRY WATCH");
      state(ok?"v65-telemetry-ok":"v65-telemetry-warn");
    }catch(e){
      set("v65_backend","OFFLINE");set("v65_state","TELEMETRY DEGRADED");state("v65-telemetry-critical");
    }
  }
  ready(()=>{
    if(document.querySelector(".v65-telemetry-layer"))return;
    const layer=document.createElement("section");
    layer.className="v65-telemetry-layer";
    layer.innerHTML=`
      <div class="v65-head">
        <div><h2>Field Advanced Diagnostic + Telemetry Layer</h2><p>v0.65B · layer data-driven applicato sopra il runtime GPU/WebGL DSP: backend health, observability matrix, persistence, event stream e fault matrix da campo.</p></div>
        <div class="v65-pill" id="v65_state">TELEMETRY INIT</div>
      </div>
      <div class="v65-grid">
        <div class="v65-card"><h3>Live Backend Telemetry</h3><div class="v65-kpis">
          <div><span>Backend</span><b id="v65_backend">—</b></div><div><span>Mode</span><b id="v65_mode">—</b></div>
          <div><span>Persistence</span><b id="v65_persistence">—</b></div><div><span>Event Stream</span><b id="v65_stream">—</b></div>
          <div><span>Health Checks</span><b id="v65_checks">—</b></div><div><span>Overall</span><b id="v65_overall">—</b></div>
        </div></div>
        <div class="v65-card"><h3>RET / AISG Workflow</h3><div class="v65-flow">
          <div><b>1 · Identify</b><br/>settore, seriale antenna, RCU/TMA, bus AISG.</div>
          <div><b>2 · Read Position</b><br/>tilt attuale, target tilt, range e controller.</div>
          <div><b>3 · Command</b><br/>micro-variazione controllata, ACK e settling time.</div>
          <div><b>4 · Validate RF</b><br/>RSRP, SINR, handover, overlap e allarmi.</div>
        </div></div>
        <div class="v65-card"><h3>Fault Matrix</h3><div class="v65-fault">
          <div><b>VSWR alto</b><br/>feeder, connector, mismatch, water ingress.</div>
          <div><b>RET timeout</b><br/>AISG chain, RCU address, cablaggio.</div>
          <div><b>Optical RX low</b><br/>SFP, patch cord, fibra sporca, attenuazione.</div>
          <div><b>Backhaul fade</b><br/>rain fade, dish alignment, Fresnel obstruction.</div>
        </div></div>
      </div>
      <div class="v65-actions"><a href="/infrastructure_digital_twin_v63.html">Digital Twin</a><a href="/rf_propagation_sandbox_v62.html">Propagation</a><a href="/runtime_golden_check_console_v29.html">Golden Check</a></div>
    `;
    const k=document.querySelector(".knowledge");
    if(k)k.insertAdjacentElement("beforebegin",layer);else document.body.appendChild(layer);
    refresh();setInterval(refresh,30000);
  });
})();
