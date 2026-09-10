"""
Structured logging configuration for TRFMC backend.

Uses structlog for structured logging with JSON output.
"""
import logging
import sys
from typing import Any

import structlog
from pythonjsonlogger import jsonlogger


def configure_logging(env: str = "dev") -> None:
    """
    Configure structured logging for application.
    
    Args:
        env: Environment (dev, staging, production)
    """
    # Determine log level based on environment
    log_level = "DEBUG" if env == "dev" else "INFO"
    
    # Configure structlog
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure stdlib logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )
    
    # Get root logger
    root_logger = logging.getLogger()
    
    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Add JSON handler for JSON output
    json_handler = logging.StreamHandler(sys.stdout)
    json_handler.setFormatter(
        jsonlogger.JsonFormatter(
            timestamp=True,
            datefmt="%Y-%m-%dT%H:%M:%S"
        )
    )
    root_logger.addHandler(json_handler)
    
    # Set level
    root_logger.setLevel(log_level)


def get_logger(name: str) -> structlog.typing.FilteringBoundLogger:
    """
    Get a configured logger for a module.
    
    Args:
        name: Logger name (usually __name__)
        
    Returns:
        Configured structlog logger
        
    Example:
        ```python
        logger = get_logger(__name__)
        logger.info("message", key="value", status=200)
        ```
    """
    return structlog.get_logger(name)


def log_request(
    request_id: str,
    method: str,
    path: str,
    query_params: dict | None = None,
    **extra: Any
) -> None:
    """
    Log incoming HTTP request.
    
    Args:
        request_id: Unique request identifier
        method: HTTP method (GET, POST, etc)
        path: Request path
        query_params: Query parameters dict
        **extra: Additional fields to log
    """
    logger = get_logger("api.request")
    logger.info(
        "request",
        request_id=request_id,
        method=method,
        path=path,
        query_params=query_params,
        **extra
    )


def log_response(
    request_id: str,
    status_code: int,
    duration_ms: float,
    **extra: Any
) -> None:
    """
    Log outgoing HTTP response.
    
    Args:
        request_id: Unique request identifier
        status_code: HTTP status code
        duration_ms: Request duration in milliseconds
        **extra: Additional fields to log
    """
    logger = get_logger("api.response")
    
    # Determine level based on status code
    if 200 <= status_code < 300:
        level = "info"
    elif 300 <= status_code < 400:
        level = "warning"
    elif 400 <= status_code < 500:
        level = "warning"
    else:
        level = "error"
    
    getattr(logger, level)(
        "response",
        request_id=request_id,
        status_code=status_code,
        duration_ms=duration_ms,
        **extra
    )


def log_error(
    error_type: str,
    message: str,
    request_id: str | None = None,
    **extra: Any
) -> None:
    """
    Log application error.
    
    Args:
        error_type: Type of error (e.g., "database_error")
        message: Error message
        request_id: Optional request identifier
        **extra: Additional context
    """
    logger = get_logger("app.error")
    logger.error(
        "error_occurred",
        error_type=error_type,
        message=message,
        request_id=request_id,
        **extra
    )


def log_service_call(
    service_name: str,
    method_name: str,
    duration_ms: float,
    success: bool = True,
    **extra: Any
) -> None:
    """
    Log service/method call.
    
    Args:
        service_name: Name of service
        method_name: Name of method called
        duration_ms: Execution duration in milliseconds
        success: Whether call succeeded
        **extra: Additional context
    """
    logger = get_logger("app.service")
    
    level = "info" if success else "error"
    getattr(logger, level)(
        "service_call",
        service_name=service_name,
        method_name=method_name,
        duration_ms=duration_ms,
        success=success,
        **extra
    )


def log_database_query(
    query_type: str,
    table: str,
    duration_ms: float,
    rows_affected: int | None = None,
    **extra: Any
) -> None:
    """
    Log database query.
    
    Args:
        query_type: Type of query (SELECT, INSERT, UPDATE, DELETE)
        table: Table name
        duration_ms: Query execution time
        rows_affected: Number of affected rows
        **extra: Additional context
    """
    logger = get_logger("db.query")
    logger.debug(
        "query_executed",
        query_type=query_type,
        table=table,
        duration_ms=duration_ms,
        rows_affected=rows_affected,
        **extra
    )


# Module-level logger
logger = get_logger(__name__)
