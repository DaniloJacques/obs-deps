param(
    [string] $Name = 'srt',
    [string] $Version = '44d106f491333a022351f8c105e23886aad4e248',
    [string] $Uri = 'https://github.com/Haivision/srt.git',
    [string] $Hash = "44d106f491333a022351f8c105e23886aad4e248",
    [array] $Targets = @('x64', 'arm64'),
    [switch] $ForceShared = $true,
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/srt/0002-update-mbedtls-discovery-windows.patch"
            HashSum = "8fa5fa45ce83371a31d1235f36a0215afe5f70676527c5b77032974f14ff5a38"
        },
        @{
            PatchFile = "${PSScriptRoot}/patches/srt/0003-fix-mbedtls-v3.5.0-plus-build-error-on-windows.patch"
            HashSum = "ba871894fc21a50aa70d8b288b6d77bb59260f4191e184d790ed929f1695b436"
        },
        @{
            PatchFile = "${PSScriptRoot}/patches/srt/0004-fix-link-bcrypt-on-windows-when-mbedtls-v3.5.0-plus.patch"
            HashSum = "1352dde39960d4c5f1c5c73873207177d2a07007d580b8999085a425f0759d5e"
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path
}

function Clean {
    Set-Location $Path

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Patch {
    Log-Information "Patch (${Target})"
    Set-Location $Path

    $Patches | ForEach-Object {
        $Params = $_
        Safe-Patch @Params
    }
}

function Configure {
    Log-Information "Configure (${Target})"
    Set-Location $Path

    if ( $ForceShared -and ( $script:Shared -eq $false ) ) {
        $Shared = $true
    } else {
        $Shared = $script:Shared.isPresent
    }

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DENABLE_SHARED:BOOL=$($OnOff[$Shared])"
        '-DENABLE_STATIC:BOOL=ON'
        '-DENABLE_APPS:BOOL=OFF'
        '-DUSE_ENCLIB:STRING=mbedtls'
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
        "-DCMAKE_C_COMPILER=C:/PROGRA~1/LLVM/bin/clang-cl.exe"
        "-DCMAKE_CXX_COMPILER=C:/PROGRA~1/LLVM/bin/clang-cl.exe"
        "-DCMAKE_SHARED_LINKER_FLAGS=delayimp.lib"
        "-DCMAKE_C_FLAGS=-w /EHsc"
        "-DCMAKE_CXX_FLAGS=-w /EHsc"
    )

    Invoke-External cmake -S . -B "build_${Target}" @Options
}

function Build {
    Log-Information "Build (${Target})"
    Set-Location $Path

    $Options = @(
        '--build', "build_${Target}"
        '--config', $Configuration
    )

    if ( $VerbosePreference -eq 'Continue' ) {
        $Options += '--verbose'
    }

    $Options += @($CmakePostfix)

    Invoke-External cmake @Options
}

function Install {
    Log-Information "Install (${Target})"
    Set-Location $Path

    $Options = @(
        '--install', "build_${Target}"
        '--config', $Configuration
    )

    if ( $Configuration -match "(Release|MinSizeRel)" ) {
        $Options += '--strip'
    }

    Invoke-External cmake @Options
}

function Fixup {
    Log-Information "Fixup (${Target})"
    Set-Location $Path

    $PkgConfigPath = "$($script:ConfigData.OutputPath)/lib/pkgconfig"
    if ( Test-Path $PkgConfigPath ) {
        Get-ChildItem -Path $PkgConfigPath -Filter *.pc | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            $content = $content -replace '(?i)\bws2_32\.lib\b', '-lws2_32'
            Set-Content -Path $_.FullName -Value $content -NoNewline
        }
    }
}
