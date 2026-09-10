"""
Authentication services.
"""


class AuthService:
    """Authentication service."""
    
    def __init__(self):
        self.name = "auth"
    
    async def get_status(self):
        """Get authentication service status."""
        return {
            "service": "authentication",
            "status": "operational",
            "features": ["jwt", "oauth2", "refresh_tokens"]
        }
