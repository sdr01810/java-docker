#!/usr/bin/env bash
## Entry point for the Java container.
##

set -e

umask 0002

xx() {
	echo "+" "$@"
	"$@"
}

xx_eval() {
	eval "xx" "$@"
}

printenv_sorted() {
	xx printenv | xx env LC_ALL=C sort
}

##

if command -v git >/dev/null ; then
	git config --global user.email root@localhost
	git config --global user.name "Administrator"
fi

##

echo
echo "Environment variables:"
xx :
printenv_sorted

##

xx :
xx cd "${java_docker_image_setup_root}"

if [ $# -gt 0 ] ; then
	echo
	echo "Running command..."
	xx :
	xx exec "$@"
else
if [ -t 0 ] ; then
	echo
	echo "Launching shell..."
	xx :
	xx exec bash -l
fi;fi

##

