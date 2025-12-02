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

        // Define precious metals to track
        const metals = [
            { code: 'XAU', name: 'Altın (Gold)', symbol: 'XAU' },
            { code: 'XAG', name: 'Gümüş (Silver)', symbol: 'XAG' },
            { code: 'XPT', name: 'Platin (Platinum)', symbol: 'XPT' },
            { code: 'XPD', name: 'Paladyum (Palladium)', symbol: 'XPD' },
            { code: 'XCU', name: 'Bakır (Copper)', symbol: 'XCU' },
        ]

        const assets = metals.map(metal => ({
            code: metal.code,
            display_name: metal.name,
            category: 'metal',
            provider: 'metals-api',
            tefas_code: metal.symbol,  // Use tefas_code for metal symbol
            is_active: true,
        }))

        // Upsert metals
        const { error } = await supabase
            .from('assets')
            .upsert(assets, { onConflict: 'code' })

        if (error) throw error

        return new Response(
            JSON.stringify({
                success: true,
                synced: assets.length,
                metals: metals.map(m => m.code)
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
