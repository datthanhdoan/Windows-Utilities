# Yeu cau quyen Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    Write-Warning "Can chay voi quyen Administrator!"
    Break
}

# Dinh nghia cac thu muc can di chuyen va GUID tuong ung
$UserFolders = @{
    'Desktop' = @{
        KnownFolderId = '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'
        NewPath = 'X:\Home\Desktop'
        IconResource = '%SystemRoot%\System32\imageres.dll,-183'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21769'
        SpecialFolder = [System.Environment+SpecialFolder]::Desktop
    }
    'Documents' = @{
        KnownFolderId = '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}'
        NewPath = 'X:\Home\Documents'
        IconResource = '%SystemRoot%\System32\imageres.dll,-112'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21770'
        SpecialFolder = [System.Environment+SpecialFolder]::MyDocuments
    }
    'Downloads' = @{
        KnownFolderId = '{374DE290-123F-4565-9164-39C4925E467B}'
        NewPath = 'X:\Home\Downloads'
        IconResource = '%SystemRoot%\System32\imageres.dll,-184'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21798'
        SpecialFolder = [System.Environment+SpecialFolder]::UserProfile # Special case for Downloads
    }
    'Music' = @{
        KnownFolderId = '{4BD8D571-6D19-48D3-BE97-422220080E43}'
        NewPath = 'X:\Home\Music'
        IconResource = '%SystemRoot%\System32\imageres.dll,-108'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21790'
        SpecialFolder = [System.Environment+SpecialFolder]::MyMusic
    }
    'Pictures' = @{
        KnownFolderId = '{33E28130-4E1E-4676-835A-98395C3BC3BB}'
        NewPath = 'X:\Home\Pictures'
        IconResource = '%SystemRoot%\System32\imageres.dll,-113'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21779'
        SpecialFolder = [System.Environment+SpecialFolder]::MyPictures
    }
    'Videos' = @{
        KnownFolderId = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}'
        NewPath = 'X:\Home\Videos'
        IconResource = '%SystemRoot%\System32\imageres.dll,-189'
        LocalizedResourceId = '@%SystemRoot%\system32\shell32.dll,-21791'
        SpecialFolder = [System.Environment+SpecialFolder]::MyVideos
    }
}

# Load Windows API
$code = @'
using System;
using System.Runtime.InteropServices;

public class KnownFolders {
    [DllImport("shell32.dll")]
    public static extern int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
}
'@

Add-Type -TypeDefinition $code

function Update-FolderIcon {
    param (
        [string]$FolderPath,
        [string]$IconResource,
        [string]$LocalizedResourceId
    )
    
    try {
        # Tao thu muc moi neu chua ton tai
        if (-not (Test-Path $FolderPath)) {
            New-Item -Path $FolderPath -ItemType Directory -Force
        }

        # Dat thuoc tinh System cho thu muc
        attrib.exe +S $FolderPath

        # Tao noi dung desktop.ini
        $iniContent = @"
[.ShellClassInfo]
IconResource=$IconResource
LocalizedResourceName=$LocalizedResourceId
IconFile=%SystemRoot%\System32\shell32.dll
IconIndex=0
"@
        
        # Ghi file desktop.ini
        $desktopIniPath = Join-Path $FolderPath "desktop.ini"
        $iniContent | Out-File -FilePath $desktopIniPath -Encoding Unicode -Force
        
        # Dat thuoc tinh System va Hidden cho desktop.ini
        attrib.exe +S +H $desktopIniPath
        
        Write-Host "Da cap nhat icon va thuoc tinh cho $FolderPath"
    }
    catch {
        Write-Warning "Khong the cap nhat icon cho $FolderPath. Loi: $($_.Exception.Message)"
    }
}

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

function Move-KnownFolder {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FolderName,
        [Parameter(Mandatory=$true)]
        [string]$NewPath
    )
    
    try {
        # Lay GUID cua thu muc
        $Guid = [System.Guid]::Parse($UserFolders[$FolderName].KnownFolderId)
        
        # Di chuyen thu muc
        $result = [KnownFolders]::SHSetKnownFolderPath([ref]$Guid, 0, 0, $NewPath)
        
        if ($result -eq 0) {
            Write-Host "Da di chuyen thanh cong thu muc $FolderName sang $NewPath"
            
            # Cap nhat icon va thuoc tinh
            Update-FolderIcon -FolderPath $NewPath `
                            -IconResource $UserFolders[$FolderName].IconResource `
                            -LocalizedResourceId $UserFolders[$FolderName].LocalizedResourceId
            
            # Copy noi dung tu thu muc cu (neu can)
            $oldPath = Get-OriginalPath -FolderName $FolderName -SpecialFolder $UserFolders[$FolderName].SpecialFolder
            if (Test-Path $oldPath) {
                Get-ChildItem -Path $oldPath -Force | Where-Object { $_.Name -ne "desktop.ini" } | Copy-Item -Destination $NewPath -Recurse -Force
            }
        }
        else {
            Write-Warning "Khong the di chuyen thu muc $FolderName. Ma loi: $result"
        }
    }
    catch {
        Write-Error "Loi khi di chuyen $FolderName. Chi tiet: $($_.Exception.Message)"
    }
}

# Di chuyen tung thu muc
foreach ($folder in $UserFolders.Keys) {
    Move-KnownFolder -FolderName $folder -NewPath $UserFolders[$folder].NewPath
}

Write-Host "Hoan tat di chuyen cac thu muc!"

# Refresh Explorer
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Process "explorer.exe"