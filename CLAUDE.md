# CLAUDE.md

App web interactiva sobre nuestra práctica de Física: Movimiento Rectilíneo Uniforme (MRU), del Equipo 4, Instituto Tecnológico de Saltillo. Se compartirá por link/QR y se abrirá en celular y computadora. **Todo el texto de la app va en español.**

## Stack

- Monorepo con dos carpetas: `/app` (Flutter Web, Dart) y `/server` (Node.js 20 + Express + Postgres).
- En producción un solo servicio de Railway: el servidor Node sirve la build de Flutter Web (`/app/build/web`) como archivos estáticos y expone la API en `/api`. Mismo origen, sin CORS.
- Paquetes Flutter permitidos: `google_fonts`, `http`, `shared_preferences`. Nada de paquetes de gráficas: todo se dibuja con `CustomPainter`.

## Traducción del spec web a Flutter

- `requestAnimationFrame` con delta time → un `Stopwatch` de Dart es la fuente de verdad del tiempo de simulación (se detiene al pausar), y un `Ticker` solo dispara el repintado. La posición siempre se calcula como `x = f(t)` desde el tiempo acumulado, nunca sumando pasos por frame.
- `canvas` → `CustomPainter`.
- `localStorage` → `shared_preferences` (en web usa localStorage). Toda lectura/escritura va en try/catch y la app funciona igual si falla.

## Datos reales de la práctica (usar exactamente)

- Carrito sobre una regla de 30 cm con marcas cada 5 cm. Velocidad constante v = 0.10 m/s.
- Tiempos promedio medidos: 0 cm → 0.00 s, 5 → 0.50, 10 → 1.00, 15 → 1.50, 20 → 2.04, 25 → 2.53, 30 → 3.00 s.
- Ajuste lineal de nuestra gráfica x-t: pendiente 0.099 m/s, R² = 0.9998.
- Ecuaciones: x = x₀ + v·t ; v = x / t ; t prom = (t₁+t₂+t₃)/3.
- Incertidumbre: u(v) = v·√[(u(x)/x)² + (u(t)/t)²], con u(x) = 1 mm y u(t) = desviación estándar/√3.
- Fuente de error principal: tiempo de reacción humano ≈ 0.2 s.
- Decisión metodológica: el carrito se libera ANTES del 0 para que ya vaya a velocidad constante al cruzar la primera marca.

## Reglas del reto (ya decididas, no cambiarlas)

- Un intento = 3 rondas seguidas. En cada ronda el usuario toca "¡MARCA!" (o barra espaciadora) cuando la nariz del carrito cruza 5, 10, 15, 20, 25 y 30 cm. Tiempo real de cada marca = x/v: 0.50, 1.00, 1.50, 2.00, 2.50, 3.00 s.
- Tiempo del usuario = tiempo del toque medido desde que la nariz cruzó 0 cm.
- Cada toque se asigna a la siguiente marca pendiente. Toques antes del 0 y toques de más se ignoran. La ronda termina a los 4.00 s; una marca sin tocar cuenta como 1.000 s de diferencia.
- **PUNTAJE** = promedio de |t_usuario − t_real| sobre los 18 toques (6 marcas × 3 rondas), en segundos, redondeado a 3 decimales. Menor gana.
- Empate (mismo puntaje a 3 decimales): gana el intento que terminó primero.
- Tiempo de reacción promedio = promedio CON signo de (t_usuario − t_real) sobre los toques hechos. Positivo = tarde.
- Error de velocidad = |pendiente del ajuste de sus tiempos promedio por marca − 0.10| / 0.10 × 100. Solo informativo, no decide.
- Estrellas: ≤ 0.050 s → 5, ≤ 0.100 → 4, ≤ 0.200 → 3, ≤ 0.350 → 2, resto 1.
- Referencia del Equipo 4: 0.012 s de diferencia promedio (sus tiempos promedio contra el ideal). Mostrarla como "meta a vencer".
- Máximo 3 intentos por nombre por sesión del reto; en el marcador cuenta el mejor. Reiniciar la tabla (solo con PIN de admin) abre una sesión nueva.
- Nombres: 2 a 16 caracteres, recortados, filtro básico de groserías en español; se comparan sin mayúsculas ni acentos.
- El marcador es global (backend), se refresca cada 3 s, muestra top 10, la posición propia y un feed de "entró" / "terminó #N".

## Diseño

- Instrumento de laboratorio digital: fondo oscuro (#0E1116 aprox.), un acento vivo (verde lima o cian), números y cronómetro en JetBrains Mono, texto en Inter.
- Encabezado: "Práctica de Física: MRU · Equipo 4 · ITS Saltillo". Pestañas Simulación / Reto.
- Responsive: en pantallas < 800 px de ancho todo se apila en una columna. Botones de al menos 48×48 px.

## Calidad

- Con v = 0.10 m/s el carrito tarda 0.50 s por cada 5 cm y 3.00 s en 30 cm. Esto debe estar cubierto por tests.
- Pausar congela carrito y cronómetro sin perder tiempo; Reiniciar regresa al estado inicial.
- Sin errores en consola; funciona en Chrome móvil y escritorio.
- La lógica (física, ajuste lineal, puntaje) va en Dart puro sin Flutter, con tests en `/app/test`. La misma fórmula de puntaje se reimplementa en `/server` con tests que usen los mismos casos.

## Comandos

- App: `cd app && flutter run -d chrome` · `flutter test` · `flutter build web`
- Server: `cd server && npm install && npm start`
