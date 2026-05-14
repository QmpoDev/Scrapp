import type { NextApiRequest, NextApiResponse } from 'next'
import { supabaseAdmin } from '../../../../lib/supabase'

/**
 * POST /api/shops/[id]/reject
 *
 * Body (form-encoded): rejection_reason=<string>
 *
 * Updates the shop status to 'rejected', sets rejected_at and rejection_reason.
 * Redirects back to /dashboard on success.
 *
 * Requirements: 11.5, 11.7
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    if (req.method !== 'POST') {
        res.setHeader('Allow', 'POST')
        return res.status(405).json({ error: 'Method Not Allowed' })
    }

    const { id } = req.query as { id: string }

    // Parse form-encoded body (Next.js doesn't auto-parse for API routes)
    const raw = await new Promise<string>((resolve) => {
        let data = ''
        req.on('data', (chunk: Buffer) => { data += chunk.toString() })
        req.on('end', () => resolve(data))
    })

    const params = new URLSearchParams(raw)
    const rejectionReason = (params.get('rejection_reason') ?? '').trim()

    if (rejectionReason.length < 1 || rejectionReason.length > 500) {
        return res.status(400).json({ error: 'rejection_reason must be 1–500 characters' })
    }

    const { error } = await supabaseAdmin
        .from('junkshops')
        .update({
            status: 'rejected',
            rejected_at: new Date().toISOString(),
            rejection_reason: rejectionReason,
        })
        .eq('id', id)
        .eq('status', 'pending') // safety: only reject pending shops

    if (error) {
        return res.status(500).json({ error: error.message })
    }

    // Redirect back to dashboard — row will no longer appear in pending list
    res.redirect(303, '/dashboard')
}
