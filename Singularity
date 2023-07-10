BootStrap: docker
From: ubuntu:20.04

%setup


%files
    # copying files from the host system to the container.
    mb-livelist.rb /usr/local/bin
    mb-filelist.rb /usr/local/bin
    mb-validate.rb /usr/local/bin
    mb-update.rb /usr/local/bin
    mb-public.rb /usr/local/bin    
    lib/*rb /usr/local/bin/lib/
    conf/*json /usr/local/bin/conf/

%environment
    export RUBYOPT='-EUTF-8'


%labels
    Maintainer Bioinformation and DDBJ Center
    Version    v1.0


%runscript



%post
    echo "Hello from inside the container"
    sed -i.bak -e "s%http://archive.ubuntu.com/ubuntu/%http://ftp.jaist.ac.jp/pub/Linux/ubuntu/%g" /etc/apt/sources.list
    sed -i.bak -e "s%http://security.ubuntu.com/ubuntu/%http://ftp.jaist.ac.jp/pub/Linux/ubuntu/%g" /etc/apt/sources.list
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install ruby-full=1:2.7+1
    apt-get -y install build-essential
    gem install csv -v "3.2.3"
    gem install fileutils -v "1.4.1"
    gem install optparse -v "0.2.0"
    gem install json -v "2.6.2"
    gem install pp -v "0.1.0"
    gem install date -v "3.0.0"
    chmod +x /usr/local/bin/mb-livelist.rb
    chmod +x /usr/local/bin/mb-filelist.rb
    chmod +x /usr/local/bin/mb-validate.rb
    chmod +x /usr/local/bin/mb-update.rb
    chmod +x /usr/local/bin/mb-public.rb
    chmod +x /usr/local/bin/lib/*.rb
