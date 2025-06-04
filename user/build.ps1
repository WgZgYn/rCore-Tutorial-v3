# Configuration
$TARGET = "riscv64gc-unknown-none-elf"
$MODE = "release"
$APP_DIR = "src/bin"
$TARGET_DIR = "target/$TARGET/$MODE"
$TEST = $null  # Default empty, can be set to "1" when needed

# Tools
$OBJDUMP = "rust-objdump --arch-name=riscv64"
$OBJCOPY = "rust-objcopy --binary-architecture=riscv64"

function Build-Elf {
    Write-Host "Building ELF files..."
    cargo build --release
    
    if ($TEST -eq "1") {
        Write-Host "Setting up test environment..."
        Copy-Item -Path "$TARGET_DIR/usertests" -Destination "$TARGET_DIR/initproc" -Force
    }
}

function Convert-ToBinary {
    param(
        [string]$elfFile
    )
    $binFile = $elfFile + ".bin"
    Write-Host "Converting $elfFile to binary..."
    Invoke-Expression "$OBJCOPY $elfFile --strip-all -O binary $binFile"
}

function Build-Binary {
    Write-Host "Generating binary files..."
    
    # Get all ELF files in target directory
    $elfFiles = Get-ChildItem -Path $TARGET_DIR -File | 
                Where-Object { $_.Extension -eq "" } |  # ELF files typically have no extension
                Select-Object -ExpandProperty FullName
    
    foreach ($elf in $elfFiles) {
        Convert-ToBinary -elfFile $elf
    }
}

function Invoke-Build {
    Build-Elf
    Build-Binary
}

function Invoke-Clean {
    Write-Host "Cleaning build..."
    cargo clean
}

# Main entry point
if ($args.Count -gt 0) {
    switch ($args[0]) {
        "elf" { Build-Elf }
        "binary" { Build-Binary }
        "build" { Invoke-Build }
        "clean" { Invoke-Clean }
        default { Invoke-Build }
    }
}
else {
    Write-Host @"
Usage: ./build.ps1 [target]
Available targets:
  elf     - Build ELF files
  binary  - Convert ELF to binary
  build   - Build everything (default)
  clean   - Clean build artifacts
"@
}