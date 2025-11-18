from flask import Flask, render_template
import mysql.connector

app = Flask(__name__)

@app.route("/")
def index():
    # Connect to the MySQL database
    connection = mysql.connector.connect(
        host="mysql",  # Use the Docker service name for MySQL
        user="test",
        password = environ.get('OAUTH_SECRET') # Replace with your MySQL password
        database="YOUR_MYSQL_DATABASE"
    )
    cursor = connection.cursor()
    cursor.execute("SELECT * FROM sample_data")  # Replace with your table name
    data = cursor.fetchall()
    connection.close()

    # Render HTML template with database data
    return render_template("index.html", data=data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
