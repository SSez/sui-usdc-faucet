export const API_BASE =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_API_BASE) ||
  'http://localhost:8787';

export const DEFAULT_CLOCK = '0x6';
