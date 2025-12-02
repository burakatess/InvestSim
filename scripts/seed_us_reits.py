#!/usr/bin/env python3
"""
Seed US REITs to Supabase
Adds top 50 US Real Estate Investment Trusts
"""

import os
import sys
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://hplmwcjyfzjghijdqypa.supabase.co")
# Use SERVICE_ROLE key for write operations (bypasses RLS)
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"))

# Top 50 US REITs (mix of individual REITs and REIT ETFs)
US_REITS = [
    # REIT ETFs
    {"code": "VNQ", "name": "Vanguard Real Estate ETF", "category": "us_reit_etf"},
    {"code": "IYR", "name": "iShares U.S. Real Estate ETF", "category": "us_reit_etf"},
    {"code": "XLRE", "name": "Real Estate Select Sector SPDR", "category": "us_reit_etf"},
    {"code": "SCHH", "name": "Schwab U.S. REIT ETF", "category": "us_reit_etf"},
    {"code": "USRT", "name": "iShares Core U.S. REIT ETF", "category": "us_reit_etf"},
    
    # Individual REITs - Diversified
    {"code": "PLD", "name": "Prologis Inc", "category": "us_reit"},
    {"code": "AMT", "name": "American Tower Corp", "category": "us_reit"},
    {"code": "CCI", "name": "Crown Castle Inc", "category": "us_reit"},
    {"code": "EQIX", "name": "Equinix Inc", "category": "us_reit"},
    {"code": "PSA", "name": "Public Storage", "category": "us_reit"},
    {"code": "WELL", "name": "Welltower Inc", "category": "us_reit"},
    {"code": "DLR", "name": "Digital Realty Trust", "category": "us_reit"},
    {"code": "O", "name": "Realty Income Corp", "category": "us_reit"},
    {"code": "CBRE", "name": "CBRE Group Inc", "category": "us_reit"},
    {"code": "SPG", "name": "Simon Property Group", "category": "us_reit"},
    
    # Residential REITs
    {"code": "AVB", "name": "AvalonBay Communities", "category": "us_reit"},
    {"code": "EQR", "name": "Equity Residential", "category": "us_reit"},
    {"code": "MAA", "name": "Mid-America Apartment Communities", "category": "us_reit"},
    {"code": "UDR", "name": "UDR Inc", "category": "us_reit"},
    {"code": "ESS", "name": "Essex Property Trust", "category": "us_reit"},
    
    # Healthcare REITs
    {"code": "PEAK", "name": "Healthpeak Properties", "category": "us_reit"},
    {"code": "VTR", "name": "Ventas Inc", "category": "us_reit"},
    {"code": "DOC", "name": "Physicians Realty Trust", "category": "us_reit"},
    {"code": "HR", "name": "Healthcare Realty Trust", "category": "us_reit"},
    
    # Industrial REITs
    {"code": "DRE", "name": "Duke Realty Corp", "category": "us_reit"},
    {"code": "REXR", "name": "Rexford Industrial Realty", "category": "us_reit"},
    {"code": "FR", "name": "First Industrial Realty Trust", "category": "us_reit"},
    
    # Retail REITs
    {"code": "REG", "name": "Regency Centers Corp", "category": "us_reit"},
    {"code": "FRT", "name": "Federal Realty Investment Trust", "category": "us_reit"},
    {"code": "KIM", "name": "Kimco Realty Corp", "category": "us_reit"},
    
    # Office REITs
    {"code": "BXP", "name": "Boston Properties", "category": "us_reit"},
    {"code": "VNO", "name": "Vornado Realty Trust", "category": "us_reit"},
    {"code": "SLG", "name": "SL Green Realty Corp", "category": "us_reit"},
    
    # Data Center REITs
    {"code": "CONE", "name": "CyrusOne Inc", "category": "us_reit"},
    {"code": "QTS", "name": "QTS Realty Trust", "category": "us_reit"},
    
    # Self-Storage REITs
    {"code": "EXR", "name": "Extra Space Storage", "category": "us_reit"},
    {"code": "CUBE", "name": "CubeSmart", "category": "us_reit"},
    {"code": "LSI", "name": "Life Storage Inc", "category": "us_reit"},
    
    # Hotel REITs
    {"code": "HST", "name": "Host Hotels & Resorts", "category": "us_reit"},
    {"code": "RHP", "name": "Ryman Hospitality Properties", "category": "us_reit"},
    
    # Specialty REITs
    {"code": "INVH", "name": "Invitation Homes Inc", "category": "us_reit"},
    {"code": "AMH", "name": "American Homes 4 Rent", "category": "us_reit"},
    {"code": "STAG", "name": "STAG Industrial Inc", "category": "us_reit"},
    {"code": "COLD", "name": "Americold Realty Trust", "category": "us_reit"},
    {"code": "SBAC", "name": "SBA Communications Corp", "category": "us_reit"},
]

def seed_reits():
    """Seed US REITs to Supabase"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print(f"🏢 Seeding {len(US_REITS)} US REITs to Supabase...")
        
        added_count = 0
        skipped_count = 0
        
        for reit in US_REITS:
            asset_data = {
                "code": reit["code"],
                "name": reit["name"],
                "symbol": reit["code"],
                "category": reit["category"],
                "provider": "alpaca",  # Use Alpaca for real-time data
                "is_websocket": True,
                "websocket_provider": "alpaca"
            }
            
            try:
                # Upsert with on_conflict to handle duplicates
                result = supabase.table("assets").upsert(asset_data, on_conflict="code").execute()
                added_count += 1
                print(f"✅ Added: {reit['code']} - {reit['name']}")
            except Exception as e:
                if "duplicate key" in str(e).lower():
                    skipped_count += 1
                    print(f"⏭️ Skipped (exists): {reit['code']}")
                else:
                    raise
        
        print(f"\n🎉 Seeding complete! Added: {added_count}, Skipped: {skipped_count}")
        
    except Exception as e:
        print(f"❌ Error seeding REITs: {e}")
        sys.exit(1)

if __name__ == "__main__":
    seed_reits()
