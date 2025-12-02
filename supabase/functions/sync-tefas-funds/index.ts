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

        // TEFAS public endpoint - using main domain
        // This endpoint works from Supabase Edge Functions
        const today = new Date()
        const dateStr = today.toISOString().split('T')[0]

        // Try TEFAS main website API
        const tefasUrl = `https://www.tefas.gov.tr/api/DB/BindHistoryInfo?fontip=YAT&bastarih=${dateStr}&bittarih=${dateStr}&fonkod=&fongrubu=`

        console.log('Fetching from TEFAS:', tefasUrl)

        const response = await fetch(tefasUrl, {
            headers: {
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0',
            }
        })

        if (!response.ok) {
            throw new Error(`TEFAS returned ${response.status}: ${response.statusText}`)
        }

        const contentType = response.headers.get('content-type')
        console.log('Content-Type:', contentType)

        const data = await response.json()
        console.log('Response data type:', typeof data)
        console.log('Is array:', Array.isArray(data))

        // TEFAS returns array of funds directly
        const funds = Array.isArray(data) ? data : (data.data || [])

        if (funds.length === 0) {
            throw new Error('No funds returned from TEFAS')
        }

        console.log(`Found ${funds.length} funds`)

        // Prepare assets for insertion
        const assets = funds.map((fund: any) => {
            // TEFAS fund object structure
            const code = fund.FONKODU || fund.fonKodu || fund.code
            const name = fund.FONUNVAN || fund.fonUnvan || fund.name || code

            return {
                code: code,
                display_name: name,
                category: 'fund',
                provider: 'tefas',
                tefas_code: code,
                is_active: true,
            }
        }).filter(asset => asset.code) // Remove any without code

        console.log(`Prepared ${assets.length} assets for insertion`)

        // Insert in batches to avoid conflicts
        let successCount = 0
        const batchSize = 50

        for (let i = 0; i < assets.length; i += batchSize) {
            const batch = assets.slice(i, i + batchSize)

            const { error } = await supabase
                .from('assets')
                .upsert(batch, { onConflict: 'code' })

            if (error) {
                console.error(`Batch ${i}-${i + batchSize} error:`, error)
            } else {
                successCount += batch.length
            }
        }

        return new Response(
            JSON.stringify({
                success: true,
                synced: successCount,
                total: assets.length,
                message: `Synced ${successCount}/${assets.length} TEFAS funds`
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 200,
            }
        )

    } catch (error: any) {
        console.error('Error:', error)
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message,
                stack: error.stack
            }),
            {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                status: 500,
            }
        )
    }
})
