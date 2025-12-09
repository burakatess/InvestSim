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

        // Fetch forex assets from DB (using correct schema: symbol, asset_class)
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('id, symbol, provider_symbol')
            .eq('asset_class', 'fx')

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
        const today = new Date().toISOString().split('T')[0]

        // Process each forex asset
        for (const asset of assets) {
            let rate = null

            // Handle 6-char format like EURUSD, JPYUSD
            const symbol = asset.symbol.toUpperCase().replace(/[\/-]/g, '')

            if (symbol.length === 6) {
                const base = symbol.substring(0, 3)
                const quote = symbol.substring(3, 6)

                // Frankfurter API with from=USD returns: 1 USD = X currency
                // For XXXUSD format (e.g., EURUSD = 1 EUR = ? USD):
                // rates[EUR] = 0.86 means 1 USD = 0.86 EUR
                // So 1 EUR = 1/0.86 = 1.16 USD ✓
                // But we already inverted in DB, so now use direct rate
                if (quote === 'USD' && frankfurterData.rates[base]) {
                    // 1 XXX = 1/rates[base] USD
                    // EURUSD: 1 EUR = 1/0.86 = 1.16 USD
                    rate = 1 / frankfurterData.rates[base]
                }
                // USDXXX format (if any remain)
                else if (base === 'USD' && frankfurterData.rates[quote]) {
                    rate = frankfurterData.rates[quote]
                }
            }

            if (rate) {
                // Insert into prices_history table
                updates.push({
                    asset_id: asset.id,
                    date: today,
                    open: rate,
                    high: rate,
                    low: rate,
                    close: rate,
                    volume: null,
                    provider: 'fx',
                })
            }
        }

        // Upsert prices into prices_history
        if (updates.length > 0) {
            const { error: upsertError } = await supabase
                .from('prices_history')
                .upsert(updates, { onConflict: 'asset_id,date' })

            if (upsertError) throw upsertError
        }

        return new Response(
            JSON.stringify({
                success: true,
                updated: updates.length,
                total_assets: assets.length,
                date: today,
                sample_rates: updates.slice(0, 3).map(u => ({
                    asset_id: u.asset_id,
                    rate: u.close
                }))
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error) {
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
