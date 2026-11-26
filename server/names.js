import { readFileSync } from 'node:fs';

const BAD = new Set(
  readFileSync(new URL('./groserias.txt', import.meta.url), 'utf8')
    .split(/\r?\n/)
    .map((w) => w.trim())
    .filter((w) => w && !w.startsWith('#'))
    .map(toKey),
);

const LEET = { 0: 'o', 1: 'i', 3: 'e', 4: 'a', 5: 's', 7: 't', '@': 'a', $: 's' };

export function toKey(s) {
  return s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
}

function isBad(key) {
  const leet = key.replace(/[013457@$]/g, (c) => LEET[c]);
  for (const v of [key, leet]) {
    // ponytail: palabra completa o nombre entero sin separadores; no busca subcadenas
    // (evita falsos positivos tipo "computadora"). Agregar variantes a groserias.txt.
    const words = v.split(/[^\p{L}]+/u).filter(Boolean);
    if (words.some((w) => BAD.has(w)) || BAD.has(words.join(''))) return true;
  }
  return false;
}

/** {displayName, nameKey} o {error}. */
export function normalizeName(raw) {
  if (typeof raw !== 'string') return { error: 'nombre_invalido' };
  const displayName = raw.trim().replace(/\s+/g, ' ');
  const len = [...displayName].length;
  // U+FFFD = texto mal codificado por el cliente.
  if (len < 2 || len > 16 || /[\p{C}\u{FFFD}]/u.test(displayName)) return { error: 'nombre_invalido' };
  const nameKey = toKey(displayName);
  if (isBad(nameKey)) return { error: 'nombre_no_permitido' };
  return { displayName, nameKey };
}
