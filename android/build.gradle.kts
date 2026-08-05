import com.android.build.gradle.BaseExtension

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
// 所有 Android 子项目（插件）统一 compileSdk = 36，解决 AAR metadata 版本检查
// 使用 plugins.withId 注册回调，避免 afterEvaluate 在已评估项目上抛异常
subprojects {
    plugins.withId("com.android.application") {
        extensions.findByType(BaseExtension::class.java)?.compileSdkVersion("android-36")
    }
    plugins.withId("com.android.library") {
        extensions.findByType(BaseExtension::class.java)?.compileSdkVersion("android-36")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
