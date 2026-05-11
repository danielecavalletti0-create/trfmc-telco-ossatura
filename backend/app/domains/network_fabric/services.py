class GlobalNetworkFabricService:
    destinations = {"New York":("USA",65.0),"Sydney":("Australia",210.0),"Pechino":("China",145.0),"Mumbai":("India",110.0),"Jakarta":("Indonesia",155.0),"Beirut":("Lebanon",75.0),"Il Cairo":("Egypt",60.0),"Stoccolma":("Sweden",45.0),"Buenos Aires":("Argentina",180.0)}
    def build_path(self, destination_city: str):
        country, gwan = self.destinations.get(destination_city, ("UNKNOWN",120.0))
        segments = [
            {"segment_id":"SEG-RAN","type":"RAN","source":"UE_REMOTE","destination":"GNB_REMOTE","latency_ms":8,"jitter_ms":1,"packet_loss_percent":0.02,"status":"NOMINAL"},
            {"segment_id":"SEG-BACKHAUL","type":"MICROWAVE_OR_SAT_BACKHAUL","source":"REMOTE_SITE","destination":"LOCAL_AGG","latency_ms":18,"jitter_ms":4,"packet_loss_percent":0.05,"capacity_mbps":300,"utilization_percent":44,"status":"NOMINAL"},
            {"segment_id":"SEG-REGIONAL","type":"REGIONAL_AGGREGATION","source":"LOCAL_AGG","destination":"REGIONAL_POP","latency_ms":10,"jitter_ms":1,"packet_loss_percent":0.01,"status":"NOMINAL"},
            {"segment_id":"SEG-CORE","type":"NATIONAL_5GC_IMS","source":"REGIONAL_POP","destination":"IMS_SBC","latency_ms":12,"jitter_ms":1,"packet_loss_percent":0.01,"status":"NOMINAL"},
            {"segment_id":"SEG-GWAN","type":"GWAN_IPX_PEERING_SUBMARINE_OR_SAT","source":"IMS_SBC","destination":f"REMOTE_OPERATOR_{destination_city}","latency_ms":gwan,"jitter_ms":max(4,gwan*0.08),"packet_loss_percent":0.08,"status":"NOMINAL" if gwan<180 else "DEGRADED"},
        ]
        rtt = 2 * sum(s["latency_ms"] for s in segments)
        mos = 4.3 if rtt < 180 else 3.7 if rtt < 350 else 3.1
        dominant = max(segments, key=lambda s: s["latency_ms"])["segment_id"]
        return {"path_id":f"PATH-REMOTE-UE-{destination_city.upper().replace(' ','-')}","mission_id":"MISSION-GLOBAL-SERVICE-JOURNEY-001","service_type":"VoNR","source":"Remote UE / Desert or rural site","destination_city":destination_city,"destination_country":country,"segments":segments,"estimated_rtt_ms":rtt,"mos_estimate":mos,"dominant_latency_segment":dominant}
