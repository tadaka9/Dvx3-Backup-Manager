# Guide: Setting Up a GitLab Runner on Raspberry Pi (32-bit / armhf)

This guide walks you through installing and registering a GitLab Runner on a Raspberry Pi 1, 2, or Zero (armhf/32-bit). This runner will be configured to handle your `docker` and `arm` tagged jobs.

---

### **Part 1: Prepare Your Raspberry Pi**

Run these commands in the terminal on your Raspberry Pi.

1.  **Update Your System:**
    Ensure your package list and installed packages are up-to-date.
    ```bash
    sudo apt update
    sudo apt full-upgrade -y
    ```

2.  **Install Docker:**
    The easiest way to install Docker is using the official convenience script.
    ```bash
    curl -sSL https://get.docker.com | sh
    ```

3.  **Add Your User to the `docker` Group:**
    This allows you to run Docker commands without `sudo`.
    ```bash
    sudo usermod -aG docker ${USER}
    ```
    **IMPORTANT:** You must log out and log back in for this change to take effect.

---

### **Part 2: Install the GitLab Runner**

1.  **Download the Runner Binary for 32-bit ARM (armhf):**
    This command downloads the latest GitLab Runner executable for your Raspberry Pi 1.
    ```bash
    sudo curl -L --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-arm"
    ```

2.  **Make it Executable:**
    ```bash
    sudo chmod +x /usr/local/bin/gitlab-runner
    ```

3.  **Create a User for the Runner:**
    It's best practice to run the service as its own dedicated user.
    ```bash
    sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
    ```

4.  **Install and Start the Service:**
    This command installs the runner as a system service that will start on boot.
    ```bash
    sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
    sudo gitlab-runner start
    ```
    You can check its status with `sudo gitlab-runner status`.

---

### **Part 3: Register the New Runner**

This step links your new runner to your GitLab project.

1.  **Get a New Registration Token:**
    *   On your main computer, go to your GitLab project: `https://gitlab.com/cryptoware/Dvx3-backup-manager`
    *   Go to **Settings > CI/CD > Runners**.
    *   Click **New project runner**.
    *   Copy the new registration token (it starts with `glrt-`).

2.  **Run the Registration Command on Your Pi:**
    Run the following command on your Raspberry Pi. It will ask you a series of questions.
    ```bash
    sudo gitlab-runner register
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
        Raspberry Pi 1 (armhf) Runner
        ```
    *   **Enter tags for the runner (comma-separated):**
        *This is the most important step!*
        ```
        docker,arm
        ```
    *   **Enter optional maintenance note for the runner:**
        *Just press Enter to leave it blank.*
    *   **Enter an executor:**
        *Choose `docker`.*
        ```
        docker
        ```
    *   **Enter the default Docker image:**
        *Let's use the `trixie` image we discussed.*
        ```
        debian:trixie
        ```

    The runner is now registered! It will automatically be managed by the service you started earlier.

---

### **Part 4: Verify and Test**

1.  **Check GitLab:**
    *   Go back to the **Settings > CI/CD > Runners** page in GitLab. You should now see your **"Raspberry Pi ARM64 Runner"** online with a green circle.

2.  **Enable the ARM Build Job:**
    *   On your main computer, open `.gitlab-ci.yml`.
    *   Find the `.build-raspberry-armhf` job.
    *   **Remove the dot (`.`)** from the beginning of its name to re-enable it. It should look like this:
        ```yaml
        # Raspberry Pi ARMv7 (armhf) .deb package
        build-raspberry-armhf:
          stage: build
          image: arm32v7/debian:trixie
          # ... rest of the job
        ```

3.  **Commit and Push:**
    *   Save the `.gitlab-ci.yml` file.
    *   Commit and push the change.
        ```bash
        git add .gitlab-ci.yml
        git commit -m "ci: Enable armhf build job for Raspberry Pi 1 runner"
        git push
        ```

A new pipeline will start. Your local Kubernetes runner will run the `k8s-test` job, and your **new Raspberry Pi runner** should pick up and run the `build-raspberry-armhf` job. You've now got a multi-platform CI setup!
