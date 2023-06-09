#!/usr/bin/env zsh

#-
# Copyright (c) 2022 Shawn Webb <shawn.webb@hardenedbsd.org>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Dependencies:
#
# 1. ZSH
# 2. git
# 3. jq

#set -ex

myself="${0}"

bare=""
clean_destdir=0
destdir=""
github_pat=""
mirror=""
org=""
repo_types="all"

GITHUB_API_ROOT="https://api.github.com"

function usage() {
	echo "USAGE: ${myself} [-b] [-c] [-m] [-p PAT ] [-t] -d DESTDIR -o ORGANIZATION"
	echo "Arguments:"
	echo "\t-b:\tClone as a bare repo"
	echo "\t-c:\tClean the destination directory"
	echo "\t-d:\tDestination directory"
	echo "\t-m:\tPass --mirror to git clone"
	echo "\t-o:\tOrganization"
	echo "\t-p:\tGitHub Personal Access Token (PAT)"
	echo "\t-t:\tSpecify which repo types to fetch"
	exit 0
}

function clone_repo() {
	repo="${1}"
	if [ -z "${repo}" ]; then
		echo "[-] clone_repo: Repo not specified." 1>&2
		return 1
	fi

	(
		set -ex

		cd ${destdir}
		echo "[*] Cloning ${repo}"
		git clone \
			${bare} \
			${mirror} \
			${repo}
	)

	return ${?}
}

function get_total_number_repos() {
	local nrepos

	nrepos=$(curl -H "@${destdir}/headers.txt" "${GITHUB_API_ROOT}/orgs/${org}" | jq -r '.public_repos + .total_private_repos')

	echo ${nrepos}

	return 0
}

function prepare_headers() {
	truncate -s 0 ${destdir}/headers.txt

	if [ ! -z "${github_pat}" ]; then
		echo "Authorization: Bearer ${github_pat}" > ${destdir}/headers.txt
	fi

	return 0
}

function fetch_org() {
	local argstring
	local pagerpos
	local nrepos
	local repo

	pagerpos=0
	nrepos=$(get_total_number_repos)

	for (( pagerpos = 0; ((${pagerpos} * 100)) < ${nrepos}; pagerpos++)); do
		argstring="?per_page=100&"
		argstring="${argstring}type=${repo_types}&"
		argstring="${argstring}page=$((${pagerpos} + 1))&"

		curl -H "@${destdir}/headers.txt" "${GITHUB_API_ROOT}/orgs/${org}/repos${argstring}" | jq -r '.[].clone_url' | while read -n repo; do
			clone_repo "${repo}" || return 1
		done
	done

	return 0
}

while getopts "bcd:mo:p:t:" o; do
	case "${o}" in
		b)
			bare="--bare"
			;;
		c)
			clean_destdir=1
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
		p)
			github_pat="${OPTARG}"
			;;
		t)
			repo_types="${OPTARG}"
			;;
		*)
			usage
			;;
	esac
done

if [ -z "${destdir}" ]; then
	echo "[-] destdir required." 1>&2
	exit 1
fi

if [ ${clean_destdir} -gt 0 ]; then
	rm -rf ${destdir}
fi

if [ ! -d ${destdir} ]; then
	mkdir -p ${destdir} || exit 1
fi

if [ -z "${org}" ]; then
	echo "[-] org required." 1>&2
	exit 1
fi

prepare_headers

echo "[*] Total number of repos: $(get_total_number_repos)"

fetch_org
exit ${?}
