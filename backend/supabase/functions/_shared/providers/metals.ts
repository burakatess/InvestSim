/**
 * Metals Price Provider
 * Fetches precious metals prices from goldprice.org (free, no API key)
 */

import { PriceProvider, LatestPrice, OHLCV } from './interface.ts';

// goldprice.org free API
const METALS_API = 'https://data-asg.goldprice.org/dbXRates/USD';

export class MetalsPriceProvider implements PriceProvider {
    name = 'metals';

    async fetchLatest(symbols: string[]): Promise<Map<string, LatestPrice>> {
        const results = new Map<string, LatestPrice>();

        if (symbols.length === 0) return results;

        try {
            const response = await fetch(METALS_API);

            if (!response.ok) {
                console.error(`Metals API error: ${response.status}`);
                throw new Error(`Metals API error: ${response.status}`);
            }

            const data = await response.json();
            // Format: {"items":[{"xauPrice":4195.30,"xagPrice":58.31,"chgXau":-17.84,"pcXau":-0.42,...}]}
            const prices = data.items?.[0];

            if (!prices) {
                console.error('No price data from goldprice.org');
                return results;
            }

            console.log(`Metals API: XAU=${prices.xauPrice}, XAG=${prices.xagPrice}`);

            for (const symbol of symbols) {
                const symbolLower = symbol.toLowerCase();
                let price: number | undefined;
                let change24h = 0;

                // Map our symbols to API fields
                if (symbolLower === 'gold' || symbolLower === 'xauusd') {
                    price = prices.xauPrice;
                    change24h = prices.pcXau || 0;
                } else if (symbolLower === 'silver' || symbolLower === 'xagusd') {
                    price = prices.xagPrice;
                    change24h = prices.pcXag || 0;
                }
                // Note: goldprice.org only has gold/silver, platinum/palladium not available

                if (price !== undefined) {
                    console.log(`Metals: ${symbol} = ${price}, change: ${change24h}%`);
                    results.set(symbol, {
                        price: price,
                        change24h: change24h,
                    });
                }
            }
        } catch (error) {
            console.error('Metals fetchLatest error:', error);
        }

        return results;
    }

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        // goldprice.org doesn't provide historical data via free API
        // Return empty array - history should be fetched from prices_history table
        console.log(`Metals fetchHistory: Not implemented for ${symbol}`);
        return [];
    }
}

export const metalsProvider = new MetalsPriceProvider();
