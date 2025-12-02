#!/usr/bin/env python3
"""
Seed US Mutual Funds to Supabase
Adds popular Vanguard, Fidelity, and Schwab mutual funds
"""

import os
import sys
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://hplmwcjyfzjghijdqypa.supabase.co")
# Use SERVICE_ROLE key for write operations (bypasses RLS)
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2MjY1NjEsImV4cCI6MjA3OTIwMjU2MX0.G5Cv2az01Jis-fH4P7ThakjQfVfGI8UMKwrY-hTh5k4"))

# Top US Mutual Funds
US_MUTUAL_FUNDS = [
    # Vanguard Index Funds
    {"code": "VFIAX", "name": "Vanguard 500 Index Admiral", "type": "Large Cap"},
    {"code": "VTSAX", "name": "Vanguard Total Stock Market Index Admiral", "type": "Total Market"},
    {"code": "VGTSX", "name": "Vanguard Total International Stock Index", "type": "International"},
    {"code": "VTIAX", "name": "Vanguard Total International Stock Index Admiral", "type": "International"},
    {"code": "VBTLX", "name": "Vanguard Total Bond Market Index Admiral", "type": "Bond"},
    {"code": "VBMFX", "name": "Vanguard Total Bond Market Index", "type": "Bond"},
    {"code": "VWELX", "name": "Vanguard Wellington Fund", "type": "Balanced"},
    {"code": "VWINX", "name": "Vanguard Wellesley Income Fund", "type": "Balanced"},
    {"code": "VWIUX", "name": "Vanguard Wellesley Income Admiral", "type": "Balanced"},
    {"code": "VGSLX", "name": "Vanguard Real Estate Index Admiral", "type": "Real Estate"},
    {"code": "VEXAX", "name": "Vanguard Extended Market Index Admiral", "type": "Mid/Small Cap"},
    {"code": "VSIAX", "name": "Vanguard Small-Cap Index Admiral", "type": "Small Cap"},
    {"code": "VMCAX", "name": "Vanguard Mid-Cap Index Admiral", "type": "Mid Cap"},
    {"code": "VIGAX", "name": "Vanguard Growth Index Admiral", "type": "Growth"},
    {"code": "VVIAX", "name": "Vanguard Value Index Admiral", "type": "Value"},
    
    # Fidelity Index Funds
    {"code": "FXAIX", "name": "Fidelity 500 Index", "type": "Large Cap"},
    {"code": "FSKAX", "name": "Fidelity Total Market Index", "type": "Total Market"},
    {"code": "FTIHX", "name": "Fidelity Total International Index", "type": "International"},
    {"code": "FXNAX", "name": "Fidelity U.S. Bond Index", "type": "Bond"},
    {"code": "FSMAX", "name": "Fidelity Extended Market Index", "type": "Mid/Small Cap"},
    {"code": "FSMDX", "name": "Fidelity Mid Cap Index", "type": "Mid Cap"},
    {"code": "FSSNX", "name": "Fidelity Small Cap Index", "type": "Small Cap"},
    {"code": "FZROX", "name": "Fidelity ZERO Total Market Index", "type": "Total Market"},
    {"code": "FZILX", "name": "Fidelity ZERO International Index", "type": "International"},
    
    # Schwab Index Funds
    {"code": "SWPPX", "name": "Schwab S&P 500 Index", "type": "Large Cap"},
    {"code": "SWTSX", "name": "Schwab Total Stock Market Index", "type": "Total Market"},
    {"code": "SWISX", "name": "Schwab International Index", "type": "International"},
    {"code": "SWAGX", "name": "Schwab U.S. Aggregate Bond Index", "type": "Bond"},
    {"code": "SWSSX", "name": "Schwab Small-Cap Index", "type": "Small Cap"},
    
    # Target Date Funds (Vanguard)
    {"code": "VTTVX", "name": "Vanguard Target Retirement 2025", "type": "Target Date"},
    {"code": "VTTHX", "name": "Vanguard Target Retirement 2030", "type": "Target Date"},
    {"code": "VTHRX", "name": "Vanguard Target Retirement 2035", "type": "Target Date"},
    {"code": "VFORX", "name": "Vanguard Target Retirement 2040", "type": "Target Date"},
    {"code": "VTIVX", "name": "Vanguard Target Retirement 2045", "type": "Target Date"},
    {"code": "VFIFX", "name": "Vanguard Target Retirement 2050", "type": "Target Date"},
    {"code": "VTTSX", "name": "Vanguard Target Retirement 2060", "type": "Target Date"},
]

def seed_mutual_funds():
    """Seed US Mutual Funds to Supabase"""
    try:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print(f"💰 Seeding {len(US_MUTUAL_FUNDS)} US Mutual Funds to Supabase...")
        
        added_count = 0
        skipped_count = 0
        
        for fund in US_MUTUAL_FUNDS:
            asset_data = {
                "code": fund["code"],
                "name": fund["name"],
                "symbol": fund["code"],
                "category": "us_mutual_fund",
                "provider": "yahoo",  # Yahoo Finance for EOD prices
                "is_websocket": False,  # Mutual funds are EOD only
                "websocket_provider": None
            }
            
            try:
                # Upsert with on_conflict to handle duplicates
                result = supabase.table("assets").upsert(asset_data, on_conflict="code").execute()
                added_count += 1
                print(f"✅ Added: {fund['code']} - {fund['name']} ({fund['type']})")
            except Exception as e:
                if "duplicate key" in str(e).lower():
                    skipped_count += 1
                    print(f"⏭️ Skipped (exists): {fund['code']}")
                else:
                    raise
        
        print(f"\n🎉 Seeding complete! Added: {added_count}, Skipped: {skipped_count}")
        
    except Exception as e:
        print(f"❌ Error seeding mutual funds: {e}")
        sys.exit(1)

if __name__ == "__main__":
    seed_mutual_funds()
