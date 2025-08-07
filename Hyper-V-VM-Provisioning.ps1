<#
.SYNOPSIS
Author      : Abhinay Pal

Version     : 1.0

Description : PowerShell script with GUI to provision Hyper-V virtual machines with configurable settings.

DateUpdated : 2025-08-07
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Hyper-V VM Provisioning" Height="600" Width="800">
    <Grid Margin="10" Background="Ivory">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <ScrollViewer Grid.Column="0" Grid.Row="0" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="10">
                <TextBlock Text="VM Name:"/>
                <TextBox Name="VMNameBox"/>

                <TextBlock Text="VHD Location:"/>
                <StackPanel Orientation="Horizontal">
                    <TextBox Name="VHDPathBox" Width="250"/>
                    <Button Name="BrowseVHD" Content="Browse" Width="80"/>
                </StackPanel>

                <TextBlock Text="RAM (GB):"/>
                <TextBox Name="RAMBox"/>

                <TextBlock Text="CPU Cores:"/>
                <TextBox Name="CPUBox"/>

                <TextBlock Text="Disk Size (GB):"/>
                <TextBox Name="DiskBox"/>

                <TextBlock Text="Virtual Switch (optional):"/>
                <ComboBox Name="SwitchComboBox" IsEditable="True"/>

                <TextBlock Text="VM Generation:"/>
                <ComboBox Name="GenBox">
                    <ComboBoxItem Content="1"/>
                    <ComboBoxItem Content="2"/>
                </ComboBox>

                <CheckBox Name="ISOCheck" Content="Attach ISO"/>
                <StackPanel Orientation="Horizontal">
                    <TextBox Name="ISOPathBox" Width="250" IsEnabled="False"/>
                    <Button Name="BrowseISO" Content="Browse" Width="80" IsEnabled="False"/>
                </StackPanel>

                <CheckBox Name="TPMCheck" Content="Enable TPM (Gen 2 only)" IsEnabled="False"/>

                <CheckBox Name="StartVMCheck" Content="Start VM after creation" IsChecked="True"/>
            </StackPanel>
        </ScrollViewer>

        <GroupBox Header="Provisioning Progress" Grid.Column="1" Grid.Row="0" Margin="10">
            <TextBox Name="ProgressBox" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" IsReadOnly="True" TextWrapping="Wrap"/>
        </GroupBox>

        <Button Grid.Column="0" Grid.Row="1" Content="Provision VM" HorizontalAlignment="Right" Width="120" Margin="10" Name="CreateBtn"/>
        <TextBlock Grid.ColumnSpan="2" Grid.Row="2" Text="Developed by Abhinay Pal" HorizontalAlignment="Right" Margin="5" FontStyle="Italic" Foreground="Gray"/>
    </Grid>
</Window>
"@

# Confirmation dialog XAML as a string (not loaded yet)
$confirmDialogXamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Confirm TPM Enablement"
        WindowStartupLocation="CenterOwner"
        SizeToContent="WidthAndHeight"
        ResizeMode="NoResize"
        WindowStyle="SingleBorderWindow"
        Topmost="True"
        >
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" TextWrapping="Wrap" Width="350" FontWeight="SemiBold" Margin="0 0 0 15">
            Are you sure you want to perform this action? 
            Upgrading the VM configuration version is irreversible and will prevent the VM from being migrated or imported on older versions of Windows.
        </TextBlock>
        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button Name="YesBtn" Width="80" Margin="0 0 10 0" IsDefault="True">Yes</Button>
            <Button Name="NoBtn" Width="80" IsCancel="True">No</Button>
        </StackPanel>
    </Grid>
</Window>
"@

# Load main window XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls from main window
$vmNameBox = $window.FindName("VMNameBox")
$vhdPathBox = $window.FindName("VHDPathBox")
$ramBox = $window.FindName("RAMBox")
$cpuBox = $window.FindName("CPUBox")
$diskBox = $window.FindName("DiskBox")
$switchComboBox = $window.FindName("SwitchComboBox")
$genBox = $window.FindName("GenBox")
$isoCheck = $window.FindName("ISOCheck")
$isoPathBox = $window.FindName("ISOPathBox")
$browseISO = $window.FindName("BrowseISO")
$browseVHD = $window.FindName("BrowseVHD")
$tpmCheck = $window.FindName("TPMCheck")
$createBtn = $window.FindName("CreateBtn")
$progressBox = $window.FindName("ProgressBox")
$startVMCheck = $window.FindName("StartVMCheck")

# Enable/Disable ISO path and TPM checkbox logic
$isoCheck.Add_Checked({
    $isoPathBox.IsEnabled = $true
    $browseISO.IsEnabled = $true
})
$isoCheck.Add_Unchecked({
    $isoPathBox.IsEnabled = $false
    $browseISO.IsEnabled = $false
})

$genBox.Add_SelectionChanged({
    $tpmCheck.IsEnabled = ($genBox.SelectedIndex -eq 1)
    if (-not $tpmCheck.IsEnabled) {
        $tpmCheck.IsChecked = $false
    }
})

# Browse ISO file
$browseISO.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "ISO files (*.iso)|*.iso"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $isoPathBox.Text = $dialog.FileName
    }
})

# Browse VHD folder
$browseVHD.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $vhdPathBox.Text = $dialog.SelectedPath
    }
})

# Populate Virtual Switch ComboBox with available Hyper-V switches
try {
    $switches = Get-VMSwitch | Select-Object -ExpandProperty Name
} catch {
    $switches = @()
}

foreach ($sw in $switches) {
    $switchComboBox.Items.Add($sw) | Out-Null
}

# Log progress to the progress box
function Log-Progress($message) {
    $progressBox.AppendText("$message`r`n")
    $progressBox.ScrollToEnd()
}

# Function to create and show a fresh confirmation dialog every time
function Show-ConfirmDialog {
    param (
        [System.Windows.Window]$OwnerWindow
    )

    # Load the confirm dialog XAML fresh
    [xml]$confirmDialogXaml = $confirmDialogXamlString
    $confirmReader = (New-Object System.Xml.XmlNodeReader $confirmDialogXaml)
    $confirmWindow = [Windows.Markup.XamlReader]::Load($confirmReader)

    # Find buttons from new dialog instance
    $yesButton = $confirmWindow.FindName("YesBtn")
    $noButton = $confirmWindow.FindName("NoBtn")

    # Variable to hold user answer
    $script:confirmResult = $false

    # Register button click handlers
    $yesButton.Add_Click({
        $script:confirmResult = $true
        $confirmWindow.Close()
    })
    $noButton.Add_Click({
        $script:confirmResult = $false
        $confirmWindow.Close()
    })

    # Set owner for modality and show dialog synchronously
    $confirmWindow.Owner = $OwnerWindow
    $confirmWindow.ShowDialog() | Out-Null

    return $script:confirmResult
}

# Function to clear all input fields and reset controls after VM creation
function Clear-FormFields {
    # Clear TextBoxes
    $vmNameBox.Text = ""
    $vhdPathBox.Text = ""
    $ramBox.Text = ""
    $cpuBox.Text = ""
    $diskBox.Text = ""
    $isoPathBox.Text = ""

    # Reset ComboBox for Switch selection (clear editable text but preserve items)
    $switchComboBox.Text = ""

    # Reset Generation ComboBox to first item (generation 1)
    $genBox.SelectedIndex = 0

    # Reset CheckBoxes
    $isoCheck.IsChecked = $false
    $tpmCheck.IsChecked = $false
    $tpmCheck.IsEnabled = $false
    $startVMCheck.IsChecked = $true

    # Disable ISO path textbox and browse button accordingly
    $isoPathBox.IsEnabled = $false
    $browseISO.IsEnabled = $false
}

# Create VM logic
$createBtn.Add_Click({
    try {
        $vmName = $vmNameBox.Text.Trim()
        $vhdLocation = $vhdPathBox.Text.Trim()
        $switchName = $switchComboBox.Text.Trim()
        $generation = [int]::Parse($genBox.SelectedItem.Content.ToString())
        $useISO = $isoCheck.IsChecked
        $isoPath = $isoPathBox.Text.Trim()
        $tpmEnabled = $tpmCheck.IsChecked
        $startVM = $startVMCheck.IsChecked

        $ramGB = 0
        $cpuCount = 0
        $diskGB = 0

        if (-not [System.Int32]::TryParse($ramBox.Text, [ref]$ramGB)) {
            Log-Progress "Invalid RAM value."
            return
        }
        if (-not [System.Int32]::TryParse($cpuBox.Text, [ref]$cpuCount)) {
            Log-Progress "Invalid CPU value."
            return
        }
        if (-not [System.Int32]::TryParse($diskBox.Text, [ref]$diskGB)) {
            Log-Progress "Invalid Disk Size value."
            return
        }

        if ([string]::IsNullOrWhiteSpace($vmName) -or [string]::IsNullOrWhiteSpace($vhdLocation)) {
            Log-Progress "VM Name and VHD Location are required."
            return
        }

        if (-not (Test-Path $vhdLocation)) {
            Log-Progress "VHD location does not exist."
            return
        }

        if ($useISO -and (-not (Test-Path $isoPath))) {
            Log-Progress "ISO path is invalid."
            return
        }

        $ramBytes = [int64]$ramGB * 1GB
        $diskBytes = [int64]$diskGB * 1GB
        $vhdPath = Join-Path $vhdLocation "$vmName.vhdx"

        if (Test-Path $vhdPath) {
            Log-Progress "Virtual hard disk '$vhdPath' already exists. Please choose a different VM name or delete the existing VHD."
            return
        }

        Log-Progress "Creating VM..."
        if ([string]::IsNullOrWhiteSpace($switchName)) {
            New-VM -Name $vmName -MemoryStartupBytes $ramBytes -Generation $generation -Path $vhdLocation | Out-Null
        } else {
            New-VM -Name $vmName -MemoryStartupBytes $ramBytes -Generation $generation -SwitchName $switchName -Path $vhdLocation | Out-Null
        }

        Log-Progress "Creating virtual hard disk..."
        New-VHD -Path $vhdPath -SizeBytes $diskBytes -Dynamic | Out-Null

        Log-Progress "Attaching hard disk to VM..."
        Add-VMHardDiskDrive -VMName $vmName -Path $vhdPath

        Log-Progress "Setting CPU count..."
        Set-VMProcessor -VMName $vmName -Count $cpuCount

        if ($useISO) {
            Log-Progress "Attaching ISO file..."
            $dvdDrive = Get-VMDvdDrive -VMName $vmName -ErrorAction SilentlyContinue
            if ($dvdDrive) {
                Set-VMDvdDrive -VMName $vmName -ControllerNumber $dvdDrive.ControllerNumber -ControllerLocation $dvdDrive.ControllerLocation -Path $isoPath
            } else {
                Add-VMDvdDrive -VMName $vmName -Path $isoPath
            }
        }

        if ($tpmEnabled -and $generation -eq 2) {
            $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
            if ($null -ne $vm) {
                $confirmed = Show-ConfirmDialog -OwnerWindow $window
                if ($confirmed) {
                    Log-Progress "User confirmed VM version upgrade. Upgrading..."
                    Start-Sleep -Seconds 2
                    try {
                        Update-VMVersion -VMName $vmName -Confirm:$false
                        Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector -ErrorAction Stop
                        Enable-VMTPM -VMName $vmName -ErrorAction Stop
                        Log-Progress "TPM enabled successfully."
                    }
                    catch {
                        Log-Progress "Failed to update VM version or enable TPM: $_"
                    }
                } else {
                    Log-Progress "User cancelled VM version upgrade. TPM not enabled."
                }
            }
            else {
                Log-Progress "VM '$vmName' does not exist. Cannot enable TPM."
            }
        }

        if ($startVM) {
            Log-Progress "Starting VM..."
            Start-VM -Name $vmName
            Log-Progress "VM '$vmName' created and started successfully."
        }
        else {
            Log-Progress "VM '$vmName' created successfully. VM not started as per user choice."
        }

        # Clear/reset form fields after VM creation attempt
        Clear-FormFields

    }
    catch {
        Log-Progress "Error: $_"
        Clear-FormFields
    }
})

# Show main window
$window.ShowDialog() | Out-Null
