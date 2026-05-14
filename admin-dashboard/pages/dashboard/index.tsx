import type { GetServerSideProps } from 'next'
import Head from 'next/head'
import { supabaseAdmin } from '../../lib/supabase'

const PAGE_SIZE = 25

interface Shop {
    id: string
    name: string
    owner_name: string
    contact_number: string
    municipality: string
    submitted_at: string
    storefront_photo_url: string | null
    lat: number | null
    lng: number | null
}

interface DashboardProps {
    shops: Shop[]
    page: number
    municipality: string
    from: string
    to: string
    municipalities: string[]
    hasNextPage: boolean
}

function streetViewUrl(lat: number | null, lng: number | null): string | null {
    if (lat == null || lng == null) return null
    return `https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${lat},${lng}`
}

function formatDate(iso: string): string {
    return new Date(iso).toLocaleString('en-PH', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    })
}

export default function Dashboard({
    shops,
    page,
    municipality,
    from,
    to,
    municipalities,
    hasNextPage,
}: DashboardProps) {
    const buildUrl = (overrides: Record<string, string | number>) => {
        const params = new URLSearchParams()
        const merged = { page, municipality, from, to, ...overrides }
        if (merged.page && Number(merged.page) > 1) params.set('page', String(merged.page))
        if (merged.municipality) params.set('municipality', String(merged.municipality))
        if (merged.from) params.set('from', String(merged.from))
        if (merged.to) params.set('to', String(merged.to))
        const qs = params.toString()
        return `/dashboard${qs ? `?${qs}` : ''}`
    }

    return (
        <>
            <Head>
                <title>Pending Submissions — Scrapp Admin</title>
            </Head>

            <div className="min-h-screen bg-gray-50">
                {/* Header */}
                <header className="bg-white border-b border-gray-200 px-6 py-4">
                    <h1 className="text-xl font-semibold text-gray-900">
                        Scrapp Admin — Pending Shop Submissions
                    </h1>
                </header>

                <main className="px-6 py-6 max-w-7xl mx-auto">
                    {/* Filters */}
                    <form method="GET" action="/dashboard" className="flex flex-wrap gap-4 mb-6 items-end">
                        {/* Municipality */}
                        <div className="flex flex-col gap-1">
                            <label htmlFor="municipality" className="text-sm font-medium text-gray-700">
                                Municipality
                            </label>
                            <select
                                id="municipality"
                                name="municipality"
                                defaultValue={municipality}
                                className="border border-gray-300 rounded-md px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                            >
                                <option value="">All municipalities</option>
                                {municipalities.map((m) => (
                                    <option key={m} value={m}>
                                        {m}
                                    </option>
                                ))}
                            </select>
                        </div>

                        {/* From date */}
                        <div className="flex flex-col gap-1">
                            <label htmlFor="from" className="text-sm font-medium text-gray-700">
                                From
                            </label>
                            <input
                                id="from"
                                type="date"
                                name="from"
                                defaultValue={from}
                                className="border border-gray-300 rounded-md px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                        </div>

                        {/* To date */}
                        <div className="flex flex-col gap-1">
                            <label htmlFor="to" className="text-sm font-medium text-gray-700">
                                To
                            </label>
                            <input
                                id="to"
                                type="date"
                                name="to"
                                defaultValue={to}
                                className="border border-gray-300 rounded-md px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                        </div>

                        <button
                            type="submit"
                            className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        >
                            Apply Filters
                        </button>

                        {(municipality || from || to) && (
                            <a
                                href="/dashboard"
                                className="px-4 py-2 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200"
                            >
                                Clear Filters
                            </a>
                        )}
                    </form>

                    {/* Empty state */}
                    {shops.length === 0 ? (
                        <div className="text-center py-20 text-gray-500 text-sm">
                            No pending submissions match the current filters.
                        </div>
                    ) : (
                        <>
                            {/* Table */}
                            <div className="overflow-x-auto rounded-lg border border-gray-200 bg-white shadow-sm">
                                <table className="min-w-full divide-y divide-gray-200 text-sm">
                                    <thead className="bg-gray-50">
                                        <tr>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Shop Name</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Owner Full Name</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Contact Number</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Municipality</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Submitted At</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Photo</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Street View</th>
                                            <th className="px-4 py-3 text-left font-medium text-gray-600 whitespace-nowrap">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-gray-100">
                                        {shops.map((shop) => {
                                            const svUrl = streetViewUrl(shop.lat, shop.lng)
                                            return (
                                                <tr key={shop.id} className="hover:bg-gray-50">
                                                    <td className="px-4 py-3 font-medium text-gray-900 whitespace-nowrap max-w-[180px] truncate">
                                                        {shop.name}
                                                    </td>
                                                    <td className="px-4 py-3 text-gray-700 whitespace-nowrap max-w-[180px] truncate">
                                                        {shop.owner_name}
                                                    </td>
                                                    <td className="px-4 py-3 text-gray-700 whitespace-nowrap">
                                                        {shop.contact_number}
                                                    </td>
                                                    <td className="px-4 py-3 text-gray-700 whitespace-nowrap">
                                                        {shop.municipality}
                                                    </td>
                                                    <td className="px-4 py-3 text-gray-500 whitespace-nowrap">
                                                        {formatDate(shop.submitted_at)}
                                                    </td>
                                                    <td className="px-4 py-3">
                                                        {shop.storefront_photo_url ? (
                                                            <a
                                                                href={shop.storefront_photo_url}
                                                                target="_blank"
                                                                rel="noopener noreferrer"
                                                            >
                                                                {/* eslint-disable-next-line @next/next/no-img-element */}
                                                                <img
                                                                    src={shop.storefront_photo_url}
                                                                    alt={`${shop.name} storefront`}
                                                                    className="w-16 h-16 object-cover rounded border border-gray-200"
                                                                />
                                                            </a>
                                                        ) : (
                                                            <span className="text-gray-400 text-xs">No photo</span>
                                                        )}
                                                    </td>
                                                    <td className="px-4 py-3">
                                                        {svUrl ? (
                                                            <a
                                                                href={svUrl}
                                                                target="_blank"
                                                                rel="noopener noreferrer"
                                                                className="text-blue-600 hover:underline text-xs whitespace-nowrap"
                                                            >
                                                                Open Street View
                                                            </a>
                                                        ) : (
                                                            <span className="text-gray-400 text-xs">N/A</span>
                                                        )}
                                                    </td>
                                                    <td className="px-4 py-3">
                                                        <div className="flex gap-2">
                                                            <form
                                                                method="POST"
                                                                action={`/api/shops/${shop.id}/approve`}
                                                                onSubmit={(e) => {
                                                                    if (!confirm(`Approve "${shop.name}"? This will mark it as verified.`)) {
                                                                        e.preventDefault()
                                                                    }
                                                                }}
                                                            >
                                                                <button
                                                                    type="submit"
                                                                    className="px-3 py-1.5 bg-green-600 text-white text-xs font-medium rounded hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500"
                                                                >
                                                                    Approve
                                                                </button>
                                                            </form>
                                                            <form
                                                                method="POST"
                                                                action={`/api/shops/${shop.id}/reject`}
                                                                onSubmit={(e) => {
                                                                    e.preventDefault()
                                                                    const reason = prompt(
                                                                        `Rejection reason for "${shop.name}" (1–500 chars):`
                                                                    )
                                                                    if (!reason || reason.trim().length < 1) return
                                                                    if (reason.trim().length > 500) {
                                                                        alert('Rejection reason must be 500 characters or fewer.')
                                                                        return
                                                                    }
                                                                    const form = e.currentTarget as HTMLFormElement
                                                                    let input = form.querySelector<HTMLInputElement>(
                                                                        'input[name="rejection_reason"]'
                                                                    )
                                                                    if (!input) {
                                                                        input = document.createElement('input')
                                                                        input.type = 'hidden'
                                                                        input.name = 'rejection_reason'
                                                                        form.appendChild(input)
                                                                    }
                                                                    input.value = reason.trim()
                                                                    form.submit()
                                                                }}
                                                            >
                                                                <button
                                                                    type="submit"
                                                                    className="px-3 py-1.5 bg-red-600 text-white text-xs font-medium rounded hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500"
                                                                >
                                                                    Reject
                                                                </button>
                                                            </form>
                                                        </div>
                                                    </td>
                                                </tr>
                                            )
                                        })}
                                    </tbody>
                                </table>
                            </div>

                            {/* Pagination */}
                            <div className="flex items-center justify-between mt-4">
                                <p className="text-sm text-gray-500">
                                    Page {page} &mdash; showing {shops.length} record{shops.length !== 1 ? 's' : ''}
                                </p>
                                <div className="flex gap-2">
                                    {page > 1 && (
                                        <a
                                            href={buildUrl({ page: page - 1 })}
                                            className="px-4 py-2 text-sm font-medium bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                                        >
                                            ← Previous
                                        </a>
                                    )}
                                    {hasNextPage && (
                                        <a
                                            href={buildUrl({ page: page + 1 })}
                                            className="px-4 py-2 text-sm font-medium bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                                        >
                                            Next →
                                        </a>
                                    )}
                                </div>
                            </div>
                        </>
                    )}
                </main>
            </div>
        </>
    )
}

export const getServerSideProps: GetServerSideProps<DashboardProps> = async ({ query }) => {
    const page = Math.max(1, parseInt((query.page as string) ?? '1', 10) || 1)
    const municipality = (query.municipality as string) ?? ''
    const from = (query.from as string) ?? ''
    const to = (query.to as string) ?? ''

    const offset = (page - 1) * PAGE_SIZE

    // Build the query — extract lat/lng from PostGIS geography column
    let dbQuery = supabaseAdmin
        .from('junkshops')
        .select(
            `id, name, owner_name, contact_number, municipality, submitted_at, storefront_photo_url,
             ST_Y(location::geometry) AS lat,
             ST_X(location::geometry) AS lng`,
            { count: 'exact' }
        )
        .eq('status', 'pending')
        .order('submitted_at', { ascending: true })
        .range(offset, offset + PAGE_SIZE) // fetch PAGE_SIZE + 1 to detect next page

    if (municipality) {
        dbQuery = dbQuery.eq('municipality', municipality)
    }
    if (from) {
        dbQuery = dbQuery.gte('submitted_at', `${from}T00:00:00Z`)
    }
    if (to) {
        dbQuery = dbQuery.lte('submitted_at', `${to}T23:59:59Z`)
    }

    const { data, error } = await dbQuery

    if (error) {
        console.error('Dashboard query error:', error)
        // Return empty state rather than crashing
        return {
            props: {
                shops: [],
                page,
                municipality,
                from,
                to,
                municipalities: [],
                hasNextPage: false,
            },
        }
    }

    const rows = (data ?? []) as Shop[]

    // Detect if there's a next page (we fetched PAGE_SIZE + 1 rows)
    const hasNextPage = rows.length > PAGE_SIZE
    const shops = hasNextPage ? rows.slice(0, PAGE_SIZE) : rows

    // Derive distinct municipalities from the current result set for the filter dropdown
    const municipalities = Array.from(
        new Set(rows.map((s) => s.municipality).filter(Boolean))
    ).sort()

    return {
        props: {
            shops,
            page,
            municipality,
            from,
            to,
            municipalities,
            hasNextPage,
        },
    }
}
