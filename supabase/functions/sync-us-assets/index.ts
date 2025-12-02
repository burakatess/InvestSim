import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface USAsset {
    symbol: string
    name: string
    type: 'stock' | 'etf'
    sector?: string
}

// Top 100 US Stocks & ETFs
const US_ASSETS: USAsset[] = [
    // Mega Cap Tech (10)
    { symbol: 'AAPL', name: 'Apple Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'MSFT', name: 'Microsoft Corporation', type: 'stock', sector: 'Technology' },
    { symbol: 'GOOGL', name: 'Alphabet Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'AMZN', name: 'Amazon.com Inc.', type: 'stock', sector: 'Consumer' },
    { symbol: 'NVDA', name: 'NVIDIA Corporation', type: 'stock', sector: 'Technology' },
    { symbol: 'META', name: 'Meta Platforms Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'TSLA', name: 'Tesla Inc.', type: 'stock', sector: 'Automotive' },
    { symbol: 'BRK-B', name: 'Berkshire Hathaway Inc.', type: 'stock', sector: 'Finance' },
    { symbol: 'V', name: 'Visa Inc.', type: 'stock', sector: 'Finance' },
    { symbol: 'MA', name: 'Mastercard Inc.', type: 'stock', sector: 'Finance' },

    // Large Cap Tech (10)
    { symbol: 'AVGO', name: 'Broadcom Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'ORCL', name: 'Oracle Corporation', type: 'stock', sector: 'Technology' },
    { symbol: 'CSCO', name: 'Cisco Systems Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'ADBE', name: 'Adobe Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'CRM', name: 'Salesforce Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'NFLX', name: 'Netflix Inc.', type: 'stock', sector: 'Media' },
    { symbol: 'INTC', name: 'Intel Corporation', type: 'stock', sector: 'Technology' },
    { symbol: 'AMD', name: 'Advanced Micro Devices', type: 'stock', sector: 'Technology' },
    { symbol: 'QCOM', name: 'Qualcomm Inc.', type: 'stock', sector: 'Technology' },
    { symbol: 'TXN', name: 'Texas Instruments', type: 'stock', sector: 'Technology' },

    // Finance (10)
    { symbol: 'JPM', name: 'JPMorgan Chase & Co.', type: 'stock', sector: 'Finance' },
    { symbol: 'BAC', name: 'Bank of America Corp.', type: 'stock', sector: 'Finance' },
    { symbol: 'WFC', name: 'Wells Fargo & Company', type: 'stock', sector: 'Finance' },
    { symbol: 'GS', name: 'Goldman Sachs Group', type: 'stock', sector: 'Finance' },
    { symbol: 'MS', name: 'Morgan Stanley', type: 'stock', sector: 'Finance' },
    { symbol: 'AXP', name: 'American Express', type: 'stock', sector: 'Finance' },
    { symbol: 'BLK', name: 'BlackRock Inc.', type: 'stock', sector: 'Finance' },
    { symbol: 'SCHW', name: 'Charles Schwab Corp.', type: 'stock', sector: 'Finance' },
    { symbol: 'C', name: 'Citigroup Inc.', type: 'stock', sector: 'Finance' },
    { symbol: 'PNC', name: 'PNC Financial Services', type: 'stock', sector: 'Finance' },

    // Healthcare (10)
    { symbol: 'JNJ', name: 'Johnson & Johnson', type: 'stock', sector: 'Healthcare' },
    { symbol: 'UNH', name: 'UnitedHealth Group', type: 'stock', sector: 'Healthcare' },
    { symbol: 'PFE', name: 'Pfizer Inc.', type: 'stock', sector: 'Healthcare' },
    { symbol: 'ABBV', name: 'AbbVie Inc.', type: 'stock', sector: 'Healthcare' },
    { symbol: 'LLY', name: 'Eli Lilly and Company', type: 'stock', sector: 'Healthcare' },
    { symbol: 'MRK', name: 'Merck & Co. Inc.', type: 'stock', sector: 'Healthcare' },
    { symbol: 'TMO', name: 'Thermo Fisher Scientific', type: 'stock', sector: 'Healthcare' },
    { symbol: 'ABT', name: 'Abbott Laboratories', type: 'stock', sector: 'Healthcare' },
    { symbol: 'DHR', name: 'Danaher Corporation', type: 'stock', sector: 'Healthcare' },
    { symbol: 'BMY', name: 'Bristol-Myers Squibb', type: 'stock', sector: 'Healthcare' },

    // Consumer (10)
    { symbol: 'WMT', name: 'Walmart Inc.', type: 'stock', sector: 'Consumer' },
    { symbol: 'HD', name: 'Home Depot Inc.', type: 'stock', sector: 'Consumer' },
    { symbol: 'DIS', name: 'Walt Disney Company', type: 'stock', sector: 'Media' },
    { symbol: 'NKE', name: 'Nike Inc.', type: 'stock', sector: 'Consumer' },
    { symbol: 'MCD', name: 'McDonald\'s Corporation', type: 'stock', sector: 'Consumer' },
    { symbol: 'SBUX', name: 'Starbucks Corporation', type: 'stock', sector: 'Consumer' },
    { symbol: 'PG', name: 'Procter & Gamble', type: 'stock', sector: 'Consumer' },
    { symbol: 'KO', name: 'Coca-Cola Company', type: 'stock', sector: 'Consumer' },
    { symbol: 'PEP', name: 'PepsiCo Inc.', type: 'stock', sector: 'Consumer' },
    { symbol: 'COST', name: 'Costco Wholesale', type: 'stock', sector: 'Consumer' },

    // Energy (5)
    { symbol: 'XOM', name: 'Exxon Mobil Corporation', type: 'stock', sector: 'Energy' },
    { symbol: 'CVX', name: 'Chevron Corporation', type: 'stock', sector: 'Energy' },
    { symbol: 'COP', name: 'ConocoPhillips', type: 'stock', sector: 'Energy' },
    { symbol: 'SLB', name: 'Schlumberger Limited', type: 'stock', sector: 'Energy' },
    { symbol: 'EOG', name: 'EOG Resources Inc.', type: 'stock', sector: 'Energy' },

    // Industrial (5)
    { symbol: 'BA', name: 'Boeing Company', type: 'stock', sector: 'Industrial' },
    { symbol: 'CAT', name: 'Caterpillar Inc.', type: 'stock', sector: 'Industrial' },
    { symbol: 'GE', name: 'General Electric', type: 'stock', sector: 'Industrial' },
    { symbol: 'UPS', name: 'United Parcel Service', type: 'stock', sector: 'Industrial' },
    { symbol: 'HON', name: 'Honeywell International', type: 'stock', sector: 'Industrial' },

    // Popular ETFs - Broad Market (10)
    { symbol: 'SPY', name: 'SPDR S&P 500 ETF', type: 'etf' },
    { symbol: 'VOO', name: 'Vanguard S&P 500 ETF', type: 'etf' },
    { symbol: 'IVV', name: 'iShares Core S&P 500 ETF', type: 'etf' },
    { symbol: 'VTI', name: 'Vanguard Total Stock Market ETF', type: 'etf' },
    { symbol: 'QQQ', name: 'Invesco QQQ Trust', type: 'etf' },
    { symbol: 'DIA', name: 'SPDR Dow Jones Industrial Average ETF', type: 'etf' },
    { symbol: 'IWM', name: 'iShares Russell 2000 ETF', type: 'etf' },
    { symbol: 'VEA', name: 'Vanguard FTSE Developed Markets ETF', type: 'etf' },
    { symbol: 'VWO', name: 'Vanguard FTSE Emerging Markets ETF', type: 'etf' },
    { symbol: 'EFA', name: 'iShares MSCI EAFE ETF', type: 'etf' },

    // Sector ETFs (10)
    { symbol: 'XLF', name: 'Financial Select Sector SPDR', type: 'etf' },
    { symbol: 'XLE', name: 'Energy Select Sector SPDR', type: 'etf' },
    { symbol: 'XLK', name: 'Technology Select Sector SPDR', type: 'etf' },
    { symbol: 'XLV', name: 'Health Care Select Sector SPDR', type: 'etf' },
    { symbol: 'XLI', name: 'Industrial Select Sector SPDR', type: 'etf' },
    { symbol: 'XLY', name: 'Consumer Discretionary SPDR', type: 'etf' },
    { symbol: 'XLP', name: 'Consumer Staples SPDR', type: 'etf' },
    { symbol: 'XLU', name: 'Utilities Select Sector SPDR', type: 'etf' },
    { symbol: 'XLRE', name: 'Real Estate Select Sector SPDR', type: 'etf' },
    { symbol: 'XLB', name: 'Materials Select Sector SPDR', type: 'etf' },

    // Bond & Other ETFs (10)
    { symbol: 'AGG', name: 'iShares Core U.S. Aggregate Bond ETF', type: 'etf' },
    { symbol: 'BND', name: 'Vanguard Total Bond Market ETF', type: 'etf' },
    { symbol: 'TLT', name: 'iShares 20+ Year Treasury Bond ETF', type: 'etf' },
    { symbol: 'GLD', name: 'SPDR Gold Shares', type: 'etf' },
    { symbol: 'SLV', name: 'iShares Silver Trust', type: 'etf' },
    { symbol: 'VNQ', name: 'Vanguard Real Estate ETF', type: 'etf' },
    { symbol: 'EEM', name: 'iShares MSCI Emerging Markets ETF', type: 'etf' },
    { symbol: 'HYG', name: 'iShares iBoxx High Yield Corporate Bond ETF', type: 'etf' },
    { symbol: 'LQD', name: 'iShares iBoxx Investment Grade Corporate Bond ETF', type: 'etf' },
    { symbol: 'TIP', name: 'iShares TIPS Bond ETF', type: 'etf' },
]

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Prepare assets for insertion
        const assets = US_ASSETS.map(asset => ({
            code: asset.symbol,
            display_name: asset.name,
            category: asset.type === 'stock' ? 'us_stock' : 'us_etf',
            provider: 'yahoo_finance',
            symbol: asset.symbol,
            is_active: true,
            metadata: asset.sector ? { sector: asset.sector } : null,
        }))

        // Insert assets (upsert to avoid duplicates)
        const { data, error } = await supabase
            .from('assets')
            .upsert(assets, { onConflict: 'code' })
            .select()

        if (error) throw error

        return new Response(
            JSON.stringify({
                success: true,
                synced: assets.length,
                stocks: US_ASSETS.filter(a => a.type === 'stock').length,
                etfs: US_ASSETS.filter(a => a.type === 'etf').length,
                message: `Synced ${assets.length} US assets (${US_ASSETS.filter(a => a.type === 'stock').length} stocks, ${US_ASSETS.filter(a => a.type === 'etf').length} ETFs)`,
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: any) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})
