# Stage 1: MySQL Image with Preloaded SQL Data
FROM mysql:9.5.0 AS mysql_base

# Set environment variables for MySQL
ENV MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
ENV MYSQL_DATABASE=${MYSQL_DATABASE}
ENV MYSQL_USER=${MYSQL_USER}
ENV MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Copy SQL initialization file to MySQL's default init directory
COPY sql_fate_data.sql /docker-entrypoint-initdb.d/

# Stage 2: Python Flask App
FROM python:3.8-slim AS app_base

# Set working directory and copy app code
WORKDIR /app
COPY . /app

# Install Flask and MySQL connector
RUN pip install flask mysql-connector-python

# Expose port for the Flask web server
EXPOSE 8081

# Start the Flask application
CMD ["python", "app.py"]
