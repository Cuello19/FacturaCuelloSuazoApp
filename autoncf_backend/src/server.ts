import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import multer from 'multer';
import { GoogleGenAI, Type, Schema } from '@google/genai';
import { createClient } from '@supabase/supabase-js';
import swaggerUi from 'swagger-ui-express';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// 🗄️ Configuración de Multer para recibir la imagen en memoria
const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: { fileSize: 5 * 1024 * 1024 } 
});

// ⚡ Inicialización de Clientes Externos
const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_ANON_KEY || ''
);

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// 📝 ESQUEMA FISCAL DINÁMICO COMPLETAMENTE PLANO (Mapeo 606 / Simple)
const esquemaFiscalDominicano: Schema = {
  type: Type.OBJECT,
  properties: {
    rnc: { type: Type.STRING, description: "RNC o Cédula del suplidor/emisor de la factura. Solo números, sin guiones." },
    tipo_id: { type: Type.STRING, description: "Pon '1' si identificas un RNC comercial o '2' si es Cédula." },
    nombre_empresa: { type: Type.STRING, description: "Nombre comercial o razón social del emisor de la factura." },
    tipo_gasto: { type: Type.STRING, description: "Formato catálogo oficial (ej: '02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS')." },
    ncf: { type: Type.STRING, description: "Número de Comprobante Fiscal completo (ej. B01..., E31...)." },
    documento_modificado: { type: Type.STRING, description: "NCF ó Documento Modificado si aplica, de lo contrario vacío." },
    fecha: { type: Type.STRING, description: "Para 606 usa Periodo (YYYYMM). Para Simple usa Formato Completo (YYYY-MM-DD)." },
    fecha_pago: { type: Type.STRING, description: "Para 606 usa Periodo (YYYYMM). Para Simple usa Formato Completo (YYYY-MM-DD)." },
    monto_servicios: { type: Type.NUMBER, description: "Monto Facturado en Servicios (0.0 si es Bienes o formato simple)." },
    monto_bienes: { type: Type.NUMBER, description: "Monto Facturado en Bienes (0.0 si es Servicios o formato simple)." },
    monto_total: { type: Type.NUMBER, description: "Total Monto Facturado final bruto de la operación." },
    itbis_total: { type: Type.NUMBER, description: "Monto total del ITBIS liquidado." },
    itbis_retenid: { type: Type.NUMBER, description: "Monto de ITBIS Retenido." },
    itbis_proporcional: { type: Type.NUMBER, description: "ITBIS sujeto a Proporcionalidad (Art. 349)." },
    itbis_costo: { type: Type.NUMBER, description: "ITBIS llevado al Costo." },
    itbis_adelantar: { type: Type.NUMBER, description: "ITBIS por Adelantar." },
    itbis_percibido: { type: Type.NUMBER, description: "ITBIS percibido en compras." },
    tipo_retencion_isr: { type: Type.STRING, description: "Tipo de Retención en ISR si aplica." },
    retencion_renta: { type: Type.NUMBER, description: "Monto Retención Renta." },
    isr_percibido: { type: Type.NUMBER, description: "ISR Percibido en compras." },
    isc: { type: Type.NUMBER, description: "Impuesto Selectivo al Consumo." },
    otros_impuestos: { type: Type.NUMBER, description: "Otros Impuesto/Tasas." },
    monto_ley: { type: Type.NUMBER, description: "Monto Propina Legal (10%)." },
    forma_pago: { type: Type.STRING, description: "Método de pago oficial (ej: '03 - TARJETA CRÉDITO/DÉBITO', '01 - EFECTIVO')." }
  },
  required: ["rnc", "tipo_id", "ncf", "monto_total", "itbis_total", "forma_pago"]
};

// =====================================================================
// 📖 ESPECIFICACIÓN ESTÁNDAR SWAGGER / OPENAPI 3.0
// =====================================================================
const swaggerDocument = {
  openapi: "3.0.0",
  info: {
    title: "AutoNCF API - Documentación Fiscal",
    version: "1.0.0",
    description: "API Engine basada en Gemini 2.5 Flash para auditoría e indexación nativa de comprobantes fiscales de la República Dominicana en Supabase PostgreSQL.",
    contact: { name: "Soporte Técnico AutoNCF" }
  },
  servers: [
    { url: "http://localhost:3000", description: "Servidor Local de Desarrollo" },
    { url: "https://autoncf-backend.onrender.com", description: "Servidor de Producción (Render)" }
  ],
  paths: {
    "/api/procesar-factura": {
      post: {
        summary: "Procesar y auditar factura física en lote",
        description: "Recibe la imagen de la factura vía multipart/form-data, ejecuta el análisis visual con Gemini AI adaptando el prompt contable según el formato solicitado y guarda en Supabase.",
        requestBody: {
          required: true,
          content: {
            "multipart/form-data": {
              schema: {
                type: "object",
                properties: {
                  empresa_id: { type: "string", format: "uuid" },
                  tipoFormato: { type: "string", example: "606", description: "Esquema solicitado ('606' o 'simple')" },
                  creado_por: { type: "string" },
                  imagen: { type: "string", format: "binary" }
                },
                required: ["empresa_id", "tipoFormato", "creado_por", "imagen"]
              }
            }
          }
        },
        responses: {
          201: { description: "Factura auditada e insertada de forma limpia." },
          400: { description: "Variables requeridas faltantes." },
          500: { description: "Fallo en el motor de IA." }
        }
      }
    }
  }
};

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// 🚀 Endpoint Principal Refactorizado Multi-Formato con Carga de Imágenes
app.post('/api/procesar-factura', upload.single('imagen'), async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { empresa_id, creado_por, tipoFormato } = req.body;
    const file = req.file;

    // Normalizamos el formato entrante
    const formatoActual = tipoFormato === 'simple' ? 'simple' : '606';

    if (!file) {
      res.status(400).json({ error: "No se proporcionó ninguna imagen de factura." });
      return;
    }

    if (!empresa_id || !creado_por) {
      res.status(400).json({ error: "Variables de entorno corporativas faltantes." });
      return;
    }

    // 📦 STEP 1: Subir la imagen recibida en memoria directamente a tu bucket público 'facturas'
    const fileName = `${Date.now()}_${Math.floor(Math.random() * 1000)}_factura.jpg`;
    
    const { data: storageData, error: storageError } = await supabase.storage
      .from('facturas')
      .upload(fileName, file.buffer, {
        contentType: file.mimetype || 'image/jpeg',
        upsert: true
      });

    if (storageError) {
      console.error("❌ Error subiendo imagen física al Storage de Supabase:", storageError);
      res.status(500).json({ error: "Fallo crítico al resguardar la imagen del comprobante." });
      return;
    }

    // 🔗 STEP 2: Extraer la URL pública permanente del asset digitalizado
    const { data: publicUrlData } = supabase.storage
      .from('facturas')
      .getPublicUrl(fileName);

    const publicFileUrl = publicUrlData.publicUrl;

    const imagenDataPart = {
      inlineData: {
        data: file.buffer.toString("base64"),
        mimeType: file.mimetype
      }
    };

    // 🧠 Prompt Híbrido heredado de tu App Script de Google
    let promptContext = `Actúa como un Auditor Fiscal experto homologado por la DGII de la República Dominicana.
    Analiza visualmente la imagen adjunta de la factura y extrae con exactitud los campos contables requeridos.
    
    REGLAS GENERALES CRÍTICAS:
    1. Extrae el RNC o Cédula del EMISOR/SUPLIDOR (quien vende y emite la factura). Ignora por completo el RNC de la empresa receptora.
    2. tipo_id: Pon '1' si es un RNC comercial (9 dígitos) o '2' si es una Cédula (11 dígitos).
    3. ncf: Código alfanumérico que debe iniciar obligatoriamente con 'B' o 'E'.
    4. forma_pago: Elige el formato largo oficial correspondiente (ej: '01 - EFECTIVO', '02 - CHEQUES/TRANSFERENCIAS/DEPÓSITOS', '03 - TARJETA CRÉDITO/DÉBITO', '04 - A CRÉDITO').
    `;

    if (formatoActual === 'simple') {
      promptContext += `
      ESTÁS PROCESANDO FORMATO: AUDITORÍA SIMPLE
      Extrae los siguientes 12 campos obligatorios:
      - nombre_empresa: Razón social o nombre comercial del emisor.
      - fecha y fecha_pago: Formato de texto estricto ISO YYYY-MM-DD.
      - monto_total: Total facturado bruto final de la operación.
      - itbis_total: ITBIS facturado líquido.
      Setea en 0.0 o vacíos todos los demás campos no pertenecientes a la auditoría simple.`;
    } else {
      promptContext += `
      ESTÁS PROCESANDO FORMATO: REPORTE 606 (DGII)
      Extrae rigurosamente los 28 campos fiscales:
      - tipo_gasto: Clasifica según catálogo oficial de la DGII (ej: '01 - GASTOS DE PERSONAL', '02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS', '03 - ARRENDAMIENTOS').
      - fecha y fecha_pago: Formato de periodo de texto YYYYMM (Año y Mes de emisión).
      - Desglosa matemáticamente: monto_servicios (Monto facturado en servicios) y monto_bienes (Monto facturado en bienes) de forma tal que sumados coincidan exactamente con monto_total.
      - Extrae detalladamente si existen: itbis_retenid, itbis_proporcional, itbis_costo, itbis_adelantar, itbis_percibido, tipo_retencion_isr, retencion_renta, isr_percibido, isc, otros_impuestos, monto_ley.`;
    }

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [promptContext, imagenDataPart],
      config: {
        responseMimeType: 'application/json',
        responseSchema: esquemaFiscalDominicano,
        temperature: 0.1,
      }
    });

    const jsonText = response.text;
    if (!jsonText) {
      throw new Error("La IA de Gemini no devolvió una estructura JSON válida.");
    }

    const datosFiscales = JSON.parse(jsonText);

    // 🚀 STEP 3: Inserción Nativa en Supabase incluyendo la columna file_url
    const { data: nuevaFactura, error: supabaseError } = await supabase
      .from('facturas')
      .insert({
        empresa_id: empresa_id,
        tipo_formato: formatoActual,
        rnc: datosFiscales.rnc ? datosFiscales.rnc.replace(/[^0-9]/g, "") : "000000000",
        tipo_id: datosFiscales.tipo_id || "1",
        nombre_empresa: formatoActual === 'simple' ? (datosFiscales.nombre_empresa || "Desconocido") : null,
        tipo_gasto: formatoActual === '606' ? (datosFiscales.tipo_gasto || "02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS") : null,
        ncf: datosFiscales.ncf || "N/A",
        documento_modificado: datosFiscales.documento_modificado || "",
        fecha: datosFiscales.fecha || "",
        fecha_pago: datosFiscales.fecha_pago || "",
        monto_servicios: Number(datosFiscales.monto_servicios) || 0.0,
        monto_bienes: Number(datosFiscales.monto_bienes) || 0.0,
        monto_total: Number(datosFiscales.monto_total) || 0.0,
        itbis_total: Number(datosFiscales.itbis_total) || 0.0,
        itbis_retenid: Number(datosFiscales.itbis_retenid) || 0.0,
        itbis_proporcional: Number(datosFiscales.itbis_proporcional) || 0.0,
        itbis_costo: Number(datosFiscales.itbis_costo) || 0.0,
        itbis_adelantar: Number(datosFiscales.itbis_adelantar) || 0.0,
        itbis_percibido: Number(datosFiscales.itbis_percibido) || 0.0,
        tipo_retencion_isr: datosFiscales.tipo_retencion_isr || "",
        retencion_renta: Number(datosFiscales.retencion_renta) || 0.0,
        isr_percibido: Number(datosFiscales.isr_percibido) || 0.0,
        isc: Number(datosFiscales.isc) || 0.0,
        otros_impuestos: Number(datosFiscales.otros_impuestos) || 0.0,
        monto_ley: Number(datosFiscales.monto_ley) || 0.0,
        forma_pago: datosFiscales.forma_pago || "03 - TARJETA CRÉDITO/DÉBITO",
        estatus: "VÁLIDO",
        creado_por: creado_por,
        file_url: publicFileUrl // 🚀 Guardado nítido del link directo de Supabase Storage
      })
      .select()
      .single();

    if (supabaseError) {
      console.error("❌ Error insertando en Supabase:", supabaseError);
      res.status(500).json({ error: "Error interno al indexar en PostgreSQL.", detalles: supabaseError.message });
      return;
    }

    res.status(201).json({
      success: true,
      mensaje: `Factura en formato ${formatoActual.toUpperCase()} auditada, resguardada en Storage e indexada con éxito.`,
      factura: nuevaFactura
    });

  } catch (error: any) {
    console.error("💥 Error en el ecosistema del servidor:", error);
    res.status(500).json({ error: "Fallo crítico en el motor de procesamiento contable.", detalles: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Servidor de AutoNCF corriendo con total fluidez en el puerto ${PORT}`);
});