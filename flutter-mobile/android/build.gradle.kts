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
subprojects {
    project.evaluationDependsOn(":app")
}
// Eski Java 8 hedefli eklentilerin "source/target value 8 is obsolete"
// uyarılarını bastırır; kendi modüllerimiz Java 17 kullanıyor.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }
}
// Bazı eklentiler AGP'nin varsayılan NDK'sını (28.x) ister; makinede o sürümün
// klasörü bozuk kalıntı olduğundan tüm alt projeleri app ile aynı, kurulu
// NDK sürümüne sabitler.
subprojects {
    listOf("com.android.library", "com.android.application").forEach { pluginId ->
        plugins.withId(pluginId) {
            (extensions.getByName("android") as com.android.build.gradle.BaseExtension)
                .ndkVersion = "29.0.14206865"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
