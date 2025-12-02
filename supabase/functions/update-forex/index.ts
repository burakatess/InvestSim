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

        // Fetch forex assets from DB
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code')
            .eq('category', 'forex')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No forex assets found' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Fetch exchange rates from Frankfurter API (free, no key required)
        const frankfurterResponse = await fetch('https://api.frankfurter.app/latest?from=USD')

        if (!frankfurterResponse.ok) {
            throw new Error(`Frankfurter API Error: ${frankfurterResponse.statusText}`)
        }

        const frankfurterData = await frankfurterResponse.json()
        const updates = []

        // Process each forex asset
        for (const asset of assets) {
            let rate = null

            // Handle different currency pair formats (e.g., "USDTRY", "USD/TRY", "USD-TRY")
            const code = asset.code.toUpperCase().replace(/[\/\-]/g, '')

            // Extract base and quote currencies (assuming 6-char format like USDTRY)
            if (code.length === 6) {
                const base = code.substring(0, 3)
                const quote = code.substring(3, 6)

                // If base is USD, we can get the rate directly
                if (base === 'USD' && frankfurterData.rates[quote]) {
                    rate = frankfurterData.rates[quote]
                }
                // If quote is USD, we need to invert
                else if (quote === 'USD' && frankfurterData.rates[base]) {
                    rate = 1 / frankfurterData.rates[base]
                }
                // For other pairs, calculate cross rate
                else if (frankfurterData.rates[base] && frankfurterData.rates[quote]) {
                    rate = frankfurterData.rates[quote] / frankfurterData.rates[base]
                }
            }

            if (rate) {
                updates.push({
                    asset_code: asset.code,
                    price: rate,
                    change_24h: null, // Frankfurter doesn't provide change data
                    volume_24h: null,
                    market_cap: null,
                    category: 'forex',
                    provider: 'frankfurter',
                    updated_at: new Date().toISOString(),
                })
            }
        }

        // Upsert prices
        if (updates.length > 0) {
            const { error: upsertError } = await supabase
                .from('prices')
                .upsert(updates, { onConflict: 'asset_code' })

            if (upsertError) throw upsertError
        }

        return new Response(
            JSON.stringify({
                success: true,
                updated: updates.length,
                total_assets: assets.length
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})
