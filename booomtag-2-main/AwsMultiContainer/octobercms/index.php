<?php

// Database connection details
$host     = getenv('DB_HOST');
$username = getenv('DB_USERNAME');
$password = getenv('DB_PASSWORD');
$dbname   = getenv('DB_DATABASE');

#fds
// Create a connection to the database
$conn = new mysqli($host, $username, $password, $dbname);

// Check if the connection is successful
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Query to fetch data from the sample_data table
$sql = "SELECT * FROM sample_data";  // Query to select all rows from the table
$result = $conn->query($sql);
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Sample Data</title>
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css">
</head>

<body>

    <div class="container">
        <header class="text-center my-5">
            <h1>Welcome to OctoberCMS</h1>
            <p>Displaying data from the database</p>
        </header>

        <section class="content">
            <div class="alert alert-info">
                <strong>Info:</strong> This is a demo showing how data from a MySQL table can be displayed in an HTML table using PHP.
            </div>

            <!-- Table displaying the data from the sample_data table -->
            <h2>Data from the Database</h2>
            <table class="table table-bordered">
                <thead>
                    <tr>
                        <th>User ID</th>
                        <th>Given Name</th>
                        <th>Family Name</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    // Check if there are any records to display
                    if ($result->num_rows > 0) {
                        // Loop through and display each row
                        while($row = $result->fetch_assoc()) {
                            echo "<tr>";
                            echo "<td>" . $row["user_id"] . "</td>";
                            echo "<td>" . $row["given_name"] . "</td>";
                            echo "<td>" . $row["family_name"] . "</td>";
                            echo "</tr>";
                        }
                    } else {
                        echo "<tr><td colspan='3'>No records found</td></tr>";
                    }
                    // Close the database connection
                    $conn->close();
                    ?>
                </tbody>
            </table>

        </section>

        <footer class="text-center my-5">
            <p>&copy; 2024 OctoberCMS. All rights reserved.</p>
        </footer>
    </div>

    <script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.9.2/dist/umd/popper.min.js"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js"></script>

</body>

</html>