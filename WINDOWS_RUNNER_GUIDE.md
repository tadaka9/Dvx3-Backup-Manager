# Guide: Setting Up a GitLab Runner on Windows 11

This guide will walk you through installing and registering a GitLab Runner on a Windows 11 machine. This runner will be configured to handle your `.build-windows-x64` job using the `shell` executor with MSYS2.

---

### **Part 1: Prepare Your Windows Environment**

Your CI job for Windows depends on MSYS2 and several packages. You must install these on the Windows machine that will host the runner.

1.  **Install MSYS2:**
    *   Go to [msys2.org](https://www.msys2.org/) and download the installer.
    *   Run the installer and follow the on-screen instructions. It's recommended to keep the default installation path (`C:\msys64`).

2.  **Install Build Dependencies:**
    *   Once MSYS2 is installed, open the **MSYS2 MINGW64** terminal (you can find it in your Start Menu).
    *   Copy and paste the following command into the terminal and press Enter. This will install all the compilers, libraries, and tools needed to build your project.
    ```bash
    pacman -Syu --noconfirm && pacman -S --noconfirm mingw-w64-x86_64-toolchain mingw-w64-x86_64-vala mingw-w64-x86_64-glib2 mingw-w64-x86_64-json-glib mingw-w64-x86_64-libsodium mingw-w64-x86_64-pkgconf mingw-w64-x86_64-qt6-base mingw-w64-x86_64-qt6-tools curl zip
    ```
    *   This process may take some time.

---

### **Part 2: Install the GitLab Runner**

1.  **Open PowerShell as Administrator:**
    *   Right-click the Start button and select **"Terminal (Admin)"** or **"Windows PowerShell (Admin)"**.

2.  **Create a Folder for the Runner:**
    Run this command to create a directory for the runner files.
    ```powershell
    New-Item -Path 'C:\GitLab-Runner' -ItemType Directory
    ```

3.  **Download the Runner Binary:**
    Run this command in the same PowerShell window to download the runner executable.
    ```powershell
    Invoke-WebRequest -Uri "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-windows-amd64.exe" -OutFile "C:\GitLab-Runner\gitlab-runner.exe"
    ```

---

### **Part 3: Register the New Runner**

This step links the runner to your GitLab project.

1.  **Get a New Registration Token:**
    *   Go to your GitLab project: `https://gitlab.com/cryptoware/Dvx3-backup-manager`
    *   Go to **Settings > CI/CD > Runners**.
    *   Click **New project runner**.
    *   Copy the new registration token (it starts with `glrt-`).

2.  **Run the Registration Command:**
    *   In your Administrator PowerShell window, navigate to the runner directory:
        ```powershell
        cd C:\GitLab-Runner
        ```
    *   Run the registration command:
        ```powershell
        .\gitlab-runner.exe register
        ```

3.  **Answer the Interactive Prompts:**
    Enter the following values when prompted.

    *   **Enter the GitLab instance URL:**
        ```
        https://gitlab.com/
        ```
    *   **Enter the registration token:**
        *Paste the new token you copied from GitLab.*
    *   **Enter a description for the runner:**
        ```
        Windows 11 x64 Runner
        ```
    *   **Enter tags for the runner (comma-separated):**
        *This is the most important step!*
        ```
        windows,shell
        ```
    *   **Enter optional maintenance note for the runner:**
        *Just press Enter to leave it blank.*
    *   **Enter an executor:**
        *Choose `shell`.*
        ```
        shell
        ```

    The runner is now registered! The configuration will be saved to `C:\GitLab-Runner\config.toml`.

---

### **Part 4: Install, Start, and Configure the Service**

1.  **Install the Service:**
    This command installs the runner as a Windows service that will start on boot.
    ```powershell
    .\gitlab-runner.exe install --user "NT AUTHORITY\System" --working-directory "C:\GitLab-Runner"
    ```

2.  **Configure the Shell:**
    We need to tell the runner to use the MSYS2 bash shell.
    *   Open the configuration file with Notepad:
        ```powershell
        notepad.exe C:\GitLab-Runner\config.toml
        ```
    *   Find the `[runners.shell]` section and add the `shell` line as shown below:
        ```toml
        [runners.shell]
          executor = "shell"
          shell = "C:\\msys64\\usr\\bin\\bash.exe" # Add this line
        ```
    *   Save and close the file.

3.  **Start the Service:**
    ```powershell
    .\gitlab-runner.exe start
    ```
    You can check its status with `.\gitlab-runner.exe status`.

---

### **Part 5: Verify and Test**

1.  **Check GitLab:**
    *   Go back to the **Settings > CI/CD > Runners** page in GitLab. You should now see your **"Windows 11 x64 Runner"** online with a green circle.

2.  **Enable the Windows Build Job:**
    *   On your main development machine, open `.gitlab-ci.yml`.
    *   Find the `.build-windows-x64` job.
    *   **Remove the dot (`.`)** from the beginning of its name to re-enable it.

3.  **Commit and Push:**
    *   Save the `.gitlab-ci.yml` file.
    *   Commit and push the change.
        ```bash
        git add .gitlab-ci.yml
        git commit -m "ci: Enable Windows x64 build job"
        git push gitlab main
        ```

A new pipeline will start, and your new Windows runner should pick up and run the `build-windows-x64` job.
