from datetime import datetime, timezone
from typing import Any, Dict, List
from uuid import uuid4

from app.domains.rf_field.schemas import RfFieldRequest
from app.domains.rf_field.services import RfFieldService
from app.domains.rf_coverage.schemas import RfCoverageRequest
from app.domains.rf_coverage.services import RfCoverageService
from app.domains.timeline.services import TimelineService
from app.domains.correlation.services import CorrelationService
from app.persistence.repositories import (
    CloudEventRepository,
    NetworkPathRepository,
    PersistenceRepository,
)
from app.shared.cloudevents import CloudEvent, ce_type
from app.core.event_bus import event_bus


class ScenarioService:
    service_name = "TRFMC_SCENARIO_RUNNER_MISSION_PLAYBOOKS_V0_16"

    def __init__(self):
        self.events = CloudEventRepository()

    def now(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def catalog(self) -> Dict[str, Any]:
        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "scenarios": [
                {
                    "scenario_id": "SCN-REMOTE-UE-RURAL-VONR",
                    "title": "Remote UE Rural / Desert VoNR Journey",
                    "category": "telco_network_journey",
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "description": "Simula UE remoto in area rurale/desertica con servizio VoNR, copertura RF e percorso globale.",
                    "actions": [
                        "RF coverage run su UE-REMOTE-001",
                        "Lettura network path esistente",
                        "Emissione CloudEvent scenario completed",
                        "Aggiornamento timeline/correlation graph",
                    ],
                },
                {
                    "scenario_id": "SCN-UAV-RF-FIELD-CHECK",
                    "title": "UAV RF Field / Antenna / Fresnel Check",
                    "category": "rf_field_uav",
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "description": "Simula collegamento UAV altitude-aware con campo E/H/Poynting, antenna pattern e Fresnel.",
                    "actions": [
                        "RF field run su UAV-ALPHA-001",
                        "Persistenza evento RF field",
                        "Emissione CloudEvent scenario completed",
                    ],
                },
                {
                    "scenario_id": "SCN-URBAN-NLOS-COVERAGE",
                    "title": "Urban NLOS Coverage Degradation",
                    "category": "rf_urban_coverage",
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "description": "Simula copertura urbana con edifici/alberi, stato LOS/NLOS, link budget e SNR.",
                    "actions": [
                        "RF coverage run su UE-REMOTE-001",
                        "Obstacle hit / NLOS evidence",
                        "Emissione CloudEvent scenario completed",
                    ],
                },
                {
                    "scenario_id": "SCN-GLOBAL-VONR-JOURNEY",
                    "title": "Global VoNR Journey / GWAN",
                    "category": "global_network_path",
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "description": "Raccoglie percorso locale-regionale-nazionale-GWAN verso destinazioni globali già modellate.",
                    "actions": [
                        "Lettura network paths persistiti",
                        "Sintesi RTT/MOS/dominant segment",
                        "Emissione CloudEvent scenario completed",
                    ],
                },
                {
                    "scenario_id": "SCN-EVIDENCE-CORRELATION-BURST",
                    "title": "Evidence Correlation Burst",
                    "category": "evidence_correlation",
                    "mission_id": "MISSION-FULL-TELCO-BOOT-001",
                    "description": "Genera un burst controllato di evidenze RF field + coverage + correlation per timeline e mission graph.",
                    "actions": [
                        "RF field run UAV",
                        "RF coverage run UE",
                        "CloudEvent scenario started/completed",
                        "Timeline replay update",
                        "Correlation graph update",
                    ],
                },
            ],
        }

    def get_scenario(self, scenario_id: str) -> Dict[str, Any]:
        for scenario in self.catalog()["scenarios"]:
            if scenario["scenario_id"] == scenario_id:
                return scenario
        raise ValueError(f"Scenario non trovato: {scenario_id}")

    async def publish_event(self, event_type: str, subject: str, data: Dict[str, Any]) -> Dict[str, Any]:
        event = CloudEvent(
            source="urn:trfmc:scenario-runner",
            type=ce_type("scenario", event_type),
            subject=subject,
            data=data,
        )
        event_dict = event.model_dump(mode="json")
        self.events.append(event_dict)
        await event_bus.broadcast(event_dict)
        return event_dict

    async def run(self, scenario_id: str) -> Dict[str, Any]:
        scenario = self.get_scenario(scenario_id)
        run_id = f"SCN-RUN-{uuid4().hex[:12].upper()}"
        mission_id = scenario["mission_id"]
        correlation_id = f"CORR-{run_id}"

        started_event = await self.publish_event(
            event_type="run_started",
            subject=run_id,
            data={
                "mission_id": mission_id,
                "correlation_id": correlation_id,
                "scenario_id": scenario_id,
                "run_id": run_id,
                "title": scenario["title"],
                "global_time_cursor_ms": 0,
            },
        )

        results: Dict[str, Any] = {
            "rf_field": None,
            "rf_coverage": None,
            "network_paths": [],
            "timeline": None,
            "correlation": None,
        }

        if scenario_id in ("SCN-UAV-RF-FIELD-CHECK", "SCN-EVIDENCE-CORRELATION-BURST"):
            results["rf_field"] = await RfFieldService().run_and_persist(
                RfFieldRequest(
                    mission_id=mission_id,
                    cell_asset_id="CELL-N78-A",
                    target_asset_id="UAV-ALPHA-001",
                    frequency_hz=3_500_000_000,
                    tx_power_dbm=43,
                    tx_gain_dbi=18,
                    antenna_max_dimension_m=0.8,
                    azimuth_deg=120,
                    mechanical_tilt_deg=4,
                    electrical_tilt_deg=2,
                )
            )

        if scenario_id in (
            "SCN-REMOTE-UE-RURAL-VONR",
            "SCN-URBAN-NLOS-COVERAGE",
            "SCN-EVIDENCE-CORRELATION-BURST",
        ):
            results["rf_coverage"] = await RfCoverageService().run_and_persist(
                RfCoverageRequest(
                    mission_id=mission_id,
                    cell_asset_id="CELL-N78-A",
                    target_asset_id="UE-REMOTE-001",
                    frequency_hz=3_500_000_000,
                    tx_power_dbm=43,
                    tx_gain_dbi=18,
                    rx_gain_dbi=0,
                    bandwidth_hz=100_000_000,
                    noise_figure_db=7,
                    grid_extent_m=600,
                    grid_step_m=100,
                )
            )

        if scenario_id in ("SCN-REMOTE-UE-RURAL-VONR", "SCN-GLOBAL-VONR-JOURNEY", "SCN-EVIDENCE-CORRELATION-BURST"):
            try:
                results["network_paths"] = NetworkPathRepository().list()
            except Exception:
                results["network_paths"] = []

        try:
            results["timeline"] = TimelineService().timeline(mission_id=mission_id, limit=50)
        except Exception as exc:
            results["timeline"] = {"error": str(exc)}

        try:
            results["correlation"] = CorrelationService().build_graph(mission_id=mission_id, limit=120).get("summary")
        except Exception as exc:
            results["correlation"] = {"error": str(exc)}

        completed_event = await self.publish_event(
            event_type="run_completed",
            subject=run_id,
            data={
                "mission_id": mission_id,
                "correlation_id": correlation_id,
                "scenario_id": scenario_id,
                "run_id": run_id,
                "title": scenario["title"],
                "category": scenario["category"],
                "rf_field_run_id": self._extract_run_id(results.get("rf_field")),
                "rf_coverage_run_id": self._extract_run_id(results.get("rf_coverage")),
                "network_path_count": len(results.get("network_paths") or []),
                "timeline_count": (results.get("timeline") or {}).get("count"),
                "correlation_summary": results.get("correlation"),
                "global_time_cursor_ms": 0,
            },
        )

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "scenario": scenario,
            "run_id": run_id,
            "correlation_id": correlation_id,
            "started_event": started_event,
            "completed_event": completed_event,
            "results": results,
            "status": "COMPLETED",
        }

    def _extract_run_id(self, payload: Any) -> Any:
        if not isinstance(payload, dict):
            return None
        run = payload.get("run")
        if isinstance(run, dict):
            return run.get("run_id")
        return None

    def runs(self, limit: int = 100) -> Dict[str, Any]:
        events = CloudEventRepository().list(limit=limit)
        scenario_events = [
            ev for ev in events
            if str(ev.get("type", "")).startswith("trfmc.scenario.")
        ]

        return {
            "service": self.service_name,
            "timestamp": self.now(),
            "count": len(scenario_events),
            "events": scenario_events,
            "persistence": PersistenceRepository().status(),
        }
