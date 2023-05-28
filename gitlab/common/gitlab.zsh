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

function repo_exists() {
	local curlflags
	local username
	local restext
	local tmptext
	local name
	local site
	local res

	curlflags="-s"

	while getopts 'in:s:u:' o; do
		case "${o}" in
			i)
				curlflags="${curlflags} -k"
				;;
			n)
				name="${OPTARG}"
				;;
			s)
				site="${OPTARG}"
				;;
			u)
				username="${OPTARG}"
				;;
		esac
	done

	restext=$( \
		curl \
			${=curlflags} \
			-H "Authorization: Bearer ${GITLAB_PAT}" \
			--url "https://${site}/api/v4/projects/${username}/${name}"
)
	res=${?}
	if [ ${res} -gt 0 ]; then
		return 1
	fi

	tmptext=$(echo "${restext}" | jq -r '.id')
	if [ "${tmptext}" = "null" ]; then
		return 1
	fi

	return 0
}

function create_repo() {
	local description
	local curlflags
	local repo_path
	local restext
	local tmptxt
	local name
	local site
	local res
	local o

	curlflags="-s"

	while getopts 'id:n:r:s:' o; do
		case "${o}" in
			d)
				description="${OPTARG}"
				;;
			i)
				curlflags="${curlflags} -k"
				;;
			n)
				name="${OPTARG}"
				;;
			r)
				repo_path="${OPTARG}"
				;;
			s)
				site="${OPTARG}"
				;;
		esac
	done

	restext=$(cat <<EOF | curl \
		${=curlflags} \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer ${GITLAB_PAT}" \
		-d "@-" \
		--url "https://${site}/api/v4/projects/"
{
	"name": "${name}",
	"description": "${description}",
	"path": "${repo_path}"
}
EOF
)
	res=${?}
	if [ ${res} -gt 0 ]; then
		return ${res}
	fi

	tmptext=$(echo "${restext}" | jq -r '.error')
	if [ "${tmptext}" != "null" ]; then
		echo "[-] tmptext is: \"${tmptext}\""
		return 1
	fi

	return 0
}
