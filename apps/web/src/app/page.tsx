import { APP_NAME } from '@nook/shared';

export default function Home() {
  return (
    <main
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh',
        fontFamily: 'system-ui, sans-serif',
      }}
    >
      <h1 style={{ fontSize: '3rem', fontWeight: 700 }}>{APP_NAME}</h1>
      <p style={{ fontSize: '1.25rem', color: '#666', marginTop: '0.5rem' }}>Coming soon.</p>
    </main>
  );
}
