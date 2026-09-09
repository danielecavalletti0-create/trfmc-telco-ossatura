class AccessTrustService:
    def classify_rat(self, previous_rat: str, current_rat: str, known_cell: bool, normal_coverage: bool):
        classification, severity, privacy = "NORMAL_FALLBACK", "INFO", "LOW"
        if previous_rat in {"5G_NR","LTE"} and current_rat in {"2G_GSM","3G_UMTS"}:
            classification, severity, privacy = "COVERAGE_DRIVEN_FALLBACK", "WARNING", "MEDIUM"
            if normal_coverage and not known_cell:
                classification, severity, privacy = "SUSPICIOUS_RAT_DOWNGRADE", "HIGH", "HIGH"
        return {"classification":classification,"severity":severity,"privacy_exposure":privacy,"device_control_risk":"RADIO_INFLUENCE_NOT_FULL_DEVICE_COMPROMISE","recommended_actions":["Compare cell against authorized inventory","Check expected 4G/5G coverage","Generate evidence package","Use LTE/5G-only policy where operationally acceptable"]}
    def classify_wifi(self, expected_security: str, observed_security: str, inventory_match: bool, same_ssid: bool, known_bssid: bool):
        classification, severity, privacy = "NORMAL_ROAMING", "INFO", "LOW"
        if same_ssid and not known_bssid:
            classification, severity, privacy = "ROGUE_AP_SUSPECTED", "HIGH", "HIGH"
        if expected_security != observed_security:
            classification, severity, privacy = "SECURITY_DOWNGRADE", "HIGH", "HIGH"
        if same_ssid and not inventory_match and expected_security != observed_security:
            classification, severity, privacy = "EVIL_TWIN_SUSPECTED", "CRITICAL", "HIGH"
        return {"classification":classification,"severity":severity,"privacy_exposure":privacy,"recommended_actions":["Verify AP inventory","Validate RADIUS/certificate chain","Block unknown BSSID","Enforce VPN always-on on untrusted Wi-Fi"]}
