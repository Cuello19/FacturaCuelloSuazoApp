require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
const { GoogleGenAI, Type } = require('@google/genai');

const app = express();

// 🚀 CORREGIDO: CORS configurado de forma elástica para desarrollo y web
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

const PORT = process.env.PORT || 3000;

app.post('/api/procesar-factura', async (req, res) => {
    const { storagePath, empresaId, tipoFormato, creadoPor } = req.body;

    if (!storagePath || !empresaId) {
        return res.status(400).json({ error: 'Faltan parámetros: storagePath o empresaId.' });
    }

    try {
        console.log(`📥 Procesando factura del storage: ${storagePath} para formato: ${tipoFormato}`);

        // 1. Descargar imagen desde Supabase Storage
        const { data: fileData, error: downloadError } = await supabase.storage
            .from('evidencias')
            .download(storagePath);

        if (downloadError) throw new Error(`Error bajando archivo de Storage: ${downloadError.message}`);

        const imageBuffer = Buffer.from(await fileData.arrayBuffer());
        const imageBase64 = imageBuffer.toString('base64');

        // 2. Esquemas JSON para Gemini
        let jsonSchema;
        let sistemaPrompt;

        if (tipoFormato === '606') {
            sistemaPrompt = "Eres un contador fiscal experto en la República Dominicana. Extrae con precisión los campos para el formato 606 de la DGII.";
            jsonSchema = {
                type: Type.OBJECT,
                properties: {
                    rnc_o_cedula: { type: Type.STRING, description: "RNC (9 dígitos) o Cédula (11 dígitos) sin guiones." },
                    tipo_id: { type: Type.STRING, description: "1 si es RNC, 2 si es Cédula." },
                    tipo_bienes_y_servicios_comprados: { type: Type.STRING, description: "Clasificación del 01 al 11." },
                    ncf: { type: Type.STRING, description: "NCF completo." },
                    ncf_o_documento_modificado: { type: Type.STRING, description: "Vacio si no aplica." },
                    fecha_comprobante: { type: Type.STRING, description: "YYYY-MM-DD" },
                    fecha_pago: { type: Type.STRING, description: "YYYY-MM-DD" },
                    monto_facturado_en_servicios: { type: Type.NUMBER },
                    monto_facturado_en_bienes: { type: Type.NUMBER },
                    total_monto_facturado: { type: Type.NUMBER },
                    itbis_facturado: { type: Type.NUMBER },
                    itbis_retenido: { type: Type.NUMBER },
                    itbis_sujeto_a_proporcionalidad: { type: Type.NUMBER },
                    itbis_llevado_al_costo: { type: Type.NUMBER },
                    itbis_por_adelantar: { type: Type.NUMBER },
                    itbis_percibido_en_compras: { type: Type.NUMBER },
                    tipo_de_retencion_en_isr: { type: Type.STRING },
                    monto_retencion_renta: { type: Type.NUMBER },
                    isr_percibido_en_compras: { type: Type.NUMBER },
                    impuesto_selectivo_al_consumo: { type: Type.NUMBER },
                    otros_impuesto_tasas: { type: Type.NUMBER },
                    monto_propina_legal: { type: Type.NUMBER },
                    forma_de_pago: { type: Type.STRING },
                    estatus: { type: Type.STRING }
                },
                required: ["rnc_o_cedula", "ncf", "fecha_comprobante", "total_monto_facturado", "itbis_facturado"]
            };
        } else {
            sistemaPrompt = "Extrae los datos esenciales para la Auditoría Simple.";
            jsonSchema = {
                type: Type.OBJECT,
                properties: {
                    rnc_o_cedula: { type: Type.STRING },
                    tipo_id: { type: Type.STRING },
                    nombre_empresa: { type: Type.STRING },
                    ncf: { type: Type.STRING },
                    fecha_comprobante: { type: Type.STRING },
                    fecha_pago: { type: Type.STRING },
                    total_monto_facturado: { type: Type.NUMBER },
                    itbis_facturado: { type: Type.NUMBER },
                    forma_de_pago: { type: Type.STRING },
                    estatus: { type: Type.STRING }
                },
                required: ["rnc_o_cedula", "nombre_empresa", "ncf", "fecha_comprobante", "total_monto_facturado"]
            };
        }

        console.log("🤖 Llamando a Gemini 2.5 Flash...");
        const respuestaAI = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: [
                sistemaPrompt,
                { inlineData: { mimeType: "image/jpeg", data: imageBase64 } }
            ],
            config: {
                responseMimeType: "application/json",
                responseSchema: jsonSchema,
                temperature: 0.1
            }
        });

        const datosExtraidos = JSON.parse(respuestaAI.text);
        const { data: urlData } = supabase.storage.from('evidencias').getPublicUrl(storagePath);

        // 🛠️ CORREGIDO: Removida columna inexistente 'tipo_format' para evitar quiebres en Supabase
        const filaInsertar = {
            empresa_id: empresaId,
            rnc: datosExtraidos.rnc_o_cedula,
            ncf: datosExtraidos.ncf,
            tipo_formato: tipoFormato,
            fecha: datosExtraidos.fecha_comprobante,
            monto_total: datosExtraidos.total_monto_facturado,
            itbis_total: datosExtraidos.itbis_facturado,
            forma_pago: datosExtraidos.forma_de_pago || datosExtraidos.forma_pago || '01',
            estatus: datosExtraidos.estatus || 'VÁLIDO',
            creado_por: creadoPor || 'Operador',
            file_url: urlData.publicUrl,
            datos_606: datosExtraidos 
        };

        const { data: facturaGuardada, error: dbError } = await supabase
            .from('facturas')
            .insert(filaInsertar)
            .select()
            .single();

        if (dbError) throw dbError;

        console.log("✅ Factura guardada exitosamente en PostgreSQL.");
        return res.status(200).json({ success: true, factura: facturaGuardada });

    } catch (error) {
        console.error('❌ Error analizando con Gemini:', error);
        return res.status(500).json({ error: error.message || 'Error interno del servidor.' });
    }
});

app.listen(PORT, () => {
    console.log(`🚀 Servidor AutoNCF con IA Gemini encendido en http://localhost:${PORT}`);
});