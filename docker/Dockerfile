FROM ubuntu:16.04
MAINTAINER Davit Nikoghosyan <davit@gluu.org>
RUN  apt-get update -y && \
     apt-get upgrade -y && \
     apt-get -y autoremove && \
     apt-get clean
RUN apt install -y \
     python \
     apt-transport-https \
     curl \
     wget
RUN echo "deb https://repo.gluu.org/ubuntu/ xenial main" > /etc/apt/sources.list.d/gluu-repo.list
RUN curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y \
     postgresql=11+* \
     oxd-server=4.0-* \
     nodejs \
     unzip \
     lua-cjson \
     python-requests \
     kong-community-edition
EXPOSE 1338
ADD setup /opt/gluu-gateway/setup
ADD kong /opt/gluu-gateway/kong
ADD konga /opt/gluu-gateway/konga
ADD third-party /opt/gluu-gateway/third-party
ADD gg_bower_components.tar.gz /opt/gluu-gateway/dist
ADD gg_node_modules.tar.gz /opt/gluu-gateway/dist
ADD setup-gluu-gateway_template.py /setup-gluu-gateway_template.py
ADD run.sh /run.sh
ENTRYPOINT ["/run.sh"]
