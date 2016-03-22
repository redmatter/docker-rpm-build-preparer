# docker-rpm-build-preparer
Docker image which prepares source code for building into an RPM from a local directory or VCS

## Preface
All steps in this README assume that the host on which the steps are being run is running Linux.  The steps provide example values which may be modified as necessary for your specific environment.

This image assumes that the spec file is available within the source path provided, and that it contains a single `Source` entry identifying a file of the format `${APP_NAME}-${VERSION}.tar.gz`, which is expected to contain the application source within a folder named `${APP_NAME}` (where `${APP_NAME}` and `${VERSION}` are substituted appropriately).

## Usage options
There are two ways to use this image - by pointing it at a local directory which already contains the source to be prepared, or by pointing it at a VCS from which the source can be obtained.
Building from a directory may be simpler if you have difficulty passing auth credentials to the Docker image, or if you want to build a working copy with local changes.  Building from a VCS is likely to be preferable if building a specific version for release.

## Common set up
Regardless of the origin of the source code, there needs to be a location where the sources and specs can be output.  The rest of the examples will assume that these directories have been created as follows:
```
$ mkdir -p /tmp/rpmbuild/SOURCES
$ mkdir -p /tmp/rpmbuild/SPECS
```

## Build from directory
This is the simplest way to prepare your source as it doesn't involve any VCS access; instead you need to ensure the source is already available locally.

To prepare the build, as a minimum you need to define the `APP_NAME` and `VERSION` environment variables, mount a volume containing the source to be prepared, as well as volumes which will take the output `.tar.gz` file and `.spec` file.

```
$ docker run --rm -e APP_NAME=MyApp -e VERSION=0.0.1 -v /host/path/to/source:/source -v /tmp/rpmbuild/SOURCES:/output/SOURCES -v /tmp/rpmbuild/SPECS:/output/SPECS redmatter/docker-rpm-build-preparer
```

If there are files which need to be excluded from the package, the `RSYNC_OPTIONS` environment variable can be used to add as many `--exclude` arguments as required.  For example, the following argument could be added to prevent `.git` and `.idea` directories being included in the build:
```
-e RSYNC_OPTIONS="--exclude *.git --exclude .idea"
```

The included `docker-compose.yml` makes it a little simpler to run the image, requiring shell or environment variables to be defined prior to the `docker-compose` call is made:
```
$ APP_NAME=MyApp VERSION=0.0.1 SOURCE_DIR=/host/path/to/source OUTPUT_DIR=/tmp/rpmbuild docker-compose up
```

If the same output directory is always used, this could be set once (either for the session or on login via `.bashrc`) to further simplify the command:

```
$ export OUTPUT_DIR=/tmp/rpmbuild 
$ APP_NAME=MyApp VERSION=0.0.1 SOURCE_DIR=/host/path/to/source docker-compose up
```

Once the container has finished running, based on the above example, the source will be available at `/tmp/rpmbuild/SOURCES/MyApp-0.0.1.tar.gz` and the spec file will be available at `/tmp/rpmbuild/SPECS/MyApp.spec`.

## Build from VCS
Rather than having the source supplied via a mounted directory, the source can instead be retrieved from a VCS.  Currently only Subversion is supported, but support for retrieval from a Git repository is planned soon.
The basic usage of this image for retrieving the source from Subversion is as follows:
```
$ docker run --rm -e APP_NAME=MyApp -e VERSION=0.0.1 -e SVN_URL=https://my.subversion.repo.com/path/to/source -v /tmp/rpmbuild/SOURCES:/output/SOURCES -v /tmp/rpmbuild/SPECS:/output/SPECS redmatter/docker-rpm-build-preparer
```

If no authentication is required, this should export the source from the specified Subversion repository and package it in the same way as it does for the directory variant above.

If authentication is required, it may be possible to pass this via the `--username` and `--password` command line arguments.  If so, these can be added to the `SVN_OPTIONS` environment variable, e.g.:
```
-e SVN_OPTIONS="--username my.user --password mypassword"
```

If svn+ssh is used to access the repository, and the host machine is set up with SSH agent forwarding, this can be passed through to the Docker image for use with the Subversion export with the following arguments:
```
-e SSH_AUTH_SOCK=${SSH_AUTH_SOCK} -v ${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}
```
However, it's likely some SSH configuration will need to be passed as well, since if the container is running for the first time, the host being connected to will not have been seen before so would be treated as an unidentified remote host.
The following configuration can be written to a temporary file and passed to the container via a volume to get around this issue:
```
Host my.subversion.repo.com
    User user.name
    StrictHostKeyChecking no
```

If this were stored in the same `/tmp/rpmbuild` location that was used for the `SOURCES` and `SPECS` directories, this can then be passed to the container with the following argument:
```
-v /tmp/rpmbuild/ssh_config:/etc/ssh/ssh_config 
```
It might alternatively be possible to pass your existing SSH config, if it already has the appropriate options set.

So the full command which can be used to prepare the source straight from Subversion via svn+ssh is:
```
$ docker run --rm -e APP_NAME=MyApp -e VERSION=0.0.1 -e SSH_AUTH_SOCK=${SSH_AUTH_SOCK} -e SVN_URL=svn+ssh://my.subversion.repo.com/path/to/source -v /tmp/rpmbuild/SOURCES:/output/SOURCES -v /tmp/rpmbuild/SPECS:/output/SPECS -v ${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK} -v /tmp/rpmbuild/ssh_config:/etc/ssh/ssh_config docker-rpm-build-preparer
```

This is obviously a pretty complex command.  To simplify things a little, the `docker-compose.svn_ssh.yml` configuration file can be used with docker-compose:

```
$ APP_NAME=MyApp VERSION=0.0.1 SVN_URL=svn+ssh://my.subversion.repo.com/path/to/source OUTPUT_DIR=/tmp/rpmbuild SSH_CONFIG_PATH=/tmp/rpmbuild/ssh_config docker-compose -f docker-compose.svn_ssh.yml up
```

## Environment variable reference
The following environment variables can be used to control the preparation of the build:
### Common
|Environment variable|Purpose|
|--------------------|-------|
|APP_NAME|Defines the application name|
|VERSION|Defines the version|
|SPEC_FILE|The image assumes that there will be a single `\*.spec` file in the root of the source directory.  If this is not the case, the path to the spec file relative to the root of the source directory can be specified with this environment variable|
|RSYNC_OPTIONS|Used to apply any additional rsync options for the copy of files to the directory to be tarred.  This is expected to be used for the `--exclude` option, to prevent certain files being included in the final RPM.|


### Subversion-only
|Environment variable|Purpose|
|--------------------|-------|
|SVN_URL|Subversion path for the source, to be passed to the `svn export` command|
|SVN_OPTIONS|Any options applicable to the `svn export` command may be applied here.  Expected examples include `-q`, `--username` and `--password`.|

## Volume reference
The following container paths should be mounted to for passing data between the host and container:

|Container path|Purpose|
|--------------|-------|
|/output/SOURCES|The generated .tar.gz output will be placed here|
|/output/SPECS|The spec file from the source will be placed here|
|/source|Source must be mounted here if a VCS is not being used to access the source|

## Complementary Docker images
This image was created in an effort to complement the existing [mmornati/docker-mock-rpmbuilder](https://github.com/mmornati/docker-mock-rpmbuilder) image, reducing the manual steps required to prepare the source code for use with the docker-mock-rpmbuilder image.

If this image is used to prepare source using the sample paths specified in this README (i.e. `/tmp/rpmbuild`), the steps in the mmornati/docker-mock-rpmbuilder README should work without any source-related modification.

## Docker Hub
This repository is automatically linked to Docker Hub: https://hub.docker.com/r/redmatter/rpm-build-preparer/.

Any new commit and contribution will automatically force a build on Docker Hub to have the latest version of the container ready to use.
