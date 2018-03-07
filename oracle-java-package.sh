#!/usr/bin/env bash
## Provides useful commands for working with Oracle Java packages.
## By Stephen D. Rogers <inbox.c7r@steve-rogers.com>, 2018-03.
##
## Typical uses:
##
##     egrep -v -h '^\s*#' packages.[0-9]*.txt | ./oracle-java-package.sh egrep -v > packages.filtered.standard.txt
##     egrep -v -h '^\s*#' packages.[0-9]*.txt | ./oracle-java-package.sh egrep    > packages.filtered.oracle-java.txt
##     
##     ./oracle-java-package.sh split-package-name oracle-java-8u162-jdk
##     ./oracle-java-package.sh split-package-name oracle-java-8u162-jdk-x86_64
##     
##     ./oracle-java-package.sh install oracle-java-8u162-jdk
##     
##     ./oracle-java-package.sh remove  oracle-java-8u162-jdk
##     
##     #^-- all of the above, with option "--dry-run" before the verb
##
## Example package names:
## 
##     oracle-java-6-jre
##     
##     oracle-java-8u051-jdk
##     oracle-java-8u162-jdk
##     
##     oracle-java-6-jre-i386
##     oracle-java-6-jre-i586
##     
##     oracle-java-6-jre-x32
##     oracle-java-6-jre-amd32
##     oracle-java-6-jre-x86_32
##     
##     oracle-java-8u162-jdk-x64
##     oracle-java-8u162-jdk-amd64
##     oracle-java-8u162-jdk-x86_64
##
## Environment variables:
##
##     JAVA_ARTIFACTS_ROOT_DPN
##         The directory holding pre-downloaded tarballs for Oracle Java packages.
##         
##         Default value: "artifacts.d" if it exists, else "/var/local/downloads".
##     
##     JAVA_INSTALLATION_ROOT_PARENT_DPN
##         The parent directory of Java installations on your system.
##         
##         Default value: "test.installation.d" if it exists, else "/usr/lib/jvm".
## 

set -e

umask 0002

this_script_fbn="$(basename "$0")"

function xx() {
	echo 1>&2 "+" "$@"
	"$@"
}

function qq() {
	printf "%q" "$@"
}

## 

if [ -z "${JAVA_ARTIFACTS_ROOT_DPN}" ] ; then

	JAVA_ARTIFACTS_ROOT_DPN=artifacts.d

	[ -d "${JAVA_ARTIFACTS_ROOT_DPN:?}" ] ||
	JAVA_ARTIFACTS_ROOT_DPN=/var/local/downloads
fi
     
##

if [ -z "${JAVA_INSTALLATION_ROOT_PARENT_DPN}" ] ; then

	JAVA_INSTALLATION_ROOT_PARENT_DPN=test.installations.d

	[ -d "${JAVA_INSTALLATION_ROOT_PARENT_DPN:?}" ] ||
	JAVA_INSTALLATION_ROOT_PARENT_DPN=/usr/lib/jvm
fi

##

command_rm="sudo rm"

command_tar="sudo tar"

command_egrep="sudo egrep"

command_mkdir="sudo mkdir"

dry_run_p=
case "${1}" in
--dry-run) dry_run_p=t ; shift ;;
esac

if [ -n "${dry_run_p}" ] ; then

	command_rm="echo ${command_rm}"

	command_tar="echo ${command_tar}"

	command_egrep="echo ${command_egrep}"

	command_mkdir="echo ${command_mkdir}"
fi

##

function tarball_fpn_from_package_name() { # package_name

	local package_name="${1:?missing argument: package_name}"

	local tarball_glob_pattern="$(tarball_glob_pattern_from_package_name "${package_name:?}")"

        (eval "LC_ALL=C ls -d $(qq "${JAVA_ARTIFACTS_ROOT_DPN:?}")/${tarball_glob_pattern}" || :) |
	if ! read -r result || [ -z "${result}" ] ; then 

		if [ "${java_docker_image_fails_on_missing_oracle_java_package}" = "true" ] ; then

			echo 1>&2 "Package not available: ${package_name:?} (tarball ${tarball_glob_pattern##*/}); aborting."
		        false
		else
			echo 1>&2 "Package not available: ${package_name:?} (tarball ${tarball_glob_pattern##*/}); skipping."
		        true
		fi
	else
		echo "${result}"
	fi
}

function tarball_glob_pattern_from_package_name() { # package_name

	local package_name="${1:?missing argument: package_name}"

        local product version component arch

        split_package_name "${package_name:?}" |
	while read product version component arch ; do

		arch="$(canonical_arch_name "${arch}")"

		local arch_for_tarball="${arch:?}"

		case "${arch_for_tarball}" in
		x86_32)
			arch_for_tarball="i586"
			;;
		x86_64)
			arch_for_tarball="x64"
			;;
		esac

		local version_stem="${version%u[0-9]*}"
		local version_update="${version#${version_stem}}"

                if [ -z "${version_update}" ] ; then

			echo "${component}-${version_stem}u[0-9]*-linux-${arch_for_tarball}.tar.gz";
		else
			echo "${component}-${version_stem}${version_update}-linux-${arch_for_tarball}.tar.gz";
		fi
	done
}

function installation_dbn_from_tarball_fpn() { # tarball_fpn package_name

	local tarball_fpn="${1:?missing argument: tarball_fpn}"

	local package_name="${2:?missing argument: package_name}"

	local result="$(tar tzf "${tarball_fpn:?}" | head -1 | perl -lne 'print if s{/.*$}{}')"

        local arch="$(canonical_arch_name "$(split_package_name "${package_name:?}" | cut -f4)")"

	if [ "${arch:?}" != "$(canonical_arch_name "$(uname -m)")" ] ; then

		result="${result:?}-${arch:?}"
	fi

	echo "${result:?}"
}

function split_package_name() { # package_name

	local package_name="${1:?missing argument: package_name}"

	echo "${package_name:?}" | perl -lne '

		next unless m{^(\w[-\w]*?)-(\d[.\d]*[^-]*)-(\w+)(?:-([^-]+))?$};
		#              1           2               3        4

		($product, $version, $component, $arch) = ($1, $2, $3, $4);

		print join("\t", $product, $version, $component, $arch);
	';
}

function canonical_arch_name() { # arch_name

        local result="${1:-$(uname -m)}"

        case "${result:?}" in
	x86_32|amd32|x32|i[0-7]86)
		result=x86_32
		;;
	x86_64|amd64|x64)
		result=x86_64
		;;
	esac

	echo "${result:?}"
}

##

function perform_command_egrep() { # [egrep_option ...]

	local oracle_package_re='^\s*oracle-java-[0-9]+\w*-(jre|jdk)(-i[0-7]86|-x(32|64)|-amd(32|64)|-x86_(32|64))?\s*$'

        local command_egrep_and_options="${command_egrep}"

        while [ $# -gt 0 ] ; do
        case "$1" in
	-*)
		command_egrep_and_options+=" $(qq "${1}")"
		shift
		;;
	*)
		break
		;;
	esac
	done

	eval "${command_egrep_and_options} $(qq "${oracle_package_re}") "'"$@"'
}

function perform_command_install() { # [package_name ...]

	local p1

	for p1 in "$@" ; do

		perform_command_install_1 "${p1:?}"
	done
}

function perform_command_install_1() { # package_name

	local package_name="${1:?missing argument: package_name}"

	local tarball_fpn="$(tarball_fpn_from_package_name "${package_name:?}")"

	[ -n "${tarball_fpn}" ] || return

	##

	local installation_dbn="$(installation_dbn_from_tarball_fpn "${tarball_fpn:?}" "${package_name:?}")"

	local d1

	for d1 in "${JAVA_INSTALLATION_ROOT_PARENT_DPN:?}/${installation_dbn:?}" ; do

		! [ -d "${d1}" ] || continue

		${command_mkdir} -p --mode u+rwX,g+rwXs,o+rX "${d1}"

		${command_tar} xzf "${tarball_fpn:?}" --strip-components 1 -C "${d1}"
	done

	[ -d "${d1}" ]
}

function perform_command_remove() { # [package_name ...]

	local p1

	for p1 in "$@" ; do

		perform_command_remove_1 "${p1:?}"
	done
}

function perform_command_remove_1() { # package_name

	local package_name="${1:?missing argument: package_name}"

	local tarball_fpn="$(tarball_fpn_from_package_name "${package_name:?}")"

	[ -n "${tarball_fpn}" || return

	##

	local installation_dbn="$(installation_dbn_from_tarball_fpn "${tarball_fpn:?}" "${package_name:?}")"

	local d1

	for d1 in "${JAVA_INSTALLATION_ROOT_PARENT_DPN:?}/${installation_dbn:?}" ; do

		[ -e "${d1}" ] || continue

		${command_rm} -rf "${d1}"
	done

	! [ -e "${d1}" ]
}

function perform_command_split-package-name() { # [package_name ...]

	local p1

	for p1 in "$@" ; do

		perform_command_split-package-name_1 "${p1:?}"
	done
}

function perform_command_split-package-name_1() { # package_name ...

	local package_name="${1:?missing argument: package_name}"

        split_package_name "${package_name:?}"
}

##

function main() {

	local command="${1:?missing argument: command}" ; shift

	case "${command}" in
	egrep|install|remove|split-package-name)
		(perform_command_${command} "$@")
		;;
	*)
		echo 1>&2 "Unrecognized ${this_script_fbn%.*sh} command: ${command}; aborting."
		false
		;;
	esac
}

##

main "$@"

