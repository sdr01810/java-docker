Provides OpenJDK and/or Oracle Java, packaged as a Docker image.

Installs JRE(s) and/or JDK(s) from either vendor, in any combination.

OpenJDK versions are downloaded and installed automatically from the
operating system's standard package repository during Docker image
construction.  Oracle Java versions are downloaded manually from the
official Oracle web site beforehand, then automatically copied into place
and installed during Docker image construction.  They are not downloaded
automatically due to Oracle's licensing restrictions.

Supported platforms:
- Debian and its derivatives: Ubuntu

