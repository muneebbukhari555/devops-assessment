# Use a base image with Java runtime
FROM openjdk:21-slim

# Set the working directory
WORKDIR /app

# Copy the JAR file into the container
COPY target/java-web-app-0.0.3-SNAPSHOT.jar app.jar

# Expose the port the application runs on
EXPOSE 8080

# Command to run the application
ENTRYPOINT ["java", "-jar", "app.jar"]