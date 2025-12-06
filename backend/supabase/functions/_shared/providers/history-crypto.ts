/**
 * History Provider - Crypto
 * Uses Binance API for historical OHLCV data
 * Supports pagination for 3+ years of data
 */

import { OHLCV } from './interface.ts';

const BINANCE_API = 'https://api.binance.com/api/v3';
const MAX_CANDLES_PER_REQUEST = 1000;

export class CryptoHistoryProvider {
    name = 'crypto-history';

    async fetchHistory(symbol: string, from: Date, to: Date): Promise<OHLCV[]> {
        const results: OHLCV[] = [];

        try {
            let currentStart = from.getTime();
            const endTime = to.getTime();

            // Paginate through data in 1000-candle chunks
            while (currentStart < endTime) {
                const url = `${BINANCE_API}/klines?symbol=${symbol}&interval=1d&startTime=${currentStart}&endTime=${endTime}&limit=${MAX_CANDLES_PER_REQUEST}`;

                console.log(`Fetching crypto history: ${symbol} from ${new Date(currentStart).toISOString().split('T')[0]}`);

                const response = await fetch(url);

                if (!response.ok) {
                    console.error(`Binance API error: ${response.status}`);
                    break;
                }

                const klines = await response.json();

                if (!klines || klines.length === 0) {
                    break;
                }

                for (const kline of klines) {
                    const date = new Date(kline[0]).toISOString().split('T')[0];
                    results.push({
                        date,
                        open: parseFloat(kline[1]),
                        high: parseFloat(kline[2]),
                        low: parseFloat(kline[3]),
                        close: parseFloat(kline[4]),
                        volume: parseFloat(kline[5]),
                    });
                }

                // Move start time to after last candle
                const lastTimestamp = klines[klines.length - 1][0];
                currentStart = lastTimestamp + 86400000; // +1 day in ms

                // Rate limiting
                await new Promise(resolve => setTimeout(resolve, 100));
            }

            console.log(`Fetched ${results.length} crypto history points for ${symbol}`);
        } catch (error) {
            console.error('Crypto history error:', error);
        }

        return results;
    }
}

export const cryptoHistoryProvider = new CryptoHistoryProvider();
