// Nook Design Tokens
// Shared across Web, iOS, and Android

export const colors = {
  background: '#FDFBF9',
  foreground: '#2C2826',
  primary: '#462D3E',
  primaryForeground: '#FFFFFF',
  secondary: '#F4F1EE',
  secondaryForeground: '#2C2826',
  mutedForeground: '#827C77',
  accent: '#DF8E63',
  card: '#FFFFFF',
  cardForeground: '#2C2826',
  border: '#E8E5E1',
  input: '#F4F1EE',
} as const;

export const fonts = {
  heading: 'Plus Jakarta Sans',
  body: 'Plus Jakarta Sans',
} as const;

export const radii = {
  lg: 44.44,
  md: 33.33,
  sm: 16,
  xs: 8,
} as const;

export type Colors = typeof colors;
export type Fonts = typeof fonts;
export type Radii = typeof radii;
