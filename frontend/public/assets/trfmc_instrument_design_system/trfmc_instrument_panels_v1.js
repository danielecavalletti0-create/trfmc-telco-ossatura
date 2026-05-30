/*
 TRFMC Instrument Panels V1
 Lightweight reusable cockpit panels.
*/

(function(){
  "use strict";

  class TrfmcInstrumentPanel extends HTMLElement{
    connectedCallback(){
      const title = this.getAttribute("title") || "Instrument Panel";
      const value = this.getAttribute("value") || "READY";
      const subtitle = this.getAttribute("subtitle") || "TRFMC instrument telemetry";
      this.classList.add("trfmc-instrument-panel");
      this.style.padding = "10px";
      this.innerHTML = `
        <div class="trfmc-instrument-title" style="font-size:12px">${title}</div>
        <div class="trfmc-instrument-kpi" style="margin-top:8px">
          <small>${subtitle}</small>
          <b>${value}</b>
        </div>
      `;
    }
  }

  if(!customElements.get("trfmc-instrument-panel")){
    customElements.define("trfmc-instrument-panel", TrfmcInstrumentPanel);
  }
})();
