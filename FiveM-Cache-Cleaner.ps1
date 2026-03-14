# ============================================================
#  FiveM Cache Cleaner
#  https://github.com/[ton-repo]
# ============================================================

# Encodage UTF-8 pour la console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Add-Type -AssemblyName System.Windows.Forms

# ============================================================
#  LANGUES
# ============================================================

$i18n = @{
    fr = @{
        Title           = "===== FiveM Cache Cleaner ====="
        Folder          = "Dossier"
        SelectHint      = "Appuyez sur un numero pour cocher/decocher :"
        TotalSelected   = "Total selectionne"
        BtnChange       = "[C] Changer le dossier d'installation"
        BtnClean        = "[N] Nettoyer les dossiers selectionnes"
        BtnLang         = "[L] Switch to English"
        BtnQuit         = "[Q] Quitter"
        YourChoice      = "Votre choix"
        Deleted             = "Supprime"
        GameStorageWarning  = "Votre dossier 'game-storage' ne sera pas supprime."
        PickInfo        = "Veuillez selectionner votre dossier 'FiveM Application Data'.`n`nIl s'agit generalement du dossier 'FiveM.app' situe dans :`n{0}`n`nOu d'un dossier personnalise contenant les sous-dossiers 'data', 'crashes', 'logs', etc."
        PickTitle       = "Selection du dossier FiveM"
        PickDescription = "Selectionner le dossier 'FiveM Application Data'"
        NotFound        = "Le dossier FiveM n'a pas ete trouve a l'emplacement par defaut.`nVeuillez indiquer manuellement votre dossier 'FiveM Application Data'."
        NotFoundTitle   = "Dossier introuvable"
        InvalidFolder   = "Ce dossier ne semble pas etre un dossier 'FiveM Application Data' valide.`nAssurez-vous de selectionner le dossier contenant 'data', 'crashes', 'logs', etc."
        InvalidTitle    = "Dossier invalide"
        InvalidShort    = "Dossier invalide. Le chemin n'a pas ete modifie."
        ErrorTitle      = "Erreur"
        NoneSelected    = "Aucun dossier selectionne."
        InfoTitle       = "Info"
        FiveMRunning    = "FiveM est en cours d'execution. Voulez-vous le fermer avant de continuer ?"
        FiveMTitle      = "FiveM ouvert"
        ConfirmDelete   = "Supprimer {0} de donnees ?`n`nCette action est irreversible."
        ConfirmTitle    = "Confirmation"
        DoneMsg         = "{0} supprimes avec succes."
        DoneTitle       = "Termine"
    }
    en = @{
        Title           = "===== FiveM Cache Cleaner ====="
        Folder          = "Folder"
        SelectHint      = "Press a number to check/uncheck :"
        TotalSelected   = "Total selected"
        BtnChange       = "[C] Change install folder"
        BtnClean        = "[N] Clean selected folders"
        BtnLang         = "[L] Passer en francais"
        BtnQuit         = "[Q] Quit"
        YourChoice      = "Your choice"
        Deleted             = "Deleted"
        GameStorageWarning  = "Your 'game-storage' folder will not be deleted."
        PickInfo        = "Please select your 'FiveM Application Data' folder.`n`nThis is usually the 'FiveM.app' folder located at :`n{0}`n`nOr a custom folder containing the subfolders 'data', 'crashes', 'logs', etc."
        PickTitle       = "Select FiveM folder"
        PickDescription = "Select the 'FiveM Application Data' folder"
        NotFound        = "The FiveM folder was not found at the default location.`nPlease manually specify your 'FiveM Application Data' folder."
        NotFoundTitle   = "Folder not found"
        InvalidFolder   = "This folder does not appear to be a valid 'FiveM Application Data' folder.`nMake sure to select the folder containing 'data', 'crashes', 'logs', etc."
        InvalidTitle    = "Invalid folder"
        InvalidShort    = "Invalid folder. The path has not been changed."
        ErrorTitle      = "Error"
        NoneSelected    = "No folder selected."
        InfoTitle       = "Info"
        FiveMRunning    = "FiveM is currently running. Do you want to close it before continuing ?"
        FiveMTitle      = "FiveM is open"
        ConfirmDelete   = "Delete {0} of data ?`n`nThis action is irreversible."
        ConfirmTitle    = "Confirmation"
        DoneMsg         = "{0} successfully deleted."
        DoneTitle       = "Done"
    }
}

# Detection automatique : FR si le PC est en francais, EN sinon
$pcLang      = (Get-Culture).TwoLetterISOLanguageName
$langKey     = if ($pcLang -eq "fr") { "fr" } else { "en" }
$showLangBtn = ($pcLang -ne "fr")    # [L] visible uniquement sur PC non-FR
$t           = $i18n[$langKey]

function Switch-Lang {
    $script:langKey = if ($script:langKey -eq "fr") { "en" } else { "fr" }
    $script:t = $script:i18n[$script:langKey]
}

# ============================================================
#  CONFIG & CHEMINS
# ============================================================

$ConfigFile  = Join-Path $PSScriptRoot "fivem-cleaner-config.txt"
$DefaultPath = Join-Path $env:LOCALAPPDATA "FiveM\FiveM.app"

$RootDirs = @("crashes", "logs")
$DataDirs = @("cache", "server-cache", "server-cache-priv", "nui-storage")

# ============================================================
#  FONCTIONS UTILITAIRES
# ============================================================

function Get-SavedPath {
    if (Test-Path $ConfigFile) {
        $saved = Get-Content $ConfigFile -Raw
        if ($saved) { return $saved.Trim() }
    }
    return $null
}

function Save-Path($path) {
    Set-Content -Path $ConfigFile -Value $path -Encoding UTF8
}

function Format-Size($bytes) {
    if     ($bytes -lt 1KB) { return "{0:N2} B"  -f $bytes }
    elseif ($bytes -lt 1MB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    elseif ($bytes -lt 1GB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    else                    { return "{0:N2} GB" -f ($bytes / 1GB) }
}

function Get-FolderSize($folder) {
    if (-not (Test-Path $folder)) { return 0 }
    return (Get-ChildItem $folder -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
}

function Is-ValidFiveMFolder($path) {
    if (-not (Test-Path $path)) { return $false }
    $hasData = Test-Path (Join-Path $path "data")
    $hasRoot = ($RootDirs | Where-Object { Test-Path (Join-Path $path $_) }).Count -gt 0
    return $hasData -or $hasRoot
}

function Is-FiveMRunning {
    return $null -ne (Get-Process "FiveM" -ErrorAction SilentlyContinue)
}

# ============================================================
#  SELECTION DU DOSSIER
# ============================================================

function Pick-Folder($initialDir) {
    [System.Windows.Forms.MessageBox]::Show(
        ($t.PickInfo -f $DefaultPath),
        $t.PickTitle,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description         = $t.PickDescription
    $dialog.SelectedPath        = if (Test-Path $initialDir) { $initialDir } else { $env:LOCALAPPDATA }
    $dialog.ShowNewFolderButton = $false

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

function Resolve-BasePath {
    # 1. Chemin sauvegarde
    $saved = Get-SavedPath
    if ($saved -and (Is-ValidFiveMFolder $saved)) { return $saved }

    # 2. Chemin par defaut
    if (Is-ValidFiveMFolder $DefaultPath) {
        Save-Path $DefaultPath
        return $DefaultPath
    }

    # 3. Demande a l'utilisateur
    [System.Windows.Forms.MessageBox]::Show(
        $t.NotFound, $t.NotFoundTitle,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null

    while ($true) {
        $chosen = Pick-Folder $env:LOCALAPPDATA
        if ($null -eq $chosen) { exit }

        if (Is-ValidFiveMFolder $chosen) {
            Save-Path $chosen
            return $chosen
        }

        $retry = [System.Windows.Forms.MessageBox]::Show(
            $t.InvalidFolder, $t.InvalidTitle,
            [System.Windows.Forms.MessageBoxButtons]::RetryCancel,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        if ($retry -ne [System.Windows.Forms.DialogResult]::Retry) { exit }
    }
}

# ============================================================
#  PROGRAMME PRINCIPAL
# ============================================================

$BasePath = Resolve-BasePath
$DataPath = Join-Path $BasePath "data"

$items = [ordered]@{}
foreach ($d in $RootDirs) {
    $path = Join-Path $BasePath $d
    $items["root_$d"] = @{ Path = $path; Size = Get-FolderSize $path; Label = $d }
}
foreach ($d in $DataDirs) {
    $path = Join-Path $DataPath $d
    $items["data_$d"] = @{ Path = $path; Size = Get-FolderSize $path; Label = "data/$d" }
}

$keys     = @($items.Keys)
$selected = @{}
foreach ($k in $keys) { $selected[$k] = $true }

# ============================================================
#  MENU
# ============================================================

function Show-Menu {
    Clear-Host
    Write-Host $t.Title -ForegroundColor Cyan
    Write-Host "$($t.Folder) : $BasePath" -ForegroundColor DarkGray
    Write-Host "  $($t.GameStorageWarning)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  $($t.SelectHint)"
    Write-Host ""

    $i = 1
    foreach ($k in $keys) {
        $item  = $items[$k]
        $check = if ($selected[$k]) { "[X]" } else { "[ ]" }
        $size  = Format-Size $item.Size
        $color = if ($item.Size -gt 500MB) { "Red" } elseif ($item.Size -gt 100MB) { "Yellow" } else { "Gray" }
        Write-Host ("  {0} {1}  {2,-30} {3}" -f $check, $i, $item.Label, $size) -ForegroundColor $color
        $i++
    }

    $total = 0
    foreach ($k in $keys) { if ($selected[$k]) { $total += $items[$k].Size } }

    Write-Host ""
    Write-Host ("  {0} : {1}" -f $t.TotalSelected, (Format-Size $total)) -ForegroundColor White
    Write-Host ""
    Write-Host "  $($t.BtnChange)" -ForegroundColor DarkCyan
    Write-Host "  $($t.BtnClean)"  -ForegroundColor Green
    if ($showLangBtn) {
        Write-Host "  $($t.BtnLang)" -ForegroundColor DarkYellow
    }
    Write-Host "  $($t.BtnQuit)" -ForegroundColor DarkGray
    Write-Host ""
    return $total
}

# ============================================================
#  BOUCLE PRINCIPALE
# ============================================================

while ($true) {
    $total     = Show-Menu
    $userInput = Read-Host "  $($t.YourChoice)"

    # Toggle par numero
    if ($userInput -match '^\d+$') {
        $idx = [int]$userInput - 1
        if ($idx -ge 0 -and $idx -lt $keys.Count) {
            $selected[$keys[$idx]] = -not $selected[$keys[$idx]]
        }
        continue
    }

    switch ($userInput.ToUpper()) {

        "C" {
            $chosen = Pick-Folder $BasePath
            if ($chosen -and (Is-ValidFiveMFolder $chosen)) {
                $script:BasePath = $chosen
                $script:DataPath = Join-Path $chosen "data"
                Save-Path $chosen
                foreach ($d in $RootDirs) {
                    $p = Join-Path $script:BasePath $d
                    $items["root_$d"].Path = $p
                    $items["root_$d"].Size = Get-FolderSize $p
                }
                foreach ($d in $DataDirs) {
                    $p = Join-Path $script:DataPath $d
                    $items["data_$d"].Path = $p
                    $items["data_$d"].Size = Get-FolderSize $p
                }
            } elseif ($chosen) {
                [System.Windows.Forms.MessageBox]::Show(
                    $t.InvalidShort, $t.ErrorTitle, "OK", "Error") | Out-Null
            }
        }

        "N" {
            $toClean = $keys | Where-Object { $selected[$_] }
            if (-not $toClean) {
                [System.Windows.Forms.MessageBox]::Show(
                    $t.NoneSelected, $t.InfoTitle, "OK", "Information") | Out-Null
                continue
            }

            if (Is-FiveMRunning) {
                $ans = [System.Windows.Forms.MessageBox]::Show(
                    $t.FiveMRunning, $t.FiveMTitle, "YesNo", "Warning")
                if ($ans -eq "Yes") {
                    Stop-Process -Name "FiveM" -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 2
                } else { continue }
            }

            $ans = [System.Windows.Forms.MessageBox]::Show(
                ($t.ConfirmDelete -f (Format-Size $total)),
                $t.ConfirmTitle, "YesNo", "Question")

            if ($ans -eq "Yes") {
                $freed = 0
                foreach ($k in $toClean) {
                    $path = $items[$k].Path
                    if (Test-Path $path) {
                        $freed += $items[$k].Size
                        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Host "  $($t.Deleted) : $path" -ForegroundColor DarkGray
                    }
                }
                [System.Windows.Forms.MessageBox]::Show(
                    ($t.DoneMsg -f (Format-Size $freed)),
                    $t.DoneTitle, "OK", "Information") | Out-Null

                foreach ($k in $keys) { $items[$k].Size = Get-FolderSize $items[$k].Path }
            }
        }

        "L" {
            if ($showLangBtn) { Switch-Lang }
        }

        "Q" { exit }
    }
}