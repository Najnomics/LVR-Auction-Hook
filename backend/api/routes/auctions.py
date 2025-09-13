"""
Auction API routes
"""

from typing import List, Optional
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from services.auction_service import AuctionService
from models.auction import Auction, AuctionStatus, Bid

router = APIRouter()

class AuctionResponse(BaseModel):
    id: str
    pool_id: str
    start_time: datetime
    duration: int
    status: AuctionStatus
    winner: Optional[str] = None
    winning_bid: Optional[float] = None
    total_bids: int
    mev_recovered: Optional[float] = None
    block_number: int

class AuctionCreateRequest(BaseModel):
    pool_id: str
    duration: int = Field(default=12, ge=1, le=60)
    min_bid: float = Field(default=0.001, ge=0.001)

class BidRequest(BaseModel):
    auction_id: str
    bidder: str
    amount: float
    commitment: str

class BidResponse(BaseModel):
    bid_id: str
    auction_id: str
    bidder: str
    amount: float
    timestamp: datetime
    revealed: bool

@router.get("/", response_model=List[AuctionResponse])
async def get_auctions(
    status: Optional[AuctionStatus] = Query(None, description="Filter by auction status"),
    limit: int = Query(50, ge=1, le=100, description="Number of auctions to return"),
    offset: int = Query(0, ge=0, description="Number of auctions to skip"),
    auction_service: AuctionService = Depends()
):
    """Get list of auctions with optional filtering"""
    try:
        auctions = await auction_service.get_auctions(
            status=status,
            limit=limit,
            offset=offset
        )
        return [AuctionResponse.from_orm(auction) for auction in auctions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch auctions: {str(e)}")

@router.get("/active", response_model=List[AuctionResponse])
async def get_active_auctions(auction_service: AuctionService = Depends()):
    """Get all currently active auctions"""
    try:
        auctions = await auction_service.get_active_auctions()
        return [AuctionResponse.from_orm(auction) for auction in auctions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch active auctions: {str(e)}")

@router.get("/{auction_id}", response_model=AuctionResponse)
async def get_auction(
    auction_id: str,
    auction_service: AuctionService = Depends()
):
    """Get specific auction by ID"""
    try:
        auction = await auction_service.get_auction_by_id(auction_id)
        if not auction:
            raise HTTPException(status_code=404, detail="Auction not found")
        return AuctionResponse.from_orm(auction)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch auction: {str(e)}")

@router.post("/", response_model=AuctionResponse)
async def create_auction(
    request: AuctionCreateRequest,
    auction_service: AuctionService = Depends()
):
    """Create a new auction"""
    try:
        auction = await auction_service.create_auction(
            pool_id=request.pool_id,
            duration=request.duration,
            min_bid=request.min_bid
        )
        return AuctionResponse.from_orm(auction)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create auction: {str(e)}")

@router.post("/{auction_id}/bids", response_model=BidResponse)
async def submit_bid(
    auction_id: str,
    request: BidRequest,
    auction_service: AuctionService = Depends()
):
    """Submit a sealed bid to an auction"""
    try:
        bid = await auction_service.submit_bid(
            auction_id=auction_id,
            bidder=request.bidder,
            amount=request.amount,
            commitment=request.commitment
        )
        return BidResponse.from_orm(bid)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to submit bid: {str(e)}")

@router.get("/{auction_id}/bids", response_model=List[BidResponse])
async def get_auction_bids(
    auction_id: str,
    auction_service: AuctionService = Depends()
):
    """Get all bids for an auction"""
    try:
        bids = await auction_service.get_auction_bids(auction_id)
        return [BidResponse.from_orm(bid) for bid in bids]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch bids: {str(e)}")

@router.post("/{auction_id}/reveal")
async def reveal_bid(
    auction_id: str,
    bidder: str = Query(..., description="Bidder address"),
    amount: float = Query(..., description="Bid amount"),
    nonce: str = Query(..., description="Bid nonce"),
    auction_service: AuctionService = Depends()
):
    """Reveal a sealed bid"""
    try:
        success = await auction_service.reveal_bid(
            auction_id=auction_id,
            bidder=bidder,
            amount=amount,
            nonce=nonce
        )
        if not success:
            raise HTTPException(status_code=400, detail="Failed to reveal bid")
        return {"message": "Bid revealed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reveal bid: {str(e)}")

@router.post("/{auction_id}/complete")
async def complete_auction(
    auction_id: str,
    winner: str = Query(..., description="Winner address"),
    winning_bid: float = Query(..., description="Winning bid amount"),
    auction_service: AuctionService = Depends()
):
    """Complete an auction with the winner"""
    try:
        success = await auction_service.complete_auction(
            auction_id=auction_id,
            winner=winner,
            winning_bid=winning_bid
        )
        if not success:
            raise HTTPException(status_code=400, detail="Failed to complete auction")
        return {"message": "Auction completed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to complete auction: {str(e)}")

@router.get("/stats/summary")
async def get_auction_stats(auction_service: AuctionService = Depends()):
    """Get auction statistics summary"""
    try:
        stats = await auction_service.get_auction_stats()
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch auction stats: {str(e)}")

@router.get("/pool/{pool_id}", response_model=List[AuctionResponse])
async def get_pool_auctions(
    pool_id: str,
    limit: int = Query(20, ge=1, le=100),
    auction_service: AuctionService = Depends()
):
    """Get auctions for a specific pool"""
    try:
        auctions = await auction_service.get_pool_auctions(pool_id, limit)
        return [AuctionResponse.from_orm(auction) for auction in auctions]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch pool auctions: {str(e)}")
