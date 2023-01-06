#!/usr/bin/env zsh

org=""
destdir=""
bare=""
mirror=""

GITHUB_API_ROOT="https://api.github.com"

function clone_repo() {
	repo="${1}"
	if [ -z "${repo}" ]; then
		echo "[-] clone_repo: Repo not specified." 1>&2
		return 1
	fi

	(
		set -ex
		cd ${destdir}
		git clone \
			${bare} \
			${mirror} \
			${repo}
	)

	return 0
}

function fetch_org() {
	local repos
	local repo

	curl "${GITHUB_API_ROOT}/orgs/${org}/repos" | jq -r '.[].clone_url' | while read -n repo; do
		clone_repo "${repo}" || return 1
	done

	return 0
}

while getopts "bd:m:o:" o; do
	case "${o}" in
		b)
			bare="--bare"
			;;
		d)
			destdir="${OPTARG}"
			;;
		m)
			mirror="--mirror"
			;;
		o)
			org="${OPTARG}"
			;;
		*)
			usage
			;;
	esac
done

if [ -z "${destdir}" ]; then
	echo "[-] destdir required." 1>&2
	if [ ! -d ${destdir} ]; then
		mkdir -p ${destdir} || exit 1
	fi
	exit 1
fi

if [ -z "${org}" ]; then
	echo "[-] org required." 1>&2
	exit 1
fi

fetch_org
exit ${?}
