# Transport Book App - Balance Tracking API Guide

## Overview
This guide explains how the balance tracking system works in the Transport Book App. All balances revolve around **trips** and their settlement status.

## Core Concept
- **Until a trip is completely settled, the pending amounts appear in respective khata/ledgers**
- **Party Balance**: Amount to collect from party (customer)
- **Driver Balance**: Amount owed to driver (only for **Own trucks**)
- **Supplier Balance**: Amount owed to supplier (only for **Market/Hired trucks**)

---

## 1. Trip Creation & Balance Logic

### When Trip is Added with OWN TRUCK:
```json
{
  "truckId": 1,
  "truckType": "Own",
  "truckNumber": "MH 12 TY 9769",
  "partyName": "ABC Company",
  "driverName": "Raj Kumar",
  "freightAmount": 50000,
  "startDate": "2025-10-13",
  "status": "Pending"
}
```

**Balance Impact:**
- ✅ **Party Balance**: +50,000 (We need to collect from party)
- ✅ **Driver Balance**: Amount needs to be calculated/assigned to driver
- ❌ **Supplier Balance**: No impact (own truck)

### When Trip is Added with MARKET TRUCK:
```json
{
  "truckId": 2,
  "truckType": "Market",
  "truckNumber": "KA 01 AB 1234",
  "partyName": "XYZ Company",
  "supplierName": "Ram Supplier",
  "freightAmount": 60000,
  "truckHireCost": 45000,
  "startDate": "2025-10-13",
  "status": "Pending"
}
```

**Balance Impact:**
- ✅ **Party Balance**: +60,000 (We need to collect from party)
- ❌ **Driver Balance**: No impact (market truck)
- ✅ **Supplier Balance**: +45,000 (We need to pay supplier)

---

## 2. API Responses for Khata Screens

### 2.1 Party Khata API (`GET /api.php?request=parties`)

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "ABC Company",
      "phone": "+91 9876543210",
      "email": "abc@company.com",
      "balance": 150000,
      "totalTrips": 5,
      "pendingTrips": 2,
      "settledTrips": 3,
      "pendingAmount": 100000,
      "receivedAmount": 50000
    }
  ]
}
```

**Balance Calculation Logic:**
```sql
-- Party Balance = Sum of all unsettled trip freight amounts
SELECT
    p.id,
    p.name,
    p.phone,
    p.email,
    COALESCE(SUM(CASE WHEN t.status != 'Settled' THEN t.freightAmount ELSE 0 END), 0) as balance,
    COUNT(t.id) as totalTrips,
    SUM(CASE WHEN t.status != 'Settled' THEN 1 ELSE 0 END) as pendingTrips,
    SUM(CASE WHEN t.status = 'Settled' THEN 1 ELSE 0 END) as settledTrips,
    COALESCE(SUM(CASE WHEN t.status != 'Settled' THEN t.freightAmount ELSE 0 END), 0) as pendingAmount,
    COALESCE(SUM(CASE WHEN t.status = 'Settled' THEN t.freightAmount ELSE 0 END), 0) as receivedAmount
FROM parties p
LEFT JOIN trips t ON t.partyName = p.name
GROUP BY p.id
```

### 2.2 Driver Khata API (`GET /api.php?request=drivers`)

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Raj Kumar",
      "phone": "+91 9876543210",
      "balance": 25000,
      "openingBalance": 5000,
      "totalTrips": 8,
      "pendingTrips": 3,
      "settledTrips": 5,
      "pendingAmount": 20000,
      "paidAmount": 30000
    }
  ]
}
```

**Balance Calculation Logic:**
```sql
-- Driver Balance = Opening Balance + Sum of all unsettled trip driver amounts + manual transactions
SELECT
    d.id,
    d.name,
    d.phone,
    d.openingBalance,
    d.openingBalance +
        COALESCE(SUM(CASE WHEN t.status != 'Settled' AND tr.type = 'Own' THEN t.driverAmount ELSE 0 END), 0) +
        COALESCE(SUM(dt.amount * CASE WHEN dt.type = 'gave' THEN 1 ELSE -1 END), 0) as balance,
    COUNT(DISTINCT t.id) as totalTrips,
    SUM(CASE WHEN t.status != 'Settled' AND tr.type = 'Own' THEN 1 ELSE 0 END) as pendingTrips,
    SUM(CASE WHEN t.status = 'Settled' AND tr.type = 'Own' THEN 1 ELSE 0 END) as settledTrips
FROM drivers d
LEFT JOIN trips t ON t.driverName = d.name
LEFT JOIN trucks tr ON t.truckId = tr.id
LEFT JOIN driver_transactions dt ON dt.driverId = d.id
GROUP BY d.id
```

### 2.3 Supplier Khata API (`GET /api.php?request=suppliers`)

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "Ram Supplier",
      "phone": "+91 9876543210",
      "balance": 85000,
      "totalTrips": 6,
      "pendingTrips": 4,
      "settledTrips": 2,
      "pendingAmount": 85000,
      "paidAmount": 40000
    }
  ]
}
```

**Balance Calculation Logic:**
```sql
-- Supplier Balance = Sum of all unsettled trip hire costs for market trucks
SELECT
    s.id,
    s.name,
    s.phone,
    COALESCE(SUM(CASE WHEN t.status != 'Settled' AND tr.type = 'Market' THEN t.truckHireCost ELSE 0 END), 0) as balance,
    COUNT(DISTINCT t.id) as totalTrips,
    SUM(CASE WHEN t.status != 'Settled' AND tr.type = 'Market' THEN 1 ELSE 0 END) as pendingTrips,
    SUM(CASE WHEN t.status = 'Settled' AND tr.type = 'Market' THEN 1 ELSE 0 END) as settledTrips,
    COALESCE(SUM(CASE WHEN t.status != 'Settled' AND tr.type = 'Market' THEN t.truckHireCost ELSE 0 END), 0) as pendingAmount,
    COALESCE(SUM(CASE WHEN t.status = 'Settled' AND tr.type = 'Market' THEN t.truckHireCost ELSE 0 END), 0) as paidAmount
FROM suppliers s
LEFT JOIN trips t ON t.supplierName = s.name
LEFT JOIN trucks tr ON t.truckId = tr.id
GROUP BY s.id
```

---

## 3. Trip Settlement Flow

### Trip Statuses:
1. **Pending** - Trip created, not started
2. **In Progress** - Trip started
3. **Completed** - Trip completed, POD received
4. **Settled** - Payment settled, balances updated

### Settlement API (`POST /api.php?request=settle_trip`)

**Request:**
```json
{
  "tripId": 123,
  "settleAmount": 50000,
  "settlePaymentMode": "Cash",
  "settleDate": "2025-10-13",
  "settleNotes": "Full payment received"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Trip settled successfully",
  "data": {
    "tripId": 123,
    "status": "Settled",
    "partyBalanceUpdated": true,
    "driverBalanceUpdated": true,
    "supplierBalanceUpdated": false
  }
}
```

**Backend Logic on Settlement:**
```php
// When trip is settled:
1. Update trip status to 'Settled'
2. Record settlement transaction
3. Balances are automatically recalculated in khata APIs (queries exclude settled trips)
4. Create payment records for party/driver/supplier as needed
```

---

## 4. Trip Details API

### GET /api.php?request=trip_details&id={tripId}

```json
{
  "success": true,
  "data": {
    "id": 123,
    "truckId": 1,
    "truckNumber": "MH 12 TY 9769",
    "truckType": "Own",
    "partyName": "ABC Company",
    "driverName": "Raj Kumar",
    "supplierName": null,
    "origin": "Mumbai",
    "destination": "Delhi",
    "startDate": "2025-10-10",
    "endDate": "2025-10-12",
    "status": "Completed",
    "billingType": "Per Trip",
    "freightAmount": 50000,
    "truckHireCost": 0,
    "driverAmount": 8000,
    "expenses": [
      {"type": "Fuel", "amount": 12000},
      {"type": "Toll", "amount": 3000}
    ],
    "totalExpenses": 15000,
    "netProfit": 27000,
    "isPending": true,
    "partyBalancePending": 50000,
    "driverBalancePending": 8000,
    "supplierBalancePending": 0
  }
}
```

---

## 5. Balance Report API

### GET /api.php?request=balance_report

```json
{
  "success": true,
  "data": {
    "totalPartyBalance": 450000,
    "totalDriverBalance": 85000,
    "totalSupplierBalance": 120000,
    "netBalance": 245000,
    "parties": [
      {
        "name": "ABC Company",
        "balance": 150000,
        "pendingTrips": 2
      }
    ],
    "drivers": [
      {
        "name": "Raj Kumar",
        "balance": 25000,
        "pendingTrips": 3
      }
    ],
    "suppliers": [
      {
        "name": "Ram Supplier",
        "balance": 85000,
        "pendingTrips": 4
      }
    ]
  }
}
```

---

## 6. Database Schema Requirements

### Trips Table:
```sql
CREATE TABLE trips (
    id INT PRIMARY KEY AUTO_INCREMENT,
    truckId INT NOT NULL,
    truckNumber VARCHAR(50) NOT NULL,
    partyName VARCHAR(255) NOT NULL,
    driverName VARCHAR(255) NULL,
    supplierName VARCHAR(255) NULL,
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE NULL,
    status ENUM('Pending', 'In Progress', 'Completed', 'Settled') DEFAULT 'Pending',
    billingType VARCHAR(50) NOT NULL,
    freightAmount DECIMAL(10,2) NOT NULL,
    truckHireCost DECIMAL(10,2) DEFAULT 0,
    driverAmount DECIMAL(10,2) DEFAULT 0,
    rate DECIMAL(10,2) NULL,
    quantity DECIMAL(10,2) NULL,
    supplierBillingType VARCHAR(50) NULL,
    supplierRate DECIMAL(10,2) NULL,
    supplierQuantity DECIMAL(10,2) NULL,
    settleAmount DECIMAL(10,2) NULL,
    settlePaymentMode VARCHAR(50) NULL,
    settleDate DATE NULL,
    settleNotes TEXT NULL,
    createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (truckId) REFERENCES trucks(id)
);
```

### Key Points:
- `status` field determines if amounts are pending or settled
- Party balance = Sum of `freightAmount` WHERE status != 'Settled'
- Driver balance = Sum of `driverAmount` WHERE status != 'Settled' AND truckType = 'Own'
- Supplier balance = Sum of `truckHireCost` WHERE status != 'Settled' AND truckType = 'Market'

---

## 7. Important Business Rules

1. **Party Balance**:
   - Always shows pending amount from unsettled trips
   - Once trip is settled, amount is removed from balance
   - Balance can include opening balance if party had previous dues

2. **Driver Balance**:
   - Only for OWN trucks
   - Shows amount we need to pay to driver
   - Can include opening balance and manual transactions (gave/got)
   - Settled when payment is made to driver

3. **Supplier Balance**:
   - Only for MARKET/HIRED trucks
   - Shows amount we need to pay to supplier (truck hire cost)
   - Settled when payment is made to supplier

4. **Trip Settlement**:
   - Can be partial or full
   - Once marked as 'Settled', no longer appears in pending balances
   - Settlement transactions are recorded separately

5. **Validation**:
   - Truck number format: MH12TY9769 (2 state letters + 2 digits + alphanumeric)
   - Own truck must have driver
   - Market truck must have supplier and hire cost
   - All trips must have party and freight amount

---

## 8. API Testing Examples

### Test Scenario 1: Add Trip with Own Truck
```bash
curl -X POST http://localhost/transport_api/api.php?request=trips \
-H "Content-Type: application/json" \
-d '{
  "truckId": 1,
  "truckNumber": "MH 12 TY 9769",
  "partyName": "ABC Company",
  "driverName": "Raj Kumar",
  "origin": "Mumbai",
  "destination": "Delhi",
  "billingType": "Per Trip",
  "freightAmount": "50000",
  "startDate": "2025-10-13"
}'
```

**Expected Balance Changes:**
- Party "ABC Company" balance: +50,000
- Driver "Raj Kumar" balance: +driverAmount
- No supplier balance change

### Test Scenario 2: Add Trip with Market Truck
```bash
curl -X POST http://localhost/transport_api/api.php?request=trips \
-H "Content-Type: application/json" \
-d '{
  "truckId": 2,
  "truckNumber": "KA 01 AB 1234",
  "partyName": "XYZ Company",
  "supplierName": "Ram Supplier",
  "origin": "Pune",
  "destination": "Bangalore",
  "billingType": "Per Trip",
  "freightAmount": "60000",
  "supplierBillingType": "Per Trip",
  "truckHireCost": "45000",
  "startDate": "2025-10-13"
}'
```

**Expected Balance Changes:**
- Party "XYZ Company" balance: +60,000
- Supplier "Ram Supplier" balance: +45,000
- No driver balance change

### Test Scenario 3: Settle Trip
```bash
curl -X POST http://localhost/transport_api/api.php?request=settle_trip \
-H "Content-Type: application/json" \
-d '{
  "tripId": 123,
  "settleAmount": "50000",
  "settlePaymentMode": "Cash",
  "settleDate": "2025-10-13"
}'
```

**Expected Balance Changes:**
- Party balance decreases by 50,000
- Driver/Supplier balance cleared for this trip
- Trip status changes to 'Settled'

---

## Summary

The entire balance tracking system revolves around **trip status**. The app shows:

1. **Pending Balances**: All amounts from trips that are NOT settled
2. **Party Khata**: Shows how much we need to collect
3. **Driver Khata**: Shows how much we need to pay drivers (own trucks only)
4. **Supplier Khata**: Shows how much we need to pay suppliers (market trucks only)
5. **Balance Report**: Consolidated view of all pending balances

Once a trip is **settled**, it no longer contributes to pending balances!
