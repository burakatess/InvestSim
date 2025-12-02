import requests
import os
import time
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_itAYWP8oiRMKedGYkVMQMA_pnGZ9MaW')

def fetch_us_etfs():
    """Fetch US ETFs from TradingView Scanner API"""
    print("Fetching US ETFs from TradingView Scanner...")
    url = "https://scanner.tradingview.com/america/scan"
    
    # Payload to get US ETFs
    # Simplified to avoid 400 Bad Request
    payload = {
        "filter": [
            {"left": "type", "operation": "equal", "right": "fund"},
            {"left": "exchange", "operation": "in_range", "right": ["AMEX", "NASDAQ", "NYSE"]},
            {"left": "active_symbol", "operation": "equal", "right": True}
        ],
        "options": {"lang": "en"},
        "symbols": {"query": {"types": []}},
        "columns": ["name", "description", "close", "type"], # Removed subtype
        "sort": {"sortBy": "capitalization", "sortOrder": "desc"},
        "range": [0, 500]
    }
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        response.raise_for_status()
        data = response.json()
        
        if data and 'data' in data:
            etfs = []
            for item in data['data']:
                # columns: ["name", "description", "close", "type"]
                ticker = item['d'][0]
                name = item['d'][1]
                
                # Filter specifically for ETFs if subtype is available and indicates ETF
                # TradingView 'fund' type often includes ETFs. Subtype might be 'etf'.
                # Let's include them if they look like ETFs.
                
                if ticker and name:
                    etfs.append({"code": ticker, "name": name})
            
            print(f"✅ Fetched {len(etfs)} ETFs from TradingView.")
            return etfs
            
    except Exception as e:
        print(f"⚠️ Failed to fetch from TradingView: {e}")
        
    return []

def transform_to_supabase_asset(etf):
    """Transform ETF to Supabase asset format"""
    return {
        "code": etf["code"], # e.g. SPY
        "name": etf["name"], # e.g. SPDR S&P 500 ETF Trust
        "symbol": etf["code"], # e.g. SPY
        "category": "us_etf", # Specific category for ETFs
        "provider": "alpaca", # We can use Alpaca for US ETFs too
        "is_websocket": True,
        "websocket_provider": "alpaca"
    }

def seed_supabase():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # 1. Fetch
    etfs = fetch_us_etfs()
    
    if not etfs:
        print("Using curated list of top 30 US ETFs.")
        fallback_etfs = [
            # Broad Market
            {"code": "SPY", "name": "SPDR S&P 500 ETF Trust"},
            {"code": "IVV", "name": "iShares Core S&P 500 ETF"},
            {"code": "VOO", "name": "Vanguard S&P 500 ETF"},
            {"code": "QQQ", "name": "Invesco QQQ Trust"},
            {"code": "VTI", "name": "Vanguard Total Stock Market ETF"},
            {"code": "DIA", "name": "SPDR Dow Jones Industrial Average ETF"},
            {"code": "IWM", "name": "iShares Russell 2000 ETF"},
            
            # International
            {"code": "VEA", "name": "Vanguard FTSE Developed Markets ETF"},
            {"code": "IEFA", "name": "iShares Core MSCI EAFE ETF"},
            {"code": "VWO", "name": "Vanguard FTSE Emerging Markets ETF"},
            {"code": "VXUS", "name": "Vanguard Total International Stock ETF"},
            {"code": "IEMG", "name": "iShares Core MSCI Emerging Markets ETF"},
            
            # Bonds
            {"code": "AGG", "name": "iShares Core U.S. Aggregate Bond ETF"},
            {"code": "BND", "name": "Vanguard Total Bond Market ETF"},
            {"code": "TLT", "name": "iShares 20+ Year Treasury Bond ETF"},
            {"code": "LQD", "name": "iShares iBoxx $ Inv Grade Corporate Bond ETF"},
            
            # Sectors
            {"code": "XLK", "name": "Technology Select Sector SPDR Fund"},
            {"code": "XLF", "name": "Financial Select Sector SPDR Fund"},
            {"code": "XLV", "name": "Health Care Select Sector SPDR Fund"},
            {"code": "XLE", "name": "Energy Select Sector SPDR Fund"},
            {"code": "VNQ", "name": "Vanguard Real Estate ETF"},
            
            # Commodities
            {"code": "GLD", "name": "SPDR Gold Shares"},
            {"code": "SLV", "name": "iShares Silver Trust"},
            
            # Styles
            {"code": "VUG", "name": "Vanguard Growth ETF"},
            {"code": "VTV", "name": "Vanguard Value ETF"},
            {"code": "VIG", "name": "Vanguard Dividend Appreciation ETF"},
            
            # Volatility & Others
            {"code": "TQQQ", "name": "ProShares UltraPro QQQ"},
            {"code": "SQQQ", "name": "ProShares UltraPro Short QQQ"},
            {"code": "ARKK", "name": "ARK Innovation ETF"},
            {"code": "SOXX", "name": "iShares Semiconductor ETF"}
        ]
        supabase_assets = [transform_to_supabase_asset(e) for e in fallback_etfs]
    else:
        supabase_assets = [transform_to_supabase_asset(e) for e in etfs]
    
    # 2. Upsert
    batch_size = 100
    total = len(supabase_assets)
    
    print(f"Starting upsert of {total} ETFs to Supabase...")
    
    for i in range(0, total, batch_size):
        batch = supabase_assets[i:i+batch_size]
        try:
            data = supabase.table("assets").upsert(batch, on_conflict="code").execute()
            print(f"✅ Batch {i//batch_size + 1}/{(total//batch_size) + 1} processed ({len(batch)} assets)")
            time.sleep(0.1)
        except Exception as e:
            print(f"❌ Error upserting batch {i}: {e}")

    print("🎉 Seeding complete!")

if __name__ == "__main__":
    seed_supabase()
