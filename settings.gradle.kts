pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven("https://plugins.gradle.org/m2/")
        maven("https://s01.oss.sonatype.org/content/repositories/snapshots/")
    }
}

// TODO: Update project's name.
rootProject.name = "godot_awv"
include(":plugin")
