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

// 📝 ESQUEMA FISCAL DINÁMICO COMPLETAMENTE PLANO (Mapeo 606 / Simple oficial DGII)
const esquemaFiscalDominicano: Schema = {
  type: Type.OBJECT,
  properties: {
    rnc: { type: Type.STRING, description: "RNC o Cédula del suplidor/emisor de la factura. Solo números, sin guiones." },
    tipo_id: { type: Type.STRING, description: "Tipo de Identificación. Retorna estrictamente: '1' para RNC comercial (9 dígitos) o '2' para Cédula física (11 dígitos)." },
    nombre_empresa: { type: Type.STRING, description: "Nombre comercial o razón social del emisor de la factura." },
    tipo_gasto: { type: Type.STRING, description: "Clasificación de costos y gastos del 606. Retorna estrictamente uno de los códigos de catálogo: '01 - GASTOS DE PERSONAL', '02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS', '03 - ARRENDAMIENTOS', '04 - GASTOS DE ACTIVOS FIJOS', '05 - GASTOS DE REPRESENTACIÓN', '06 - OTRAS DEDUCCIONES ADMITIDAS', '07 - GASTOS FINANCIEROS', '08 - GASTOS EXTRAORDINARIOS', '09 - COMPRAS Y GASTOS QUE FORMARÁN PARTE DEL COSTO DE VENTA', '10 - ADQUISICIONES DE ACTIVOS', '11 - GASTOS DE SEGUROS'." },
    ncf: { type: Type.STRING, description: "Número de Comprobante Fiscal completo (ej. B01..., E31...)." },
    documento_modificado: { type: Type.STRING, description: "NCF ó Documento Modificado afectado por Nota de Crédito/Débito si aplica, de lo contrario vacío." },
    fecha: { type: Type.STRING, description: "Para formato 606 retorna estrictamente el periodo contable (YYYYMM). Para formato Simple retorna la fecha completa extendida (YYYY-MM-DD)." },
    fecha_pago: { type: Type.STRING, description: "Para formato 606 retorna estrictamente el periodo contable (YYYYMM). Para formato Simple retorna la fecha completa extendida (YYYY-MM-DD)." },
    monto_servicios: { type: Type.NUMBER, description: "Monto Facturado en Servicios. Excluye impuestos. 0.0 si es exclusivamente un Bien." },
    monto_bienes: { type: Type.NUMBER, description: "Monto Facturado en Bienes. Excluye impuestos. 0.0 si es exclusivamente un Servicio." },
    monto_total: { type: Type.NUMBER, description: "Total Monto Facturado final bruto de la operación." },
    itbis_total: { type: Type.NUMBER, description: "Monto total del ITBIS liquidado." },
    itbis_retenid: { type: Type.NUMBER, description: "Monto de ITBIS Retenido en operaciones de servicios o entre entidades que aplique." },
    itbis_proporcional: { type: Type.NUMBER, description: "ITBIS sujeto a Proporcionalidad (Art. 349)." },
    itbis_costo: { type: Type.NUMBER, description: "ITBIS llevado directamente al Costo." },
    itbis_adelantar: { type: Type.NUMBER, description: "ITBIS por Adelantar resultante." },
    itbis_percibido: { type: Type.NUMBER, description: "ITBIS percibido en compras." },
    tipo_retencion_isr: { type: Type.STRING, description: "Código de Tipo de Retención en ISR si aplica. Retorna estrictamente uno de estos valores: '01 - ALQUILERES', '02 - HONORARIOS POR SERVICIOS', '03 - OTRAS RENTAS', '04 - OTRAS RENTAS (RENTAS PRESUNTAS)', '05 - INTERESES PAGADOS A PERSONAS JURÍDICAS RESIDENTES', '06 - INTERESES PAGADOS A PERSONAS FÍSICAS RESIDENTES', '07 - RETENCIÓN POR PROVEEDORES DEL ESTADO', '08 - JUEGOS TELEFÓNICOS', '09 - RETENCIONES SUBSECTOR DE GANADERÍA DE CARNE BOVINA'. Si no hay retención, retorna un string vacío \"\"." },
    retencion_renta: { type: Type.NUMBER, description: "Monto de Retención de Impuesto Sobre la Renta (ISR)." },
    isr_percibido: { type: Type.NUMBER, description: "ISR Percibido en compras." },
    isc: { type: Type.NUMBER, description: "Impuesto Selectivo al Consumo." },
    otros_impuestos: { type: Type.NUMBER, description: "Otros Impuestos, Tasas o Cargos Especiales." },
    monto_ley: { type: Type.NUMBER, description: "Monto por Propina Legal establecida por Ley (10%)." },
    forma_pago: { type: Type.STRING, description: "Método de pago oficial. Retorna estrictamente uno de estos strings: '01 - EFECTIVO', '02 - CHEQUES/TRANSFERENCIAS/DEPÓSITO', '03 - TARJETA CRÉDITO/DÉBITO', '04 - COMPRA A CRÉDITO', '05 - PERMUTA', '06 - NOTAS DE CRÉDITO', '07 - MIXTO'." }
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

    // 🧠 Prompt Híbrido heredado de tu App Script de Google con mapeos estrictos de la DGII
    let promptContext = `Actúa como un Auditor Fiscal experto homologado por la DGII de la República Dominicana.
    Analiza visualmente la imagen adjunta de la factura y extrae con exactitud los campos contables requeridos.
    
    REGLAS GENERALES CRÍTICAS DE MAPEO FISCAL:
    1. Extrae el RNC o Cédula del EMISOR/SUPLIDOR (quien vende y emite la factura). Ignora por completo el RNC de la empresa receptora. Limpia guiones.
    2. tipo_id: Analiza el ID del emisor. Pon estrictamente "1" si es un RNC comercial (9 dígitos) o "2" si identifica una Cédula física (11 dígitos).
    3. ncf: Código alfanumérico completo. Debe iniciar obligatoriamente con la letra 'B' o 'E'.
    4. forma_pago: Clasifica rigurosamente usando solo uno de los siguientes valores de texto plano:
       - "01 - EFECTIVO"
       - "02 - CHEQUES/TRANSFERENCIAS/DEPÓSITO"
       - "03 - TARJETA CRÉDITO/DÉBITO"
       - "04 - COMPRA A CRÉDITO"
       - "05 - PERMUTA"
       - "06 - NOTAS DE CRÉDITO"
       - "07 - MIXTO"
    `;

    if (formatoActual === 'simple') {
      promptContext += `
      ESTÁS PROCESANDO FORMATO: AUDITORÍA SIMPLE
      Extrae los siguientes campos obligatorios de forma libre y natural desde el ticket:
      - nombre_empresa: Razón social o nombre comercial del emisor/suplidor.
      - fecha y fecha_pago: Extrae la fecha de emisión completa. Retorna en formato de texto estándar ISO extendido: "YYYY-MM-DD" (ej: "2026-06-30").
      - monto_total: Sumatoria final bruta cobrada.
      - itbis_total: ITBIS liquidado en la operación.
      Setea en 0.0 o strings vacíos "" todos los demás campos analíticos del 606.`;
    } else {
      promptContext += `
      ESTÁS PROCESANDO FORMATO: REPORTE 606 (DGII - COMPRAS DE BIENES Y SERVICIOS)
      Extrae rigurosamente los campos fiscales adaptados al layout de remisión de costos y gastos:
      - tipo_gasto: Clasifica el propósito de la compra seleccionando estrictamente uno de estos strings del catálogo de la DGII:
        "01 - GASTOS DE PERSONAL"
        "02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS"
        "03 - ARRENDAMIENTOS"
        "04 - GASTOS DE ACTIVOS FIJOS"
        "05 - GASTOS DE REPRESENTACIÓN"
        "06 - OTRAS DEDUCCIONES ADMITIDAS"
        "07 - GASTOS FINANCIEROS"
        "08 - GASTOS EXTRAORDINARIOS"
        "09 - COMPRAS Y GASTOS QUE FORMARÁN PARTE DEL COSTO DE VENTA"
        "10 - ADQUISICIONES DE ACTIVOS"
        "11 - GASTOS DE SEGUROS"
      - fecha y fecha_pago: Retorna estrictamente la fecha en formato de Período Contable DGII de 6 dígitos: "YYYYMM" (ej: Mayo de 2026 es "202605").
      - Desglose Contable: Divide el subtotal neto entre monto_servicios (Monto facturado en servicios) o monto_bienes (Monto facturado en bienes). La sumatoria de ambos campos sin impuestos debe corresponder de forma matemática al subtotal bruto.
      - tipo_retencion_isr: Si se identifica una retención de renta, selecciona únicamente uno de los siguientes códigos del catálogo oficial:
        "01 - ALQUILERES"
        "02 - HONORARIOS POR SERVICIOS"
        "03 - OTRAS RENTAS"
        "04 - OTRAS RENTAS (RENTAS PRESUNTAS)"
        "05 - INTERESES PAGADOS A PERSONAS JURÍDICAS RESIDENTES"
        "06 - INTERESES PAGADOS A PERSONAS FÍSICAS RESIDENTES"
        "07 - RETENCIÓN POR PROVEEDORES DEL ESTADO"
        "08 - JUEGOS TELEFÓNICOS"
        "09 - RETENCIONES SUBSECTOR DE GANADERÍA DE CARNE BOVINA"
        Si no se aplica retención de renta en el comprobante, devuelve obligatoriamente un string vacío "".
      - Desglosa con precisión los valores de: itbis_retenid, itbis_proporcional, itbis_costo, itbis_adelantar, itbis_percibido, retencion_renta, isr_percibido, isc, otros_impuestos, monto_ley.`;
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

    // 🚀 STEP 3: Inserción Nativa en Supabase incluyendo las columnas estandarizadas
    const { data: nuevaFactura, error: supabaseError } = await supabase
      .from('facturas')
      .insert({
        empresa_id: empresa_id,
        tipo_formato: formatoActual,
        rnc: datosFiscales.rnc ? datosFiscales.rnc.replace(/[^0-9]/g, "") : "000000000",
        tipo_id: Number(datosFiscales.tipo_id) || 1, // Se guarda numérico en PostgreSQL (1 o 2)
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
        file_url: publicFileUrl // 🚀 Link directo al Supabase Storage público resguardado
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