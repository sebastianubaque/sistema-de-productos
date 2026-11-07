# Brief: hojas virtuales de etiquetas en el Proyecto Jhadiel

Este documento es para quien vaya a modificar el **Proyecto Jhadiel** (HTML + Supabase). Explica qué
se quiere lograr y qué hay que construir. No hace falta haber visto nada más: todo lo necesario está
aquí y en `supabase_tablas.sql`.

> Reemplaza al brief anterior (`BRIEF_ESCANER_QR_MASTER.md`) y al formato de QR master: **ya no se
> usa ningún QR master**. Las hojas llegan por la base de datos. Si ya empezaste con el QR master, se descarta.

---

## 1. La idea general

Hay un programa aparte, **Generar QRs** (programa de escritorio en Windows), que lee los productos
nuevos de las hojas de cálculo e imprime **hojas de etiquetas**. Cada etiqueta lleva un QR pequeño
con el *código* del producto, más talla, precio, color, etc. Las etiquetas se recortan y se **pegan
una por una en los productos**.

El problema: con decenas de etiquetas por hoja y 10 o 15 hojas por corrida, es difícil saber rápido
**cuáles ya se pegaron, cuáles faltan y qué producto es cada una**.

La solución: cuando el programa genera las hojas, **también las envía a tablas de Supabase**: cada
hoja, cada etiqueta y dónde quedó posicionada. En Jhadiel se quiere **ver esas hojas tal como se
imprimieron** (una simulación en pantalla) y trabajar sobre ellas:

- Ver cada etiqueta en su posición real, con marca, talla, precio, etc.
- **Marcar (check) las que ya están pegadas.**
- Hacerlo de dos formas:
  1. **Escaneando con la cámara el QR pequeño de la etiqueta**: se marca sola.
  2. **Tocando el ticket** en la hoja virtual: se ve toda su información y se puede marcar o desmarcar a mano.

## 2. Qué hay que hacer

1. Ejecutar `supabase_tablas.sql` en Supabase (SQL Editor). Crea 3 tablas: `corridas`, `hojas`, `etiquetas`.
2. Construir en Jhadiel la pantalla de **hojas virtuales** que lee esas tablas (sección 4).
3. El sistema ya tiene una **función oculta** (se pidió antes y no está visible para los usuarios normales). Hoy **no puede escanear nada**. Hay que **ubicarla en el código, mantenerla oculta** (misma forma de acceso que ya tiene) y agregarle la **cámara para escanear QR de etiquetas** (sección 5). La pantalla de hojas virtuales puede vivir ahí.

No se conoce cómo está hecha esa función oculta ni la estructura de Jhadiel: **primero revisa el
proyecto** y adapta esto a lo que ya existe. Si algo choca con la arquitectura, dilo y propón la alternativa.

## 3. Qué hace el programa generador (lo que llega a la base de datos)

- Cada vez que se genera, **sube una corrida nueva y borra las anteriores**: siempre queda **solo la
  última generada**. Hojas y etiquetas se borran en cascada.
- Primero inserta la nueva y solo si todo salió bien borra las anteriores; si el envío falla a mitad,
  borra lo que alcanzó a subir y la corrida anterior queda intacta.
- Si falla el borrado final (raro) pueden coexistir dos corridas un rato: **usa siempre la más reciente** (`creada` más alta).
- Se envían las hojas **sin descripción** (`tipo` = `SIN`) y **con descripción** (`tipo` = `CON`). Son dos PDF distintos y cada uno tiene su propia numeración de hojas.
- Usa la **llave anon** del proyecto (la misma que usa la página) y las políticas del SQL.
- **No se envía el precio de compra.**

### Las tablas

| Tabla | Una fila por… | Campos importantes |
|---|---|---|
| `corridas` | generación | `id` (`AAAAMMDD-HHMMSS-xxxx`), `creada`, `formato` (Carta/A4/Oficio), `orientacion`, `con_marca`, `total_etiquetas` |
| `hojas` | hoja impresa | `corrida_id`, `tipo`, `numero` (desde 1), `pdf`, `ancho_mm`, `alto_mm` (hoja), `etiqueta_ancho_mm`, `etiqueta_alto_mm`, `marca_alto_mm`, `total` |
| `etiquetas` | etiqueta impresa | `corrida_id`, `tipo`, `orden` (desde 0), `hoja`, `x_mm`, `y_mm`, `acostada`, `codigo`, `copia`/`copias`, `fila_hoja`, `marca`, `talla`, `venta`, `color`, `estilo`, `categoria`, `descripcion`, `genero`, `zapatos`, **`pegada`**, **`pegada_en`** |

`pegada` y `pegada_en` los maneja Jhadiel (el generador no los toca; empiezan en `false`/`null`).
Si una fila de la hoja de cálculo tiene 3 copias, son 3 filas en `etiquetas` con `copia` 1, 2 y 3 y `copias` = 3.

## 4. La hoja virtual

### Lectura

```js
// la corrida más reciente
const { data: corrida } = await sb.from('corridas').select('*')
  .order('creada', { ascending: false }).limit(1).maybeSingle();

// sus hojas (dos PDF: SIN y CON)
const { data: hojas } = await sb.from('hojas').select('*')
  .eq('corrida_id', corrida.id).order('tipo').order('numero');

// las etiquetas de UNA hoja (pedir hoja por hoja: Supabase devuelve máximo 1000 filas por consulta)
const { data: etiquetas } = await sb.from('etiquetas').select('*')
  .eq('corrida_id', corrida.id).eq('tipo', 'CON').eq('hoja', 3).order('orden');
```

### Cómo dibujar una hoja

- Dibujar un rectángulo de `ancho_mm` × `alto_mm` a escala.
- Cada etiqueta ocupa una **celda** que empieza en `(x_mm, y_mm)` (medidos desde la esquina **superior izquierda** de la hoja) y mide:
  - derecha (`acostada` = false): `etiqueta_ancho_mm` de ancho × `etiqueta_alto_mm + marca_alto_mm` de alto;
  - acostada (`acostada` = true, girada 90°): `etiqueta_alto_mm + marca_alto_mm` de ancho × `etiqueta_ancho_mm` de alto.
- Si `marca_alto_mm` > 0, la franja negra con la **marca** ocupa el borde **superior** de la celda si va derecha y el borde **izquierdo** si va acostada. El resto de la celda es el marco de la etiqueta.
- Las posiciones ya incluyen márgenes (3 mm), la cuadrícula principal y las etiquetas acostadas del sobrante: **no hay que calcular nada**, basta dibujar cada celda en su sitio. Todas las hojas de un PDF tienen el mismo tamaño; la última puede estar incompleta.
- Cada ticket muestra lo esencial (código, talla, precio, marca, color) y su estado: **pegada / pendiente**.
- Tocar un ticket abre el **detalle completo** (todos los campos, `copia` de `copias`, `fila_hoja` = fila en la hoja de cálculo) con el botón de marcar/desmarcar.
- Mostrar el **progreso** de cada hoja (por ejemplo "12 / 54 pegadas") y permitir cambiar entre las hojas de la corrida y entre los dos PDF.

### Marcar

```js
await sb.from('etiquetas')
  .update({ pegada: true, pegada_en: new Date().toISOString() })   // pegada: false / pegada_en: null para desmarcar
  .match({ corrida_id: corrida.id, tipo: 'CON', orden: 117 });
```

Opcional: activar Realtime en `corridas` y `etiquetas` (hay una línea comentada al final del SQL) para que varias personas o dispositivos vean los checks al instante y la pantalla se entere cuando se genera una corrida nueva.

### Qué hacer cuando cambia la corrida

Al generar de nuevo, la corrida que la pantalla tenía abierta **desaparece** y los checks se pierden (es lo esperado: la última siempre reemplaza). La pantalla debe detectarlo (una actualización que no afecta ninguna fila, o Realtime) y recargar la corrida más reciente, avisando al usuario.

## 5. Escanear con la cámara (función oculta)

El QR de cada etiqueta contiene **solo el `codigo`** (por ejemplo `27OCT26JED01`): es corto y fácil de leer.

- Abrir la cámara trasera (`getUserMedia` con `facingMode: 'environment'`) y escanear de forma continua.
- Solo funciona en **HTTPS** (o `localhost`); en iPhone/Safari el video necesita `playsinline` y arrancar por una acción del usuario.
- Usar `BarcodeDetector` cuando exista, con una **librería de respaldo** (ZXing o similar) para los navegadores que no lo tienen. Validar con QR impresos de verdad (las etiquetas miden entre 1,3 y 1,6 cm de QR).
- Evitar lecturas repetidas del mismo QR en pocos segundos.

**Qué hacer con el código escaneado:**

1. Buscar en la **hoja abierta** una etiqueta con ese `codigo` y `pegada` = false, y **marcarla** (la de menor `orden`).
2. Si no hay en esa hoja, buscar en el resto de la corrida (`.eq('codigo', texto).eq('pegada', false).order('tipo').order('orden').limit(1)`), **abrir esa hoja** y marcarla.
3. Si todas las copias de ese código ya están pegadas, o el código no existe en la corrida, avisarlo claramente.
4. **Copias repetidas:** una fila de la hoja de cálculo puede tener varias copias (por ejemplo zapatos, que se imprimen dos veces) y **todas tienen el mismo código en el QR**; al escanear se marca la primera sin marcar y el usuario puede corregir tocando.

Mostrar una confirmación visible (código, producto, hoja y posición) para que quien está pegando vea que se leyó.

## 6. Cómo probarlo

Sin esperar al generador, se puede insertar una corrida de prueba (después se borra con `delete from corridas where id = 'PRUEBA'`):

```sql
insert into corridas (id, formato, orientacion, con_marca, total_etiquetas) values ('PRUEBA', 'A4', 'Vertical', true, 3);
insert into hojas (corrida_id, tipo, numero, pdf, ancho_mm, alto_mm, etiqueta_ancho_mm, etiqueta_alto_mm, marca_alto_mm, total)
  values ('PRUEBA', 'CON', 1, 'DESCRIPCION_QR_A4.pdf', 210, 297, 28, 49, 3, 3);
insert into etiquetas (corrida_id, tipo, orden, hoja, x_mm, y_mm, acostada, codigo, copia, copias, fila_hoja, marca, talla, venta, color, estilo, categoria, descripcion, genero, zapatos) values
  ('PRUEBA', 'CON', 0, 1, 3,  3, false, '27OCT26JED01', 1, 1, 3, 'ELEVEN', '10', 88000, 'AZUL OSCURO', 'SIN BOLSILLO', 'JEAN DAMA', 'JEAN LICRADO', 'DAMA', false),
  ('PRUEBA', 'CON', 1, 1, 31, 3, false, '27OCT26JED02', 1, 1, 4, 'ELEVEN', '12', 88000, 'NEGRO', 'CHAMBRAY', 'JEAN DAMA', 'JEAN LICRADO', 'DAMA', false),
  ('PRUEBA', 'CON', 2, 1, 3, 55, true,  '27OCT26JED03', 1, 1, 5, 'ANGEL', 'XL', 94000, 'CAFÉ', 'OCHENTERO', 'PANTALÓN DAMA', 'PANTALÓN ANCHO', 'DAMA', false);
```

Con eso debe verse una hoja A4 vertical con tres etiquetas (la tercera acostada) y franja de marca. Luego,
con la hoja impresa por el generador, **prueba obligatoria con papel**: escanear con un celular los
QR de varias etiquetas y confirmar que se marcan.

## 7. Fuera de alcance

- No hay que generar ni modificar etiquetas o PDF: eso lo hace el programa Generar QRs.
- No cambiar las tablas sin avisar: el generador escribe en ellas con esos nombres exactos. Si hace falta otro campo, se pide y se agrega en ambos lados.
