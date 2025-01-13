-- Create the databases
CREATE DATABASE FlywayAPDev;
CREATE DATABASE FlywayAPTest;
CREATE DATABASE FlywayAPProd;
CREATE DATABASE FlywayAPShadow;
CREATE DATABASE FlywayAPCheck;
CREATE DATABASE FlywayAPBuild;

USE FlywayAPDev;

-- Tables in Customers Schema
CREATE TABLE customers_customer (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    DateOfBirth DATE,
    Phone VARCHAR(20),
    Address VARCHAR(200)
);

CREATE TABLE customers_loyalty_program (
    ProgramID INT AUTO_INCREMENT PRIMARY KEY,
    ProgramName VARCHAR(50) NOT NULL,
    PointsMultiplier DECIMAL(3, 2) DEFAULT 1.0
);

CREATE TABLE customers_customer_feedback (
    FeedbackID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT,
    FeedbackDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    Rating INT CHECK (Rating BETWEEN 1 AND 5),
    Comments VARCHAR(500),
    FOREIGN KEY (CustomerID) REFERENCES customers_customer(CustomerID)
);

-- Tables in Inventory Schema
CREATE TABLE inventory_flight (
    FlightID INT AUTO_INCREMENT PRIMARY KEY,
    Airline VARCHAR(50) NOT NULL,
    DepartureCity VARCHAR(50) NOT NULL,
    ArrivalCity VARCHAR(50) NOT NULL,
    DepartureTime DATETIME NOT NULL,
    ArrivalTime DATETIME NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    AvailableSeats INT NOT NULL
);

CREATE TABLE inventory_flight_route (
    RouteID INT AUTO_INCREMENT PRIMARY KEY,
    DepartureCity VARCHAR(50) NOT NULL,
    ArrivalCity VARCHAR(50) NOT NULL,
    Distance INT NOT NULL
);

CREATE TABLE inventory_maintenance_log (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    FlightID INT,
    MaintenanceDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    Description VARCHAR(500),
    MaintenanceStatus VARCHAR(20) DEFAULT 'Pending',
    FOREIGN KEY (FlightID) REFERENCES inventory_flight(FlightID)
);

-- Tables in Sales Schema
CREATE TABLE sales_orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT,
    FlightID INT,
    OrderDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    Status VARCHAR(20) DEFAULT 'Pending',
    TotalAmount DECIMAL(10, 2),
    TicketQuantity INT,
    FOREIGN KEY (CustomerID) REFERENCES customers_customer(CustomerID),
    FOREIGN KEY (FlightID) REFERENCES inventory_flight(FlightID)
);

CREATE TABLE sales_discount_code (
    DiscountID INT AUTO_INCREMENT PRIMARY KEY,
    Code VARCHAR(20) UNIQUE NOT NULL,
    DiscountPercentage DECIMAL(4, 2) CHECK (DiscountPercentage BETWEEN 0 AND 100),
    ExpiryDate DATETIME
);

CREATE TABLE sales_order_audit_log (
    AuditID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT,
    ChangeDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ChangeDescription VARCHAR(500),
    FOREIGN KEY (OrderID) REFERENCES sales_orders(OrderID)
);

-- Views

CREATE VIEW sales_customer_orders_view AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    o.OrderID,
    o.OrderDate,
    o.Status,
    o.TotalAmount
FROM customers_customer c
JOIN sales_orders o ON c.CustomerID = o.CustomerID;

CREATE VIEW customers_customer_feedback_summary AS
SELECT 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    AVG(f.Rating) AS AverageRating,
    COUNT(f.FeedbackID) AS FeedbackCount
FROM customers_customer c
LEFT JOIN customers_customer_feedback f ON c.CustomerID = f.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName;

CREATE VIEW inventory_flight_maintenance_status AS
SELECT 
    f.FlightID,
    f.Airline,
    f.DepartureCity,
    f.ArrivalCity,
    COUNT(m.LogID) AS MaintenanceCount,
    SUM(CASE WHEN m.MaintenanceStatus = 'Completed' THEN 1 ELSE 0 END) AS CompletedMaintenance
FROM inventory_flight f
LEFT JOIN inventory_maintenance_log m ON f.FlightID = m.FlightID
GROUP BY f.FlightID, f.Airline, f.DepartureCity, f.ArrivalCity;

-- Stored Procedures

DELIMITER $$

CREATE PROCEDURE sales_get_customer_flight_history(IN CustomerID INT)
BEGIN
    SELECT 
        o.OrderID,
        f.Airline,
        f.DepartureCity,
        f.ArrivalCity,
        o.OrderDate,
        o.Status,
        o.TotalAmount
    FROM sales_orders o
    JOIN inventory_flight f ON o.FlightID = f.FlightID
    WHERE o.CustomerID = CustomerID
    ORDER BY o.OrderDate;
END$$

CREATE PROCEDURE sales_update_order_status(IN OrderID INT, IN NewStatus VARCHAR(20))
BEGIN
    UPDATE sales_orders
    SET Status = NewStatus
    WHERE OrderID = OrderID;
END$$

CREATE PROCEDURE inventory_update_available_seats(IN FlightID INT, IN SeatChange INT)
BEGIN
    UPDATE inventory_flight
    SET AvailableSeats = AvailableSeats + SeatChange
    WHERE FlightID = FlightID;
END$$

CREATE PROCEDURE sales_apply_discount(IN OrderID INT, IN DiscountCode VARCHAR(20))
BEGIN
    DECLARE DiscountID INT;
    DECLARE DiscountPercentage DECIMAL(4, 2);
    DECLARE ExpiryDate DATETIME;

    SELECT 
        DiscountID, DiscountPercentage, ExpiryDate
    INTO DiscountID, DiscountPercentage, ExpiryDate
    FROM sales_discount_code
    WHERE Code = DiscountCode;

    IF DiscountID IS NOT NULL AND ExpiryDate >= CURRENT_TIMESTAMP THEN
        UPDATE sales_orders
        SET TotalAmount = TotalAmount * (1 - DiscountPercentage / 100)
        WHERE OrderID = OrderID;

        INSERT INTO sales_order_audit_log (OrderID, ChangeDescription)
        VALUES (OrderID, CONCAT('Discount ', DiscountCode, ' applied with ', DiscountPercentage, '% off.'));
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid or expired discount code.';
    END IF;
END$$

CREATE PROCEDURE inventory_add_maintenance_log(IN FlightID INT, IN Description VARCHAR(500))
BEGIN
    INSERT INTO inventory_maintenance_log (FlightID, Description, MaintenanceStatus)
    VALUES (FlightID, Description, 'Pending');
END$$

CREATE PROCEDURE customers_record_feedback(IN CustomerID INT, IN Rating INT, IN Comments VARCHAR(500))
BEGIN
    INSERT INTO customers_customer_feedback (CustomerID, Rating, Comments)
    VALUES (CustomerID, Rating, Comments);
END$$

DELIMITER ;
