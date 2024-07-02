# Build Stage
FROM maven:3.9.6-sapmachine-21 AS build

# Set the working directory
WORKDIR /home/app/

COPY . /home/app/

RUN mvn clean package

# Package Stage Use a base image with Java runtime
FROM openjdk:21-slim

# Copy the JAR file into the container
# COPY target/java-web-app-0.0.3-SNAPSHOT.jar app.jar
COPY --from=build /home/app/target/java-web-app-0.0.1-SNAPSHOT.jar /usr/local/lib/app.jar

# Expose the port the application runs on
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["java", "-jar", "/usr/local/lib/app.jar"]