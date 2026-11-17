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

val appBuildCode = "D200_Drama"
val appDisplayName = "Dramota: Short & Dramas Reel"
val appVersionName = "0.0.4"
val appVersionCode = 4
val formattedDate: String = SimpleDateFormat("ddMMyyyy", Locale.US).format(Date())

fun releaseArtifactName(
    versionName: String?,
    versionCode: Int?,
    extension: String,
    abi: String? = null,
): String {
    val vName = versionName ?: appVersionName
    val vCode = versionCode ?: appVersionCode
    val abiSuffix = if (abi.isNullOrEmpty()) "" else "_$abi"
    return "${appBuildCode}_${vName}_${vCode}_${formattedDate}${abiSuffix}.$extension"
}

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

    applicationVariants.all {
        val variant = this
        if (variant.buildType.name == "release") {
            variant.outputs.all {
                val output = this as? com.android.build.gradle.api.ApkVariantOutput
                output?.outputFileName =
                    releaseArtifactName(variant.versionName, variant.versionCode, "apk")
            }
        }
    }
}

androidComponents {
    onVariants { variant ->
        if (variant.buildType == "release") {
            variant.outputs.forEach { output ->
                val abi = output.filters
                    .find {
                        it.filterType ==
                            com.android.build.api.variant.FilterConfiguration.FilterType.ABI
                    }
                    ?.identifier
                val vName = output.versionName.orNull ?: appVersionName
                val vCode = output.versionCode.orNull ?: appVersionCode
                (output as? com.android.build.api.variant.impl.VariantOutputImpl)
                    ?.outputFileName
                    ?.set(releaseArtifactName(vName, vCode, "apk", abi))
            }
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

tasks.matching {
    (it.name.startsWith("bundle") && it.name.endsWith("Release")) ||
        it.name == "signReleaseBundle"
}.configureEach {
    doLast {
        val bundleDir = layout.buildDirectory.dir("outputs/bundle/release").get().asFile
        val targetName = releaseArtifactName(appVersionName, appVersionCode, "aab")
        bundleDir
            .listFiles { f -> f.extension == "aab" && f.name.startsWith("app-") && f.name != targetName }
            ?.forEach { aab ->
            val targetFile = File(aab.parentFile, targetName)
            aab.copyTo(targetFile, overwrite = true)
            println("AAB successfully copied to: ${targetFile.name}")
        }
    }
}
