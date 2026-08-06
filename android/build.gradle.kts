import org.gradle.api.tasks.compile.JavaCompile

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

// Silence obsolete Java 8 warnings from Android library/plugin subprojects.
// Prefer task-level configuration (lazy) over android.compileOptions afterEvaluate —
// evaluationDependsOn(":app") can finalize :app options before a root afterEvaluate runs.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    tasks.configureEach {
        configureKotlinJvmTarget17()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

fun Any.configureKotlinJvmTarget17() {
    val kotlinOptions = javaClass.methods
        .firstOrNull { it.name == "getKotlinOptions" && it.parameterCount == 0 }
        ?.invoke(this)
        ?: return

    kotlinOptions.javaClass.methods
        .firstOrNull {
            it.name == "setJvmTarget" &&
                it.parameterCount == 1 &&
                it.parameterTypes.single() == String::class.java
        }
        ?.invoke(kotlinOptions, "17")
}
