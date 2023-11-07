#! /bin/bash

# help
function usage {
  cat <<EOM
    Usage: $(basename "$0") [OPTION]...
      -h                          Display help
      -i IDF file                 IDF file (MTBKS1.idf.txt)
      -r release_type             ini for initial release or re for re-distribution
      -d initial_release_date     initial release date (yyyy-mm-dd)
      -u last_update_date         last update date (yyyy-mm-dd)
EOM

  exit 2

}

# 引数別の処理
while getopts ":i:r:d:u:h" optKey; do
  case "$optKey" in
    i)
      I=" -i ${OPTARG}"
      ;;
    r)
      R=" -r ${OPTARG}"
      ;;
    d)
      D=" -d ${OPTARG}"
      ;;
    u)
      U=" -u ${OPTARG}"
      ;;
    '-h'|* )
      usage
      ;;
esac
done

# 実行
echo "singularity exec -B /lustre9/open/shared_data/metabobank/study:/lustre9/open/shared_data/metabobank/study /home/mbadmin/mb-tools.simg mb-public${I}${R}${D}${U}"
singularity exec -B /lustre9/open/shared_data/metabobank/study:/lustre9/open/shared_data/metabobank/study /home/mbadmin/mb-tools.simg mb-public${I}${R}${D}${U}
