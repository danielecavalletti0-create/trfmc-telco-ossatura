from app.core.database import get_connection
from app.persistence.models import DDL_STATEMENTS
from app.persistence.repositories import (
    MissionRepository,
    AssetRepository,
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
            "version": "0.3-persistence",
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

    assets = [
        ("SITE-REMOTE-001", "RADIO_SITE", "TELCO_SITE", "ACTIVE", {"backhaul": "MICROWAVE_OR_SAT"}),
        ("GNB-REMOTE-001", "GNB", "RAN", "ACTIVE", {"rat": "5G_NR"}),
        ("AAU-N78-A", "AAU_64T64R", "RF", "ACTIVE", {"frequency_hz": 3.5e9}),
        ("UE-REMOTE-001", "UE", "DEVICE", "ACTIVE", {"rat": "5G_NR", "trust": "NOMINAL"}),
        ("UAV-ALPHA-001", "UAV", "UAV", "AIRBORNE", {"link": "5G_C2"}),
        ("IOT-FIRE-001", "IOT_SENSOR", "IOT", "MONITORING", {"protocol": "NB-IOT_OR_MQTT"}),
        ("V2X-CAR-001", "AUTONOMOUS_VEHICLE", "V2X", "MOVING", {"connectivity": "C-V2X"}),
    ]

    ar = AssetRepository()
    for asset_id, asset_type, domain, status, data in assets:
        ar.upsert(asset_id, asset_type, domain, status, data)

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
