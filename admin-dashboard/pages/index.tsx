import type { GetServerSideProps } from 'next'

export default function Home() {
    return (
        <div className="p-8">
            <h1 className="text-2xl font-bold">Scrapp Admin Dashboard</h1>
            <p className="mt-2 text-gray-600">
                Go to{' '}
                <a href="/dashboard" className="text-blue-600 underline">
                    /dashboard
                </a>{' '}
                to review pending shops.
            </p>
        </div>
    )
}

export const getServerSideProps: GetServerSideProps = async () => {
    return { redirect: { destination: '/dashboard', permanent: false } }
}
