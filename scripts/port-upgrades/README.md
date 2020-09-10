# port-upgrades (internal only)

> This documentation is for internal use and will change without warning

This is an internal script used to prepare bulk-upgrade commits. The primary entrypoint is `upgradeKnownPorts.ps1`.

## `upgradeKnownPorts.ps1`
This utility uses the data in `portData.ps1` to bulk upgrade ports in the `ports/` directory.
### Parameters:
#### VcpkgPath
The path to the Vcpkg clone that will be updated (note: points to the directory, not the executable).

Source tarballs will be downloaded into the `downloads/` subfolder of this path.

#### WorkDirectory
Git repositories will be cloned under this root to analyze tags/branches.

#### NoTags
Disable updating tag-based ports

#### NoRolling
Disable updating rolling-release ports

#### Filter
A regex to only update some ports

#### ForceFailing
A regex to force updating ports that are recorded as known to fail upon upgrade

### Example:
```powershell
> upgradeKnownPorts.ps1 -VcpkgPath C:\src\vcpkg -WorkDirectory C:\src\vcpkg\working
```

## `scanNewPorts.ps1`
This utility scans the ports directory for ports that use `vcpkg_from_github` and haven't been added to the `portData.ps1` file. It also applies a heuristic to their version to enable filtering (e.g. `scan | ? type -match "date"`).

### Parameters:
#### VcpkgPath
The path to the Vcpkg clone that will be scanned (note: points to the directory, not the executable)

### Example:
```powershell
> scanNewPorts.ps1 -VcpkgPath C:\src\vcpkg
```
