# leapp-setup

This repo contains setup and installation scripts for [Leapp](https://panoramaed.atlassian.net/wiki/spaces/ENG/pages/2847113303/Leapp).
Leapp is used to manage AWS SSO credentials locally.

These scripts are made publicly available in order to allow CX members to
execute them without github accounts.

## Setup

This script sets up a Leapp integration and its dependencies.  This script
requires having the Leapp desktop application already installed ([download here](https://www.leapp.cloud/releases)).
This script performs the following:

- Installs the xcode Command Line Tools
- Ensures Homebrew is installed and installs Python and the AWS CLI
- Installs the AWS Session Manger Plugin, which is required when using AWS SSO
  in Leapp
- Installs the Leapp CLI
- Sets up an integration with Panorama's AWS SSO environment
- Renames the profiles for select AWS roles so that they match their role name.
  This allows for us to provide more consistent instructions for using
  Filezilla & using AWS SSO in local development environments.

This script expects an AWS SSO portal URL and a list of "|" separated roles to
have their profile name renamed.  The full command to run this script is
available on Panopedia on the the [Leapp Panopedia page](https://panoramaed.atlassian.net/wiki/spaces/ENG/pages/2847113303/Leapp)
for Engineering & CX to copy and paste and includes all necessary variables.
We only publish this on Panopedia to avoid publicly exposing these internal details.

## Rollback Setup

This script is only meant for testing and is used to revert the setup script in
order to run it again.  It does not require any variables as input.

## Create K8s Chained Session Setup

This script is meant to create the chained IAM Role sessions using the
`TerraformRole` in each of our K8s cluster accounts.  These sessions
enable the use of kubectl with the clusters.  Further instructions
and information can be found in the [Working With Clusters](https://panoramaed.atlassian.net/wiki/spaces/ENG/pages/2891415801/Working+with+Clusters)
KB in Panopedia.

