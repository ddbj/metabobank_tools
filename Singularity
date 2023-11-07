BootStrap: docker
From: ruby:3.2

%environment
    export PUBLIC_FILE_PATH=/lustre6/public/metabobank/study

%files
    . /opt/metabobank_tools

%labels
    Maintainer Bioinformation and DDBJ Center
    Version    v1.0

%post
    cd /opt/metabobank_tools
    bundle install
    bundle exec rake install
    bundle exec rake clobber
