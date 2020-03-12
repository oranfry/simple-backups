#!/bin/bash
gzip_flag=
gzip_ext=
save_space=
parent_dir=backup
backup_owner=root
invalid=

while getopts ":o:p:zs" opt; do
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

if [ -e "${TAR_HOME}/processing" ]; then
	echo "Cowardly refusing to run two backup processes at the same time" 1>&2
	exit 1
fi

echo '1' > "${TAR_HOME}/processing"

mkdir -p "${CLONE_HOME}"
mkdir -p "${CLONE_HOME}.new"
mkdir -p "${TAR_HOME}"

chown $backup_owner:$backup_owner "${TAR_HOME}"

if [ -n "${save_space}" -a -s "${TAR_HOME}/backup.tar${gzip_ext}" ]; then
  rm -rf "${CLONE_HOME}" && mkdir "${CLONE_HOME}" && cd "${CLONE_HOME}" && /bin/tar -xf${gzip_flag} "${TAR_HOME}/backup.tar${gzip_ext}"
fi

includesrel=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$(echo $f | sed 's,^/,,')'"; done)
cmd="/usr/bin/rsync -a --delete $includesrel '--exclude=*' '${CLONE_HOME}/' '${CLONE_HOME}.new'"
eval $cmd

rm -rf "${CLONE_HOME}"
mv "${CLONE_HOME}.new" "${CLONE_HOME}"

includes=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$f'"; done)
cmd="/usr/bin/rsync --rsync-path='sudo rsync' -az --delete $includes '--exclude=*' ${host}:/ '${CLONE_HOME}'"
eval $cmd

rm -f "${TAR_HOME}/backup.tar${gzip_ext}" # frees up space for the new archive

(cd "${CLONE_HOME}" && /bin/tar -cf${gzip_flag} "/tmp/${host}.tar" * && chown $backup_owner:$backup_owner "/tmp/${host}.tar" && mv "/tmp/${host}.tar" "${TAR_HOME}/backup.tar${gzip_ext}")

if [ -n "${save_space}" -a -s "${TAR_HOME}/backup.tar${gzip_ext}" ]; then
  rm -rf "${CLONE_HOME}"
fi

rm "${TAR_HOME}/processing"
