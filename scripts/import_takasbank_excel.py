#!/usr/bin/env python3
"""
Takasbank Excel Fund Importer
Downloads Excel file from Takasbank and imports all funds
"""

import requests
import pandas as pd
from supabase import create_client, Client
import os

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'sb_secret_itAYWP8oiRMKedGYkVMQMA_pnGZ9MaW')

def download_takasbank_excel():
    """Download Excel file from Takasbank"""
    url = "https://www.takasbank.com.tr/plugins/ExcelExportTefasFundsTradingInvestmentPlatform?language=tr"
    
    print("Downloading TEFAS funds Excel from Takasbank...")
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    }
    
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    
    # Save Excel file
    filename = 'tefas_funds.xlsx'
    with open(filename, 'wb') as f:
        f.write(response.content)
    
    print(f"✓ Downloaded {len(response.content)} bytes")
    return filename

def parse_html_table(filename):
    """Parse HTML table and extract fund codes and names"""
    print(f"\nParsing HTML table from {filename}...")
    
    # Read HTML tables
    tables = pd.read_html(filename)
    
    if not tables:
        print("⚠️  No tables found in HTML")
        return []
    
    print(f"✓ Found {len(tables)} table(s)")
    
    # Use the largest table (likely the fund list)
    df = max(tables, key=len)
    print(f"✓ Using table with {len(df)} rows and {len(df.columns)} columns")
    print(f"✓ Columns: {list(df.columns)}")
    
    funds = []
    
    # Assume first column is code, second is name
    # Or try to find by column names
    code_col = df.columns[0]
    name_col = df.columns[1] if len(df.columns) > 1 else df.columns[0]
    
    print(f"✓ Using columns: '{code_col}' and '{name_col}'")
    
    # Extract funds
    for _, row in df.iterrows():
        code = str(row[code_col]).strip()
        name = str(row[name_col]).strip() if name_col else code
        
        # Validate code (should be 2-10 uppercase letters)
        if code and code != 'nan' and len(code) >= 2 and len(code) <= 10:
            # Skip header rows
            if not code.lower().startswith('fon') and not code.lower().startswith('kod'):
                funds.append({'code': code, 'name': name})
    
    print(f"✓ Extracted {len(funds)} valid funds")
    return funds

def sync_to_supabase(funds):
    """Sync all funds to Supabase"""
    if not funds:
        print("No funds to sync!")
        return 0
    
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    assets = []
    for fund in funds:
        assets.append({
            'code': fund['code'],
            'name': fund['name'],
            'symbol': fund['code'],
            'category': 'fund',
            'provider': 'tefas',
            'is_websocket': False
        })
    
    print(f"\nSyncing {len(assets)} funds to Supabase...")
    print("=" * 60)
    
    # Batch insert
    batch_size = 100
    success_count = 0
    
    for i in range(0, len(assets), batch_size):
        batch = assets[i:i+batch_size]
        try:
            result = supabase.table('assets').upsert(batch).execute()
            success_count += len(batch)
            print(f"✓ Batch {i//batch_size + 1}: {len(batch)} funds")
        except Exception as e:
            print(f"✗ Batch {i//batch_size + 1} error: {e}")
            # Try individual inserts for this batch
            for asset in batch:
                try:
                    supabase.table('assets').upsert([asset]).execute()
                    success_count += 1
                except:
                    pass
    
    print("=" * 60)
    print(f"✅ Successfully synced {success_count}/{len(assets)} funds\n")
    
    return success_count

if __name__ == "__main__":
    try:
        print("\n" + "=" * 60)
        print("TAKASBANK TEFAS EXCEL IMPORTER")
        print("=" * 60)
        
        # Download Excel
        excel_file = download_takasbank_excel()
        
        # Parse HTML table
        funds = parse_html_table(excel_file)
        
        if len(funds) > 0:
            # Sync to Supabase
            synced = sync_to_supabase(funds)
            
            print(f"🎉 COMPLETE!")
            print(f"   Total funds: {len(funds)}")
            print(f"   Synced: {synced}")
        else:
            print("\n⚠️  No funds found in Excel file")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
