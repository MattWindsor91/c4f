#!/bin/sh
#
# Automatically generates an act.conf for the local machine and puts it on stdout.

# Prints an error string to stderr.
#
# Arguments:
#   1: the error to print.
error()
{
	echo "$0: $1" >&2
}

# Prints a 'this item not found' error.
#
# Arguments:
#   1: the item that hsan't been found.
not_found()
{
	error "'$1' not found, not adding to act.conf."
}

# Emits the appropriate 'arch' ID for a GCC-like compiler running on this
# machine.
#
# Uses global variable `arch`.
gcc_like_arch()
{
	case "${arch}" in
	x86 )
		echo "x86.att"
	;;
	* )
		echo "unknown"
	;;
	esac
}

# Emits a compiler stanza for a particular O-level of a GCC-like compiler.
# Assumes that the compiler has already been checked.
#
# $1: the compiler command.
# $2: the optimisation level, as a number (eg -Ofast isn't supported).
#
# Uses global variable `is_64`.
gcc_like_optimisation_level()
{
	_compiler="${1}"
	_optlevel="${2}"

	printf '\n    compiler %s.%s.O%d {\n' "${_compiler}" "${arch}" "${_optlevel}"
	printf '        style gcc \n'
	printf '        arch  %s \n' "$(gcc_like_arch)"
	printf '        cmd   "%s" \n' "${_compiler}"

	printf "        argv  "
	[ -z "${is_64}" ] || printf '"-m32" '
	[ "${_optlevel}" -eq "0" ] || printf '"-O%d" ' "${_optlevel}"
	echo '"-DNO_PTHREADS"'

	echo "    }"
}

# Tries to emit a compiler stanza for a GCC-like compiler.
#
# Arguments:
#    1: the compiler command.
gcc_like()
{
	_compiler="${1}"
	"${_compiler}" --version >/dev/null 2>&1 || {
		not_found "${_compiler}" && return
	}

	for _optlevel in "0" "3";
	do
		gcc_like_optimisation_level "${_compiler}" "${_optlevel}"
	done
}

# Tries to emit a compiler stanza for a generic herdtools sim.
#
# Arguments:
#   1: the sim command
#   2: the style ("herd" or "litmus")
herdtools_like()
{
	_sim="${1}"
	_style="${2}"

	"${_sim}" -version >/dev/null 2>&1 || {
		not_found "${_sim}" && return
	}

	printf '\n    sim %s {\n' "${_sim}"

	printf '        style %s \n' "${_style}"
	printf '        cmd   "%s" \n' "${_sim}"

	echo "    }"
}

# Finds and outputs compiler stanzas for the local machine.
compilers()
{
	gcc_like "gcc"
	gcc_like "clang"
}

# Finds and outputs simulator stanzas for the local machine.
simulators()
{
	herdtools_like "herd" "herd"
	herdtools_like "herd7" "herd"
	herdtools_like "litmus" "litmus"
	herdtools_like "litmus7" "litmus"
}

# Works out the correct name for the machine, and stores it in `host`.
#
# Globals:
#   - host (write)
setup_host()
{
	host="$(hostname -s)"
	if [ -z "${host}" ]; then
		host="localhost"
	fi
}

# Populates various global variables according to the machine architecture, and
# terminates the script if the architecture isn't supported by ACT.
#
# Globals:
#   - raw_arch (write)
#   - arch (write)
#   - is_64 (write)
setup_arch()
{
	raw_arch="$(uname -m)"
	case "${raw_arch}" in
		x86_64 )
			arch="x86"
			is_64=1
			;;
		* )
			error "Unsupported architecture: ${raw_arch}"
			exit 1
			;;
	esac
}

# Main entry point.
#
# Globals:
#   - host (read/write)
#   - raw_arch (read/write)
main()
{
	setup_host
	setup_arch

	echo "# Auto-generated act.conf for '${host}' (architecture ${raw_arch})."
	echo "# Generated on $(date)."
	echo
	echo "machine ${host} {"
	echo "    via local"

	compilers
	simulators

	echo "}"
	echo
	echo "default {"
	echo "    try machine ${host}"
	echo "}"
}

main
