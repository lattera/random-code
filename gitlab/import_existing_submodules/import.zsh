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

MYSELF="${0}"
TOPDIR=$(realpath $(dirname "${MYSELF}"))

GITLAB_PAT="glpat-py5xi2fB65fkpURm4Sss"

. ${TOPDIR}/../common/gitlab.zsh

repo=""
apikey=""
remote=""
insecure=""
username=""
remote_name=""
repo_prefix=""

while getopts 'ia:n:p:R:r:u:' o; do
	case "${o}" in
		a)
			apikey="${OPTARG}"
			;;
		i)
			insecure="-i"
			;;
		n)
			remote_name="${OPTARG}"
			;;
		p)
			repo_prefix="${OPTARG}"
			;;
		r)
			repo="${OPTARG}"
			;;
		R)
			remote="${OPTARG}"
			;;
		u)
			username="${OPTARG}"
			;;
	esac
done

if [ -z "${apikey}" ]; then
	echo "[-] Specify API key with -a" >&2
	exit 1
fi

if [ -z "${repo}" ]; then
	echo "[-] Specify path to repo with -r" >&2
	exit 1
fi

if [ -z "${remote}" ]; then
	echo "[-] Specify remote gitlab site (eg, gitlab.example.com) with -R" >&2
	exit 1
fi

if [ -z "${remote_name}" ]; then
	echo "[-] Specify to-be-added remote name with -n" >&2
	exit 1
fi

if [ -z "${username}" ]; then
	echo "[-] Specify username with -u" >&2
	exit 1
fi

if [ ! -d "${repo}" ]; then
	echo "[-] Repo at path ${repo} does not exist" >&2
	exit 1
fi

GITLAB_PAT="${apikey}"

cd ${repo}
for sm_path in $(git submodule status | awk '{print $2;}'); do
	(
		sm_reponame="${repo_prefix}$(echo "${sm_path}" | sed 's,/,-,g')"

		cd ${sm_path}
		echo "[+] Entering $(pwd)"

		repo_exists \
			${insecure} \
			-s ${remote} \
			-u ${username} \
			-n ${sm_reponame}
		res=${?}
		if [ ${res} -eq 0 ]; then
			echo "[-] ==> Repo ${username}/${sm_reponame} exists" >&2
			exit 1
		fi

		echo "[*] ==> Creating ${username}/${sm_reponame}" >&2

		if git remote | grep -q ${remote_name}; then
			echo "[-] ==> Remote ${remote_name} already exists for repo $(pwd)" >&2
			exit 1
		fi

		create_repo \
			${insecure} \
			-n ${sm_reponame} \
			-s ${remote}

		git remote add ${remote_name} git@${remote}:${username}/${sm_reponame}.git
		res=${?}
		if [ ${res} -gt 0 ]; then
			echo "[-] ==> Could not add remote ${remote_name} to $(pwd)" >&2
			exit 1
		fi

		git push ${remote_name}
		res=${?}
		if [ ${res} -gt 0 ]; then
			echo "[-] ==> Could not push to remote ${remote_name}" >&2
			exit 1
		fi

		exit 0
	)
	res=${?}
	if [ ${res} -gt 0 ]; then
		echo "[-] => Breaking out of loop" >&2
		exit ${res}
	fi
done
