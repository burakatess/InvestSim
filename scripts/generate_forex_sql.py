#!/usr/bin/env python3
"""
Generate optimized SQL script for forex historical prices using batch INSERT
Only includes pairs that exist in the database
"""

import sys
from datetime import datetime, timedelta
import requests

def get_date_range(days=90):
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days)
    return start_date, end_date

def fetch_frankfurter_data(start_date, end_date, currencies):
    currencies_str = ",".join(currencies)
    all_data = {}
    current_start = start_date
    
    while current_start < end_date:
        current_end = min(current_start + timedelta(days=89), end_date)
        url = f"https://api.frankfurter.app/{current_start}..{current_end}?from=EUR&to={currencies_str}"
        print(f"Fetching {current_start} to {current_end}...", file=sys.stderr)
        
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            if "rates" in data:
                all_data.update(data["rates"])
                print(f"  ✓ Got {len(data['rates'])} days", file=sys.stderr)
        except Exception as e:
            print(f"  ❌ Error: {e}", file=sys.stderr)
        
        current_start = current_end + timedelta(days=1)
    
    return all_data

def generate_optimized_sql(forex_pairs, eur_rates):
    """Generate optimized batch INSERT"""
    print("-- Forex Historical Prices - Optimized Batch Import")
    print(f"-- Generated: {datetime.now()}")
    print(f"-- Total days: {len(eur_rates)}")
    print()
    print("BEGIN;")
    print()
    
    # Collect all values
    values = []
    for date_str, rates in sorted(eur_rates.items()):
        all_rates = {"EUR": 1.0, **rates}
        
        for pair in forex_pairs:
            # Parse pair (no slash)
            if len(pair) == 6:
                base = pair[:3]
                quote = pair[3:]
            else:
                continue
                
            base_rate = all_rates.get(base)
            quote_rate = all_rates.get(quote)
            
            if base_rate and quote_rate:
                cross_rate = quote_rate / base_rate
                values.append(f"('{pair}', '{date_str}', {cross_rate}, {cross_rate}, {cross_rate}, {cross_rate}, 'forex', 'frankfurter')")
    
    # Batch insert in chunks of 500
    chunk_size = 500
    for i in range(0, len(values), chunk_size):
        chunk = values[i:i + chunk_size]
        
        print("INSERT INTO historical_prices (asset_code, date, open, high, low, close, category, provider)")
        print("VALUES")
        print(",\n".join(chunk))
        print("ON CONFLICT (asset_code, date) DO UPDATE SET")
        print("  close = EXCLUDED.close;")
        print()
    
    print("COMMIT;")
    print()
    print(f"-- Total records: {len(values)}", file=sys.stderr)

def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 90
    
    # Only pairs that exist in database (from previous query)
    forex_pairs = [
        "USDTRY", "EURTRY", "GBPTRY", "CHFTRY", "JPYTRY", "AUDTRY", "CADTRY",
        "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD",
        "EURGBP", "EURJPY", "GBPJPY", "EURCHF", "EURAUD", "EURCAD",
        "USDRUB", "USDCNY", "USDINR", "USDBRL", "USDMXN", "USDZAR"
    ]
    
    currencies = set()
    for pair in forex_pairs:
        if len(pair) == 6:
            base = pair[:3]
            quote = pair[3:]
            currencies.add(base)
            currencies.add(quote)
    currencies.discard("EUR")
    
    print(f"Generating optimized SQL for {len(forex_pairs)} pairs...", file=sys.stderr)
    
    start_date, end_date = get_date_range(days)
    eur_rates = fetch_frankfurter_data(start_date, end_date, sorted(currencies))
    print(f"✓ Got {len(eur_rates)} days of data", file=sys.stderr)
    
    generate_optimized_sql(forex_pairs, eur_rates)

if __name__ == "__main__":
    main()
