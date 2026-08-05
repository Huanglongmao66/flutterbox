import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
// 所有 Android 子项目（插件）统一 compileSdk = 36 和 JVM Target = 11
// 使用 plugins.withId 注册回调，避免 afterEvaluate 在已评估项目上抛异常
subprojects {
    plugins.withId("com.android.application") {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion("android-36")
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    plugins.withId("com.android.library") {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion("android-36")
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    // 统一 Kotlin JVM Target 与 Java 一致，避免 flutter_js 等插件的 JVM Target 不匹配
    tasks.withType<KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "11"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
