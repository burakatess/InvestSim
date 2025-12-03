import os
import time
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_itAYWP8oiRMKedGYkVMQMA_pnGZ9MaW')

# Curated list of Forex Pairs (Major, Minor, Exotic)
FOREX_PAIRS = [
    # Majors
    {"code": "EURUSD", "name": "Euro / US Dollar"},
    {"code": "GBPUSD", "name": "British Pound / US Dollar"},
    {"code": "USDJPY", "name": "US Dollar / Japanese Yen"},
    {"code": "USDCHF", "name": "US Dollar / Swiss Franc"},
    {"code": "AUDUSD", "name": "Australian Dollar / US Dollar"},
    {"code": "USDCAD", "name": "US Dollar / Canadian Dollar"},
    {"code": "NZDUSD", "name": "New Zealand Dollar / US Dollar"},
    
    # Minors / Crosses
    {"code": "EURGBP", "name": "Euro / British Pound"},
    {"code": "EURJPY", "name": "Euro / Japanese Yen"},
    {"code": "GBPJPY", "name": "British Pound / Japanese Yen"},
    {"code": "AUDJPY", "name": "Australian Dollar / Japanese Yen"},
    {"code": "EURAUD", "name": "Euro / Australian Dollar"},
    {"code": "EURCHF", "name": "Euro / Swiss Franc"},
    {"code": "AUDNZD", "name": "Australian Dollar / New Zealand Dollar"},
    
    # Exotics (featuring TRY)
    {"code": "USDTRY", "name": "US Dollar / Turkish Lira"},
    {"code": "EURTRY", "name": "Euro / Turkish Lira"},
    {"code": "GBPTRY", "name": "British Pound / Turkish Lira"},
    {"code": "TRYJPY", "name": "Turkish Lira / Japanese Yen"},
    {"code": "USDCNH", "name": "US Dollar / Chinese Yuan"},
    {"code": "USDZAR", "name": "US Dollar / South African Rand"},
    {"code": "USDMXN", "name": "US Dollar / Mexican Peso"},
    {"code": "USDBRL", "name": "US Dollar / Brazilian Real"},
    {"code": "USDRUB", "name": "US Dollar / Russian Ruble"},
    {"code": "USDINR", "name": "US Dollar / Indian Rupee"},
    {"code": "USDKRW", "name": "US Dollar / South Korean Won"}
]

# Commodities (GoldAPI / Tiingo)
COMMODITIES = [
    {"code": "XAUUSD", "name": "Gold / US Dollar", "provider": "goldapi", "symbol": "XAU/USD"},
    {"code": "XAGUSD", "name": "Silver / US Dollar", "provider": "goldapi", "symbol": "XAG/USD"},
    {"code": "XPTUSD", "name": "Platinum / US Dollar", "provider": "goldapi", "symbol": "XPT/USD"},
    {"code": "XPDUSD", "name": "Palladium / US Dollar", "provider": "goldapi", "symbol": "XPD/USD"},
    
    # Energy & Metals (Yahoo Finance)
    {"code": "CL=F", "name": "Crude Oil", "provider": "yahoo", "symbol": "CL=F"},
    {"code": "BZ=F", "name": "Brent Crude Oil", "provider": "yahoo", "symbol": "BZ=F"},
    {"code": "NG=F", "name": "Natural Gas", "provider": "yahoo", "symbol": "NG=F"},
    {"code": "HG=F", "name": "Copper", "provider": "yahoo", "symbol": "HG=F"}
]

def transform_forex(item):
    return {
        "code": item["code"], # e.g. EURUSD
        "name": item["name"], # e.g. Euro / US Dollar
        "symbol": item["code"], # e.g. EURUSD
        "category": "forex",
        "provider": "tiingo",
        "is_websocket": True,
        "websocket_provider": "tiingo"
    }

def transform_commodity(item):
    return {
        "code": item["code"], # e.g. XAUUSD
        "name": item["name"], # e.g. Gold / US Dollar
        "symbol": item["symbol"], # e.g. XAU/USD (GoldAPI format)
        "category": "commodity",
        "provider": item["provider"],
        "is_websocket": True,
        "websocket_provider": item["provider"]
    }

def seed_supabase():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    assets = []
    
    # Process Forex
    print(f"Preparing {len(FOREX_PAIRS)} Forex pairs...")
    for item in FOREX_PAIRS:
        assets.append(transform_forex(item))
        
    # Process Commodities
    print(f"Preparing {len(COMMODITIES)} Commodities...")
    for item in COMMODITIES:
        assets.append(transform_commodity(item))
    
    # Upsert in batches
    batch_size = 50
    total = len(assets)
    
    print(f"Starting upsert of {total} assets to Supabase...")
    
    for i in range(0, total, batch_size):
        batch = assets[i:i+batch_size]
        try:
            data = supabase.table("assets").upsert(batch, on_conflict="code").execute()
            print(f"✅ Batch {i//batch_size + 1}/{(total//batch_size) + 1} processed ({len(batch)} assets)")
            time.sleep(0.1)
        except Exception as e:
            print(f"❌ Error upserting batch {i}: {e}")

    print("🎉 Seeding complete!")

if __name__ == "__main__":
    seed_supabase()
