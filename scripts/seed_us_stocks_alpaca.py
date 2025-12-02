import requests
import os
import time
import json
from supabase import create_client, Client

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_itAYWP8oiRMKedGYkVMQMA_pnGZ9MaW')

# Alpaca Credentials (from environment or hardcoded for script)
# Using the keys found in the project environment variables if available, or placeholders
ALPACA_API_KEY = os.getenv('ALPACA_API_KEY', 'PKNGSERWECSBCEMJJHSAANEHO5')
ALPACA_SECRET_KEY = os.getenv('ALPACA_SECRET_KEY', 'FG2ZyDPTzWS13xn6QRkUueFUVedhWQZdewJMZev92cTN') 
ALPACA_ENDPOINT = "https://paper-api.alpaca.markets"

def fetch_top_us_stocks():
    """Fetch Top 100 US Stocks by Market Cap from TradingView Scanner"""
    print("Fetching Top 100 US Stocks from TradingView Scanner...")
    url = "https://scanner.tradingview.com/america/scan"
    
    # Payload to get Top 100 US Stocks by Market Cap
    # Simplified to avoid 400 Bad Request
    payload = {
        "filter": [
            {"left": "type", "operation": "equal", "right": "stock"},
            {"left": "exchange", "operation": "in_range", "right": ["AMEX", "NASDAQ", "NYSE"]},
            {"left": "active_symbol", "operation": "equal", "right": True}
        ],
        "options": {"lang": "en"},
        "symbols": {"query": {"types": []}},
        "columns": ["name", "description", "close", "type"],
        "sort": {"sortBy": "capitalization", "sortOrder": "desc"},
        "range": [0, 100]
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
            stocks = []
            for item in data['data']:
                # columns: ["name", "description", "close", "type"]
                ticker = item['d'][0]
                name = item['d'][1]
                
                if ticker and name:
                    stocks.append({"symbol": ticker, "name": name})
            
            print(f"✅ Fetched {len(stocks)} top US stocks from TradingView.")
            return stocks
            
    except Exception as e:
        print(f"⚠️ Failed to fetch from TradingView: {e}")
        return []

def transform_to_supabase_asset(alpaca_asset):
    """Transform Alpaca asset to Supabase asset format"""
    symbol = alpaca_asset['symbol']
    name = alpaca_asset.get('name', symbol)
    
    # Schema: code, name, symbol, category, provider, is_websocket, websocket_provider
    return {
        "code": symbol, # Unique ID, e.g. AAPL
        "name": name, # e.g. Apple Inc.
        "symbol": symbol, # Display symbol, e.g. AAPL
        "category": "us_stock",
        "provider": "alpaca",
        "is_websocket": True,
        "websocket_provider": "alpaca"
    }

def seed_supabase():
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # 1. Fetch Top 100
    alpaca_assets = fetch_top_us_stocks()
    
    if not alpaca_assets:
        print("Using curated list of top 100 US stocks...")
        # Top 100 US Stocks by Market Cap (Blue Chips + Popular Growth Stocks)
        fallback_symbols = [
            # Mega Cap Tech
            {"symbol": "AAPL", "name": "Apple Inc."},
            {"symbol": "MSFT", "name": "Microsoft Corporation"},
            {"symbol": "GOOGL", "name": "Alphabet Inc. Class A"},
            {"symbol": "GOOG", "name": "Alphabet Inc. Class C"},
            {"symbol": "AMZN", "name": "Amazon.com Inc."},
            {"symbol": "NVDA", "name": "NVIDIA Corporation"},
            {"symbol": "META", "name": "Meta Platforms Inc."},
            {"symbol": "TSLA", "name": "Tesla Inc."},
            
            # Tech & Software
            {"symbol": "AVGO", "name": "Broadcom Inc."},
            {"symbol": "ORCL", "name": "Oracle Corporation"},
            {"symbol": "ADBE", "name": "Adobe Inc."},
            {"symbol": "CRM", "name": "Salesforce Inc."},
            {"symbol": "CSCO", "name": "Cisco Systems Inc."},
            {"symbol": "INTC", "name": "Intel Corporation"},
            {"symbol": "AMD", "name": "Advanced Micro Devices Inc."},
            {"symbol": "QCOM", "name": "QUALCOMM Inc."},
            {"symbol": "TXN", "name": "Texas Instruments Inc."},
            {"symbol": "NFLX", "name": "Netflix Inc."},
            {"symbol": "UBER", "name": "Uber Technologies Inc."},
            {"symbol": "ABNB", "name": "Airbnb Inc."},
            {"symbol": "SNOW", "name": "Snowflake Inc."},
            {"symbol": "PLTR", "name": "Palantir Technologies Inc."},
            
            # Finance
            {"symbol": "BRK.B", "name": "Berkshire Hathaway Inc. Class B"},
            {"symbol": "JPM", "name": "JPMorgan Chase & Co."},
            {"symbol": "V", "name": "Visa Inc."},
            {"symbol": "MA", "name": "Mastercard Inc."},
            {"symbol": "BAC", "name": "Bank of America Corp."},
            {"symbol": "WFC", "name": "Wells Fargo & Co."},
            {"symbol": "GS", "name": "Goldman Sachs Group Inc."},
            {"symbol": "MS", "name": "Morgan Stanley"},
            {"symbol": "AXP", "name": "American Express Co."},
            {"symbol": "BLK", "name": "BlackRock Inc."},
            
            # Healthcare & Pharma
            {"symbol": "UNH", "name": "UnitedHealth Group Inc."},
            {"symbol": "JNJ", "name": "Johnson & Johnson"},
            {"symbol": "LLY", "name": "Eli Lilly and Co."},
            {"symbol": "ABBV", "name": "AbbVie Inc."},
            {"symbol": "MRK", "name": "Merck & Co. Inc."},
            {"symbol": "PFE", "name": "Pfizer Inc."},
            {"symbol": "TMO", "name": "Thermo Fisher Scientific Inc."},
            {"symbol": "ABT", "name": "Abbott Laboratories"},
            {"symbol": "DHR", "name": "Danaher Corporation"},
            
            # Consumer
            {"symbol": "WMT", "name": "Walmart Inc."},
            {"symbol": "HD", "name": "Home Depot Inc."},
            {"symbol": "COST", "name": "Costco Wholesale Corp."},
            {"symbol": "PG", "name": "Procter & Gamble Co."},
            {"symbol": "KO", "name": "Coca-Cola Co."},
            {"symbol": "PEP", "name": "PepsiCo Inc."},
            {"symbol": "MCD", "name": "McDonald's Corp."},
            {"symbol": "NKE", "name": "Nike Inc."},
            {"symbol": "SBUX", "name": "Starbucks Corp."},
            {"symbol": "TGT", "name": "Target Corp."},
            
            # Industrial & Energy
            {"symbol": "XOM", "name": "Exxon Mobil Corp."},
            {"symbol": "CVX", "name": "Chevron Corp."},
            {"symbol": "BA", "name": "Boeing Co."},
            {"symbol": "CAT", "name": "Caterpillar Inc."},
            {"symbol": "GE", "name": "General Electric Co."},
            {"symbol": "RTX", "name": "RTX Corporation"},
            {"symbol": "LMT", "name": "Lockheed Martin Corp."},
            
            # Telecom & Media
            {"symbol": "T", "name": "AT&T Inc."},
            {"symbol": "VZ", "name": "Verizon Communications Inc."},
            {"symbol": "CMCSA", "name": "Comcast Corp."},
            {"symbol": "DIS", "name": "Walt Disney Co."},
            
            # Semiconductors
            {"symbol": "ASML", "name": "ASML Holding NV"},
            {"symbol": "TSM", "name": "Taiwan Semiconductor Manufacturing"},
            {"symbol": "AMAT", "name": "Applied Materials Inc."},
            {"symbol": "LRCX", "name": "Lam Research Corp."},
            {"symbol": "KLAC", "name": "KLA Corporation"},
            {"symbol": "MU", "name": "Micron Technology Inc."},
            
            # E-commerce & Retail
            {"symbol": "BABA", "name": "Alibaba Group Holding Ltd."},
            {"symbol": "SHOP", "name": "Shopify Inc."},
            {"symbol": "MELI", "name": "MercadoLibre Inc."},
            
            # Automotive
            {"symbol": "F", "name": "Ford Motor Co."},
            {"symbol": "GM", "name": "General Motors Co."},
            {"symbol": "RIVN", "name": "Rivian Automotive Inc."},
            
            # Biotech
            {"symbol": "GILD", "name": "Gilead Sciences Inc."},
            {"symbol": "AMGN", "name": "Amgen Inc."},
            {"symbol": "VRTX", "name": "Vertex Pharmaceuticals Inc."},
            {"symbol": "REGN", "name": "Regeneron Pharmaceuticals Inc."},
            
            # Payment & Fintech
            {"symbol": "PYPL", "name": "PayPal Holdings Inc."},
            {"symbol": "SQ", "name": "Block Inc."},
            {"symbol": "COIN", "name": "Coinbase Global Inc."},
            
            # Cloud & Cybersecurity
            {"symbol": "NOW", "name": "ServiceNow Inc."},
            {"symbol": "PANW", "name": "Palo Alto Networks Inc."},
            {"symbol": "CRWD", "name": "CrowdStrike Holdings Inc."},
            {"symbol": "ZS", "name": "Zscaler Inc."},
            
            # Entertainment & Gaming
            {"symbol": "SPOT", "name": "Spotify Technology SA"},
            {"symbol": "RBLX", "name": "Roblox Corp."},
            {"symbol": "EA", "name": "Electronic Arts Inc."},
            
            # Other Notable
            {"symbol": "IBM", "name": "International Business Machines"},
            {"symbol": "SPGI", "name": "S&P Global Inc."},
            {"symbol": "ISRG", "name": "Intuitive Surgical Inc."},
            {"symbol": "INTU", "name": "Intuit Inc."},
            {"symbol": "ADSK", "name": "Autodesk Inc."},
            {"symbol": "MRNA", "name": "Moderna Inc."}
        ]
        print(f"Using {len(fallback_symbols)} curated US stocks.")
        supabase_assets = [transform_to_supabase_asset(a) for a in fallback_symbols]
    else:
        # 2. Transform
        # Limit to top 100 or so to avoid overwhelming if needed, or take all
        # For now, let's take all but process in batches
        supabase_assets = [transform_to_supabase_asset(a) for a in alpaca_assets]
    
    # 3. Upsert in batches
    batch_size = 100
    total = len(supabase_assets)
    
    print(f"Starting upsert of {total} assets to Supabase...")
    
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
