# Recovery Environment

This project implements a debian package that allows for the easy creation, installation, and updating of a network-accessible recovery environment.

The overall structure of the project is simple, though not entirely obvious. The stage1 script is the primary build script; it constructs the recovery environment package, which can then be installed on any system with a compatible architecture. The debian/postinst script functions as stage 2; it runs when the package is installed on the target system, and copied system-specific information into the recovery environment. Finally, there is the recovery_sync script. This script is intended to be run by automation on the target system whenever a significant configuratioin change occurs, and will copy this config data into the recovery environment so that it remains accessible over the network.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

* debhelper
* dropbear

Requires that systemd-networkd be in use for networking config, and requires a ZFS boot/root pool. Also requires that the envblock feature be present in the system's version of GRUB, and that the ZFS version be recent enough to use it.


## Contributing

Please read [CONTRIBUTING.md](https://github.com/delphix/.github/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* **Paul Dagnelie** - *Initial work* - [Delphix](https://github.com/delphix)
* [mkinitcpio](https://github.com/archlinux/mkinitcpio) - *Init System*

See also the list of [contributors](https://github.com/your/project/contributors) who participated in this project.

## License

This project is licensed under the Apache License - see the [LICENSE.md](LICENSE.md) file for details
Portions are licensed under GPLv2

## Acknowledgments

* mkinitcpio for creating the init automation that this was initially developed from.
