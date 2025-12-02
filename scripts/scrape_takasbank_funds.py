#!/usr/bin/env python3
"""
Takasbank TEFAS Fund Scraper
Scrapes ALL ~960 funds from Takasbank official list
48 pages × 20 funds per page
"""

import requests
from bs4 import BeautifulSoup
import json
import time
from supabase import create_client, Client
import os

# Supabase credentials
SUPABASE_URL = "https://hplmwcjyfzjghijdqypa.supabase.co"
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwbG13Y2p5ZnpqZ2hpamRxeXBhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzYyNjU2MSwiZXhwIjoyMDc5MjAyNTYxfQ.Ry3pPvVBJTwjGCEBvqcfLBYJgFXWQCDvGWKMCLCPxMo')

def scrape_takasbank_funds():
    """Scrape all funds from Takasbank (48 pages)"""
    base_url = "https://www.takasbank.com.tr/tr/kaynaklar/tefas-yatirim-fonlari"
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }
    
    all_funds = {}
    
    print("Scraping Takasbank TEFAS fund list...")
    print("=" * 60)
    
    # Scrape all 48 pages
    for page in range(1, 49):
        url = f"{base_url}?page={page}" if page > 1 else base_url
        
        try:
            print(f"Page {page}/48...", end=' ')
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find fund table
            # Takasbank uses a table structure
            table = soup.find('table') or soup.find('div', class_='table')
            
            if table:
                rows = table.find_all('tr')[1:]  # Skip header
                
                for row in rows:
                    cells = row.find_all('td')
                    if len(cells) >= 2:
                        # First column: Fund code, Second column: Fund name
                        code = cells[0].get_text(strip=True)
                        name = cells[1].get_text(strip=True)
                        
                        if code and len(code) >= 2 and len(code) <= 10:
                            all_funds[code] = name
                
                print(f"✓ Found {len(rows)} funds")
            else:
                # Try alternative structure
                # Look for fund list in divs or other elements
                fund_items = soup.find_all('div', class_=lambda x: x and 'fund' in x.lower())
                
                for item in fund_items:
                    # Extract code and name
                    code_elem = item.find(class_=lambda x: x and 'code' in x.lower())
                    name_elem = item.find(class_=lambda x: x and 'name' in x.lower())
                    
                    if code_elem and name_elem:
                        code = code_elem.get_text(strip=True)
                        name = name_elem.get_text(strip=True)
                        if code:
                            all_funds[code] = name
                
                print(f"✓ Found {len(fund_items)} funds")
            
            # Be nice to the server
            time.sleep(0.5)
            
        except Exception as e:
            print(f"✗ Error: {e}")
            continue
    
    print("=" * 60)
    print(f"Total unique funds scraped: {len(all_funds)}")
    
    return [{'code': k, 'name': v} for k, v in all_funds.items()]

def sync_to_supabase(funds):
    """Sync all funds to Supabase"""
    if not funds:
        print("No funds to sync!")
        return 0
    
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    assets = []
    for fund in funds:
        code = fund['code']
        name = fund['name'] or code
        
        assets.append({
            'code': code,
            'display_name': name,
            'category': 'fund',
            'provider': 'tefas',
            'tefas_code': code,
            'is_active': True
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
            print(f"✓ Batch {i//batch_size + 1}/{(len(assets)-1)//batch_size + 1}: {len(batch)} funds")
        except Exception as e:
            print(f"✗ Batch {i//batch_size + 1} error: {e}")
    
    print("=" * 60)
    print(f"✅ Successfully synced {success_count}/{len(assets)} funds")
    
    return success_count

def save_to_json(funds, filename='tefas_funds.json'):
    """Save funds to JSON file as backup"""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(funds, f, ensure_ascii=False, indent=2)
    print(f"\n💾 Saved to {filename}")

if __name__ == "__main__":
    try:
        print("\n" + "=" * 60)
        print("TAKASBANK TEFAS FUND SCRAPER")
        print("=" * 60)
        print("Scraping all ~960 funds from official Takasbank list\n")
        
        # Scrape all funds
        funds = scrape_takasbank_funds()
        
        if len(funds) == 0:
            print("\n⚠️  No funds scraped. Check if website structure changed.")
            print("Falling back to manual list...")
            # You can add fallback here
        else:
            # Save to JSON as backup
            save_to_json(funds)
            
            # Sync to Supabase
            synced = sync_to_supabase(funds)
            
            print(f"\n🎉 COMPLETE!")
            print(f"   Funds scraped: {len(funds)}")
            print(f"   Funds synced: {synced}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
