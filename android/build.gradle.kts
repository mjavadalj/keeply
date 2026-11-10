import com.android.build.api.dsl.LibraryExtension

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    buildscript.configurations.configureEach {
        resolutionStrategy.force(
            "com.android.tools.build:gradle:8.11.1",
            "org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20",
        )
    }
}

subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension> {
                compileSdk = 36
                ndkVersion = "28.2.13676358"
            }
        }
    }
}

tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }
