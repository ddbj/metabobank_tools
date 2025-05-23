# /bin/sh

# generate mb study livelist and filelist daily
cd /home/mbadmin
/opt/pkg/singularity-ce/4.2.1/bin/singularity exec /home/mbadmin/mb-tools.simg mb-livelist
/opt/pkg/singularity-ce/4.2.1/bin/singularity exec -B /lustre9/open/shared_data/metabobank/study:/lustre9/open/shared_data/metabobank/study /home/mbadmin/mb-tools.simg mb-filelist

