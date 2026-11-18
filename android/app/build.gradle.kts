
import com.android.build.api.dsl.ApplicationExtension

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin은 Android와 Kotlin 플러그인 다음에 적용
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter에서 가져오는 SDK 설정
val flutterCompileSdk = flutter.compileSdkVersion
val flutterNdkVersion = flutter.ndkVersion
val flutterMinSdk = flutter.minSdkVersion
val flutterTargetSdk = flutter.targetSdkVersion
val flutterVersionCode = flutter.versionCode
val flutterVersionName = flutter.versionName

// 기존 android {} 대신 AGP의 ApplicationExtension 사용
extensions.configure<ApplicationExtension>("android") {
    namespace = "com.example.exercise_assist"
    compileSdk = flutterCompileSdk
    ndkVersion = flutterNdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.exercise_assist"
        minSdk = flutterMinSdk
        targetSdk = flutterTargetSdk
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 기존 kotlinOptions 대신 compilerOptions 사용
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
