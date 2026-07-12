package com.example.takipversie1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode {
        // TextureView fixes white screen after camera intent on some OEM devices
        // (Xiaomi, Samsung, etc.) where SurfaceView fails to re-attach.
        return RenderMode.texture
    }
}
