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
        fontFamily: 'var(--font-heading)',
      }}
    >
      <h1 style={{ fontSize: '3rem', fontWeight: 700 }}>{APP_NAME}</h1>
      <p
        style={{ fontSize: '1.25rem', color: 'var(--color-muted-foreground)', marginTop: '0.5rem' }}
      >
        Coming soon.
      </p>
    </main>
  );
}
