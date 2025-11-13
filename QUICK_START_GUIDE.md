# Transport Book App - Quick Start Guide

## 🚀 Getting Started

### Prerequisites
- Flutter installed
- Backend API running at `http://localhost/transport_api/api.php`
- MySQL database configured

---

## 📱 App Flow

### 1. Add a Truck
**Navigation:** Dashboard → My Trucks → Add Truck Button

#### Own Truck:
```
1. Enter truck number: MH12TY9769
   - Must follow format: 2 letters + 2 digits + alphanumeric
2. Select "My Truck"
3. Click "Confirm"
```

#### Market Truck:
```
1. Enter truck number: KA01AB1234
2. Select "Market Truck"
3. Select supplier (or add new)
4. Click "Confirm"
```

**Validation:**
- ✅ MH12TY9769 → Valid
- ✅ KA01AB1234 → Valid
- ❌ 123456 → Invalid (missing state code letters)
- ❌ MH1234 → Invalid (too short)
- ❌ MH123456 → Invalid (missing letters after state code)

---

### 2. Add a Trip

**Navigation:** Dashboard → Add Trip / Truck Details → Add Trip

#### Own Truck Trip:
```
1. Select party (customer)
2. Select driver
3. Select truck (own truck)
4. Enter origin and destination
5. Select billing type:
   - Per Trip: Enter total freight amount
   - Per Ton/Kg: Enter rate and quantity (auto-calculates)
6. Enter trip start date
7. Click "Save Trip"
```

**Balance Impact:**
- Party balance: +Freight Amount
- Driver balance: +Driver Amount (calculated/entered)

#### Market Truck Trip:
```
1. Select party (customer)
2. Select supplier
3. Select truck (market truck)
4. Enter origin and destination
5. Party Billing:
   - Select billing type
   - Enter freight amount
6. Supplier Billing:
   - Select billing type
   - Enter truck hire cost
7. Enable SMS (optional)
8. Enter trip start date
9. Click "Save Trip"
```

**Balance Impact:**
- Party balance: +Freight Amount
- Supplier balance: +Truck Hire Cost

---

### 3. View Balances

#### Party Khata
**Navigation:** Dashboard → Party Khata

**Shows:**
- All parties with outstanding balance
- Amount to collect from each party
- Based on unsettled trips

**Actions:**
- Add new party
- View party details
- See trip history

#### Driver Khata
**Navigation:** Dashboard → Driver Khata

**Shows:**
- All drivers with pending payments (own trucks only)
- Amount to pay each driver
- Based on unsettled trips

**Actions:**
- Add new driver
- View driver details
- Add gave/got transactions

#### Supplier Khata
**Navigation:** Dashboard → Supplier Khata

**Shows:**
- All suppliers with pending payments (market trucks only)
- Amount to pay each supplier (hire costs)
- Based on unsettled trips

**Actions:**
- Add new supplier
- View supplier details
- See supplier trip history

---

### 4. Settle a Trip

**Navigation:** Trip Details → Settle Trip Button

```
1. Go to trip details
2. Click "Settle Trip"
3. Enter settlement amount
4. Select payment mode
5. Enter settlement date
6. Add notes (optional)
7. Confirm settlement
```

**Balance Impact:**
- Trip status changes to "Settled"
- Party balance decreases by freight amount
- Driver/Supplier balance decreases by their amount
- Trip no longer appears in pending balances

---

### 5. View Reports

#### Balance Report
**Navigation:** Dashboard → Balance Report

**Features:**
- View all party balances
- Filter by date range
- Filter by balance type
- Select multiple parties
- Export to PDF

**Filters:**
- Date range selector
- Month selector
- Balance type (To Receive, Settled, All)

---

## 🎯 Common Scenarios

### Scenario 1: Complete Own Truck Trip Flow
```
1. Add truck: MH12TY9769 (Own Truck)
2. Add driver: "Raj Kumar" with phone
3. Add party: "ABC Company"
4. Add trip:
   - Truck: MH12TY9769
   - Driver: Raj Kumar
   - Party: ABC Company
   - Route: Mumbai → Delhi
   - Freight: ₹50,000
5. Check balances:
   - Party "ABC Company": ₹50,000 (to receive)
   - Driver "Raj Kumar": ₹8,000 (to pay)
6. Complete trip and receive payment
7. Settle trip: ₹50,000
8. Check balances:
   - Party "ABC Company": ₹0
   - Driver "Raj Kumar": ₹0
```

### Scenario 2: Complete Market Truck Trip Flow
```
1. Add supplier: "Ram Supplier"
2. Add truck: KA01AB1234 (Market Truck, Supplier: Ram Supplier)
3. Add party: "XYZ Company"
4. Add trip:
   - Truck: KA01AB1234
   - Supplier: Ram Supplier
   - Party: XYZ Company
   - Route: Pune → Bangalore
   - Freight: ₹60,000
   - Hire Cost: ₹45,000
5. Check balances:
   - Party "XYZ Company": ₹60,000 (to receive)
   - Supplier "Ram Supplier": ₹45,000 (to pay)
6. Complete trip and receive payment
7. Settle trip: ₹60,000
8. Pay supplier: ₹45,000
9. Check balances:
   - Party "XYZ Company": ₹0
   - Supplier "Ram Supplier": ₹0
```

### Scenario 3: Multiple Unsettled Trips
```
1. Add 3 trips for same party "ABC Company":
   - Trip 1: ₹50,000 (Unsettled)
   - Trip 2: ₹40,000 (Unsettled)
   - Trip 3: ₹30,000 (Unsettled)
2. Check party balance: ₹1,20,000
3. Settle Trip 1: ₹50,000
4. Check party balance: ₹70,000 (Trip 2 + Trip 3)
5. Settle Trip 2: ₹40,000
6. Check party balance: ₹30,000 (Trip 3 only)
7. Settle Trip 3: ₹30,000
8. Check party balance: ₹0
```

---

## 🔍 Balance Calculation Logic

### Party Balance
```
Balance = Sum of freight amounts from all unsettled trips
```
**Example:**
- Trip 1 (Unsettled): ₹50,000
- Trip 2 (Unsettled): ₹40,000
- Trip 3 (Settled): ₹30,000
- **Party Balance: ₹90,000** (Trip 1 + Trip 2 only)

### Driver Balance (Own Trucks Only)
```
Balance = Opening Balance +
          Sum of driver amounts from unsettled trips +
          Manual transactions
```
**Example:**
- Opening Balance: ₹5,000
- Trip 1 (Unsettled, Own Truck): ₹8,000
- Trip 2 (Unsettled, Own Truck): ₹7,000
- Gave transaction: ₹2,000
- **Driver Balance: ₹18,000** (5,000 + 8,000 + 7,000 - 2,000)

### Supplier Balance (Market Trucks Only)
```
Balance = Sum of hire costs from unsettled trips
```
**Example:**
- Trip 1 (Unsettled, Market Truck): ₹45,000
- Trip 2 (Unsettled, Market Truck): ₹40,000
- Trip 3 (Settled, Market Truck): ₹35,000
- **Supplier Balance: ₹85,000** (Trip 1 + Trip 2 only)

---

## ⚠️ Important Points

### Truck Number Validation:
- Always use proper format: **MH12TY9769**
- First 2 characters: State code (MH, KA, GJ, etc.)
- Next 2 characters: Numbers (01-99)
- Rest: Alphanumeric (letters and numbers)

### Trip Balance Rules:
1. **Own Truck Trip:**
   - Creates party balance (freight amount)
   - Creates driver balance (driver amount)
   - No supplier balance

2. **Market Truck Trip:**
   - Creates party balance (freight amount)
   - Creates supplier balance (hire cost)
   - No driver balance

3. **Trip Settlement:**
   - Removes amounts from all related balances
   - Trip status changes to "Settled"
   - Cannot be undone (be careful!)

### Balance Reports:
- Show only **pending/unsettled** amounts
- Filter by date to see historical balances
- Export to PDF for record-keeping
- Total balance = Sum of all pending amounts

---

## 🎨 UI Color Codes

### Balance Colors:
- 🟢 **Green**: Amount to receive (Party balance)
- 🔴 **Red**: Amount to pay (Driver/Supplier balance)

### Trip Status Colors:
- 🟢 **Green**: Available/Completed
- 🔵 **Blue**: On Trip/In Progress
- 🟠 **Orange**: Under Maintenance
- 🔴 **Red**: Inactive

### Truck Type Colors:
- 🟢 **Green Badge**: Own Truck
- 🟠 **Orange Badge**: Market Truck

---

## 📊 Sample Data for Testing

### Trucks:
```
1. MH12TY9769 - Own Truck
2. MH14AB1234 - Own Truck
3. KA01CD5678 - Market Truck (Supplier: Ram Supplier)
4. GJ02EF9012 - Market Truck (Supplier: Krishna Transport)
```

### Parties:
```
1. ABC Company - Mumbai
2. XYZ Corporation - Delhi
3. PQR Industries - Bangalore
4. LMN Traders - Pune
```

### Drivers:
```
1. Raj Kumar - +91 98765 43210
2. Amit Singh - +91 98765 43211
3. Suresh Patel - +91 98765 43212
```

### Suppliers:
```
1. Ram Supplier - +91 98765 43220
2. Krishna Transport - +91 98765 43221
3. Satish Logistics - +91 98765 43222
```

### Sample Trips:
```
Trip 1 (Own Truck):
- Truck: MH12TY9769
- Driver: Raj Kumar
- Party: ABC Company
- Route: Mumbai → Delhi
- Freight: ₹50,000

Trip 2 (Market Truck):
- Truck: KA01CD5678
- Supplier: Ram Supplier
- Party: XYZ Corporation
- Route: Pune → Bangalore
- Freight: ₹60,000
- Hire Cost: ₹45,000
```

---

## 🐛 Troubleshooting

### Issue: Truck number validation failing
**Solution:** Ensure format is correct:
- ✅ MH12TY9769
- ❌ mh12ty9769 (will be auto-converted to uppercase)
- ❌ 12MH9769 (wrong order)

### Issue: Balance not updating
**Solution:** Check:
1. Backend API is running
2. Trip status is correct (not already settled)
3. Refresh the khata screen

### Issue: Cannot add trip
**Solution:** Verify:
1. Truck is added first
2. Party is selected
3. Driver (own truck) or Supplier (market truck) is selected
4. All required fields are filled

### Issue: PDF generation fails
**Solution:**
1. Check internet connection (for fonts)
2. Ensure at least one party is selected
3. Try with fewer parties if too many selected

---

## 📝 Best Practices

### 1. Always Add Master Data First:
```
Step 1: Add Trucks
Step 2: Add Parties
Step 3: Add Drivers (for own trucks)
Step 4: Add Suppliers (for market trucks)
Step 5: Start Adding Trips
```

### 2. Keep Truck Numbers Consistent:
- Use standard format
- Don't add spaces manually (app handles it)
- Always verify truck number before submission

### 3. Settle Trips Regularly:
- Don't let unsettled trips accumulate
- Settle trips as soon as payment is received
- This keeps balances accurate

### 4. Review Balances Frequently:
- Check party khata weekly
- Check driver khata before making payments
- Check supplier khata to plan payments

### 5. Use Filters in Reports:
- Filter by date to see monthly balances
- Filter by party to see specific customer dues
- Export to PDF for accounts/records

---

## 🎯 Success Indicators

### App is Working Correctly When:
1. ✅ Truck validation accepts valid numbers, rejects invalid ones
2. ✅ Adding trip increases party balance immediately
3. ✅ Adding own truck trip increases driver balance
4. ✅ Adding market truck trip increases supplier balance
5. ✅ Settling trip decreases all related balances
6. ✅ Balance reports show correct totals
7. ✅ PDF export works without errors
8. ✅ All khata screens load quickly

---

## 📞 Support

### For Backend Issues:
- Check `API_BALANCE_TRACKING_GUIDE.md`
- Verify database schema
- Test API endpoints individually

### For Flutter Issues:
- Check `IMPLEMENTATION_SUMMARY.md`
- Verify API responses have `balance` field
- Check console for errors

### For Business Logic Questions:
- Refer to `API_BALANCE_TRACKING_GUIDE.md`
- Balance tracking is trip-based
- Everything revolves around trip status

---

## 🚀 Quick Test Checklist

Run this to verify everything works:

- [ ] Add own truck with valid number
- [ ] Add market truck with supplier
- [ ] Add party
- [ ] Add driver
- [ ] Create own truck trip
- [ ] Check party balance increased
- [ ] Check driver balance increased
- [ ] Create market truck trip
- [ ] Check party balance increased
- [ ] Check supplier balance increased
- [ ] Settle one trip
- [ ] Check related balances decreased
- [ ] Generate balance report
- [ ] Export report to PDF

**If all checks pass, the app is fully functional!** ✅

---

## 🎉 You're Ready!

The app is now ready for production use. All features are functional:
- ✅ Truck management with validation
- ✅ Trip creation and tracking
- ✅ Balance tracking (party/driver/supplier)
- ✅ Trip settlement
- ✅ Reports and PDF export
- ✅ Complete UI with filters and search

Just ensure the backend API is updated as per `API_BALANCE_TRACKING_GUIDE.md` and you're good to go! 🚀
