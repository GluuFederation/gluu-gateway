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
     wget \
     sudo \
     net-tools 
RUN echo "deb https://repo.gluu.org/ubuntu/ xenial main" > /etc/apt/sources.list.d/gluu-repo.list
RUN curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y \
     gluu-gateway=1.0-*
EXPOSE 1338
ADD run.sh /run.sh
ADD setup-gluu-gateway_template.py /setup-gluu-gateway_template.py
ENTRYPOINT ["/run.sh"]
