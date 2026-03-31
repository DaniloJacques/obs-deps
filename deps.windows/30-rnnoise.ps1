param(
    [string] $Name = 'rnnoise',
    [string] $Version = '70f1d256acd4b34a572f999a05c87bf00b67730d',
    [string] $Uri = 'https://github.com/xiph/rnnoise.git',
    [string] $Hash = '70f1d256acd4b34a572f999a05c87bf00b67730d',
    [array] $Targets = @('x64', 'arm64')
)

function Setup {
    Invoke-GitCheckout -Uri $Uri -Commit $Hash -Path $Path -PullRequest '88'
}

function Clean {
    Set-Location $Path

    if ( Test-Path "build_${Target}" ) {
        Log-Information "Clean build directory (${Target})"
        Remove-Item -Path "build_${Target}" -Recurse -Force
    }
}

function Configure {
    Log-Information "Config (${Target})"
    Set-Location $Path

    $OnOff = @('OFF', 'ON')
    $Options = @(
        $CmakeOptions
        "-DBUILD_SHARED_LIBS:BOOL=$($OnOff[$script:Shared.isPresent])"
        '-DRNNOISE_COMPILE_OPUS:BOOL=ON'
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
    )

    Log-Debug "CMake configure options: ${Options}"

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

    $Params = @{
        ErrorAction = "SilentlyContinue"
        Path = @(
            "$($ConfigData.OutputPath)/bin"
            "$($ConfigData.OutputPath)/lib"
            "$($ConfigData.OutputPath)/include"
        )
        ItemType = "Directory"
        Force = $true
    }

    New-Item @Params *> $null

    $Items = @(
        @{
            Path = "./include/rnnoise.h"
            Destination = "$($ConfigData.OutputPath)/include/"
        }
        @{
            Path = "./build_${Target}/rnnoise.lib"
            Destination = "$($ConfigData.OutputPath)/lib/"
        }
        @{
            Path = "./build_${Target}/rnnoise.dll"
            Destination = "$($ConfigData.OutputPath)/bin/"
            ErrorAction = 'SilentlyContinue'
        }
    )

    $Items | ForEach-Object {
        $Item = $_
        Log-Status ('{0} => {1}' -f $Item.Path, $Item.Destination)
        Copy-Item @Item
    }
}
