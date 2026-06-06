# Tienda Jahdiel — Estructura Completa del Proyecto

> **Archivo único:** `index.html` (≈ 4830 líneas)  
> **Stack:** HTML + CSS + JavaScript inline. Sin frameworks. Sin build tools.  
> **Plataforma destino:** Mobile-first (PWA-like). Optimizado para pantallas ≤ 480px.  
> **Estilo visual:** Dark glassmorphism — fondos oscuros semitransparentes, backdrop-filter blur, gradientes sutiles.

---

## 1. ESTRUCTURA GENERAL DEL ARCHIVO

```
index.html
├── <head>          (líneas 1–16)       — Meta, fuentes, librerías externas
├── <style>         (líneas 16–847)     — Todo el CSS inline
├── <body>          (líneas 849–1280)   — HTML estático: header, páginas, nav
└── <script>        (líneas 1281–4829)  — Toda la lógica JS inline
```

---

## 2. LIBRERÍAS EXTERNAS

| Librería | Versión | Uso |
|---|---|---|
| Inter + Space Grotesk | Google Fonts | Tipografía |
| Lucide Icons | latest (CDN) | Todos los íconos SVG |
| Supabase JS | v2 (CDN) | Base de datos en la nube |
| ExcelJS | 4.3.0 (CDN) | Exportación a Excel |
| element_sdk / data_sdk | SDK interno | Plataforma de hosting |

---

## 3. CSS — VARIABLES Y SISTEMA DE DISEÑO (líneas 17–46)

```css
/* Paleta de colores */
--bg: #0A0E1A          /* fondo principal */
--bg2: #0F1525         /* fondo modales */
--accent: #6C63FF      /* violeta principal */
--green: #10D9A0       /* éxito / precios venta */
--yellow: #FFB547      /* variaciones / advertencia */
--red: #FF5757         /* eliminar / error */
--blue: #38BDF8        /* info */

/* Radios */
--radius: 16px         /* cards principales */
--radius-sm: 10px      /* inputs, botones */
--radius-xs: 7px       /* chips, pills pequeñas */

/* Glassmorphism */
--glass: blur(20px) saturate(180%)
```

---

## 4. HTML — LAYOUT Y PÁGINAS (líneas 849–1280)

### 4.1 Header (sticky, líneas 856–878)
```
.header (sticky top, glassmorphism, z-index:100)
├── .header-brand        — Logo (favicon.png) + "Tienda Jahdiel" + "Tienda de Ropa"
├── .header-actions      — Botones ícono (monitor, dollar-sign) — decorativos actualmente
└── #headerInvoiceBadge  — Chip morado que muestra "#0001" de la factura activa
                           Aparece solo cuando hay factura activa. Clic → va a tab Facturas.
```

### 4.2 Páginas (`.page`, ocultas por defecto, `.page.active` visible)

| ID | Tab | Descripción |
|---|---|---|
| `#page-home` | Inicio | Dashboard con stats de factura activa + sincronización |
| `#page-add` | Agregar | Formulario para crear producto simple o con variaciones |
| `#page-products` | Productos | Lista de todos los productos del inventario |
| `#page-invoices` | Facturas | Gestión de facturas (crear, ver, enviar) |

### 4.3 Bottom Nav (fixed, líneas 1262–1279)
4 botones: Inicio / Agregar / Productos / Facturas  
`switchPage(name, el)` maneja la navegación — cambia `.active` en página y botón.

### 4.4 FAB (flotante)
`#fabInvoice` — botón "+" circular morado, visible solo en tab Facturas.  
Llama a `openNewInvoiceSheet()`.

---

## 5. PAGE: INICIO / DASHBOARD (`#page-home`)

### Stats de factura activa (líneas 888–915)
5 tarjetas en grid 2 columnas:
- **Ítems** (`#statTotal`) — cantidad de ítems distintos
- **Unidades** (`#statUnits`) — total de unidades sumadas
- **Inversión** (`#statInv`) — suma precio_compra × qty (formato COP)
- **Total venta** (`#statGain`) — suma precio_venta × qty (formato COP)
- **Costo Ticket** (`#statTicket`) — unidades × $250 (formato COP, ancho completo)

Función: `updateStats()` línea 2544. Calcula en base a `getActiveInvoice()`.  
Formato COP: `n.toLocaleString('es-CO', {style:'currency', currency:'COP', ...})`

### Sincronización (líneas 918–932)
- **Enviar a Google Sheets** — `#syncSheetsBtn`
- **Ver Sheets** — `#viewSheetsBtn`
- **Borrar Sheets** — `#clearSheetsBtn`
Configurados en `setupSheetsButtons()` línea 3678.

### Acciones rápidas (líneas 934–944)
- **Analizar** → `analyzeDatabase()` — modal con gráficas de distribución
- **Limpiar todo** → `clearAllProducts()` — vacía la factura activa (NO borra inventario)

### Banner factura activa
`#homeInvoiceBar` — renderizado por `renderInvoiceBar('homeInvoiceBar')`.

---

## 6. PAGE: AGREGAR PRODUCTO (`#page-add`)

### Selector de tipo (líneas 961–968)
Toggle: **Simple** / **Con variaciones** → `setProductType(type)` línea 2013.  
- Simple: muestra `#simpleFields` (estilo, color, talla, cantidad)
- Con variaciones: oculta `#simpleFields`, muestra `#variationsCta`

### Formulario acordeón (`#productForm`, líneas 970–1219)

Cada campo está envuelto en `.ac-field` con dos estados:
- **Contraído** (`.ac-collapsed`): muestra el header con valor resumido
- **Expandido**: muestra el input/control completo

**Campos acordeón:**
| ID campo | Tipo | Chips | Multi-select |
|---|---|---|---|
| `marca` | texto | ✅ | ❌ |
| `descripcion` | texto | ❌ | ❌ |
| `genero` | texto | ✅ | ❌ |
| `precios` | 2 inputs numéricos | ❌ | ❌ |
| `estilo` | texto | ✅ | ✅ |
| `color` | texto | ✅ | ✅ |
| `talla` | texto | ✅ | ✅ |
| `cantidad` | stepper numérico | ❌ | ❌ |

**Lógica acordeón (líneas 1508–1597):**
```
AC_FIELDS = ['marca','descripcion','genero','precios','estilo','color','talla','cantidad']

acExpand(name)         — expande un campo, colapsa los demás
acCollapse(name)       — colapsa un campo, actualiza el summary en el header
acGetValue(name)       — extrae el valor actual del campo
acUpdateSummary(name)  — escribe el valor en #acv-{name}
acOnBlur(name)         — al perder foco: guarda valor y colapsa
initMultiFieldAccordions() — agrega listener focusout en el bloque entero
                             → colapsa cuando el foco sale del bloque completo
```

**Lógica de chips (accesos rápidos):**
```
usedValues = { marca:[], genero:[], estilo:[], color:[], talla:[] }
deletedValues = localStorage 'jahdiel_deleted_values' — blacklist de eliminados

uvAdd(fieldId, val)    — agrega al inicio del array (newest first)
uvRemove(fieldId, val) — elimina y agrega a blacklist
uvAddSmart(fieldId, val) — para multi-select: split por '/' y guarda partes individuales
renderChips(fieldId)   — renderiza los chips en #chips-{fieldId}

MULTI_SELECT_FIELDS = ['color','estilo','talla']
chipToggleMulti(fieldId, v) — toggle de valor en input con separador '/'
                              Ej: BLANCO/NEGRO al seleccionar ambos

Valor nuevo: input.classList = 'is-new' (rojo) → aparece botón .add-new-btn (+)
Valor existente: input.classList = 'is-existing' (verde)
confirmAddNew(fieldId) — guarda el nuevo valor en usedValues
```

**Eliminación de chips:**  
`×` en cada chip → `showConfirmation(...)` → `uvRemove()` + `SFX.delete()`

**Cantidad:**  
Stepper: `stepQty(id, delta)`, chips rápidos +1 +5 +10 +25 y reset 0.

**Precios:**  
`formatPriceInput()` — formato con puntos al escribir  
`formatPriceBlur()` — formato final al salir  
`calcPriceInfo()` — muestra ganancia y % de margen en banner debajo

**Submit (línea 2041–2083):**  
`productForm.onsubmit` → crea objeto producto → guarda en `currentProducts` → `saveToLocalStorage()` → `queueSupabaseSync('products')` → agrega a factura activa si existe → `SFX.create()` → limpia formulario.

### Modal de variaciones (`#variationsModal`, líneas 2087–2540)

Se abre con `openVariationsModal()`.  
Cada variación tiene: Estilo, Color, Talla, Cantidad.  
`tempVariations[]` — array temporal durante edición.

**Funciones clave:**
```
openVariationsModal(isReopen)  — construye el HTML del modal
varInputId(vid, fieldType)     — genera ID del input: "varColor-{vid}"
varRenderChips(vid, fieldType) — renderiza chips en #varChips-{vid}-{fieldType}
varShowChips / varHideChips    — muestra/oculta al enfocar/blur
varCheckNew(vid, fieldType, v) — detecta si es valor nuevo (+ botón)
varConfirmAdd(vid, fieldType)  — guarda nuevo valor
syncVarModalFromDOM()          — lee el DOM y actualiza tempVariations[]
addTempVariation()             — agrega fila vacía al modal
removeTempVariation(id)        — elimina fila del modal
saveAllVariations()            — guarda todas las variaciones como productos
```

---

## 7. PAGE: PRODUCTOS (`#page-products`)

### Renderizado (`renderProductsPage()`, línea 3828)

Los productos se agrupan por tipo:
- **Simple**: cada `p.tipo === 'simple'` → tarjeta individual
- **Con variaciones**: productos con misma `marca_descripcion_genero` → una sola tarjeta agrupada

**Estructura tarjeta (ambos tipos):**
```
.product-card
├── .product-card-header (clickeable → toggleCardBody())
│   ├── badge Simple / Con variaciones
│   ├── .product-name (MARCA — DESCRIPCION)
│   ├── .product-meta (categoría · género · variaciones · uds.)
│   └── .card-chevron (↓ rota 180° al abrir)
└── .product-card-body (max-height:0 por defecto, .open → 4000px)
    ├── .product-attrs (pills: Color, Talla, Cantidad, P.Compra, P.Venta, Ganancia)
    ├── [variaciones] .var-row por cada variación (color, talla, cant + botones icon)
    ├── [acciones] .card-body-actions → .btn-icon (editar, eliminar, agregar)
    └── [grupo] botones "Editar grupo" y "Agregar variación"
```

**Toggle colapso:**
```
toggleCardBody(cid)  — abre/cierra .product-card-body por ID
toggleVarList(gid)   — abre/cierra .var-list-body (solo en facturas)
```

**Botones icon-only (`.btn-icon`, 28×28px):**
- Normal: borde gris sutil
- `.danger` hover: fondo rojo semitransparente

### Edición individual (`editProduct(productId)`, línea 2704)
Modal bottom sheet con todos los campos editables + stepper de cantidad.

### Edición de grupo (`editSharedFields(marca, desc, genero)`, línea 2781)
Modal que edita Marca, Descripción, P.Compra y P.Venta para **todas** las variaciones del grupo a la vez.  
Identifica el grupo filtrando `currentProducts` por los tres valores clave.

### Filtros (líneas 2910–2985)
Panel colapsable con:
- Búsqueda de texto
- Filtro por categoría
- Filtro por marca
- Filtro por tipo (simple / variaciones)
- Ordenamiento (fecha, marca, precio, cantidad)

`applyFilters()` actualiza `filteredProducts[]` y llama `updateProductsDisplay()`.

---

## 8. PAGE: FACTURAS (`#page-invoices`)

### Estructura de datos (línea 4081)
```js
invoices = [{
  id: string,           // uuid
  number: number,       // auto-incremental
  name: string,         // nombre del cliente
  date: string,         // YYYY-MM-DD
  items: [{
    productId, marca, descripcion, color, talla, estilo,
    precioCompra, precioVenta, qty
  }],
  status: 'pending' | 'sent',
  createdAt: timestamp
}]
```
Persistido en `localStorage` como `jahdiel_invoices`.

### Factura activa
```
activeInvoiceId  — guardado en localStorage 'jahdiel_active_invoice'
getActiveInvoice()   — devuelve el objeto o null
setActiveInvoice(id) — cambia activa + refreshAllInvoiceBars()
```

### Barra de factura activa
Aparece en Inicio y Agregar como `.active-invoice-bar`:
- **Con factura:** fondo violeta, muestra `#XXXX NombreCliente · N ítems · $total`
- **Sin factura:** fondo rojo, mensaje de advertencia
- Clic → `openInvoiceSwitcher()` — sheet para cambiar factura activa

### renderInvoices() (línea 4113)
Renderiza cada factura como `.invoice-card` con:
- Número, nombre, fecha, estado (badge Pendiente/Enviada)
- Total en verde
- Botones: **Ver detalle** / **Enviar** / **Eliminar**

### Modal Ver Detalle (`openInvoiceDetail`, línea 4204)
Bottom sheet con estructura flex en 3 secciones:
```
.modal-sheet (flex column, max-height:92dvh)
├── Cabecera fija    — #XXXX, nombre, fecha, estado
├── Lista scrollable — ítems (marca, attrs, qty, precio · btn-icon ×)
└── Footer fijo      — "N ítems · M uds." + total grande + [Enviar a Sheets] [Cerrar]
```
El ID del overlay es `#invoiceDetailOverlay` — se reutiliza para refrescar sin cerrar.

### Crear factura (`openNewInvoiceSheet`, línea 4154)
Sheet para ingresar nombre y fecha → crea el objeto → lo setea como activa.

### Selector de factura (`openInvoiceSwitcher`, línea 4032)
Sheet con lista de todas las facturas. Clic en una → `setActiveInvoice(id)`.

### Enviar a Sheets (`confirmSendInvoice`, líneas 3421+)
Envía la factura a Google Sheets via API. Cambia `status` a `'sent'`.

---

## 9. DATOS Y PERSISTENCIA

### localStorage (claves)
| Clave | Contenido |
|---|---|
| `jahdiel_products` | Array de productos `currentProducts[]` |
| `jahdiel_invoices` | Array de facturas `invoices[]` |
| `jahdiel_invoice_counter` | Contador auto-incremental de facturas |
| `jahdiel_active_invoice` | ID de la factura activa |
| `jahdiel_deleted_values` | Objeto `deletedValues` — blacklist de chips eliminados |

### Supabase (base de datos en la nube)
```
SUPABASE_URL: https://npcjpugamvptxsltepih.supabase.co
Tablas: SUPABASE_TABLES = { products: '...', ... }

queueSupabaseSync(scope)  — encola sync con debounce
snapshotCollection(scope) — sincroniza con Supabase
loadFromSupabase()        — carga datos al iniciar
refreshFromSupabase()     — se llama cada 8 segundos (setInterval)
```

### Google Sheets API
```
SHEETS_API_URL: https://script.google.com/macros/s/...
productToSheetRow(p)  — convierte producto a fila de hoja de cálculo
```

---

## 10. FUNCIONES UTILITARIAS CLAVE

```js
// Navegación
switchPage(name, el)           — cambia tab activo

// UI
showToast(title, msg, type)    — notificación esquina superior derecha
showConfirmation(title, msg, onConfirm, okText, cancelText, isGreen)
                               — modal de confirmación centrado (z-index:2000)

// Precios
formatPriceInput(input)        — formato con puntos al escribir
formatPriceBlur(input)         — formato final
parsePriceInput(input)         — lee y limpia a número
formatShort(n)                 — abrevia: 1000→1K, 1000000→1M

// Categoría automática
generateCategory(descripcion, genero) — clasifica el producto por palabras clave

// Audio
SFX.create()        — sonido al crear producto
SFX.editProduct()   — sonido al editar
SFX.delete()        — sonido al eliminar chip
SFX.deleteProduct() — sonido al eliminar producto
SFX.addInventory()  — sonido al agregar a factura
SFX.clearAll()      — sonido al limpiar
```

---

## 11. INICIALIZACIÓN (`init()`, línea 4803)

```
init()
├── elementSdk.init()          — SDK de plataforma
├── loadFromLocalStorage()     — carga productos y valores usados
├── loadInvoices()             — carga facturas
├── loadFromSupabase()         — sincroniza con la nube (await)
├── loadActiveInvoice()        — restaura la factura activa
├── applyDataAfterSupabaseRefresh() — aplica datos remotos
├── refreshAllInvoiceBars()    — actualiza las barras de factura
├── setupSheetsButtons()       — configura los botones de Sheets
├── renderAllChips()           — renderiza chips de campos
├── initMultiFieldAccordions() — registra listeners focusout
├── lucide.createIcons()       — renderiza todos los íconos
├── updateStats()              — calcula stats del dashboard
└── setInterval(refreshFromSupabase, 8000) — polling cada 8 seg
```

---

## 12. SISTEMA DE CHIPS — RESUMEN COMPLETO

```
Campos con chips: marca, genero, estilo, color, talla
Multi-select (valor separado por /): estilo, color, talla

usedValues = {
  marca:  [],          // newest first via unshift
  genero: ['DAMA','HOMBRE','NIÑO','NIÑA','UNISEX'],
  estilo: [],
  color:  ['NEGRO','BLANCO','AZUL','ROJO','VERDE','GRIS'],
  talla:  ['XS','S','M','L','XL','XXL','XXXL','6','8','10','12']
}

deletedValues = localStorage — evita que chips eliminados reaparezcan

Flujo chip:
1. renderChips(fieldId)  — lee usedValues, renderiza .chip buttons
2. chip click            — chipToggleMulti() o setea valor directo
3. foco sale del bloque  — focusout → acCollapse() → guarda valor
4. × en chip             — showConfirmation → uvRemove() → renderChips()

Input desconocido:
1. oninput → checkNewValue() → is-new (rojo) + btn + verde visible
2. toca +  → confirmAddNew() → uvAdd() → renderChips() → is-existing (verde)
```

---

## 13. CLASES CSS MÁS USADAS — REFERENCIA RÁPIDA

| Clase | Descripción |
|---|---|
| `.product-card` | Tarjeta de producto colapsable |
| `.product-card-body.open` | Body de tarjeta expandido |
| `.card-chevron.open` | Chevron rotado 180° |
| `.btn-icon` | Botón cuadrado 28×28 sin texto |
| `.btn-icon.danger` | Ídem, se pone rojo al hover |
| `.card-body-actions` | Fila de acciones al fondo del card |
| `.ac-field` | Bloque acordeón del formulario |
| `.ac-field.ac-collapsed` | Estado colapsado (muestra header) |
| `.ac-body` | Contenido expandible del acordeón |
| `.chips-row` | Fila de chips de acceso rápido |
| `.chip.active` | Chip seleccionado (fondo violeta) |
| `.add-new-btn` | Botón + verde junto al input |
| `.form-input.is-new` | Input con valor desconocido (rojo) |
| `.form-input.is-existing` | Input con valor conocido (verde) |
| `.var-row` | Fila de variación individual |
| `.var-chips-full` | Chips ancho completo en modal var. |
| `.active-invoice-bar` | Barra de factura activa |
| `.modal-overlay` | Overlay de fondo oscuro |
| `.modal-sheet` | Hoja modal desde abajo |
| `.stat-card` | Tarjeta de estadística en dashboard |
| `.attr-pill` | Píldora de atributo en tarjeta |
| `.invoice-card` | Tarjeta de factura en listado |

---

## 14. GITHUB

Repositorio: `https://github.com/sebastianubaque/sistema-de-productos`  
Rama principal: `main`  
Último commit al crear este documento: `de2b166`
