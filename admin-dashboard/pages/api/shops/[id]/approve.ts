import type { NextApiRequest, NextApiResponse } from 'next'
import { supabaseAdmin } from '../../../../lib/supabase'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    if (req.method !== 'POST') {
        res.setHeader('Allow', 'POST')
        return res.status(405).json({ error: 'Method Not Allowed' })
    }

    const { id } = req.query as { id: string }

    const { error } = await supabaseAdmin
        .from('junkshops')
        .update({ status: 'verified', verified_at: new Date().toISOString() })
        .eq('id', id)
        .eq('status', 'pending') // safety: only approve pending shops

    if (error) {
        return res.status(500).json({ error: error.message })
    }

    // Redirect back to dashboard after success
    res.redirect(303, '/dashboard')
}
