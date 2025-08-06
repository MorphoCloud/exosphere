# Exosphere: the User-Friendliest Interface for Non-proprietary Cloud Infrastructure

- Empowers researchers and other non-IT professionals to deploy code and run services on [OpenStack](https://www.openstack.org)-based cloud systems, without advanced virtualization or networking knowledge
- Fills the gap between OpenStack interfaces built for system administrators (like [Horizon](https://docs.openstack.org/horizon/latest/)), and intuitive-but-proprietary services like [DigitalOcean](https://www.digitalocean.com/) and [Amazon Lightsail](https://aws.amazon.com/lightsail)
- Enables cloud operators to deliver a friendly, powerful interface to their community with customized branding, nomenclature, and single sign-on integration

## About This Repository

> [!IMPORTANT]
>
> This is **not** the official [exosphere](https://github.com/exosphere-project/exosphere) repository.

This fork is maintained as part of the **MorphoCloud** project and is used as a staging area for:

* Project-specific changes
* Customizations to Ansible playbooks
* Integration with the [MorphoCloudWorkflow](https://github.com/MorphoCloud/MorphoCloudWorkflow)

## Branch Naming Convention

Branches in this repository follow the pattern:

```
morpho-cloud-portal-YYYY.MM.DD-SHA{N}
```

Where:

* `morpho-cloud-portal` indicates changes specific to the MorphoCloud project.
* `YYYY.MM.DD` is the date of the last official commit this branch is based on.
* `SHA{N}` are the first `N` characters of that commit's hash.


## How to Identify the Branch Used by MorphoCloud

You can determine the Exosphere branch used by the MorphoCloud workflow in two ways:

### 1. Inspect the `exosphere_sha` Variable

Check the comment next to the `exosphere_sha` variable in [`cloud-config`](https://github.com/MorphoCloud/MorphoCloudWorkflow/blob/main/cloud-config#L83).


### 2. Run the `display-exosphere-version` Nox Session

```bash
PROJECTS_DIR=/home/jcfr/Projects
cd $PROJECTS_DIR

# Clone the workflow repository
git clone git@github.com:MorphoCloud/MorphoCloudWorkflow.git
cd MorphoCloudWorkflow

# Display the version of Exosphere used
pipx run nox -s display-exosphere-version
```

> [!TIP]
>
> Need to install `pipx`? See the [Maintenance Guide](https://github.com/MorphoCloud/MorphoCloudWorkflow/blob/main/MAINTENANCE.md).

## How to Update the Version of Exosphere Used in MorphoCloud

Refer to the *Vendoring `exosphere`* section in the MorphoCloudWorkflow [Maintenance Guide](https://github.com/MorphoCloud/MorphoCloudWorkflow/blob/main/MAINTENANCE.md).

