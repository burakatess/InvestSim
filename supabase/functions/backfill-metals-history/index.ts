import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

        // Fetch metal assets
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, tefas_code')
            .eq('category', 'metal')

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

        const historicalPrices = []

        // For demo: using approximate metal prices in USD
        // In production, fetch from metals.dev or similar API
        const metalPricesUSD: Record<string, number> = {
            'XAU': 2050.00,  // Gold
            'XAG': 24.50,    // Silver
            'XPT': 920.00,   // Platinum
            'XPD': 1050.00,  // Palladium
            'XCU': 3.85,     // Copper
        }

        // Process each date
        for (const [date, rates] of Object.entries(fxData.rates)) {
            const usdToTry = (rates as any).TRY

            for (const asset of assets) {
                const metalCode = asset.tefas_code || asset.code
                const priceUSD = metalPricesUSD[metalCode]

                if (priceUSD && usdToTry) {
                    const priceTRY = priceUSD * usdToTry

                    historicalPrices.push({
                        asset_code: asset.code,
                        date: date,
                        open: priceTRY,
                        high: priceTRY,
                        low: priceTRY,
                        close: priceTRY,
                        volume: null,
                        category: 'metal',
                        provider: 'frankfurter-fx',
                    })
                }
            }
        }

        // Insert in batches
        const batchSize = 1000
        let inserted = 0

        for (let i = 0; i < historicalPrices.length; i += batchSize) {
            const batch = historicalPrices.slice(i, i + batchSize)

            const { error: insertError } = await supabase
                .from('historical_prices')
                .upsert(batch, { onConflict: 'asset_code,date' })

            if (insertError) throw insertError

            inserted += batch.length
            console.log(`Inserted ${inserted}/${historicalPrices.length}`)
        }

        return new Response(
            JSON.stringify({
                success: true,
                assets: assets.length,
                days: days,
                total_records: historicalPrices.length,
                inserted: inserted,
                note: 'Using reference USD prices with historical FX rates',
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
