from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    project_name: str = "Telco RF Mission Control Platform"
    env: str = "dev"
    operational_mode: str = "SIMULATION_ONLY"
    restricted_enabled: bool = False

    class Config:
        env_prefix = "TRFMC_"

settings = Settings()
