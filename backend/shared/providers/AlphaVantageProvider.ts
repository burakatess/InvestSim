/**
 * Alpha Vantage Provider
 * Handles commodities: Gold, Silver, Oil (WTI, Brent), Natural Gas, etc.
 * Free tier: 25 requests/day, 5 requests/minute
 */

import type { Asset, LatestPrice } from '../types/index.ts';

// Commodity symbol mapping for Alpha Vantage
const COMMODITY_MAPPING: Record<string, { function: string; symbol?: string }> = {
    // Precious Metals
    'XAUUSD': { function: 'COMMODITIES', symbol: 'GOLD' },
    'XAU': { function: 'COMMODITIES', symbol: 'GOLD' },
    'GOLD': { function: 'COMMODITIES', symbol: 'GOLD' },
    'XAGUSD': { function: 'COMMODITIES', symbol: 'SILVER' },
    'XAG': { function: 'COMMODITIES', symbol: 'SILVER' },
    'SILVER': { function: 'COMMODITIES', symbol: 'SILVER' },
    'XPTUSD': { function: 'COMMODITIES', symbol: 'PLATINUM' },
    'PLATINUM': { function: 'COMMODITIES', symbol: 'PLATINUM' },
    'XPDUSD': { function: 'COMMODITIES', symbol: 'PALLADIUM' },
    'PALLADIUM': { function: 'COMMODITIES', symbol: 'PALLADIUM' },

    // Energy
    'WTICOUSD': { function: 'WTI' },
    'WTI': { function: 'WTI' },
    'CRUDEOIL': { function: 'WTI' },
    'OIL': { function: 'WTI' },
    'BRENTOIL': { function: 'BRENT' },
    'BRENT': { function: 'BRENT' },
    'NATURALGAS': { function: 'NATURAL_GAS' },
    'NATGAS': { function: 'NATURAL_GAS' },

    // Agricultural (bonus)
    'WHEAT': { function: 'WHEAT' },
    'CORN': { function: 'CORN' },
    'COTTON': { function: 'COTTON' },
    'SUGAR': { function: 'SUGAR' },
    'COFFEE': { function: 'COFFEE' },
};

class AlphaVantageProvider {
    private apiKey: string;
    private baseUrl = 'https://www.alphavantage.co/query';
    private lastRequestTime = 0;
    private minRequestInterval = 12000; // 12 seconds (5 requests/min limit)

    constructor() {
        this.apiKey = Deno.env.get('ALPHAVANTAGE_API_KEY') || 'demo';
    }

    /**
     * Check if this provider supports the given asset
     */
    supports(asset: Asset): boolean {
        const code = asset.code.toUpperCase();
        return asset.provider === 'goldapi' ||
            asset.provider === 'alphavantage' ||
            asset.type === 'metal' ||
            asset.type === 'commodity' ||
            COMMODITY_MAPPING[code] !== undefined;
    }

    /**
     * Rate limiting - wait if needed
     */
    private async rateLimit(): Promise<void> {
        const now = Date.now();
        const elapsed = now - this.lastRequestTime;
        if (elapsed < this.minRequestInterval) {
            await new Promise(resolve =>
                setTimeout(resolve, this.minRequestInterval - elapsed)
            );
        }
        this.lastRequestTime = Date.now();
    }

    /**
     * Fetch latest price for a commodity
     */
    async getLatestPrice(asset: Asset): Promise<LatestPrice | null> {
        const code = asset.code.toUpperCase();
        const mapping = COMMODITY_MAPPING[code];

        if (!mapping) {
            console.log(`⚠️ AlphaVantage: Unknown commodity symbol: ${code}`);
            return null;
        }

        try {
            await this.rateLimit();

            let url: string;

            if (mapping.function === 'COMMODITIES') {
                // For precious metals, use COMMODITY_EXCHANGE_RATE
                url = `${this.baseUrl}?function=COMMODITY_EXCHANGE_RATE&from_symbol=${mapping.symbol}&to_symbol=USD&apikey=${this.apiKey}`;
            } else {
                // For energy and agricultural commodities
                url = `${this.baseUrl}?function=${mapping.function}&interval=daily&apikey=${this.apiKey}`;
            }

            console.log(`📊 AlphaVantage: Fetching ${code}...`);

            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();

            // Check for API errors
            if (data['Error Message'] || data['Note']) {
                console.error(`❌ AlphaVantage error for ${code}:`, data['Error Message'] || data['Note']);
                return null;
            }

            let price: number | null = null;

            // Parse response based on endpoint type
            if (mapping.function === 'COMMODITIES' && data['Realtime Commodity Exchange Rate']) {
                // Precious metals response format
                const rate = data['Realtime Commodity Exchange Rate'];
                price = parseFloat(rate['5. Exchange Rate'] || rate['Exchange Rate']);
            } else if (data['data'] && Array.isArray(data['data']) && data['data'].length > 0) {
                // Time series response format (energy, agricultural)
                const latestPoint = data['data'][0];
                price = parseFloat(latestPoint.value);
            }

            if (price === null || isNaN(price)) {
                console.log(`⚠️ AlphaVantage: Could not parse price for ${code}`);
                return null;
            }

            console.log(`✅ AlphaVantage: ${code} = $${price}`);

            return {
                asset_id: asset.id,
                price: price,
                percent_change_24h: null,
                provider: 'alphavantage',
                updated_at: new Date().toISOString(),
            };

        } catch (error) {
            console.error(`❌ AlphaVantage error for ${code}:`, error);
            return null;
        }
    }

    /**
     * Batch fetch - fetches one at a time due to rate limits
     */
    async getBatchPrices(assets: Asset[]): Promise<LatestPrice[]> {
        const results: LatestPrice[] = [];

        for (const asset of assets) {
            if (this.supports(asset)) {
                const price = await this.getLatestPrice(asset);
                if (price) {
                    results.push(price);
                }
            }
        }

        return results;
    }
}

export const alphaVantageProvider = new AlphaVantageProvider();
