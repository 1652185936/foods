from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class MigrationSettings(BaseSettings):
    """The complete configuration surface available to Alembic."""

    model_config = SettingsConfigDict(
        env_prefix="ORDIN_",
        case_sensitive=False,
        env_file=".env",
        extra="ignore",
    )

    database_url: str = Field(
        default="postgresql+psycopg://ordin:ordin@127.0.0.1:55432/ordin",
        min_length=1,
    )
