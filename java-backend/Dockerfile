# Multi-stage build for Java 25
FROM maven:3.9-eclipse-temurin-25 as builder

WORKDIR /app

# Copy Maven files
COPY pom.xml .
COPY mvnw .

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests -q

# Runtime stage
FROM eclipse-temurin:25-jre

WORKDIR /app

# Copy the built JAR from builder stage
COPY --from=builder /app/target/vampire-raiders-server.jar .

# Expose the game server port
EXPOSE 7777

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 \
  CMD java -version || exit 1

# Run the application
CMD ["java", "-jar", "vampire-raiders-server.jar"]
