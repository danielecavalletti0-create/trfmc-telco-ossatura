class MissionService:
    def get_status(self):
        return {
            "mission_id": "MISSION-FULL-TELCO-BOOT-001",
            "name": "Full Telco Skeleton Bootstrap",
            "mode": "SIMULATION_ONLY",
            "status": "RUNNING",
            "domains": ["scientific_core", "global_network_fabric", "telco_mns", "assets", "access_trust", "soc_noc", "evidence", "restricted_locked"],
            "global_time_cursor_ms": 0,
        }
