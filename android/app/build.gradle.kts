// android/app/build.gradle.kts  ( módulo :app )

plugins {
    // Plug‑ins principais do módulo Android + Flutter
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ➜  Pacote SEM underline
    namespace = "com.example.brainmonitor"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // ➜  Application ID SEM underline (precisa bater com o cadastro no Firebase)
        applicationId = "com.example.brainmonitor"

        // Demais ajustes padrão do projeto Flutter
        minSdk       = 23
        targetSdk    = flutter.targetSdkVersion
        versionCode  = flutter.versionCode
        versionName  = flutter.versionName
    }

    buildTypes {
        release {
            // Por enquanto assina com as chaves de debug; troque pela sua keystore de release depois
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
