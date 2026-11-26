// Uso: npm run qr -- https://tu-app.up.railway.app  →  docs/qr.png
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import QRCode from 'qrcode';

const url = process.argv[2];
if (!/^https?:\/\/\S+$/.test(url ?? '')) {
  console.error('Uso: npm run qr -- https://tu-app.up.railway.app');
  process.exit(1);
}
const out = fileURLToPath(new URL('../docs/qr.png', import.meta.url));
mkdirSync(fileURLToPath(new URL('../docs/', import.meta.url)), { recursive: true });
// 1024 px y corrección de errores alta: se lee bien impreso o proyectado.
await QRCode.toFile(out, url, { width: 1024, margin: 2, errorCorrectionLevel: 'H' });
console.log(`QR de ${url} → docs/qr.png`);
