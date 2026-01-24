# Minimal shell-less Jenkins image
# Built on zero-CVE apko base with Wolfi packages
# Jenkins WAR is downloaded before build and copied in

FROM jenkins-base:latest

# Copy pre-downloaded Jenkins WAR (downloaded in Makefile/CI)
COPY jenkins.war /usr/share/jenkins/jenkins.war

EXPOSE 8080 50000

VOLUME /var/jenkins_home

# Run Jenkins directly with java (no shell needed)
ENTRYPOINT ["/usr/bin/java"]
CMD ["-Xmx512m", "-Djava.awt.headless=true", "-jar", "/usr/share/jenkins/jenkins.war"]
