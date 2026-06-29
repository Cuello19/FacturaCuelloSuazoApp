package com.example.facturacuellosuazo_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {

    // 🔥 CAPTURA DE ARRANQUE FRÍO: Si la app estaba cerrada y se abre por el link de Google
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let { uri ->
            // Le pasamos la URL del link a Flutter de inmediato
            intent.action = Intent.ACTION_VIEW
        }
    }

    // 🔥 CAPTURA EN CALIENTE: Si la app estaba abierta en segundo plano (El caso de tu Meberry M7)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Obligatorio para que el plugin de Flutter reciba la URL con el token de Supabase
        setIntent(intent)
    }
}