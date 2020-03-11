#!/bin/bash
gzip_flag=
gzip_ext=
parent_dir=backup
backup_owner=root

while getopts ":o:p:z" opt; do
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
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

host=$1

if [ "${host}" == "" ]; then
    echo no host given
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

includesrel=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$(echo $f | sed 's,^/,,')'"; done)
cmd="/usr/bin/rsync -a --delete $includesrel '--exclude=*' '${CLONE_HOME}/' '${CLONE_HOME}.new'"
eval $cmd

rm -rf "${CLONE_HOME}"
mv "${CLONE_HOME}.new" "${CLONE_HOME}"

includes=$(cat "${TAR_HOME}/files.list" | while read f; do while [ "$f" != "/" ]; do echo "$f"; f="$(dirname "$f")"; done; done | sort | uniq | while read f; do echo " '--include=$f'"; done)
cmd="/usr/bin/rsync --rsync-path='sudo rsync' -az --delete $includes '--exclude=*' ${host}:/ '${CLONE_HOME}'"
eval $cmd

(cd "${CLONE_HOME}" && /bin/tar -cf${gzip_flag} "/tmp/${host}.tar" * && chown $backup_owner:$backup_owner "/tmp/${host}.tar" && mv "/tmp/${host}.tar" "${TAR_HOME}/backup.tar${gzip_ext}")

rm "${TAR_HOME}/processing"
