##
## Normal greehost/maker:latest
##
FROM centos:7

COPY GreeHost-Maker-0.001.tar.gz /tmp/
COPY GreeHost-StaticServ-0.001.tar.gz /tmp/
COPY GreeHost-Config-0.001.tar.gz /tmp/

RUN yum install -y epel-release; \
     yum -y update; \
     yum -y upgrade; \
     yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo; \
     yum install -y perl-App-cpanminus perl-core perl-Moose docker-ce docker-compose; \
     yum groupinstall -y "Development Tools"; \
     cpanm /tmp/GreeHost-Config-0.001.tar.gz; \ 
     cpanm /tmp/GreeHost-StaticServ-0.001.tar.gz; \ 
     cpanm /tmp/GreeHost-Maker-0.001.tar.gz;


##
## For development, get a full one up and then call it
## greehost/basemaker:latest instead, we'll rebuild it
## with only the perl modules.
##

# FROM greehost/basemaker:latest

# COPY GreeHost-Maker-0.001.tar.gz /tmp/
# COPY GreeHost-StaticServ-0.001.tar.gz /tmp/
# COPY GreeHost-Config-0.001.tar.gz /tmp/

# RUN cpanm /tmp/GreeHost-Config-0.001.tar.gz; \ 
#     cpanm /tmp/GreeHost-StaticServ-0.001.tar.gz; \ 
#     cpanm /tmp/GreeHost-Maker-0.001.tar.gz;


