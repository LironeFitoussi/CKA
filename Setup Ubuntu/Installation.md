# Install Git and Connect to GitHub on Ubuntu

This guide explains how to install Git, configure your identity, connect your Ubuntu machine to GitHub using SSH, and push a local project to a GitHub repository.

## 1. Update the package index

```bash
sudo apt update
```

## 2. Install Git

```bash
sudo apt install -y git
```

Verify the installation:

```bash
git --version
```

## 3. Configure Git

Set the name and email address that will appear in your commits:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

Use the same email address associated with your GitHub account.

Set `main` as the default branch name for new repositories:

```bash
git config --global init.defaultBranch main
```

Review your configuration:

```bash
git config --global --list
```

## 4. Create an SSH key for GitHub

Generate a new SSH key, replacing the example email address with your GitHub email address:

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
```

Press **Enter** to accept the default file location. You may optionally enter a passphrase for additional security.

Start the SSH agent and add your private key:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Display your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the complete output, including `ssh-ed25519` at the beginning.

## 5. Add the SSH key to GitHub

1. Sign in to GitHub.
2. Open **Settings**.
3. Select **SSH and GPG keys**.
4. Select **New SSH key**.
5. Enter a descriptive title, such as `Ubuntu workstation`.
6. Paste your public key and select **Add SSH key**.

Test the connection:

```bash
ssh -T git@github.com
```

The first time you connect, type `yes` to trust GitHub's host key. A successful connection displays a message containing your GitHub username.

## 6. Create a repository on GitHub

1. On GitHub, select **New repository**.
2. Enter a repository name.
3. Choose whether the repository should be public or private.
4. Leave the README, `.gitignore`, and license options unselected when pushing an existing local project.
5. Select **Create repository**.

Keep the repository page open so you can copy its SSH URL. It will look like this:

```text
git@github.com:YOUR_USERNAME/YOUR_REPOSITORY.git
```

## 7. Push an existing local project to GitHub

Open the project directory:

```bash
cd /path/to/your/project
```

Initialize the Git repository and create the first commit:

```bash
git init
git add .
git commit -m "Initial commit"
```

Connect the local repository to GitHub and push the `main` branch:

```bash
git remote add origin git@github.com:YOUR_USERNAME/YOUR_REPOSITORY.git
git branch -M main
git push -u origin main
```

Replace `YOUR_USERNAME` and `YOUR_REPOSITORY` with your GitHub username and repository name.

## 8. Push future changes

After editing files, review and publish your changes with:

```bash
git status
git add .
git commit -m "Describe your changes"
git push
```

## 9. Clone an existing GitHub repository

To download a repository that already exists on GitHub:

```bash
git clone git@github.com:YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```
