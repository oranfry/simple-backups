#!/bin/bash

gzip_flag=
gzip_ext=
save_space=
parent_dir=backup
backup_owner=root
tar_opts=
invalid=
verbose=

while getopts ":o:p:zsv" opt; do
  case ${opt} in
    o )
      backup_owner=$OPTARG
      ;;
    p )
      parent_dir=$OPTARG
      ;;
    z )
      gzip_flag=z
      gzip_ext=.gz
      ;;
    s )
      save_space=1
      tar_opts="--remove-files"
      ;;
    v )
      verbose=1
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      invalid=1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      invalid=1
      ;;
  esac
done
shift $((OPTIND -1))

host=$1

if [ "${host}" == "" ]; then
    echo no host given
    exit
fi

if [ -n "${invalid}" ]; then
  exit
fi

CLONE_HOME="/root/.clone/${host}"
TAR_HOME="$(eval echo ~$backup_owner)/${parent_dir}/${host}"
TAR_FILE="${TAR_HOME}/backup.tar${gzip_ext}"

test -n "$verbose" && echo -e "CLONE_HOME: $CLONE_HOME\nTAR_HOME: $TAR_HOME\nTAR_FILE: $TAR_FILE\n"

if [ -e "${TAR_HOME}/processing" ]; then
	echo "Cowardly refusing to run two backup processes at the same time" 1>&2
	exit 1
fi

test -n "$verbose" && echo -e "Locking...\n"
echo '1' > "${TAR_HOME}/processing"

mkdir -p "${CLONE_HOME}"
mkdir -p "${CLONE_HOME}.new"
mkdir -p "${TAR_HOME}"

chown $backup_owner:$backup_owner "${TAR_HOME}"

if [ -n "${save_space}" -a -s "${TAR_FILE}" ]; then
  test -n "$verbose" && echo -e "Extracting existing backup...\n"
  rm -rf "${CLONE_HOME}" && mkdir "${CLONE_HOME}" && cd "${CLONE_HOME}" && /bin/tar -x${gzip_flag}f "${TAR_FILE}"
fi

set -o noglob
includesrel=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$(echo $f | sed 's,^/,,')'"; done)
cmd="/usr/bin/rsync -a --remove-source-files $includesrel '--exclude=*' '${CLONE_HOME}/' '${CLONE_HOME}.new'"
set +o noglob

test -n "$verbose" && echo -e "Pruning cache based on file patterns...\n$cmd\n"
eval $cmd

rm -rf "${CLONE_HOME}"
mv "${CLONE_HOME}.new" "${CLONE_HOME}"

set -o noglob
includes=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$f'"; done)
cmd="/usr/bin/rsync --rsync-path='sudo rsync' -az --delete $includes '--exclude=*' ${host}:/ '${CLONE_HOME}'"
set +o noglob

test -n "$verbose" && echo -e "Rsync'ing with server...\n$cmd\n"
eval $cmd

test -n "$verbose" && echo -e "Removing existing backup...\n"
rm -f "${TAR_FILE}" # frees up space for the new archive

TAR_FILE_TMP="/tmp/${host}.tar${gzip_ext}"
test -n "$verbose" && echo -e "Creating new backup...\n"
(cd "${CLONE_HOME}" && /bin/tar $tar_opts -c${gzip_flag}f "${TAR_FILE_TMP}" * && chown $backup_owner:$backup_owner "${TAR_FILE_TMP}" && mv "${TAR_FILE_TMP}" "${TAR_FILE}")

if [ -n "${save_space}" -a -s "${TAR_FILE}" ]; then
  test -n "$verbose" && echo -e "Clearing cache...\n"
  rm -rf "${CLONE_HOME}"
fi

test -n "$verbose" && echo -e "Unlocking...\n"
rm "${TAR_HOME}/processing"
