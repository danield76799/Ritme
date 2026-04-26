# Set environment variables
$env:ANDROID_HOME = "B:\android-sdk"
$env:ANDROID_SDK_ROOT = "B:\android-sdk"
$env:JAVA_HOME = "B:\java\jdk-17.0.14+7"

# Add to Path
$env:Path = "B:\flutter\bin;B:\android-sdk\platform-tools;B:\android-sdk\cmdline-tools\latest\bin;" + $env:Path

Write-Host "Environment variables set!"
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
Write-Host "JAVA_HOME: $env:JAVA_HOME"
