# Setup Guide

## 1. Install Micro Text Editor

Open PowerShell and run the following command to install the micro text editor:

```powershell
winget install zyedidia.micro

```

## 2. Locate Your PowerShell Profile Folder

Run this command in PowerShell to find your profile folder location:

```powershell
Split-Path $PROFILE -Parent

```

## 3. Add the Profile Script

Move or copy the profile script into the folder found in the previous step.

## 4. Set Up the Environment File

Create a new file named `.env` directly inside that same profile folder. Open it and add your API keys in this format:

```env
TAVILY_API_KEY=your_tavily_key_here
GROQ_API_KEY=your_groq_key_here

```

## 5. Reload PowerShell

Run this command to load your new profile configuration:

```powershell
. $PROFILE

```
