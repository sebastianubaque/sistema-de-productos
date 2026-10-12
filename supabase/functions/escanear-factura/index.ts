// Supabase Edge Function: escanear-factura
// Recibe imágenes (data URL JPEG) de una factura de proveedor + el vocabulario
// que ya usa la tienda, y devuelve los productos extraídos por OpenAI en JSON.
//
// Secrets necesarios (Supabase → Edge Functions → Secrets):
//   OPENAI_API_KEY   (obligatorio)
//   OPENAI_MODEL     (opcional, por defecto "gpt-4.1")

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_IMAGES = 8;
const MAX_TOTAL_CHARS = 25_000_000; // ~18 MB de imágenes en base64

const nullableString = { type: ["string", "null"] };

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["proveedor", "numero_factura", "fecha", "observaciones", "items"],
  properties: {
    proveedor: nullableString,
    numero_factura: nullableString,
    fecha: { type: ["string", "null"], description: "YYYY-MM-DD" },
    observaciones: nullableString,
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "codigo", "marca", "descripcion", "genero", "estilo", "color", "talla",
          "cantidad", "precio_compra", "precio_venta", "grupo", "nota",
        ],
        properties: {
          codigo: nullableString,
          marca: { type: "string" },
          descripcion: { type: "string" },
          genero: { type: "string" },
          estilo: { type: "string" },
          color: { type: "string" },
          talla: { type: "string" },
          cantidad: { type: "integer" },
          precio_compra: { type: ["number", "null"] },
          precio_venta: { type: ["number", "null"] },
          grupo: nullableString,
          nota: nullableString,
        },
      },
    },
  },
};

const SYSTEM_PROMPT = `Eres un asistente que digitaliza facturas de proveedores para "Tienda Jahdiel", una tienda de ropa en Colombia.
Lee TODAS las páginas con mucho detalle y extrae cada producto. Devuelve SOLO el JSON del esquema.

REGLAS DE EXTRACCIÓN
- Una fila (item) por cada combinación de referencia + color + talla. Si la factura trae una curva de tallas
  (ej. "S-M-L x2 c/u", "tallas 6 8 10 12", columnas por talla), sepárala en un item por talla con su cantidad.
  Si no se puede saber cómo se reparten las tallas o colores, deja un solo item con talla/color vacío y explícalo en "nota".
- codigo: la referencia / código / SKU del proveedor tal como aparece. null si no hay.
- marca: la marca del producto. Si la factura no la indica por producto pero el proveedor es claramente la marca, usa el nombre del proveedor. Si no se sabe, "".
- descripcion: tipo de prenda + rasgo principal, corto (ej. "BLUSA CHALIS", "JEAN SKINNY", "CAMISA MANGA LARGA"). Empieza por el tipo de prenda.
- genero: DAMA, HOMBRE, NIÑO, NIÑA o UNISEX. Dedúcelo de la descripción o tallas si es evidente; si no, "".
- estilo, color, talla: "" si no aparecen. Varios colores de un mismo item: sepáralos con "/".
- cantidad: unidades (entero). Si viene en docenas, conviértela a unidades.
- precio_compra: precio UNITARIO de compra en pesos colombianos, número sin puntos ni símbolos
  (ej. "$37.000" → 37000; "1.250.000" → 1250000). Si solo hay total de línea, divide por la cantidad.
  Si los precios vienen sin IVA y el IVA está aparte, usa el precio unitario tal cual y avisa en "observaciones".
  null si no aparece.
- precio_venta: SOLO si la factura muestra precio de venta al público / PVP / precio sugerido. Si no, null. NUNCA lo inventes.
- grupo: productos que son la misma prenda (misma marca + descripción + género + precios) y solo cambian color/talla/estilo
  deben compartir el mismo texto de grupo (ej. la referencia). Si es un producto suelto, null.
- nota: algo dudoso o ilegible de ese item; si no hay, null.
- observaciones: avisos generales (páginas cortadas, totales que no cuadran, descuentos, IVA). null si nada.
- No inventes productos. Ignora subtotales, impuestos, fletes y descuentos como items.

COHERENCIA CON EL SISTEMA
- Todo el texto en MAYÚSCULAS.
- Si un valor equivale a uno del VOCABULARIO de la tienda (mismo significado, variación de escritura, abreviatura
  o sinónimo, ej. "AZ" → "AZUL", "Negro" → "NEGRO", "Lev's" → "LEVIS"), usa EXACTAMENTE el del vocabulario.
- Solo usa un valor nuevo cuando de verdad no exista equivalente.`;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function cleanList(v: unknown, max: number): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((s) => typeof s === "string" && s.length <= 80).slice(0, max);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, error: "Método no permitido" }, 405);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return json({ ok: false, error: "Falta configurar OPENAI_API_KEY en Supabase." }, 500);
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4.1";

  let body: { images?: unknown; vocabulario?: Record<string, unknown> };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "Solicitud inválida." }, 400);
  }

  const images = Array.isArray(body.images)
    ? body.images.filter((s): s is string => typeof s === "string" && s.startsWith("data:image/"))
    : [];
  if (!images.length) return json({ ok: false, error: "No llegaron imágenes." }, 400);
  if (images.length > MAX_IMAGES) return json({ ok: false, error: `Máximo ${MAX_IMAGES} páginas por escaneo.` }, 400);
  if (images.reduce((n, s) => n + s.length, 0) > MAX_TOTAL_CHARS) {
    return json({ ok: false, error: "Las imágenes son demasiado pesadas." }, 413);
  }

  const v = body.vocabulario || {};
  const vocab = {
    marcas: cleanList(v.marcas, 300),
    generos: cleanList(v.generos, 20),
    estilos: cleanList(v.estilos, 200),
    colores: cleanList(v.colores, 250),
    tallas: cleanList(v.tallas, 80),
    descripciones: cleanList(v.descripciones, 300),
  };
  const vocabText = Object.entries(vocab)
    .map(([k, list]) => `${k.toUpperCase()}: ${list.length ? list.join(" | ") : "(vacío)"}`)
    .join("\n");

  const openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `VOCABULARIO DE LA TIENDA (valores ya usados):\n${vocabText}\n\n` +
                `La factura tiene ${images.length} página(s). Extrae todos los productos.`,
            },
            ...images.map((url) => ({ type: "image_url", image_url: { url, detail: "high" } })),
          ],
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "factura_proveedor", strict: true, schema: SCHEMA },
      },
    }),
  });

  const result = await openaiRes.json().catch(() => null);
  if (!openaiRes.ok) {
    console.error("OpenAI error", openaiRes.status, result);
    const msg = result?.error?.message || `OpenAI respondió ${openaiRes.status}`;
    return json({ ok: false, error: `Error de la IA: ${msg}` }, 502);
  }

  const message = result?.choices?.[0]?.message;
  if (message?.refusal) return json({ ok: false, error: `La IA no pudo procesar el documento: ${message.refusal}` }, 422);

  try {
    const data = JSON.parse(message?.content || "");
    return json({ ok: true, data, model, usage: result.usage });
  } catch {
    console.error("Respuesta no JSON", message?.content);
    return json({ ok: false, error: "La IA devolvió una respuesta incompleta. Intenta de nuevo." }, 502);
  }
});
