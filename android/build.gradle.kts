allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 所有 Android 子项目统一 compileSdk = 36 和 JVM Target = 11
// 使用 AGP 9.0 的非弃用 API（ApplicationExtension/LibraryExtension + compilerOptions）
subprojects {
    plugins.withId("com.android.application") {
        extensions.findByType(com.android.build.api.dsl.ApplicationExtension::class.java)?.apply {
            compileSdk = 36
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    plugins.withId("com.android.library") {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.apply {
            compileSdk = 36
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    // 统一 Kotlin JVM Target 与 Java 一致，使用 compilerOptions 替代已弃用的 kotlinOptions
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
