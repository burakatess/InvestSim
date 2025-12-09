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

        // Define major forex pairs - ALL in XXXUSD format (1 XXX = ? USD)
        const forexPairs = [
            // Major pairs (already XXXUSD format)
            { code: 'EURUSD', name: 'Euro / US Dollar' },
            { code: 'GBPUSD', name: 'British Pound / US Dollar' },
            { code: 'AUDUSD', name: 'Australian Dollar / US Dollar' },
            { code: 'NZDUSD', name: 'New Zealand Dollar / US Dollar' },

            // Inverted pairs (formerly USDXXX, now XXXUSD)
            { code: 'JPYUSD', name: 'Japanese Yen / US Dollar' },
            { code: 'CHFUSD', name: 'Swiss Franc / US Dollar' },
            { code: 'CADUSD', name: 'Canadian Dollar / US Dollar' },
            { code: 'TRYUSD', name: 'Turkish Lira / US Dollar' },
            { code: 'CNYUSD', name: 'Chinese Yuan / US Dollar' },
            { code: 'INRUSD', name: 'Indian Rupee / US Dollar' },
            { code: 'BRLUSD', name: 'Brazilian Real / US Dollar' },
            { code: 'MXNUSD', name: 'Mexican Peso / US Dollar' },
            { code: 'ZARUSD', name: 'South African Rand / US Dollar' },
            { code: 'RUBUSD', name: 'Russian Ruble / US Dollar' },

            // Cross pairs (keeping as-is for now)
            { code: 'EURGBP', name: 'Euro / British Pound' },
            { code: 'EURJPY', name: 'Euro / Japanese Yen' },
            { code: 'GBPJPY', name: 'British Pound / Japanese Yen' },
            { code: 'EURCHF', name: 'Euro / Swiss Franc' },
            { code: 'EURAUD', name: 'Euro / Australian Dollar' },
            { code: 'EURCAD', name: 'Euro / Canadian Dollar' },

            // TRY cross pairs (keeping for Turkish users)
            { code: 'EURTRY', name: 'Euro / Turkish Lira' },
            { code: 'GBPTRY', name: 'British Pound / Turkish Lira' },
            { code: 'CHFTRY', name: 'Swiss Franc / Turkish Lira' },
            { code: 'JPYTRY', name: 'Japanese Yen / Turkish Lira' },
            { code: 'AUDTRY', name: 'Australian Dollar / Turkish Lira' },
            { code: 'CADTRY', name: 'Canadian Dollar / Turkish Lira' },
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
