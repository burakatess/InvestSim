#!/usr/bin/env python3
"""
Backfill historical US stock/ETF prices from Yahoo Finance
Usage: python3 backfill_us_stocks.py [days]
"""

import sys
from datetime import datetime, timedelta
import requests
import time

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzYyNjU2MSwiZXhwIjoyMDc5MjAyNTYxfQ.Ry3pPvVBJTwjGCEBvqcfLBYJgFXWQCDvGWKMCLCPxMo"

def get_date_range(days=730):
    """Calculate start and end dates (2 years = 730 days)"""
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    return int(start_date.timestamp()), int(end_date.timestamp())

def fetch_us_assets():
    """Fetch all US assets from database"""
    url = f"{SUPABASE_URL}/rest/v1/assets?select=code,symbol,category&category=in.(us_stock,us_etf)&is_active=eq.true"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }
    
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def fetch_yahoo_history(symbol, start_ts, end_ts):
    """Fetch historical data from Yahoo Finance"""
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
    params = {
        "period1": start_ts,
        "period2": end_ts,
        "interval": "1d",
        "events": "history"
    }
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        result = data.get("chart", {}).get("result", [])
        if not result:
            return None
            
        quote = result[0]
        timestamps = quote.get("timestamp", [])
        indicators = quote.get("indicators", {}).get("quote", [{}])[0]
        
        if not timestamps:
            return None
            
        # Extract OHLCV data
        opens = indicators.get("open", [])
        highs = indicators.get("high", [])
        lows = indicators.get("low", [])
        closes = indicators.get("close", [])
        volumes = indicators.get("volume", [])
        
        # Build historical data
        history = []
        for i, ts in enumerate(timestamps):
            # Skip if close price is None
            if i >= len(closes) or closes[i] is None:
                continue
                
            date = datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
            history.append({
                "date": date,
                "open": opens[i] if i < len(opens) and opens[i] else closes[i],
                "high": highs[i] if i < len(highs) and highs[i] else closes[i],
                "low": lows[i] if i < len(lows) and lows[i] else closes[i],
                "close": closes[i],
                "volume": volumes[i] if i < len(volumes) and volumes[i] else 0,
            })
        
        return history
        
    except Exception as e:
        print(f"  ❌ Error fetching {symbol}: {e}", file=sys.stderr)
        return None

def insert_historical_prices(prices, batch_size=1000):
    """Insert historical prices into database"""
    url = f"{SUPABASE_URL}/rest/v1/historical_prices"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }
    
    total = len(prices)
    inserted = 0
    
    for i in range(0, total, batch_size):
        batch = prices[i:i + batch_size]
        
        try:
            response = requests.post(url, json=batch, headers=headers)
            response.raise_for_status()
            
            inserted += len(batch)
            print(f"  Inserted {inserted}/{total} records", file=sys.stderr)
            
        except Exception as e:
            print(f"  ❌ Insert error: {e}", file=sys.stderr)
            if hasattr(response, 'text'):
                print(f"  Response: {response.text}", file=sys.stderr)
            raise
    
    return inserted

def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 730
    
    print("=" * 60)
    print("US STOCKS/ETFs HISTORICAL PRICE BACKFILL")
    print("=" * 60)
    
    # Get date range
    start_ts, end_ts = get_date_range(days)
    start_date = datetime.fromtimestamp(start_ts).strftime("%Y-%m-%d")
    end_date = datetime.fromtimestamp(end_ts).strftime("%Y-%m-%d")
    print(f"\n📅 Date Range: {start_date} to {end_date} ({days} days)")
    
    # Fetch US assets
    print("\n📊 Fetching US assets...")
    assets = fetch_us_assets()
    print(f"✓ Found {len(assets)} US assets")
    
    # Fetch historical data for each asset
    all_prices = []
    success_count = 0
    
    for idx, asset in enumerate(assets, 1):
        symbol = asset["symbol"]
        print(f"\n[{idx}/{len(assets)}] Fetching {symbol}...", file=sys.stderr)
        
        history = fetch_yahoo_history(symbol, start_ts, end_ts)
        
        if not history:
            print(f"  ⚠️  No data for {symbol}", file=sys.stderr)
            continue
        
        # Convert to historical_prices format
        for record in history:
            all_prices.append({
                "asset_code": asset["code"],
                "date": record["date"],
                "open": record["open"],
                "high": record["high"],
                "low": record["low"],
                "close": record["close"],
                "volume": record["volume"],
                "category": asset["category"],
                "provider": "yahoo_finance"
            })
        
        success_count += 1
        print(f"  ✓ {symbol}: {len(history)} days", file=sys.stderr)
        
        # Rate limiting - be nice to Yahoo
        time.sleep(0.5)
    
    print(f"\n✓ Fetched data for {success_count}/{len(assets)} assets")
    print(f"✓ Total records: {len(all_prices)}")
    
    # Insert into database
    if all_prices:
        print(f"\n💾 Inserting into Supabase...")
        inserted = insert_historical_prices(all_prices)
        
        print("\n" + "=" * 60)
        print(f"✅ SUCCESS!")
        print(f"   Assets: {success_count}/{len(assets)}")
        print(f"   Records: {inserted}")
        print("=" * 60)
    else:
        print("\n⚠️  No data to insert")

if __name__ == "__main__":
    main()
