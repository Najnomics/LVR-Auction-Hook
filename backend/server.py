"""
LVR Auction Hook Backend API Server
FastAPI-based backend for auction monitoring and data aggregation
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, Depends, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import structlog
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

from api.routes import auctions, operators, price_feeds, metrics
from services.auction_service import AuctionService
from services.price_service import PriceService
from services.operator_service import OperatorService
from utils.websocket_manager import WebSocketManager
from models.database import init_db

# Configure structured logging
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
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])

# Global services
auction_service: Optional[AuctionService] = None
price_service: Optional[PriceService] = None
operator_service: Optional[OperatorService] = None
websocket_manager: Optional[WebSocketManager] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global auction_service, price_service, operator_service, websocket_manager
    
    logger.info("Starting LVR Auction Hook Backend API")
    
    # Initialize database
    await init_db()
    
    # Initialize services
    auction_service = AuctionService()
    price_service = PriceService()
    operator_service = OperatorService()
    websocket_manager = WebSocketManager()
    
    # Start background tasks
    asyncio.create_task(price_service.start_monitoring())
    asyncio.create_task(auction_service.start_monitoring())
    asyncio.create_task(operator_service.start_monitoring())
    
    logger.info("All services started successfully")
    
    yield
    
    # Cleanup
    logger.info("Shutting down services...")
    await price_service.stop()
    await auction_service.stop()
    await operator_service.stop()
    logger.info("Shutdown complete")

# Create FastAPI app
app = FastAPI(
    title="LVR Auction Hook API",
    description="Backend API for LVR Auction Hook - MEV redistribution through EigenLayer AVS",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auctions.router, prefix="/api/v1/auctions", tags=["auctions"])
app.include_router(operators.router, prefix="/api/v1/operators", tags=["operators"])
app.include_router(price_feeds.router, prefix="/api/v1/price-feeds", tags=["price-feeds"])
app.include_router(metrics.router, prefix="/api/v1/metrics", tags=["metrics"])

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "LVR Auction Hook API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": "2024-01-01T00:00:00Z",
        "services": {
            "auction_service": auction_service.is_healthy() if auction_service else False,
            "price_service": price_service.is_healthy() if price_service else False,
            "operator_service": operator_service.is_healthy() if operator_service else False,
        }
    }

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time updates"""
    await websocket_manager.connect(websocket)
    try:
        while True:
            # Keep connection alive and handle incoming messages
            data = await websocket.receive_text()
            await websocket_manager.handle_message(websocket, data)
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Dependency injection
async def get_auction_service() -> AuctionService:
    if not auction_service:
        raise HTTPException(status_code=503, detail="Auction service not available")
    return auction_service

async def get_price_service() -> PriceService:
    if not price_service:
        raise HTTPException(status_code=503, detail="Price service not available")
    return price_service

async def get_operator_service() -> OperatorService:
    if not operator_service:
        raise HTTPException(status_code=503, detail="Operator service not available")
    return operator_service

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    logger.error("HTTP exception", status_code=exc.status_code, detail=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": exc.detail, "status_code": exc.status_code}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    logger.error("Unhandled exception", error=str(exc), exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "status_code": 500}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_level="info"
    )
