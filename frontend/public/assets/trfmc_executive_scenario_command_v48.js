(function(){
  const VERSION = "TRFMC_V0_48A_EXECUTIVE_SCENARIO_COMMAND_STRIP";
  const STORAGE_KEY = "trfmc_v48_selected_scenario";

  const scenarios = {
    "rural-ue": {
      title: "Rural UE",
      subtitle: "Remote UE / rural VoNR journey",
      risk: "MEDIUM",
      region: "Rural / remote",
      route: ["UE", "RAN", "Transport", "Core", "GWAN", "Evidence"]
    },
    "japan": {
      title: "Japan",
      subtitle: "Intercontinental mission path to Japan",
      risk: "MEDIUM",
      region: "APAC / Japan",
      route: ["UE", "RAN", "Core", "Transit", "Japan", "Report"]
    },
    "usa": {
      title: "USA",
      subtitle: "Transatlantic mission path to USA",
      risk: "MEDIUM",
      region: "North America",
      route: ["UE", "RAN", "Core", "GWAN", "USA", "Evidence"]
    },
    "africa": {
      title: "Africa",
      subtitle: "Long-haul / degraded path to Africa",
      risk: "HIGH",
      region: "Africa",
      route: ["UE", "RAN", "Core", "Transit", "Africa", "Recovery"]
    },
    "india": {
      title: "India",
      subtitle: "Regional APAC / India mission path",
      risk: "MEDIUM",
      region: "India",
      route: ["UE", "RAN", "Core", "Transit", "India", "Timeline"]
    },
    "australia": {
      title: "Australia",
      subtitle: "High-latency path to Australia",
      risk: "HIGH",
      region: "Australia",
      route: ["UE", "RAN", "Core", "GWAN", "Australia", "Report"]
    },
    "ntn": {
      title: "NTN",
      subtitle: "LEO/MEO/GEO non-terrestrial overlay",
      risk: "HIGH",
      region: "Satellite / NTN",
      route: ["Terminal", "Satellite", "Gateway", "Core", "Remote", "Evidence"]
    }
  };

  function ready(fn){
    if(document.readyState === "loading") document.addEventListener("DOMContentLoaded", fn);
    else fn();
  }

  function set(id, value){
    const el = document.getElementById(id);
    if(el) el.textContent = value ?? "—";
  }

  function renderRoute(scenario){
    const lane = document.getElementById("v48_route_lane");
    if(!lane) return;
    lane.innerHTML = scenario.route.map((step, idx) => `
      <div class="v48-route-step active" style="transition-delay:${idx * 80}ms">
        <b>${idx + 1}</b>
        <span>${step}</span>
      </div>
    `).join("");
  }

  function selectScenario(id){
    const scenario = scenarios[id] || scenarios["rural-ue"];
    localStorage.setItem(STORAGE_KEY, id);

    document.querySelectorAll(".v48-scenario-button").forEach(btn => {
      btn.classList.toggle("active", btn.dataset.scenario === id);
    });

    set("v48_selected_title", scenario.title);
    set("v48_selected_detail", scenario.subtitle);
    set("v48_selected_region", scenario.region);
    set("v48_selected_risk", scenario.risk);
    set("v48_last_scenario", scenario.title);
    set("v48_launch_state", "READY");
    set("v48_launch_detail", VERSION + " · " + new Date().toLocaleTimeString());

    renderRoute(scenario);
  }

  function bindScenarioButtons(){
    document.querySelectorAll(".v48-scenario-button").forEach(btn => {
      btn.addEventListener("click", () => selectScenario(btn.dataset.scenario));
    });
  }

  function bindLaunchButtons(){
    const globalBtn = document.getElementById("v48_open_global_launcher");
    const runnerBtn = document.getElementById("v48_open_scenario_runner");

    if(globalBtn){
      globalBtn.addEventListener("click", () => {
        window.location.href = "/global_mission_scenario_launcher_v39.html";
      });
    }

    if(runnerBtn){
      runnerBtn.addEventListener("click", () => {
        window.location.href = "/scenario_runner_console_v16.html";
      });
    }
  }

  function addToV47Navigator(){
    const links = document.querySelector(".v47-section-links");
    if(!links || document.querySelector('[data-v47-target="v48_scenario"]')) return;

    const a = document.createElement("a");
    a.href = "#v48_scenario";
    a.dataset.v47Target = "v48_scenario";
    a.textContent = "Scenario";
    links.insertBefore(a, links.firstChild);
  }

  ready(function(){
    const section = document.querySelector(".v48-scenario-command");
    if(section && !section.id) section.id = "v48_scenario";

    bindScenarioButtons();
    bindLaunchButtons();
    addToV47Navigator();

    const last = localStorage.getItem(STORAGE_KEY) || "rural-ue";
    selectScenario(last);
  });
})();
