param(
    [string] $Name = 'svt-av1',
    [string] $Version = 'b486d839',
    [string] $Uri = 'https://gitlab.com/AOMediaCodec/SVT-AV1.git',
    [string] $Hash = 'b486d839ac13c1ed8a616aaccefd78ed295f4f3b',
    [array] $Targets = @('x64'),
    [array] $Patches = @(
        @{
            PatchFile = "${PSScriptRoot}/patches/svt-av1/0001-fix-preset-8-and-higher.patch"
            HashSum = "6c0708218c75e88b4557460f06dba998fc5eaf75fbff767c8799227f1f4cbf68"
        }
    )
)

function Setup {
    Setup-Dependency -Uri $Uri -Hash $Hash -DestinationPath $Path

    if ( ! ( $SkipAll -or $SkipDeps ) ) {
        Invoke-External pacman.exe -S --noconfirm --needed --noprogressbar nasm
    }
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

    $OnOff = @('OFF', 'ON')
    $ClangTargetString = if ($script:ClangTargetFlags) { ($script:ClangTargetFlags -split ' ' | ForEach-Object { "/clang:$_" }) -join ' ' } else { '' }
    $ClangFlags = "/clang:-O3 $ClangTargetString".Trim()
    $Options = @(
        $CmakeOptions
        '-T', 'ClangCL'
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$script:Shared.isPresent])"
        '-DBUILD_APPS:BOOL=OFF'
        '-DBUILD_DEC:BOOL=ON'
        '-DBUILD_ENC:BOOL=ON'
        '-DENABLE_NASM:BOOL=ON'
        '-DBUILD_TESTING:BOOL=OFF'
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
        '-DSVT_AV1_LTO:BOOL=ON'
        '-DENABLE_AVX512:BOOL=ON'
        "-DCMAKE_C_FLAGS=$ClangFlags"
        "-DCMAKE_CXX_FLAGS=$ClangFlags"
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
