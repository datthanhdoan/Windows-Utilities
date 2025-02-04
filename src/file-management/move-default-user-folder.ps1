# Kiểm tra quyền Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Chạy script với quyền Administrator!"
    Break
}

# --- Nhập các tùy chọn tương tác từ người dùng ---
$targetDrive = Read-Host "Nhập phân vùng đích (mặc định: X:)"
if ([string]::IsNullOrEmpty($targetDrive)) { $targetDrive = "X:" }

$operationInput = Read-Host "Chọn thao tác cho nội dung (Move/Copy) (mặc định: Move)"
if ([string]::IsNullOrEmpty($operationInput)) { $operationInput = "Move" }
if ($operationInput -notin @("Move", "Copy")) {
    Write-Host "Giá trị không hợp lệ, mặc định là Move."
    $operationInput = "Move"
}
$operation = $operationInput

$simulateInput = Read-Host "Chạy ở chế độ simulation? (y/n) (mặc định: n)"
if ([string]::IsNullOrEmpty($simulateInput)) { $simulateInput = "n" }
$simulate = $simulateInput -match "^(y|Y)"

$restartInput = Read-Host "Restart Explorer sau khi hoàn tất? (y/n) (mặc định: y)"
if ([string]::IsNullOrEmpty($restartInput)) { $restartInput = "y" }
$restartExplorer = $restartInput -match "^(y|Y)"

Write-Host "`n=== Các tùy chọn đã chọn ==="
Write-Host "Phân vùng đích: $targetDrive"
Write-Host "Thao tác nội dung: $operation"
Write-Host "Chế độ Simulation: $simulate"
Write-Host "Restart Explorer sau khi hoàn tất: $restartExplorer"
Write-Host "=============================`n"

# Xác định đường dẫn cơ sở mới theo phân vùng đích
$BasePath = Join-Path $targetDrive "Home"

# Định nghĩa các folder cần di chuyển cùng thuộc tính (GUID, icon, …)
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

# Load Windows API (để gọi hàm SHSetKnownFolderPath)
$code = @'
using System;
using System.Runtime.InteropServices;

public class KnownFolders {
    [DllImport("shell32.dll")]
    public static extern int SHSetKnownFolderPath(ref Guid folderId, uint flags, IntPtr token, [MarshalAs(UnmanagedType.LPWStr)] string path);
}
'@
Add-Type -TypeDefinition $code

# Hàm cập nhật icon và thuộc tính cho folder
function Update-FolderIcon {
    param (
        [string]$FolderPath,
        [string]$IconResource,
        [string]$LocalizedResourceId
    )
    
    try {
        if ($simulate) {
            Write-Host "[Simulation] Sẽ tạo folder và cập nhật desktop.ini tại $FolderPath"
            return
        }
        
        # Tạo folder nếu chưa tồn tại
        if (-not (Test-Path $FolderPath)) {
            New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
        }

        # Đặt thuộc tính System cho folder
        attrib.exe +S $FolderPath

        # Tạo nội dung cho desktop.ini
        $iniContent = @"
[.ShellClassInfo]
IconResource=$IconResource
LocalizedResourceName=$LocalizedResourceId
IconFile=%SystemRoot%\System32\shell32.dll
IconIndex=0
"@
        $desktopIniPath = Join-Path $FolderPath "desktop.ini"
        $iniContent | Out-File -FilePath $desktopIniPath -Encoding Unicode -Force
        
        # Đặt thuộc tính System và Hidden cho desktop.ini
        attrib.exe +S +H $desktopIniPath
        
        Write-Host "Đã cập nhật icon và thuộc tính cho $FolderPath"
    }
    catch {
        Write-Warning "Không thể cập nhật icon cho $FolderPath. Lỗi: $($_.Exception.Message)"
    }
}

# Hàm lấy đường dẫn gốc của folder dựa trên SpecialFolder
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

# Hàm di chuyển (hoặc sao chép) folder đã được chuyển sang đường dẫn mới
function Move-KnownFolder {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FolderName,
        [Parameter(Mandatory=$true)]
        [string]$NewPath
    )
    
    try {
        # Lấy GUID của folder
        $Guid = [System.Guid]::Parse($UserFolders[$FolderName].KnownFolderId)
        
        if ($simulate) {
            Write-Host "[Simulation] Sẽ cập nhật đường dẫn của folder $FolderName sang $NewPath"
        }
        else {
            # Gọi API để cập nhật đường dẫn folder
            $result = [KnownFolders]::SHSetKnownFolderPath([ref]$Guid, 0, [IntPtr]::Zero, $NewPath)
            if ($result -ne 0) {
                Write-Warning "Không thể cập nhật đường dẫn của folder $FolderName. Mã lỗi: $result"
                return
            }
        }
        
        Write-Host "Đã cập nhật thành công đường dẫn cho folder $FolderName sang $NewPath"
        
        # Cập nhật icon và thuộc tính cho folder mới
        Update-FolderIcon -FolderPath $NewPath `
                          -IconResource $UserFolders[$FolderName].IconResource `
                          -LocalizedResourceId $UserFolders[$FolderName].LocalizedResourceId
        
        # Lấy đường dẫn gốc của folder cần di chuyển nội dung
        $oldPath = Get-OriginalPath -FolderName $FolderName -SpecialFolder $UserFolders[$FolderName].SpecialFolder
        
        if (Test-Path $oldPath) {
            Write-Host "Đang thực hiện $operation nội dung từ $oldPath sang $NewPath..."
            if ($simulate) {
                Write-Host "[Simulation] Sẽ $operation các file (trừ desktop.ini) từ $oldPath sang $NewPath"
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
                    Write-Host "Đã $operation nội dung từ $oldPath sang $NewPath"
                    
                    # --- Ý tưởng mở rộng: ---
                    # Sau khi di chuyển, bạn có thể kiểm tra nếu folder cũ rỗng và xóa nó.
                    # if ((Get-ChildItem -Path $oldPath -Force | Measure-Object).Count -eq 0) {
                    #     Remove-Item -Path $oldPath -Force
                    #     Write-Host "Folder cũ $oldPath đã được xóa vì không còn nội dung."
                    # }
                }
                else {
                    Write-Host "Không có nội dung nào cần $operation tại $oldPath"
                }
            }
        }
        else {
            Write-Warning "Không tìm thấy folder gốc: $oldPath"
        }
    }
    catch {
        Write-Error "Lỗi khi xử lý folder $FolderName. Chi tiết: $($_.Exception.Message)"
    }
}

# Di chuyển (hoặc sao chép) các folder đã định nghĩa
foreach ($folder in $UserFolders.Keys) {
    Move-KnownFolder -FolderName $folder -NewPath $UserFolders[$folder].NewPath
}

Write-Host "Hoàn tất di chuyển các folder!"

# Restart Explorer nếu người dùng chọn restart
if ($restartExplorer) {
    if ($simulate) {
        Write-Host "[Simulation] Sẽ restart Explorer."
    }
    else {
        Write-Host "Restarting Explorer..."
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Process "explorer.exe"
    }
}
