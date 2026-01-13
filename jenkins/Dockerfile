# Minimal Jenkins - Zero CVE Target
# Uses distroless Java base with Jenkins WAR
ARG JENKINS_VERSION=2.492
ARG JAVA_VERSION=17

# Build stage - download and prepare Jenkins
FROM eclipse-temurin:${JAVA_VERSION}-jdk-alpine AS builder

ARG JENKINS_VERSION

# Download Jenkins WAR
RUN wget -q -O /jenkins.war \
    "https://get.jenkins.io/war-stable/${JENKINS_VERSION}/jenkins.war" && \
    echo "Verifying Jenkins WAR..." && \
    java -jar /jenkins.war --version

# Create directory structure
RUN mkdir -p /rootfs/usr/share/jenkins /rootfs/var/jenkins_home && \
    cp /jenkins.war /rootfs/usr/share/jenkins/jenkins.war

# Runtime stage - distroless Java
FROM gcr.io/distroless/java${JAVA_VERSION}-debian12:nonroot

# Copy Jenkins WAR
COPY --from=builder /rootfs/usr/share/jenkins/jenkins.war /usr/share/jenkins/jenkins.war

# Jenkins home will be mounted as volume
ENV JENKINS_HOME=/var/jenkins_home \
    JENKINS_SLAVE_AGENT_PORT=50000 \
    JENKINS_UC=https://updates.jenkins.io \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.footerURL="

EXPOSE 8080 50000

USER nonroot

WORKDIR /var/jenkins_home

ENTRYPOINT ["java", "-jar", "/usr/share/jenkins/jenkins.war"]
CMD ["--httpPort=8080"]
