# Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Please run this script as Administrator!"
    Break
}

# --- User Input Options ---
$targetDrive = Read-Host "Enter target drive (default: X:)"
if ([string]::IsNullOrEmpty($targetDrive)) { $targetDrive = "X:" }

# Ensure target drive is in proper format (e.g., "X:")
if ($targetDrive -notmatch "^[A-Za-z]:$") {
    $targetDrive = $targetDrive.TrimEnd(":") + ":"
}

# Check if the drive exists
if (-not (Test-Path $targetDrive)) {
    Write-Warning "Target drive '$targetDrive' does not exist. Exiting..."
    Break
}

$operationInput = Read-Host "Choose content operation (Move/Copy) (default: Move)"
if ([string]::IsNullOrEmpty($operationInput)) { $operationInput = "Move" }
if ($operationInput -notin @("Move", "Copy")) {
    Write-Host "Invalid value. Defaulting to Move."
    $operationInput = "Move"
}
$operation = $operationInput

$simulateInput = Read-Host "Run in simulation mode? (y/n) (default: n)"
if ([string]::IsNullOrEmpty($simulateInput)) { $simulateInput = "n" }
$simulate = $simulateInput -match "^(y|Y)"

$restartInput = Read-Host "Restart Explorer after completion? (y/n) (default: y)"
if ([string]::IsNullOrEmpty($restartInput)) { $restartInput = "y" }
$restartExplorer = $restartInput -match "^(y|Y)"

# Display selected options with a nicer UI
Write-Host ""
Write-Host "==================================="
Write-Host "        Selected Options         " -ForegroundColor Cyan
Write-Host "-----------------------------------"
Write-Host "Target Drive          : $targetDrive"
Write-Host "Content Operation     : $operation"
Write-Host "Simulation Mode       : $simulate"
Write-Host "Restart Explorer      : $restartExplorer"
Write-Host "==================================="
Write-Host ""

# Define the base path on the target drive
$BasePath = Join-Path $targetDrive "Home"

# Define special folders along with their attributes
$UserFolders = @{
    'Desktop' = @{
        KnownFolderId        = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
        NewPath              = (Join-Path $BasePath "Desktop")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-183'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21769'
        SpecialFolder        = [System.Environment+SpecialFolder]::Desktop
    }
    'Documents' = @{
        KnownFolderId        = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
        NewPath              = (Join-Path $BasePath "Documents")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-112'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21770'
        SpecialFolder        = [System.Environment+SpecialFolder]::MyDocuments
    }
    'Downloads' = @{
        KnownFolderId        = '{374DE290-123F-4565-9164-39C4925E467B}'
        NewPath              = (Join-Path $BasePath "Downloads")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-184'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21798'
        SpecialFolder        = [System.Environment+SpecialFolder]::UserProfile
    }
    'Music' = @{
        KnownFolderId        = '{4BD8D571-6D19-48D3-BE97-422220080E43}'
        NewPath              = (Join-Path $BasePath "Music")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-108'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21790'
        SpecialFolder        = [System.Environment+SpecialFolder]::MyMusic
    }
    'Pictures' = @{
        KnownFolderId        = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
        NewPath              = (Join-Path $BasePath "Pictures")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-113'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21779'
        SpecialFolder        = [System.Environment+SpecialFolder]::MyPictures
    }
    'Videos' = @{
        KnownFolderId        = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
        NewPath              = (Join-Path $BasePath "Videos")
        IconResource         = '%SystemRoot%\System32\imageres.dll,-189'
        LocalizedResourceId  = '@%SystemRoot%\system32\shell32.dll,-21791'
        SpecialFolder        = [System.Environment+SpecialFolder]::MyVideos
    }
}

# Load Windows API (to call SHSetKnownFolderPath)
$code = @'
using System;
using System.Runtime.InteropServices;

public class KnownFolders {
    [DllImport("shell32.dll")]
    public static extern int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
}
'@
Add-Type -TypeDefinition $code

# Function to update folder icon and properties
function Update-FolderIcon {
    param (
        [string]$FolderPath,
        [string]$IconResource,
        [string]$LocalizedResourceId
    )
    
    try {
        if ($simulate) {
            Write-Host "[Simulation] Would create folder and update desktop.ini at: $FolderPath" -ForegroundColor Yellow
            return
        }
        
        # Create folder if it doesn't exist
        if (-not (Test-Path $FolderPath)) {
            New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
        }

        # Set system attribute for the folder
        attrib.exe +S $FolderPath

        # Prepare desktop.ini content
        $iniContent = @"
[.ShellClassInfo]
IconResource=$IconResource
LocalizedResourceName=$LocalizedResourceId
IconFile=%SystemRoot%\System32\shell32.dll
IconIndex=0
"@
        $desktopIniPath = Join-Path $FolderPath "desktop.ini"
        $iniContent | Out-File -FilePath $desktopIniPath -Encoding Unicode -Force
        
        # Set system and hidden attributes for desktop.ini
        attrib.exe +S +H $desktopIniPath
        
        Write-Host "Updated icon and properties for: $FolderPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not update icon for $FolderPath. Error: $($_.Exception.Message)"
    }
}

# Function to get the original path of the folder based on SpecialFolder
function Get-OriginalPath {
    param (
        [string]$FolderName,
        [System.Environment+SpecialFolder]$SpecialFolder
    )
    
    if ($FolderName -eq 'Downloads') {
        $userProfile = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        return Join-Path $userProfile 'Downloads'
    }
    else {
        return [Environment]::GetFolderPath($SpecialFolder)
    }
}

# Function to move (or copy) the folder's content to the new location
function Move-KnownFolder {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderName,
        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )
    
    try {
        # Get the folder GUID from configuration
        $Guid = [System.Guid]::Parse($UserFolders[$FolderName].KnownFolderId)
        
        # Check and create new folder if it doesn't exist
        if (-not (Test-Path $NewPath)) {
            if ($simulate) {
                Write-Host "[Simulation] Would create folder: $NewPath" -ForegroundColor Yellow
            }
            else {
                New-Item -Path $NewPath -ItemType Directory -Force | Out-Null
                Write-Host "Created folder: $NewPath" -ForegroundColor Green
            }
        }
        
        # Update the folder path using Windows API
        if ($simulate) {
            Write-Host "[Simulation] Would update path for folder '$FolderName' to: $NewPath" -ForegroundColor Yellow
        }
        else {
            $result = [KnownFolders]::SHSetKnownFolderPath([ref]$Guid, 0, [IntPtr]::Zero, $NewPath)
            if ($result -ne 0) {
                Write-Warning "Could not update path for folder '$FolderName'. Error code: $result"
                return
            }
        }
        
        Write-Host "Successfully updated path for folder '$FolderName' to: $NewPath" -ForegroundColor Green
        
        # Update the icon and properties for the new folder
        Update-FolderIcon -FolderPath $NewPath `
                          -IconResource $UserFolders[$FolderName].IconResource `
                          -LocalizedResourceId $UserFolders[$FolderName].LocalizedResourceId
        
        # Get the original folder path to move content from
        $oldPath = Get-OriginalPath -FolderName $FolderName -SpecialFolder $UserFolders[$FolderName].SpecialFolder
        
        if (Test-Path $oldPath) {
            Write-Host "Performing '$operation' operation:" -ForegroundColor Cyan
            Write-Host "  Source     : $oldPath"
            Write-Host "  Destination: $NewPath"
            if ($simulate) {
                Write-Host "[Simulation] Would $operation files (excluding desktop.ini) from $oldPath to $NewPath" -ForegroundColor Yellow
            }
            else {
                $items = Get-ChildItem -Path $oldPath -Force | Where-Object { $_.Name -ne "desktop.ini" }
                if ($items) {
                    if ($operation -eq "Move") {
                        $items | Move-Item -Destination $NewPath -Force -ErrorAction Stop
                    }
                    elseif ($operation -eq "Copy") {
                        $items | Copy-Item -Destination $NewPath -Recurse -Force -ErrorAction Stop
                    }
                    Write-Host "$operation operation completed from $oldPath to $NewPath" -ForegroundColor Green
                    
                    # Optional: Remove the original folder if empty
                    # if ((Get-ChildItem -Path $oldPath -Force | Measure-Object).Count -eq 0) {
                    #     Remove-Item -Path $oldPath -Force
                    #     Write-Host "Original folder $oldPath has been removed as it is empty." -ForegroundColor Green
                    # }
                }
                else {
                    Write-Host "No content found to $operation in: $oldPath" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Warning "Original folder not found: $oldPath"
        }
    }
    catch {
        Write-Error "Error processing folder '$FolderName'. Details: $($_.Exception.Message)"
    }
}

# Process each defined folder
foreach ($folder in $UserFolders.Keys) {
    Move-KnownFolder -FolderName $folder -NewPath $UserFolders[$folder].NewPath
}

Write-Host "`nFolder relocation completed!" -ForegroundColor Magenta

# Restart Explorer if chosen
if ($restartExplorer) {
    if ($simulate) {
        Write-Host "[Simulation] Would restart Explorer." -ForegroundColor Yellow
    }
    else {
        Write-Host "Restarting Explorer..." -ForegroundColor Cyan
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Process "explorer.exe"
    }
}
