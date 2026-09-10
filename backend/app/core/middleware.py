"""
FastAPI middleware for structured logging and observability.
"""
import time
import uuid
from typing import Callable

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from app.core.logging import log_request, log_response


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware che loga tutte le richieste e risposte con timestamp e duration.
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """
        Process request, log it, and log response.
        """
        # Generate request ID
        request_id = str(uuid.uuid4())[:8]
        
        # Extract request info
        method = request.method
        path = request.url.path
        query_params = dict(request.query_params) if request.query_params else None
        client_host = request.client.host if request.client else "unknown"
        
        # Log incoming request
        log_request(
            request_id=request_id,
            method=method,
            path=path,
            query_params=query_params,
            client=client_host,
        )
        
        # Store request ID in state for use in handlers
        request.state.request_id = request_id
        
        # Time the request processing
        start_time = time.time()
        
        try:
            # Process request
            response = await call_next(request)
            
            # Calculate duration
            duration_ms = (time.time() - start_time) * 1000
            
            # Log response
            log_response(
                request_id=request_id,
                status_code=response.status_code,
                duration_ms=f"{duration_ms:.2f}",
            )
            
            return response
            
        except Exception as exc:
            # Calculate duration for error case
            duration_ms = (time.time() - start_time) * 1000
            
            # Log error response
            log_response(
                request_id=request_id,
                status_code=500,
                duration_ms=f"{duration_ms:.2f}",
            )
            
            raise


class ErrorHandlingMiddleware(BaseHTTPMiddleware):
    """
    Middleware per gestire errori non previsti e loggare opportunamente.
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """
        Catch and log errors.
        """
        try:
            return await call_next(request)
        except Exception as exc:
            # Get request ID if available
            request_id = getattr(request.state, "request_id", "unknown")
            
            # Log the error with full context
            import logging
            logger = logging.getLogger(__name__)
            logger.exception(
                f"Unhandled error for request {request_id}",
                extra={
                    "request_id": request_id,
                    "path": request.url.path,
                    "method": request.method,
                }
            )
            
            raise
