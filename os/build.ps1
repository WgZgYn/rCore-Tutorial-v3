$TARGET = "riscv64gc-unknown-none-elf"
$MODE = "release"
$KERNEL_ELF = "target/$TARGET/$MODE/os"
$KERNEL_BIN = "$KERNEL_ELF.bin"
$DISASM_TMP = "target/$TARGET/$MODE/asm"
$FS_IMG = "../user/target/$TARGET/$MODE/fs.img"
$BOARD = "qemu"
$SBI = "rustsbi"
$BOOTLOADER = "../bootloader/${SBI}-${BOARD}.bin"
$KERNEL_ENTRY_PA = "0x80200000"	

# change rustup mirrors
$RUSTUP_DIST_SERVER = "https://mirrors.tuna.tsinghua.edu.cn/rustup"
$RUSTUP_UPDATE_ROOT = "https://mirrors.ustc.edu.cn/rust-static/rustup"

# QEMU arguments
$QEMU_ARGS = @(
    "-machine", "virt",
    "-bios", $BOOTLOADER,
    "-serial", "stdio",
    "-display", "gtk",
    "-device", "loader,file=$KERNEL_BIN,addr=$KERNEL_ENTRY_PA",
    "-drive", "file=$FS_IMG,if=none,format=raw,id=x0",
    "-device", "virtio-blk-device,drive=x0",
    "-device", "virtio-gpu-device",
    "-device", "virtio-keyboard-device",
    "-device", "virtio-mouse-device",
    "-device", "virtio-net-device,netdev=net0",
    "-netdev", "user,id=net0,hostfwd=udp::6200-:2000,hostfwd=tcp::6201-:80",
    "-m", "2048"
)

# Tools
$OBJDUMP = "rust-objdump --arch-name=riscv64"
$OBJCOPY = "rust-objcopy --binary-architecture=riscv64"
$QEMU = "qemu-system-riscv64"

function Show-Menu {
    Clear-Host
    Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    Write-Host " RISC-V OS Build and Run Utility"
    Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    Write-Host ""
    Write-Host "1. Install required tools"
    Write-Host "2. Build kernel"
    Write-Host "3. Build filesystem image"
    Write-Host "4. Run in QEMU"
    Write-Host "5. Clean build"
    Write-Host "6. Disassemble kernel"
    Write-Host "7. Debug with GDB"
    Write-Host "8. Exit"
    Write-Host "9. Run directly"
    Write-Host ""
}

function Invoke-Env {
    Write-Host "Installing required tools..."
    rustup target add $TARGET
    cargo install cargo-binutils
    rustup component add rust-src
    rustup component add llvm-tools-preview
    Pause
}

function Invoke-BuildKernel {
    Write-Host "Building kernel for platform: $BOARD"
    Copy-Item -Path "src/linker-${BOARD}.ld" -Destination "src/linker.ld" -Force
    cargo build --release
    Remove-Item -Path "src/linker.ld" -Force
    Invoke-Expression "$OBJCOPY $KERNEL_ELF --strip-all -O binary $KERNEL_BIN"
    Pause
}

function Invoke-FsImg {
    Write-Host "Building filesystem image..."
    Set-Location "../user"
    & ./build.ps1 build
    Set-Location "../os"
    if (Test-Path $FS_IMG) { Remove-Item $FS_IMG -Force }
    Set-Location "../easy-fs-fuse"
    cargo run --release -- -s "../user/src/bin/" -t "../user/target/riscv64gc-unknown-none-elf/release/"
    Set-Location "../os"
    Pause
}

function Invoke-Run {
    Invoke-BuildKernel
    Invoke-FsImg
    Write-Host "Starting QEMU..."
    # Start-Process -NoNewWindow -FilePath $QEMU -ArgumentList $QEMU_ARGS
    Start-Process -FilePath $QEMU -ArgumentList $QEMU_ARGS    
    exit
}

function Invoke-Clean {
    Write-Host "Cleaning build..."
    cargo clean
    Pause
}

function Invoke-Disasm {
    Write-Host "Disassembling kernel..."
    Invoke-Expression "$OBJDUMP -x $KERNEL_ELF | more"
    Pause
}

function Invoke-Debug {
    Write-Host "Starting debug session..."
    Start-Process -FilePath $QEMU -ArgumentList ($QEMU_ARGS + "-s", "-S")
    Start-Process -NoNewWindow -FilePath "riscv64-unknown-elf-gdb" -ArgumentList @(
        "-ex", "file $KERNEL_ELF",
        "-ex", "set arch riscv:rv64",
        "-ex", "target remote localhost:1234"
    )
    Pause
}

function Pause {
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Judge whether need prompt
if ($args.Count -gt 0) {
    switch ($args[0]) {
	"build-kernel" { Invoke-BuildKernel }
        "build-img" { Invoke-FsImg }
        "clean" { Invoke-Clean }
        "run" { Start-Process -FilePath $QEMU -ArgumentList $QEMU_ARGS }
	default { Write-Host "Invalid option" }
    }
    exit
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Select option"
    
    switch ($choice) {
        "1" { Invoke-Env }
        "2" { Invoke-BuildKernel }
        "3" { Invoke-FsImg }
        "4" { Invoke-Run }
        "5" { Invoke-Clean }
        "6" { Invoke-Disasm }
        "7" { Invoke-Debug }
        "8" { exit }
	"9" { Start-Process -FilePath $QEMU -ArgumentList $QEMU_ARGS }
        default { Write-Host "Invalid option"; Pause }
    }
}