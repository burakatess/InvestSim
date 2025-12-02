import requests
import os
import time
import urllib3
from supabase import create_client, Client

# Suppress insecure request warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Supabase credentials (from your project)
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
# Using the Service Role Key provided by user
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_itAYWP8oiRMKedGYkVMQMA_pnGZ9MaW')

import json

def fetch_binance_assets():
    """Fetch all trading pairs from Binance with fallbacks"""
    urls = [
        "https://api.binance.com/api/v3/exchangeInfo",
        "https://data-api.binance.vision/api/v3/exchangeInfo"
    ]
    
    # 1. Try Online APIs
    for url in urls:
        print(f"Attempting to fetch assets from {url}...")
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            data = response.json()
            return process_response(data)
        except requests.exceptions.SSLError:
            print(f"⚠️ SSL Error with {url}. Trying insecure connection...")
            try:
                # Try without SSL verification as last resort for this URL
                response = requests.get(url, verify=False, timeout=10)
                response.raise_for_status()
                data = response.json()
                return process_response(data)
            except Exception as e:
                print(f"❌ Failed insecure connection to {url}: {e}")
        except Exception as e:
            print(f"❌ Error fetching from {url}: {e}")
            
    # 2. Fallback to Local JSON
    print("⚠️ All API attempts failed. Falling back to local data...")
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        json_path = os.path.join(script_dir, "binance_fallback_data.json")
        
        with open(json_path, 'r') as f:
            data = json.load(f)
            print(f"✅ Loaded {len(data)} assets from local fallback file.")
            return data
    except Exception as e:
        print(f"❌ Failed to load local fallback data: {e}")
        
    return []

def process_response(data):
    symbols = data.get('symbols', [])
    print(f"Found {len(symbols)} total symbols on Binance.")
    
    # Filter for USDT trading pairs
    active_pairs = [
        s for s in symbols 
        if s['status'] == 'TRADING' and s['quoteAsset'] == 'USDT'
    ]
    
    print(f"Filtered to {len(active_pairs)} active USDT pairs.")
    return active_pairs

def transform_to_supabase_asset(binance_symbol):
    """Transform Binance symbol to Supabase asset format"""
    symbol = binance_symbol['symbol'] # e.g. BTCUSDT
    base_asset = binance_symbol['baseAsset'] # e.g. BTC
    quote_asset = binance_symbol['quoteAsset'] # e.g. USDT
    
    # Schema: code, name, symbol, category, provider, is_websocket, websocket_provider
    return {
        "code": symbol, # Unique ID, e.g. BTCUSDT
        "name": f"{base_asset}/{quote_asset}", # e.g. BTC/USDT
        "symbol": symbol, # Display symbol, e.g. BTCUSDT
        "category": "crypto",
        "provider": "binance",
        "is_websocket": True,
        "websocket_provider": "binance"
    }

def seed_supabase():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # 1. Fetch from Binance
    binance_assets = fetch_binance_assets()
    
    if not binance_assets:
        print("No assets found. Exiting.")
        return

    # 2. Transform
    supabase_assets = [transform_to_supabase_asset(a) for a in binance_assets]
    
    # 3. Upsert in batches
    batch_size = 100
    total = len(supabase_assets)
    
    print(f"Starting upsert of {total} assets to Supabase...")
    
    for i in range(0, total, batch_size):
        batch = supabase_assets[i:i+batch_size]
        try:
            # Using upsert to update existing or insert new
            data = supabase.table("assets").upsert(batch, on_conflict="code").execute()
            print(f"✅ Batch {i//batch_size + 1}/{(total//batch_size) + 1} processed ({len(batch)} assets)")
            time.sleep(0.1) # Rate limit politeness
        except Exception as e:
            print(f"❌ Error upserting batch {i}: {e}")

    print("🎉 Seeding complete!")

if __name__ == "__main__":
    seed_supabase()
