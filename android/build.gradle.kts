allprojects {
    repositories {
        // China mirrors (faster in China)
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // Flutter artifacts mirror for China
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        // Original repositories as fallback
        google()
        mavenCentral()
    }
}

// Fix namespace issues for old plugins that don't specify namespace
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension is com.android.build.gradle.LibraryExtension) {
                if (androidExtension.namespace.isNullOrEmpty()) {
                    val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        val packageRegex = """package\s*=\s*["']([^"']+)["']""".toRegex()
                        val matchResult = packageRegex.find(manifestContent)
                        if (matchResult != null) {
                            androidExtension.namespace = matchResult.groupValues[1]
                        }
                    }
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
