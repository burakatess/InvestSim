import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PriceHistoryRecord {
    asset_id: string
    date: string
    open: number
    high: number
    low: number
    close: number
    volume: number | null
    provider: string
}

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Get parameters
        const { days = 730 } = await req.json().catch(() => ({}))

        const endDate = new Date()
        const startDate = new Date()
        startDate.setDate(startDate.getDate() - days)

        // Fetch metal assets - use symbol and asset_class
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol')
            .eq('asset_class', 'metal')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No metal assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Get USD/TRY historical rates from Frankfurter
        const fxUrl = `https://api.frankfurter.app/${formatDate(startDate)}..${formatDate(endDate)}?from=USD&to=TRY`
        const fxResponse = await fetch(fxUrl)
        const fxData = await fxResponse.json()

        const priceRecords: PriceHistoryRecord[] = []

        // Reference metal prices in USD (approximate averages)
        // XAUUSD format symbols
        const metalPricesUSD: Record<string, number> = {
            'XAUUSD': 2050.00,   // Gold
            'XAGUSD': 24.50,    // Silver
            'XPTUSD': 920.00,   // Platinum
            'XAU': 2050.00,
            'XAG': 24.50,
            'XPT': 920.00,
        }

        // Process each date
        for (const [date, rates] of Object.entries(fxData.rates)) {
            for (const asset of assets) {
                const symbol = asset.symbol
                const priceUSD = metalPricesUSD[symbol]

                if (priceUSD) {
                    priceRecords.push({
                        asset_id: asset.id,
                        date: date,
                        open: priceUSD,
                        high: priceUSD,
                        low: priceUSD,
                        close: priceUSD,
                        volume: null,
                        provider: 'reference-price',
                    })
                }
            }
        }

        // Insert in batches to price_history table
        const batchSize = 1000
        let inserted = 0

        for (let i = 0; i < priceRecords.length; i += batchSize) {
            const batch = priceRecords.slice(i, i + batchSize)

            const { error: insertError } = await supabase
                .from('price_history')
                .upsert(batch, { onConflict: 'asset_id,date' })

            if (insertError) throw insertError

            inserted += batch.length
            console.log(`Inserted ${inserted}/${priceRecords.length}`)
        }

        return new Response(
            JSON.stringify({
                success: true,
                assets: assets.length,
                days: days,
                total_records: priceRecords.length,
                inserted: inserted,
                note: 'Using reference USD prices',
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: any) {
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})

function formatDate(date: Date): string {
    return date.toISOString().split('T')[0]
}
