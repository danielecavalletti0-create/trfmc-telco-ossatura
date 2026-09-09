"""Authentication services."""

class AuthService:
    def __init__(self):
        self.name = "auth"
    
    async def get_status(self):
        return {
            "service": "authentication",
            "status": "operational",
            "features": ["jwt", "oauth2", "refresh_tokens"]
        }
