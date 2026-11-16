import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val appBuildCode = "D200_ShortDrama"
val appDisplayName = "Dramota: Short & Dramas Reel"
val appVersionName = "0.0.1"
val appVersionCode = 1
val buildDate = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())

android {
    namespace = "com.reels.shortdrama.dramaseries.dramota"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.reels.shortdrama.dramaseries.dramota"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersionCode
        versionName = appVersionName
        multiDexEnabled = true
        manifestPlaceholders["appName"] = appDisplayName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")
    implementation("com.google.android.material:material:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

gradle.projectsEvaluated {
    val vName = appVersionName.replace(".", "")
    val vCode = appVersionCode
    val outputBaseName = "${appBuildCode}_v${vName}_${vCode}_${buildDate}"

    listOf("Debug", "Release", "Profile").forEach { variant ->
        val mode = variant.lowercase(Locale.US)
        val suffix = if (mode == "release") "" else "-$mode"
        tasks.matching { it.name == "assemble$variant" }.configureEach {
            doLast {
                val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
                val flutterApk = File(flutterApkDir, "app-$mode.apk")
                val rawApk = layout.buildDirectory.file("outputs/apk/$mode/app-$mode.apk").get().asFile
                val sourceApk = if (flutterApk.exists()) flutterApk else rawApk
                if (sourceApk.exists()) {
                    flutterApkDir.mkdirs()
                    sourceApk.copyTo(File(flutterApkDir, "$outputBaseName$suffix.apk"), overwrite = true)
                    if (rawApk.exists()) {
                        rawApk.copyTo(File(rawApk.parentFile, "$outputBaseName$suffix.apk"), overwrite = true)
                    }
                }
            }
        }
        tasks.matching { it.name == "bundle$variant" }.configureEach {
            doLast {
                val rawAab = layout.buildDirectory.file("outputs/bundle/$mode/app-$mode.aab").get().asFile
                if (rawAab.exists()) {
                    rawAab.copyTo(File(rawAab.parentFile, "$outputBaseName$suffix.aab"), overwrite = true)
                }
            }
        }
    }
}
