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

        // Fetch fund assets from DB
        const { data: assets, error: assetsError } = await supabase
            .from('assets')
            .select('code, tefas_code')
            .eq('category', 'fund')

        if (assetsError) throw assetsError
        if (!assets || assets.length === 0) {
            return new Response(JSON.stringify({ message: 'No fund assets found. Run sync-tefas-funds first.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            })
        }

        // Fetch latest prices from TEFAS
        const today = new Date()
        const dateStr = today.toISOString().split('T')[0]

        const tefasUrl = `https://www.tefas.gov.tr/api/DB/BindHistoryInfo?fontip=YAT&bastarih=${dateStr}&bittarih=${dateStr}&fonkod=&fongrubu=`

        const response = await fetch(tefasUrl, {
            headers: {
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0',
            }
        })

        if (!response.ok) {
            throw new Error(`TEFAS returned ${response.status}`)
        }

        const data = await response.json()
        const fundsData = Array.isArray(data) ? data : (data.data || [])

        const updates = []

        // Match our assets with TEFAS data
        for (const asset of assets) {
            const fundCode = asset.tefas_code || asset.code
            const fundInfo = fundsData.find((f: any) =>
                (f.FONKODU || f.fonKodu) === fundCode
            )

            if (fundInfo) {
                // TEFAS price field
                const priceField = fundInfo.FIYAT || fundInfo.fiyat || fundInfo.price
                const returnField = fundInfo.GETIRI || fundInfo.getiri || fundInfo.return

                if (priceField) {
                    const price = parseFloat(priceField.toString().replace(',', '.'))

                    if (!isNaN(price) && price > 0) {
                        updates.push({
                            asset_code: asset.code,
                            price: price,
                            change_24h: returnField ? parseFloat(returnField.toString().replace(',', '.')) : null,
                            volume_24h: null,
                            market_cap: null,
                            category: 'fund',
                            provider: 'tefas',
                            updated_at: new Date().toISOString(),
                        })
                    }
                }
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
                total_assets: assets.length,
                message: `Updated ${updates.length}/${assets.length} fund prices`
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
