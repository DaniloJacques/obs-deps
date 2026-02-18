param(
    [string] $Name = 'svt-av1',
    [string] $Version = '4.0.1',
    [string] $Uri = 'https://gitlab.com/AOMediaCodec/SVT-AV1.git',
    [string] $Hash = '4ae9272b588a05ee6e77a43e8dfdac05f54c4ff0',
    [array] $Targets = @('x64'),
    [array] $Patches = @()
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
    $ClangFlags = '/clang:-march=tigerlake /clang:-mtune=tigerlake /clang:-O3'
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
