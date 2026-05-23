import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Nook',
  description: 'Your personal space, reimagined.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
