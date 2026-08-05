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
// 仅处理 library 子项目（app 项目已在自身 build.gradle.kts 配置 compileSdk=36 和 JVM 17）
// 使用 androidComponents.finalizeDsl：在插件 build.gradle 评估后、AGP 锁定前覆盖配置
// AGP 9.0 中 afterEvaluate 已太晚（compileSdk 已 finalized），plugins.withId 太早（被插件覆盖）
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
            ?.finalizeDsl { ext ->
                ext.compileSdk = 36
                ext.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
    }
    // 统一 Kotlin JVM Target 与 Java 一致，使用 compilerOptions 替代已弃用的 kotlinOptions
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
