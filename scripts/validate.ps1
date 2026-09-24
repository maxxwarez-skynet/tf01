param([switch]$SkipTests)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    & tofu fmt -check -recursive
    if ($LASTEXITCODE -ne 0) { throw "OpenTofu formatting failed." }
    $roots = @(
        "bootstrap/azure",
        "live/azure/aira/dev/centralindia/foundation",
        "live/azure/aira/dev/centralindia/data",
        "live/azure/aira/dev/centralindia/application",
        "live/aws/aira/dev/ap-south-1/recordings"
    )
    foreach ($root in $roots) {
        & tofu "-chdir=$root" init -backend=false -input=false -no-color
        if ($LASTEXITCODE -ne 0) { throw "Initialization failed: $root" }
        & tofu "-chdir=$root" validate -no-color
        if ($LASTEXITCODE -ne 0) { throw "Validation failed: $root" }
    }
    if (-not $SkipTests) {
        $testModules = @("modules/azure/compute", "modules/azure/mysql", "modules/azure/cache", "modules/aws/recordings")
        foreach ($module in $testModules) {
            & tofu "-chdir=$module" init -backend=false -input=false -no-color
            if ($LASTEXITCODE -ne 0) { throw "Test initialization failed: $module" }
            & tofu "-chdir=$module" test -no-color
            if ($LASTEXITCODE -ne 0) { throw "Tests failed: $module" }
        }
    }
} finally {
    Pop-Location
}
