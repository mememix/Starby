allprojects {
    repositories {
        google()
        mavenCentral()
        // 高德地图 Maven 仓库
        maven { url = uri("https://developer.huawei.com/repo/") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }

    // 解决 amap_flutter_location: Android resource linking failed - lStar not found
    configurations.all {
        resolutionStrategy.force("androidx.core:core-ktx:1.12.0")
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
