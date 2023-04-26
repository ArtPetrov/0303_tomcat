FROM bellsoft/alpaquita-linux-gcc:12.2-glibc as base

ARG KEY='70092656FB28DBB76C3BB42E89619023B6601234'
ENV KEY=${KEY}

ARG GPG_KEY_URL="https://github.com/slurmorg/build-containers-trusted/raw/main/key.gpg"
ARG ROOTFS_URL="https://github.com/slurmorg/build-containers-trusted/raw/main/rootfs.tar.gz"
ARG MAVEN_URL="https://github.com/slurmorg/build-containers-trusted/raw/main/apache-maven-3.9.1-bin.tar.gz"
ARG TOMCAT_URL="https://github.com/slurmorg/build-containers-trusted/raw/main/apache-tomcat-10.1.7.tar.gz"

RUN apk update && apk add gnupg

ADD $GPG_KEY_URL  /tmp/key.gpg
ADD $ROOTFS_URL $ROOTFS_URL.sha512 $ROOTFS_URL.sha512.asc  /tmp/
ADD $MAVEN_URL $MAVEN_URL.sha512 $MAVEN_URL.sha512.asc  /tmp/
ADD $TOMCAT_URL $TOMCAT_URL.sha512 $TOMCAT_URL.sha512.asc  /tmp/

RUN if [ $KEY != $(gpg --show-keys /tmp/key.gpg | grep  -E -o "[0-9A-Z]{40}") ]; then echo "IS NOT VALID KEY" && exit 1; fi

RUN if [ $(sha512sum /tmp/rootfs.tar.gz | awk '{print $1}') != $(cat /tmp/rootfs.tar.gz.sha512 | awk '{print $1}') ]; then echo "IS NOT VALID SH512 FOR ROOTFS" && exit 1; fi
RUN if [ $(sha512sum /tmp/apache-maven-3.9.1-bin.tar.gz | awk '{print $1}') != $(cat /tmp/apache-maven-3.9.1-bin.tar.gz.sha512 | awk '{print $1}') ]; then echo "IS NOT VALID SH512 FOR MAVEN" && exit 1; fi
RUN if [ $(sha512sum /tmp/apache-tomcat-10.1.7.tar.gz | awk '{print $1}') != $(cat /tmp/apache-tomcat-10.1.7.tar.gz.sha512 | awk '{print $1}') ]; then echo "IS NOT VALID SH512 FOR TOMCAT" && exit 1; fi

RUN gpg --import /tmp/key.gpg;

RUN if [ "Good" = $(gpg --verify /tmp/rootfs.tar.gz.sha512.asc 2>&1 | grep -o "Good") ]; then echo "OK"; else echo "IS NOT VALID ASC FOR ROOTFS" && exit 1; fi
RUN if [ "Good" = $(gpg --verify /tmp/apache-maven-3.9.1-bin.tar.gz.sha512.asc 2>&1 | grep -o "Good") ]; then echo "OK"; else echo "IS NOT VALID ASC FOR MAVEN" && exit 1; fi
RUN if [ "Good" = $(gpg --verify /tmp/apache-tomcat-10.1.7.tar.gz.sha512.asc 2>&1 | grep -o "Good") ]; then echo "OK"; else echo "IS NOT VALID ASC FOR TOMCAT" && exit 1; fi

RUN mkdir /tmp/rootfs && tar -zxf /tmp/rootfs.tar.gz --directory /tmp/rootfs
RUN tar -zxf /tmp/apache-maven-3.9.1-bin.tar.gz --directory /tmp/
RUN tar -zxf /tmp/apache-tomcat-10.1.7.tar.gz --directory /tmp/


FROM scratch as buider

COPY --from=base /tmp/rootfs/ /
COPY --from=base /tmp/apache-maven-3.9.1/ /opt/bin/maven

ENV PATH="/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/maven/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8:en"
ENV JAVA_HOME="/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64"
ENV MAVEN_HOME="/opt/bin/maven"

WORKDIR /app
COPY src/pom.xml ./
RUN mvn dependency:resolve
COPY ./src ./
RUN mvn verify

FROM scratch

COPY --from=base /tmp/rootfs/ /
COPY --from=base /tmp/apache-tomcat-10.1.7/ /opt/bin/tomcat

ENV PATH="/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US.UTF-8:en"
ENV JAVA_HOME="/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64"
ENV CATALINA_HOME="/opt/bin/tomcat"

RUN rm -rf $CATALINA_HOME/webapps
COPY --from=buider /app/target/api.war $CATALINA_HOME/webapps/ROOT.war

EXPOSE 8080
CMD catalina.sh run
