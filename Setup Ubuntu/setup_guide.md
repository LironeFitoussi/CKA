# Ubuntu VM Setup Guide

## Part 1: Auto-Start VMs in VMware Workstation 17

1. Open `services.msc`.
2. Find **VMware Autostart Service**:

   * Set startup type to **Automatic**.
   * Configure it to log on using your Windows account.
   * Restart the service.

3. Close VMware Workstation → right-click shortcut → **Run as administrator**. (Admins get full control on the config file — avoids the permission error below.)
4. Open VMware Workstation, enable Library from **View → Customize → Library**.
5. Right-click **My Computer** → **Configure Auto Start VMs**.
6. Select VMs, set startup order → OK.

### Permission error

If you still get:

```text
Failed to update auto start configuration
```

Find VMware autostart XML file (`C:\ProgramData\VMware\hostd`), open **Properties → Security**, give your Windows account **Full Control**.

### Notes

* Encrypted VMs may not start automatically.
* The VMs start in the background; VMware Workstation itself does not open.
* If the VM shows a black screen, suspend and resume it.

## Part 2: Connect to VS Code Without a Password

### 1. Create an SSH key on your computer

```bash
ssh-keygen -t ed25519
```

Press Enter at every prompt.

### 2. Copy the key to the server

**Mac / Linux:**

```bash
ssh-copy-id username@SERVER_IP
```

**Windows PowerShell:**

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh lirone@192.168.154.129 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Enter the server password one last time.

### 3. Configure VS Code

Open the following file:

```text
~/.ssh/config
```

Add the following configuration (add one `Host` block per machine):

```sshconfig
Host my-server
    HostName SERVER_IP
    User username
    IdentityFile ~/.ssh/id_ed25519

Host VMWare
    HostName 192.168.154.129
    User lirone
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

**Meaning of each option:**

* `Host` — the shortcut name for the SSH connection.
* `HostName` — the IP address of the virtual machine.
* `User` — the Linux username.
* `IdentityFile` — the private SSH key.
* `IdentitiesOnly yes` — forces SSH to use the configured key.

Now connect through VS Code using:

```text
Remote-SSH: Connect to Host
```

Select `my-server` (or `VMWare`).

## Part 3: Windows Shortcut to Open VS Code over SSH

Create a Windows desktop shortcut that opens VS Code directly on the remote machine, skipping the Remote-SSH host picker. Assumes the `Host VMWare` entry from Part 2 is already in `~/.ssh/config`.

### 1. Test the SSH connection

```powershell
ssh VMWare
```

If this succeeds, VS Code can use it too.

### 2. Find the VS Code executable

```powershell
Get-Command code | Select-Object -ExpandProperty Source
```

or:

```powershell
where.exe code
```

Typical locations:

```text
C:\Users\liron\AppData\Local\Programs\Microsoft VS Code\Code.exe
C:\Program Files\Microsoft VS Code\Code.exe
```

### 3. Create the desktop shortcut

1. Right-click the Windows desktop → **New → Shortcut**.
2. Location:

```text
"C:\Users\liron\AppData\Local\Programs\Microsoft VS Code\Code.exe" --remote ssh-remote+VMWare /home/lirone
```

3. Next → name it `VS Code - VMware` → Finish.

### 4. Open a different remote folder

Change the final path in the shortcut target, e.g.:

```text
"C:\Users\liron\AppData\Local\Programs\Microsoft VS Code\Code.exe" --remote ssh-remote+VMWare /home/lirone/projects
```

### 5. Change the shortcut icon

1. Right-click shortcut → **Properties** → **Change Icon**.
2. Browse to `Code.exe` (path above), select icon, OK.

### Final shortcut target

```text
"C:\Users\liron\AppData\Local\Programs\Microsoft VS Code\Code.exe" --remote ssh-remote+VMWare /home/lirone
```

VS Code reads IP, username, and SSH key from the `VMWare` entry in `~/.ssh/config`.
