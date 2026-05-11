from app.core.database import get_connection
from app.persistence.models import DDL_STATEMENTS
from app.persistence.repositories import (
    MissionRepository,
    AssetRepository,
    AssetLinkRepository,
    EvidenceRepository,
    IncidentRepository,
)


def bootstrap_database() -> None:
    with get_connection() as conn:
        for ddl in DDL_STATEMENTS:
            conn.execute(ddl)

    seed_baseline()


def seed_baseline() -> None:
    MissionRepository().upsert(
        mission_id="MISSION-FULL-TELCO-BOOT-001",
        name="Full Telco Skeleton Bootstrap",
        mode="SIMULATION_ONLY",
        status="RUNNING",
        data={
            "version": "0.6-asset-digital-twin",
            "domains": [
                "scientific_core",
                "network_fabric",
                "telco_mns",
                "assets",
                "access_trust",
                "soc_noc",
                "evidence",
                "restricted_locked",
            ],
        },
    )

    ar = AssetRepository()

    assets = [
        (
            "SITE-REMOTE-001",
            "RADIO_SITE",
            "TELCO_SITE",
            "ACTIVE",
            {
                "label": "Remote desert/rural radio site",
                "position": {"lat": 41.9000, "lon": 12.5000, "altitude_m": 60},
                "backhaul": "MICROWAVE_OR_SAT",
                "classification": "INTERNAL",
            },
        ),
        (
            "TOWER-REMOTE-001",
            "TOWER",
            "TELCO_SITE",
            "ACTIVE",
            {
                "height_m": 35,
                "site_id": "SITE-REMOTE-001",
                "grounding": "PRESENT",
            },
        ),
        (
            "GNB-REMOTE-001",
            "GNB",
            "RAN",
            "ACTIVE",
            {
                "rat": "5G_NR",
                "plmn": "LAB-001",
                "cell_group": "REMOTE_CLUSTER",
            },
        ),
        (
            "AAU-N78-A",
            "AAU_64T64R",
            "RF",
            "ACTIVE",
            {
                "frequency_hz": 3.5e9,
                "band": "n78",
                "azimuth_deg": 120,
                "tilt_deg": 4,
                "polarization": "dual_slant",
                "antenna_dimension_m": 0.8,
            },
        ),
        (
            "CELL-N78-A",
            "NR_CELL",
            "RAN",
            "ACTIVE",
            {
                "band": "n78",
                "dl_arfcn": "PLACEHOLDER",
                "bandwidth_mhz": 100,
                "serving_status": "ON_AIR_SIMULATED",
            },
        ),
        (
            "UE-REMOTE-001",
            "UE",
            "DEVICE",
            "ACTIVE",
            {
                "rat": "5G_NR",
                "trust": "NOMINAL",
                "position": {"lat": 41.9020, "lon": 12.5030, "altitude_m": 1.5},
            },
        ),
        (
            "UAV-ALPHA-001",
            "UAV",
            "UAV",
            "AIRBORNE",
            {
                "link": "5G_C2",
                "position": {"lat": 41.9040, "lon": 12.5060, "altitude_m": 120},
                "c2_latency_ms": 42,
            },
        ),
        (
            "IOT-FIRE-001",
            "IOT_SENSOR",
            "IOT",
            "MONITORING",
            {
                "sensor_type": "fire_temperature_smoke",
                "protocol": "NB-IOT_OR_MQTT",
                "position": {"lat": 41.9010, "lon": 12.5015, "altitude_m": 3},
            },
        ),
        (
            "V2X-CAR-001",
            "AUTONOMOUS_VEHICLE",
            "V2X",
            "MOVING",
            {
                "connectivity": "C-V2X",
                "position": {"lat": 41.8990, "lon": 12.4990, "altitude_m": 1.4},
                "speed_kmh": 42,
            },
        ),
        (
            "MW-LINK-REMOTE-REGIONAL",
            "MICROWAVE_LINK",
            "BACKHAUL",
            "ACTIVE",
            {
                "frequency_ghz": 18,
                "capacity_mbps": 300,
                "availability_target": "99.95%",
                "path": ["SITE-REMOTE-001", "POP-REGIONAL-001"],
            },
        ),
        (
            "POP-REGIONAL-001",
            "REGIONAL_POP",
            "NETWORK_FABRIC",
            "ACTIVE",
            {
                "role": "regional aggregation",
                "transport": "IP/MPLS_SR_READY",
            },
        ),
        (
            "CORE-5GC-001",
            "5GC_CORE",
            "TELCO_CORE",
            "ACTIVE",
            {
                "functions": ["AMF", "SMF", "UPF", "AUSF", "UDM", "PCF"],
                "open5gs_policy": "API_ONLY_NO_DIRECT_MONGODB",
            },
        ),
        (
            "IMS-SBC-001",
            "IMS_SBC",
            "SERVICE_CORE",
            "ACTIVE",
            {
                "service": "VoNR/VoLTE interconnect",
                "security_role": "border_control",
            },
        ),
        (
            "GWAN-TRANSATLANTIC-001",
            "GWAN_SEGMENT",
            "GLOBAL_NETWORK",
            "ACTIVE",
            {
                "path_type": "IPX_PEERING_SUBMARINE",
                "destination_hint": "New York",
                "latency_ms": 65,
            },
        ),
        (
            "WIFI-AP-MISSION-001",
            "WIFI_AP",
            "WIFI",
            "ACTIVE",
            {
                "ssid": "MISSION-NET",
                "security": "WPA3_ENTERPRISE",
                "band": "5/6GHz",
                "trusted": True,
            },
        ),
        (
            "ROGUE-CELL-PLACEHOLDER-001",
            "ROGUE_CELL_PLACEHOLDER",
            "ACCESS_TRUST",
            "LOCKED_SIMULATION_ONLY",
            {
                "purpose": "defensive simulation placeholder",
                "real_rf_emission": False,
            },
        ),
        (
            "ROGUE-WIFI-PLACEHOLDER-001",
            "ROGUE_WIFI_PLACEHOLDER",
            "ACCESS_TRUST",
            "LOCKED_SIMULATION_ONLY",
            {
                "purpose": "evil twin defensive simulation placeholder",
                "real_rf_emission": False,
            },
        ),
    ]

    for asset_id, asset_type, domain, status, data in assets:
        ar.upsert(asset_id, asset_type, domain, status, data)

    lr = AssetLinkRepository()

    links = [
        ("L-SITE-TOWER", "SITE-REMOTE-001", "TOWER-REMOTE-001", "CONTAINS"),
        ("L-TOWER-AAU", "TOWER-REMOTE-001", "AAU-N78-A", "MOUNTS"),
        ("L-AAU-CELL", "AAU-N78-A", "CELL-N78-A", "RADIATES"),
        ("L-CELL-GNB", "CELL-N78-A", "GNB-REMOTE-001", "SERVED_BY"),
        ("L-UE-CELL", "UE-REMOTE-001", "CELL-N78-A", "ATTACHED_TO"),
        ("L-UAV-CELL", "UAV-ALPHA-001", "CELL-N78-A", "C2_LINK_VIA"),
        ("L-IOT-CELL", "IOT-FIRE-001", "CELL-N78-A", "TELEMETRY_VIA"),
        ("L-V2X-CELL", "V2X-CAR-001", "CELL-N78-A", "V2X_LINK_VIA"),
        ("L-SITE-MW", "SITE-REMOTE-001", "MW-LINK-REMOTE-REGIONAL", "BACKHAUL_VIA"),
        ("L-MW-POP", "MW-LINK-REMOTE-REGIONAL", "POP-REGIONAL-001", "TERMINATES_AT"),
        ("L-POP-CORE", "POP-REGIONAL-001", "CORE-5GC-001", "ROUTES_TO"),
        ("L-CORE-IMS", "CORE-5GC-001", "IMS-SBC-001", "VOICE_SERVICE_VIA"),
        ("L-IMS-GWAN", "IMS-SBC-001", "GWAN-TRANSATLANTIC-001", "INTERNATIONAL_PATH_VIA"),
        ("L-WIFI-DEVICE", "UE-REMOTE-001", "WIFI-AP-MISSION-001", "TRUSTED_WIFI_PROFILE"),
        ("L-ROGUE-CELL-WATCH", "ROGUE-CELL-PLACEHOLDER-001", "UE-REMOTE-001", "MONITORS_RISK_FOR"),
        ("L-ROGUE-WIFI-WATCH", "ROGUE-WIFI-PLACEHOLDER-001", "UE-REMOTE-001", "MONITORS_RISK_FOR"),
    ]

    for link_id, src, dst, rel in links:
        lr.add(
            link_id=link_id,
            source_asset_id=src,
            target_asset_id=dst,
            relation_type=rel,
            data={"mission_id": "MISSION-FULL-TELCO-BOOT-001"},
        )

    EvidenceRepository().add(
        evidence_id="EVD-BOOT-0001",
        mission_id="MISSION-FULL-TELCO-BOOT-001",
        evidence_type="BOOTSTRAP",
        object_ref="sqlite://runtime/trfmc.db",
        hash_sha256=None,
        data={"note": "Initial persistence bootstrap evidence placeholder"},
    )

    IncidentRepository().upsert(
        incident_id="INC-BOOT-OBSERVABILITY-001",
        mission_id="MISSION-FULL-TELCO-BOOT-001",
        classification="BOOTSTRAP_OBSERVABILITY",
        severity="INFO",
        status="OPEN",
        data={"note": "Initial SOC/NOC incident placeholder for persistence validation"},
    )
