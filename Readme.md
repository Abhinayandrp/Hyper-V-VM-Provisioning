# Hyper-V VM Provisioning PowerShell GUI
A PowerShell script that provides a graphical user interface (GUI) to easily provision Hyper-V virtual machines (VMs) on Windows using WPF, with embedded XAML for the UI.

# Features
User-friendly WPF GUI embedded inside the PowerShell script—no external UI files needed

# Input fields for VM configuration:

VM Name

VHD storage location

RAM size (GB)

CPU cores

Disk size (GB)

Virtual Switch selection via a dropdown populated dynamically from existing Hyper-V switches

VM Generation (Gen 1 or Gen 2) selection

ISO file selection using a browse dialog with enable/disable logic

Enable TPM chip support for Gen 2 VMs with a confirmation modal dialog to warn about irreversible VM version upgrade

Option to automatically start the VM after creation

Real-time progress and error logging displayed in the UI

Validation of inputs before VM provisioning

Clears input fields after every VM creation for clean subsequent usage

Runs entirely in PowerShell using built-in WPF support — no external dependencies

# Prerequisites
Windows 10 / Windows Server with Hyper-V role installed and enabled

PowerShell 5.1 or higher

Administrative privileges to manage Hyper-V VMs

Hyper-V PowerShell module (part of Hyper-V feature)

# Usage
Run the PowerShell script with Administrator privileges:

# powershell
`powershell.exe -ExecutionPolicy Bypass -File .\Hyper-V-VM-Provisioning.ps1`
The GUI will open containing fields for all VM parameters.

# Fill in the VM details:

Enter a unique VM name.

Select or browse to a folder for the VHD.

Specify RAM (in GB), CPU cores, and disk size (GB).

Select a virtual switch from the dropdown or leave blank for no network.

Select VM generation: 1 or 2.

Optionally check Attach ISO and browse to an ISO image.

If Gen 2 is selected, optionally enable TPM (a confirmation dialog will appear).

Check or uncheck Start VM after creation.

Click Provision VM.

Monitor progress and any error messages in the progress box on the right.

After completion, the form will clear automatically for your next VM configuration.

# Notes
If enabling TPM on Gen 2 VMs, a confirmation dialog appears warning that upgrading the VM version is irreversible and may affect migration/import compatibility.

The Virtual Switch dropdown is auto-populated with available Hyper-V switches on script start.

The script validates all numeric inputs and required fields before creating the VM.

Errors during VM creation appear in the progress log for troubleshooting.

The script creates and attaches VHDX files dynamically.

The ISO attachment area and TPM checkbox enable/disable depending on user choices.

# Troubleshooting
Ensure you run PowerShell as Administrator.

Confirm the Hyper-V role and module are properly installed.

Verify the VHD folder path exists and is accessible.

The VM name must be unique; existing VHD files with the same name will block creation.

TPM enabling requires Gen 2 VM generation.

If you select ISO attachment, verify the ISO path is valid.

For any errors, check the progress box in the UI for detailed messages.

# License
MIT License