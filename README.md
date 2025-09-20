# Windows Development Maintenance Toolkit

A comprehensive PowerShell-based maintenance toolkit for Windows development environments.

## Features

- **System Health Monitoring**: Check system health and performance
- **Profile Cleanup**: Clean up user profiles and temporary files  
- **GitHub Management**: Tools for repository cleanup and automation
- **Scheduled Tasks**: Automated maintenance with detailed logging
- **Secure Storage**: Encrypted credential management via DPAPI
- **Notification System**: Email alerts for maintenance results

## Components

- **Scripts**: Individual maintenance utilities
- **Modules**: Reusable PowerShell modules
- **Tests**: Comprehensive test suite
- **Configuration**: JSON-based configuration management

## Usage

Run  for interactive maintenance or use individual scripts as needed.

## Requirements

- PowerShell 7+
- Windows 10/11
- DPAPI for secure credential storage
## Shared Script Dependencies

This toolkit depends on the centralized helpers stored in ~/Documents/dev/shared for bootstrap and validation tasks. Ensure that repository is kept in sync so optional workflows (like the consolidated Nix helpers) remain available.

