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

        // Define major forex pairs
        const forexPairs = [
            // TRY pairs (Turkish Lira)
            { code: 'USDTRY', name: 'Dolar/TL', base: 'USD', quote: 'TRY' },
            { code: 'EURTRY', name: 'Euro/TL', base: 'EUR', quote: 'TRY' },
            { code: 'GBPTRY', name: 'Sterlin/TL', base: 'GBP', quote: 'TRY' },
            { code: 'CHFTRY', name: 'İsviçre Frangı/TL', base: 'CHF', quote: 'TRY' },
            { code: 'JPYTRY', name: 'Japon Yeni/TL', base: 'JPY', quote: 'TRY' },
            { code: 'AUDTRY', name: 'Avustralya Doları/TL', base: 'AUD', quote: 'TRY' },
            { code: 'CADTRY', name: 'Kanada Doları/TL', base: 'CAD', quote: 'TRY' },

            // Major pairs (USD base)
            { code: 'EURUSD', name: 'Euro/Dolar', base: 'EUR', quote: 'USD' },
            { code: 'GBPUSD', name: 'Sterlin/Dolar', base: 'GBP', quote: 'USD' },
            { code: 'USDJPY', name: 'Dolar/Japon Yeni', base: 'USD', quote: 'JPY' },
            { code: 'USDCHF', name: 'Dolar/İsviçre Frangı', base: 'USD', quote: 'CHF' },
            { code: 'AUDUSD', name: 'Avustralya Doları/Dolar', base: 'AUD', quote: 'USD' },
            { code: 'USDCAD', name: 'Dolar/Kanada Doları', base: 'USD', quote: 'CAD' },
            { code: 'NZDUSD', name: 'Yeni Zelanda Doları/Dolar', base: 'NZD', quote: 'USD' },

            // Cross pairs
            { code: 'EURGBP', name: 'Euro/Sterlin', base: 'EUR', quote: 'GBP' },
            { code: 'EURJPY', name: 'Euro/Japon Yeni', base: 'EUR', quote: 'JPY' },
            { code: 'GBPJPY', name: 'Sterlin/Japon Yeni', base: 'GBP', quote: 'JPY' },
            { code: 'EURCHF', name: 'Euro/İsviçre Frangı', base: 'EUR', quote: 'CHF' },
            { code: 'EURAUD', name: 'Euro/Avustralya Doları', base: 'EUR', quote: 'AUD' },
            { code: 'EURCAD', name: 'Euro/Kanada Doları', base: 'EUR', quote: 'CAD' },

            // Emerging markets
            { code: 'USDRUB', name: 'Dolar/Ruble', base: 'USD', quote: 'RUB' },
            { code: 'USDCNY', name: 'Dolar/Yuan', base: 'USD', quote: 'CNY' },
            { code: 'USDINR', name: 'Dolar/Rupi', base: 'USD', quote: 'INR' },
            { code: 'USDBRL', name: 'Dolar/Real', base: 'USD', quote: 'BRL' },
            { code: 'USDMXN', name: 'Dolar/Peso', base: 'USD', quote: 'MXN' },
            { code: 'USDZAR', name: 'Dolar/Rand', base: 'USD', quote: 'ZAR' },
        ]

        // Prepare assets for insertion
        const assets = forexPairs.map(pair => ({
            code: pair.code,
            display_name: pair.name,
            category: 'forex',
            provider: 'frankfurter',
            is_active: true,
        }))

        // Upsert assets
        const { error: upsertError } = await supabase
            .from('assets')
            .upsert(assets, {
                onConflict: 'code'
            })

        if (upsertError) throw upsertError

        return new Response(
            JSON.stringify({
                success: true,
                synced: assets.length,
                message: `Synced ${assets.length} forex pairs`
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
