plugins {
    kotlin("plugin.serialization") version "1.9.0"
}

dependencies {
    implementation(project(":server:common"))
    implementation(project(":server:cache"))
    implementation(project(":server:engine"))
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:_")
}