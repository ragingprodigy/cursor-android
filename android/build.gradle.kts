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
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.configureJava17CompileOptions()
        tasks.configureEach {
            configureKotlinJvmTarget17()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

fun Any.configureJava17CompileOptions() {
    val compileOptions = javaClass.methods
        .firstOrNull { it.name == "getCompileOptions" && it.parameterCount == 0 }
        ?.invoke(this)
        ?: return

    for (methodName in listOf("setSourceCompatibility", "setTargetCompatibility")) {
        compileOptions.javaClass.methods
            .firstOrNull {
                it.name == methodName &&
                    it.parameterCount == 1 &&
                    it.parameterTypes.single().isAssignableFrom(JavaVersion::class.java)
            }
            ?.invoke(compileOptions, JavaVersion.VERSION_17)
    }
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
