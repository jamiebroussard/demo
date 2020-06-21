FROM openjdk:8-jre-alpine
EXPOSE 8080
RUN apk --no-cache add curl
RUN mkdir -p /app/
ADD target/hello-world-spring-boot-0.1.0.jar /app/hello-world-spring-boot-0.1.0.jar
ENTRYPOINT ["java", "-jar", "/app/hello-world-spring-boot-0.1.0.jar"]
