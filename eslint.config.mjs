import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: [
      '**/node_modules/**',
      '**/dist/**',
      '**/build/**',
      '**/.next/**',
      'apps/ios/**',
      'apps/android/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
);
