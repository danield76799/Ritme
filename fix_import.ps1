$path = "B:\fluffer-repo\lib\screens\statistics_screen.dart"
$content = Get-Content $path -Raw
$new = $content.Replace("import '../main.dart';", "import '../service_locator.dart';")
Set-Content -NoNewline -Path $path -Value $new
Write-Host "Done"
