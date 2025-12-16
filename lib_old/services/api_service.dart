import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_storage.dart';

/// API Service for TMS Prime - FastAPI Backend
/// Updated for JWT authentication and RESTful endpoints
class ApiService {
  // For local development, use:
  static const String baseUrl = 'http://localhost:8000/api/v1';

  // FastAPI Backend URL - Production Server
  // Using HTTP because HTTPS certificate is invalid (ERR_CERT_AUTHORITY_INVALID)
  // static const String baseUrl = 'http://mb-app.tms-support.in/api/v1';

  // HTTPS URL (currently has SSL certificate issues)
  // static const String baseUrl = 'https://mb-app.tms-support.in/api/v1';

  // Direct IP (won't work due to Nginx proxy)
  // static const String baseUrl = 'http://31.97.229.168:8000/api/v1';

  /// Get authentication headers with JWT token
  static Future<Map<String, String>> _getHeaders() async {
    return await AuthStorage.getAuthHeaders();
  }

  /// Helper to parse API error response
  static Map<String, dynamic> _parseErrorResponse(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      return {
        'success': false,
        'message': errorData['detail'] ?? errorData['message'] ?? 'Operation failed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Operation failed'};
    }
  }

  // ==================== DASHBOARD ====================

  /// Get dashboard aggregated data
  static Future<Map<String, dynamic>?> getDashboardData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/'),  // Added trailing slash
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching dashboard data: $e');
      return null;
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Send OTP to phone number
  static Future<Map<String, dynamic>> verifyPhone(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-phone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Network error'};
    } catch (e) {
      print('Error verifying phone: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Verify OTP and login/register
  static Future<Map<String, dynamic>> verifyOTP(
    String phone,
    String otp, {
    String? businessName,
    String? ownerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phone,
          'otp': otp,
          if (businessName != null) 'business_name': businessName,
          if (ownerName != null) 'owner_name': ownerName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['token'] != null) {
          // Save authentication data
          await AuthStorage.saveToken(data['token']);
          if (data['refresh_token'] != null) {
            await AuthStorage.saveRefreshToken(data['refresh_token']);
          }
          if (data['tenant_id'] != null) {
            await AuthStorage.saveTenantId(data['tenant_id']);
          }
          if (data['user'] != null) {
            await AuthStorage.saveUser(data['user']);
          }
        }
        return data;
      } else {
        // Parse error response
        final errorData = json.decode(response.body);
        String errorMessage = 'Invalid OTP';
        if (errorData['detail'] != null) {
          errorMessage = errorData['detail'];
        } else if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  /// Logout user
  static Future<bool> logout() async {
    try {
      final token = await AuthStorage.getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: await _getHeaders(),
          body: json.encode({'token': token}),
        );
      }
      await AuthStorage.clearAll();
      return true;
    } catch (e) {
      print('Error logging out: $e');
      await AuthStorage.clearAll(); // Clear anyway
      return false;
    }
  }

  // ==================== TRUCKS ====================

  /// Get all trucks
  static Future<List<dynamic>> getTrucks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trucks/'),  // Added trailing slash
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching trucks: $e');
      return [];
    }
  }

  /// Add new truck
  static Future<Map<String, dynamic>?> addTruck({
    required String number,
    required String type,
    String? supplier,
    String? location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks/'),
        headers: await _getHeaders(),
        body: json.encode({
          'number': number,
          'type': type,
          'supplier': supplier,
          'location': location,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding truck: $e');
      return null;
    }
  }

  /// Get truck details
  static Future<Map<String, dynamic>?> getTruckDetails(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching truck details: $e');
      return null;
    }
  }

  /// Update truck
  static Future<bool> updateTruck({
    required int truckId,
    required String truckNumber,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: await _getHeaders(),
        body: json.encode({'number': truckNumber}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating truck: $e');
      return false;
    }
  }

  // ==================== TRIPS ====================

  /// Get all trips
  static Future<List<dynamic>> getAllTrips() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching trips: $e');
      return [];
    }
  }

  /// Get trips by truck ID
  static Future<List<dynamic>> getTripsByTruck(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips?truck_id=$truckId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching trips: $e');
      return [];
    }
  }

  /// Get trip details by trip ID
  static Future<Map<String, dynamic>?> getTripDetails(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching trip details: $e');
      return null;
    }
  }

  /// Add new trip
  static Future<Map<String, dynamic>?> addTrip({
    required int truckId,
    required String truckNumber,
    required String partyName,
    required String origin,
    required String destination,
    required String billingType,
    required String freightAmount,
    required String startDate,
    String? driverName,
    String? supplierName,
    String? supplierBillingType,
    String? truckHireCost,
    String? rate,
    String? quantity,
    String? supplierRate,
    String? supplierQuantity,
    bool sendSMS = false,
    // IDs for proper foreign key relationships
    int? partyId,
    int? driverId,
    int? supplierId,
  }) async {
    try {
      final Map<String, dynamic> tripData = {
        'truck_id': truckId,
        'truck_number': truckNumber,
        'truck_type': 'Own',  // Required field
        'party_name': partyName,
        'origin': origin,
        'destination': destination,
        'billing_type': billingType,
        'freight_amount': double.parse(freightAmount),
        'start_date': startDate,
      };

      // Add party_id if provided (preferred for proper foreign key relationship)
      if (partyId != null) {
        tripData['party_id'] = partyId;
      }

      if (driverName != null && driverName.isNotEmpty) {
        tripData['driver_name'] = driverName;
      }

      // Add driver_id if provided (preferred for proper foreign key relationship)
      if (driverId != null) {
        tripData['driver_id'] = driverId;
      }

      if (rate != null && rate.isNotEmpty) {
        tripData['rate'] = double.parse(rate);
      }
      if (quantity != null && quantity.isNotEmpty) {
        tripData['quantity'] = double.parse(quantity);
      }

      if (supplierName != null && supplierName.isNotEmpty) {
        tripData['truck_type'] = 'Market';
        tripData['supplier_name'] = supplierName;
        tripData['supplier_billing_type'] = supplierBillingType;
        tripData['truck_hire_cost'] = double.parse(truckHireCost ?? '0');
        tripData['send_sms'] = sendSMS;

        // Add supplier_id if provided (preferred for proper foreign key relationship)
        if (supplierId != null) {
          tripData['supplier_id'] = supplierId;
        }

        if (supplierRate != null && supplierRate.isNotEmpty) {
          tripData['supplier_rate'] = double.parse(supplierRate);
        }
        if (supplierQuantity != null && supplierQuantity.isNotEmpty) {
          tripData['supplier_quantity'] = double.parse(supplierQuantity);
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/trips/'),
        headers: await _getHeaders(),
        body: json.encode(tripData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip: $e');
      return null;
    }
  }

  /// Start Trip
  static Future<bool> startTrip({
    required int tripId,
    required String tripStartDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/start'),
        headers: await _getHeaders(),
        body: json.encode({'trip_start_date': tripStartDate}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error starting trip: $e');
      return false;
    }
  }

  /// Complete Trip
  static Future<bool> completeTrip({
    required int tripId,
    required String tripEndDate,
    String? totalKm,
  }) async {
    try {
      final body = {
        'trip_end_date': tripEndDate,
      };

      // Only include total_km if provided
      if (totalKm != null && totalKm.isNotEmpty) {
        body['total_km'] = totalKm;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/complete'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error completing trip: $e');
      return false;
    }
  }

  /// Delete Trip
  static Future<bool> deleteTrip(int tripId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting trip: $e');
      return false;
    }
  }

  /// POD Received
  static Future<bool> podReceived({
    required int tripId,
    required String podReceivedDate,
    required List<String> podPhotos,
  }) async {
    try {
      // Use multipart request to upload multiple images
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trips/$tripId/pod-received'),
      );

      // Add auth headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add text fields
      request.fields['pod_received_date'] = podReceivedDate;

      // Add multiple image files
      for (int i = 0; i < podPhotos.length; i++) {
        final imagePath = podPhotos[i];
        if (imagePath.isNotEmpty) {
          final file = File(imagePath);
          if (await file.exists()) {
            final multipartFile = await http.MultipartFile.fromPath(
              'pod_photos',
              imagePath,
            );
            request.files.add(multipartFile);
          }
        }
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking POD received: $e');
      return false;
    }
  }

  /// POD Submitted
  static Future<bool> podSubmitted({
    required int tripId,
    required String podSubmittedDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/pod-submitted'),
        headers: await _getHeaders(),
        body: json.encode({'pod_submitted_date': podSubmittedDate}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting POD: $e');
      return false;
    }
  }

  /// Settle Trip
  static Future<Map<String, dynamic>> settleTrip({
    required int tripId,
    required String settleAmount,
    required String settlePaymentMode,
    required String settleDate,
    String? settleNotes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/settle'),
        headers: await _getHeaders(),
        body: json.encode({
          'settle_amount': settleAmount,
          'payment_mode': settlePaymentMode,
          'settle_date': settleDate,
          'settle_notes': settleNotes,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return _parseErrorResponse(response);
      }
    } catch (e) {
      print('Error settling trip: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Add note to trip
  static Future<Map<String, dynamic>?> addTripNote({
    required int tripId,
    required String note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/notes'),
        headers: await _getHeaders(),
        body: json.encode({'note': note}),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip note: $e');
      return null;
    }
  }

  /// Add trip expense with image upload
  static Future<Map<String, dynamic>?> addTripExpense({
    required int tripId,
    required String expenseType,
    required String amount,
    required String date,
    required String paymentMode,
    String? notes,
    String? imagePath,
  }) async {
    try {
      // Use multipart request to upload image
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trips/$tripId/expenses'),
      );

      // Add auth headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add text fields
      request.fields['expense_type'] = expenseType;
      request.fields['amount'] = amount;
      request.fields['date'] = date;
      request.fields['payment_mode'] = paymentMode;

      if (notes != null) {
        request.fields['notes'] = notes;
      }

      // Add image file if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          final multipartFile = await http.MultipartFile.fromPath(
            'image',
            imagePath,
          );
          request.files.add(multipartFile);
        }
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip expense: $e');
      return null;
    }
  }

  /// Add trip advance
  static Future<Map<String, dynamic>?> addTripAdvance({
    required int tripId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/advances'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip advance: $e');
      return null;
    }
  }

  /// Add trip charge
  static Future<Map<String, dynamic>?> addTripCharge({
    required int tripId,
    required String chargeType,
    required String amount,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/charges'),
        headers: await _getHeaders(),
        body: json.encode({
          'charge_type': chargeType,
          'amount': amount,
          'date': date,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip charge: $e');
      return null;
    }
  }

  /// Add trip payment
  static Future<Map<String, dynamic>?> addTripPayment({
    required int tripId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/payments'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip payment: $e');
      return null;
    }
  }

  /// Add supplier payment
  static Future<Map<String, dynamic>?> addSupplierPayment({
    required int supplierId,
    required int tripId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/suppliers/$supplierId/trips/$tripId/payments'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding supplier payment: $e');
      return null;
    }
  }

  /// Add supplier advance (from trip details)
  static Future<Map<String, dynamic>?> addSupplierAdvanceFromTrip({
    required int tripId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/supplier-advances'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding supplier advance: $e');
      return null;
    }
  }

  /// Add supplier charge (from trip details)
  static Future<Map<String, dynamic>?> addSupplierChargeFromTrip({
    required int tripId,
    required String chargeType,
    required String amount,
    required String date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/supplier-charges'),
        headers: await _getHeaders(),
        body: json.encode({
          'charge_type': chargeType,
          'amount': amount,
          'date': date,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding supplier charge: $e');
      return null;
    }
  }

  /// Add supplier payment (from trip details)
  static Future<Map<String, dynamic>?> addSupplierPaymentFromTrip({
    required int tripId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/supplier-payments'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding supplier payment: $e');
      return null;
    }
  }

  /// Get supplier transactions (advances, charges, payments)
  static Future<Map<String, dynamic>?> getSupplierTransactions(int supplierId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/suppliers/$supplierId/transactions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get party transactions (advances, charges, payments, settlements)
  static Future<Map<String, dynamic>?> getPartyTransactions(int partyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/parties/$partyId/transactions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update supplier advance
  static Future<bool> updateSupplierAdvance({
    required int tripId,
    required int advanceId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/supplier-advances/$advanceId'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating supplier advance: $e');
      return false;
    }
  }

  /// Delete supplier advance
  static Future<bool> deleteSupplierAdvance({
    required int tripId,
    required int advanceId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/supplier-advances/$advanceId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting supplier advance: $e');
      return false;
    }
  }

  /// Update supplier charge
  static Future<bool> updateSupplierCharge({
    required int tripId,
    required int chargeId,
    required String chargeType,
    required String amount,
    required String date,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/supplier-charges/$chargeId'),
        headers: await _getHeaders(),
        body: json.encode({
          'charge_type': chargeType,
          'amount': amount,
          'date': date,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating supplier charge: $e');
      return false;
    }
  }

  /// Delete supplier charge
  static Future<bool> deleteSupplierCharge({
    required int tripId,
    required int chargeId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/supplier-charges/$chargeId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting supplier charge: $e');
      return false;
    }
  }

  /// Update supplier payment
  static Future<bool> updateSupplierPayment({
    required int tripId,
    required int paymentId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/supplier-payments/$paymentId'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating supplier payment: $e');
      return false;
    }
  }

  /// Delete supplier payment
  static Future<bool> deleteSupplierPayment({
    required int tripId,
    required int paymentId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/supplier-payments/$paymentId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting supplier payment: $e');
      return false;
    }
  }

  /// Update trip advance
  static Future<bool> updateTripAdvance({
    required int tripId,
    required int advanceId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/advances/$advanceId'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating trip advance: $e');
      return false;
    }
  }

  /// Delete trip advance
  static Future<bool> deleteTripAdvance({
    required int tripId,
    required int advanceId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/advances/$advanceId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting trip advance: $e');
      return false;
    }
  }

  /// Update trip charge
  static Future<bool> updateTripCharge({
    required int tripId,
    required int chargeId,
    required String chargeType,
    required String amount,
    required String date,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/charges/$chargeId'),
        headers: await _getHeaders(),
        body: json.encode({
          'charge_type': chargeType,
          'amount': amount,
          'date': date,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating trip charge: $e');
      return false;
    }
  }

  /// Delete trip charge
  static Future<bool> deleteTripCharge({
    required int tripId,
    required int chargeId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/charges/$chargeId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting trip charge: $e');
      return false;
    }
  }

  /// Update trip payment
  static Future<bool> updateTripPayment({
    required int tripId,
    required int paymentId,
    required String amount,
    required String date,
    required String paymentMode,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId/payments/$paymentId'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating trip payment: $e');
      return false;
    }
  }

  /// Delete trip payment
  static Future<bool> deleteTripPayment({
    required int tripId,
    required int paymentId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/payments/$paymentId'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting trip payment: $e');
      return false;
    }
  }

  /// Get trip loads (child trips)
  static Future<List<Map<String, dynamic>>> getTripLoads(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId/loads'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['loads'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching trip loads: $e');
      return [];
    }
  }

  /// Add load to trip
  static Future<Map<String, dynamic>?> addTripLoad({
    required int tripId,
    required String partyName,
    required String origin,
    required String destination,
    required String billingType,
    required String freightAmount,
    required String startDate,
    String? rate,
    String? quantity,
    String? lrNumber,
    bool sendSms = false,
    int? partyId, // ID for proper foreign key relationship
  }) async {
    try {
      final body = {
        'party_name': partyName,
        'origin': origin,
        'destination': destination,
        'billing_type': billingType,
        'freight_amount': double.tryParse(freightAmount) ?? 0.0,
        'start_date': startDate,
        'send_sms': sendSms,
      };

      // Add party_id if provided (preferred for proper foreign key relationship)
      if (partyId != null) {
        body['party_id'] = partyId;
      }

      if (rate != null && rate.isNotEmpty) {
        body['rate'] = double.tryParse(rate) ?? 0.0;
      }
      if (quantity != null && quantity.isNotEmpty) {
        body['quantity'] = double.tryParse(quantity) ?? 0.0;
      }
      if (lrNumber != null && lrNumber.isNotEmpty) {
        body['lr_number'] = lrNumber;
      }

      final url = Uri.parse('$baseUrl/trips/$tripId/loads');
      print('DEBUG addTripLoad: tripId=$tripId');
      print('DEBUG addTripLoad: baseUrl=$baseUrl');
      print('DEBUG addTripLoad: Full URL=$url');
      print('DEBUG addTripLoad: Request body=${json.encode(body)}');

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      print('DEBUG addTripLoad: Response status=${response.statusCode}');
      print('DEBUG addTripLoad: Response body=${response.body}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding trip load: $e');
      return null;
    }
  }

  /// Update trip
  static Future<bool> updateTrip({
    required int tripId,
    int? partyId, // Changed from partyName to partyId
    int? driverId, // Changed from driverName to driverId
    required String origin,
    required String destination,
    String? billingType,
    String? rate,
    String? quantity,
    required String startDate,
    required String endDate,
    required String lrNumber,
    required String freightAmount,
    String? material,
    String? totalKm,
    String? remarks,
  }) async {
    try {
      final Map<String, dynamic> tripData = {
        'origin': origin,
        'destination': destination,
        'start_date': startDate,
        'lr_number': lrNumber,
        'freight_amount': double.parse(freightAmount),
      };

      // Add optional fields if provided
      if (partyId != null) {
        tripData['party_id'] = partyId; // Send ID instead of name
      }

      if (driverId != null) {
        tripData['driver_id'] = driverId; // Send ID instead of name
      }

      // Note: truck_number is NOT sent - truck can't be changed after trip creation

      if (billingType != null && billingType.isNotEmpty) {
        tripData['billing_type'] = billingType;
      }

      if (rate != null && rate.isNotEmpty) {
        tripData['rate'] = double.parse(rate);
      }

      if (quantity != null && quantity.isNotEmpty) {
        tripData['quantity'] = double.parse(quantity);
      }

      if (material != null && material.isNotEmpty) {
        tripData['material'] = material;
      }

      if (totalKm != null && totalKm.isNotEmpty) {
        tripData['total_km'] = double.parse(totalKm);
      }

      if (remarks != null && remarks.isNotEmpty) {
        tripData['remarks'] = remarks;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: await _getHeaders(),
        body: json.encode(tripData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating trip: $e');
      return false;
    }
  }

  // ==================== PARTIES ====================

  /// Get all parties
  static Future<List<dynamic>> getParties() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/parties/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching parties: $e');
      return [];
    }
  }

  /// Add new party
  static Future<Map<String, dynamic>?> addParty({
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/parties/'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'phone': phone,
          'email': email,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding party: $e');
      return null;
    }
  }

  /// Update party details
  static Future<bool> updateParty({
    required int partyId,
    String? name,
    String? phone,
    String? email,
    String? address,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;
      if (address != null) body['address'] = address;

      final response = await http.put(
        Uri.parse('$baseUrl/parties/$partyId'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating party: $e');
      return false;
    }
  }

  /// Delete party
  static Future<bool> deleteParty({required int partyId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/parties/$partyId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting party: $e');
      return false;
    }
  }

  /// Add opening balance to party
  static Future<bool> addPartyOpeningBalance({
    required int partyId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/parties/$partyId/opening-balance'),
        headers: await _getHeaders(),
        body: json.encode({'amount': amount}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding opening balance: $e');
      return false;
    }
  }

  // ==================== SUPPLIERS ====================

  /// Get all suppliers
  static Future<List<dynamic>> getSuppliers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/suppliers/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching suppliers: $e');
      return [];
    }
  }

  /// Add new supplier
  static Future<Map<String, dynamic>?> addSupplier({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/suppliers/'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'phone': phone,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding supplier: $e');
      return null;
    }
  }

  /// Update supplier
  static Future<bool> updateSupplier({
    required int supplierId,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/suppliers/$supplierId'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (phone != null) 'phone': phone,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating supplier: $e');
      return false;
    }
  }

  /// Delete supplier (soft delete)
  static Future<bool> deleteSupplier({required int supplierId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/suppliers/$supplierId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting supplier: $e');
      return false;
    }
  }

  /// Get supplier details
  static Future<Map<String, dynamic>?> getSupplierDetails(int supplierId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/suppliers/$supplierId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching supplier details: $e');
      return null;
    }
  }

  // ==================== DRIVERS ====================

  /// Get all drivers
  static Future<List<dynamic>> getDrivers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/drivers/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching drivers: $e');
      return [];
    }
  }

  /// Add new driver
  static Future<Map<String, dynamic>?> addDriver({
    required String name,
    required String phone,
    double openingBalance = 0.0,
    bool enableSMS = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/drivers/'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'phone': phone,
          'enable_sms': enableSMS,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding driver: $e');
      return null;
    }
  }

  /// Get driver details
  static Future<Map<String, dynamic>?> getDriverDetails(int driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/drivers/$driverId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching driver details: $e');
      return null;
    }
  }

  /// Add driver balance transaction
  static Future<Map<String, dynamic>?> addDriverBalanceTransaction({
    required int driverId,
    required String type,
    required String amount,
    required String reason,
    required String date,
    String? note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/drivers/$driverId/transactions'),
        headers: await _getHeaders(),
        body: json.encode({
          'driver_id': driverId,
          'type': type,
          'amount': double.parse(amount),
          'reason': reason,
          'date': date,
          'note': note,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding driver transaction: $e');
      return null;
    }
  }

  /// Update driver
  static Future<bool> updateDriver({
    required int driverId,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$driverId'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (phone != null) 'phone': phone,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating driver: $e');
      return false;
    }
  }

  /// Delete driver (soft delete)
  static Future<bool> deleteDriver({required int driverId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/drivers/$driverId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting driver: $e');
      return false;
    }
  }

  /// Update driver transaction
  static Future<bool> updateDriverTransaction({
    required int driverId,
    required int transactionId,
    required String type,
    required double amount,
    required String reason,
    required String date,
    String? note,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$driverId/transactions/$transactionId'),
        headers: await _getHeaders(),
        body: json.encode({
          'driver_id': driverId,
          'type': type,
          'amount': amount,
          'reason': reason,
          'date': date,
          'note': note,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating driver transaction: $e');
      return false;
    }
  }

  /// Delete driver transaction
  static Future<bool> deleteDriverTransaction({
    required int driverId,
    required int transactionId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/drivers/$driverId/transactions/$transactionId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting driver transaction: $e');
      return false;
    }
  }

  /// Settle driver balance
  static Future<bool> settleDriverBalance({required int driverId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/drivers/$driverId/settle'),
        headers: await _getHeaders(),
        body: json.encode({}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error settling driver balance: $e');
      return false;
    }
  }

  /// Add driver opening balance
  static Future<bool> addDriverOpeningBalance({
    required int driverId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/drivers/$driverId/opening-balance?amount=$amount'),
        headers: await _getHeaders(),
        body: json.encode({}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding driver opening balance: $e');
      return false;
    }
  }

  // ==================== SHOPS ====================

  /// Get all shops
  static Future<List<dynamic>> getShops() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shops'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching shops: $e');
      return [];
    }
  }

  /// Add new shop
  static Future<Map<String, dynamic>?> addShop({
    required String name,
    required String phone,
    double openingBalance = 0.0,
    bool enableSMS = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shops'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'phone': phone,
          'enable_sms': enableSMS,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding shop: $e');
      return null;
    }
  }

  /// Get shop details
  static Future<Map<String, dynamic>?> getShopDetails(int shopId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shops/$shopId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching shop details: $e');
      return null;
    }
  }

  /// Add shop transaction
  static Future<Map<String, dynamic>?> addShopTransaction({
    required int shopId,
    required String type,
    required String amount,
    required String reason,
    required String date,
    String? note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/transactions'),
        headers: await _getHeaders(),
        body: json.encode({
          'shop_id': shopId,
          'type': type,
          'amount': double.parse(amount),
          'reason': reason,
          'date': date,
          'note': note,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding shop transaction: $e');
      return null;
    }
  }

  /// Update shop
  static Future<bool> updateShop({
    required int shopId,
    required String name,
    String? phone,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shops/$shopId'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          if (phone != null) 'phone': phone,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating shop: $e');
      return false;
    }
  }

  /// Delete shop (soft delete)
  static Future<bool> deleteShop({required int shopId}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shops/$shopId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting shop: $e');
      return false;
    }
  }

  /// Update shop transaction
  static Future<bool> updateShopTransaction({
    required int shopId,
    required int transactionId,
    required String type,
    required double amount,
    required String reason,
    required String date,
    String? note,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shops/$shopId/transactions/$transactionId'),
        headers: await _getHeaders(),
        body: json.encode({
          'shop_id': shopId,
          'type': type,
          'amount': amount,
          'reason': reason,
          'date': date,
          'note': note,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating shop transaction: $e');
      return false;
    }
  }

  /// Delete shop transaction
  static Future<bool> deleteShopTransaction({
    required int shopId,
    required int transactionId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/shops/$shopId/transactions/$transactionId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting shop transaction: $e');
      return false;
    }
  }

  /// Settle shop balance
  static Future<bool> settleShopBalance({required int shopId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/settle'),
        headers: await _getHeaders(),
        body: json.encode({}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error settling shop balance: $e');
      return false;
    }
  }

  /// Add shop opening balance
  static Future<bool> addShopOpeningBalance({
    required int shopId,
    required double amount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/opening-balance?amount=$amount'),
        headers: await _getHeaders(),
        body: json.encode({}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding shop opening balance: $e');
      return false;
    }
  }

  // ==================== CITIES ====================

  /// Get all cities
  static Future<List<String>> getCities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cities'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final cities = List<dynamic>.from(json.decode(response.body));
        return cities.map((city) => city['name'] as String).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching cities: $e');
      return [];
    }
  }

  // ==================== INVOICES ====================

  /// Get all invoices
  static Future<List<dynamic>> getInvoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/invoices'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching invoices: $e');
      return [];
    }
  }

  /// Get invoice by ID
  static Future<Map<String, dynamic>?> getInvoiceById(int invoiceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/invoices/$invoiceId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching invoice: $e');
      return null;
    }
  }

  /// Create new invoice
  static Future<Map<String, dynamic>?> createInvoice({
    required String invoiceNumber,
    required String partyName,
    required String partyAddress,
    required String partyGST,
    required String invoiceDate,
    required String dueDate,
    required double totalAmount,
    required double balanceAmount,
    double paidAmount = 0.0,
    required List<Map<String, dynamic>> trips,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/invoices/'),
        headers: await _getHeaders(),
        body: json.encode({
          'invoice_number': invoiceNumber,
          'party_name': partyName,
          'party_address': partyAddress,
          'party_gst': partyGST,
          'invoice_date': invoiceDate,
          'due_date': dueDate,
          'total_amount': totalAmount,
          'paid_amount': paidAmount,
          'balance_amount': balanceAmount,
          'trips': trips,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating invoice: $e');
      return null;
    }
  }

  // ==================== COLLECTION REMINDERS ====================

  /// Get all collection reminders
  static Future<List<dynamic>> getCollectionReminders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collection-reminders'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching collection reminders: $e');
      return [];
    }
  }

  /// Get collection reminder by ID
  static Future<Map<String, dynamic>?> getCollectionReminderById(int reminderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collection-reminders/$reminderId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching collection reminder: $e');
      return null;
    }
  }

  /// Create collection reminder
  static Future<Map<String, dynamic>?> createCollectionReminder({
    String type = 'collection',
    required String partyName,
    required String partyPhone,
    required String partyEmail,
    required double outstandingAmount,
    required String dueDate,
    required int daysPastDue,
    required String invoiceNumber,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collection-reminders/'),
        headers: await _getHeaders(),
        body: json.encode({
          'type': type,
          'party_name': partyName,
          'party_phone': partyPhone,
          'party_email': partyEmail,
          'outstanding_amount': outstandingAmount,
          'due_date': dueDate,
          'days_past_due': daysPastDue,
          'invoice_number': invoiceNumber,
          'notes': notes,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating collection reminder: $e');
      return null;
    }
  }

  /// Send collection reminder
  static Future<bool> sendCollectionReminder(int reminderId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collection-reminders/$reminderId/send'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error sending collection reminder: $e');
      return false;
    }
  }

  // ==================== EXPENSES ====================

  /// Get expenses by truck ID
  static Future<List<dynamic>> getExpenses(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/expenses/?truck_id=$truckId'),  // Added trailing slash
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching expenses: $e');
      return [];
    }
  }

  /// Add new expense
  static Future<Map<String, dynamic>?> addExpense(Map<String, dynamic> expenseData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expenses/'),  // Added trailing slash
        headers: await _getHeaders(),
        body: json.encode(expenseData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding expense: $e');
      return null;
    }
  }

  /// Get my expenses
  static Future<List<dynamic>> getMyExpenses({
    String? category,
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '$baseUrl/expenses/my-expenses/';
      List<String> params = [];
      if (category != null) params.add('category=$category');
      if (startDate != null) params.add('date_from=$startDate');
      if (endDate != null) params.add('date_to=$endDate');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching my expenses: $e');
      return [];
    }
  }

  /// Add my expense
  static Future<Map<String, dynamic>?> addMyExpense({
    required String category,
    required String expenseType,
    required String amount,
    required String paymentMode,
    required String date,
    String? truckNumber,
    int? tripId,
    String? note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expenses/my-expenses/'),
        headers: await _getHeaders(),
        body: json.encode({
          'category': category,
          'expenseType': expenseType,
          'amount': double.parse(amount),
          'paymentMode': paymentMode,
          'date': date,
          if (truckNumber != null) 'truckNumber': truckNumber,
          if (tripId != null) 'tripId': tripId,
          if (note != null) 'note': note,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding my expense: $e');
      return null;
    }
  }

  /// Delete expense (Diesel/Maintenance)
  static Future<bool> deleteExpense(int expenseId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/$expenseId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }

  /// Delete my expense (Truck/Trip/Office)
  static Future<bool> deleteMyExpense(int expenseId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/my-expenses/$expenseId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting my expense: $e');
      return false;
    }
  }

  /// Update expense (Diesel/Maintenance)
  static Future<Map<String, dynamic>?> updateExpense(int expenseId, Map<String, dynamic> expenseData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/expenses/$expenseId'),
        headers: await _getHeaders(),
        body: json.encode(expenseData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating expense: $e');
      return null;
    }
  }

  /// Update my expense (Truck/Trip/Office)
  static Future<Map<String, dynamic>?> updateMyExpense(int expenseId, Map<String, dynamic> expenseData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/expenses/my-expenses/$expenseId'),
        headers: await _getHeaders(),
        body: json.encode(expenseData),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating my expense: $e');
      return null;
    }
  }

  // ==================== DOCUMENTS ====================

  /// Get documents by truck ID
  static Future<List<dynamic>> getDocuments(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents?truck_id=$truckId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching documents: $e');
      return [];
    }
  }

  /// Get all documents (without truck filter)
  static Future<List<dynamic>> getAllDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching all documents: $e');
      return [];
    }
  }

  /// Add new document
  static Future<Map<String, dynamic>?> addDocument({
    required int truckId,
    required String name,
    required String expiryDate,
    String? documentNumber,
    String? issueDate,
    String? imagePath,
    String status = 'Active',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: await _getHeaders(),
        body: json.encode({
          'truck_id': truckId,
          'name': name,
          'expiry_date': expiryDate,
          if (documentNumber != null) 'document_number': documentNumber,
          if (issueDate != null) 'issue_date': issueDate,
          if (imagePath != null) 'image_path': imagePath,
          'status': status,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding document: $e');
      return null;
    }
  }

  /// Update document
  static Future<Map<String, dynamic>?> updateDocument({
    required int documentId,
    String? name,
    String? documentNumber,
    String? issueDate,
    String? expiryDate,
    String? status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: await _getHeaders(),
        body: json.encode({
          if (name != null) 'name': name,
          if (documentNumber != null) 'document_number': documentNumber,
          if (issueDate != null) 'issue_date': issueDate,
          if (expiryDate != null) 'expiry_date': expiryDate,
          if (status != null) 'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating document: $e');
      return null;
    }
  }

  /// Delete document
  static Future<bool> deleteDocument(int documentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  // ==================== EMIS ====================

  /// Get EMIs by truck ID
  static Future<List<dynamic>> getEmis(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/emis?truck_id=$truckId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching EMIs: $e');
      return [];
    }
  }

  /// Add new EMI
  static Future<Map<String, dynamic>?> addEmi({
    required int truckId,
    required String loanProvider,
    required String loanAmount,
    required String emiAmount,
    required String totalEmis,
    required String nextDueDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/emis'),
        headers: await _getHeaders(),
        body: json.encode({
          'truck_id': truckId,
          'loan_provider': loanProvider,
          'loan_amount': double.parse(loanAmount),
          'emi_amount': double.parse(emiAmount),
          'total_emis': int.parse(totalEmis),
          'remaining_emis': int.parse(totalEmis),
          'next_due_date': nextDueDate,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding EMI: $e');
      return null;
    }
  }

  // ==================== REPORTS ====================

  /// Get truck revenue report
  static Future<Map<String, dynamic>?> getTruckRevenueReport() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/truck-revenue'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching truck revenue report: $e');
      return null;
    }
  }

  /// Get truck monthly profit & loss report
  static Future<Map<String, dynamic>?> getTruckMonthlyProfitLoss(int truckId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/trucks/$truckId/profit-loss-monthly'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching truck monthly profit/loss report: $e');
      return null;
    }
  }

  /// Get party revenue report
  static Future<Map<String, dynamic>?> getPartyRevenueReport() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/party-revenue'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching party revenue report: $e');
      return null;
    }
  }

  /// Get profit/loss report
  static Future<Map<String, dynamic>?> getProfitLossReport() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports/profit-loss'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching profit/loss report: $e');
      return null;
    }
  }

  // ==================== LORRY RECEIPT (LR) ====================

  /// Create lorry receipt
  static Future<Map<String, dynamic>?> createLorryReceipt({
    required int tripId,
    required String lrNumber,
    required String lrDate,
    String? companyName,
    String? companyGst,
    String? companyPan,
    String? companyAddress1,
    String? companyAddress2,
    String? companyPincode,
    String? companyState,
    String? companyMobile,
    String? companyEmail,
    String? consignorGst,
    required String consignorName,
    String? consignorAddress1,
    String? consignorAddress2,
    String? consignorState,
    String? consignorPincode,
    String? consignorMobile,
    String? consigneeGst,
    required String consigneeName,
    String? consigneeAddress1,
    String? consigneeAddress2,
    String? consigneeState,
    String? consigneePincode,
    String? consigneeMobile,
    String? materialDescription,
    String? totalPackages,
    String? actualWeight,
    String? chargedWeight,
    String? declaredValue,
    String? freightAmount,
    String? gstAmount,
    String? otherCharges,
    String? paymentTerms,
    String? paidBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lorry-receipts/'),
        headers: await _getHeaders(),
        body: json.encode({
          'trip_id': tripId,
          'lr_number': lrNumber,
          'lr_date': lrDate,
          'company_name': companyName,
          'company_gst': companyGst,
          'company_pan': companyPan,
          'company_address_line1': companyAddress1,
          'company_address_line2': companyAddress2,
          'company_pincode': companyPincode,
          'company_state': companyState,
          'company_mobile': companyMobile,
          'company_email': companyEmail,
          'consignor_gst': consignorGst,
          'consignor_name': consignorName,
          'consignor_address_line1': consignorAddress1,
          'consignor_address_line2': consignorAddress2,
          'consignor_state': consignorState,
          'consignor_pincode': consignorPincode,
          'consignor_mobile': consignorMobile,
          'consignee_gst': consigneeGst,
          'consignee_name': consigneeName,
          'consignee_address_line1': consigneeAddress1,
          'consignee_address_line2': consigneeAddress2,
          'consignee_state': consigneeState,
          'consignee_pincode': consigneePincode,
          'consignee_mobile': consigneeMobile,
          'material_description': materialDescription,
          'total_packages': totalPackages != null && totalPackages.isNotEmpty ? int.parse(totalPackages) : null,
          'actual_weight': actualWeight != null && actualWeight.isNotEmpty ? double.parse(actualWeight) : null,
          'charged_weight': chargedWeight != null && chargedWeight.isNotEmpty ? double.parse(chargedWeight) : null,
          'declared_value': declaredValue != null && declaredValue.isNotEmpty ? double.parse(declaredValue) : null,
          'freight_amount': freightAmount != null && freightAmount.isNotEmpty ? double.parse(freightAmount) : null,
          'gst_amount': gstAmount != null && gstAmount.isNotEmpty ? double.parse(gstAmount) : null,
          'other_charges': otherCharges != null && otherCharges.isNotEmpty ? double.parse(otherCharges) : null,
          'payment_terms': paymentTerms,
          'paid_by': paidBy,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating lorry receipt: $e');
      return null;
    }
  }

  /// Get all lorry receipts for a trip
  static Future<List<dynamic>> getTripLorryReceipts(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lorry-receipts/?trip_id=$tripId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print('Error fetching trip lorry receipts: $e');
      return [];
    }
  }

  /// Get lorry receipt by ID
  static Future<Map<String, dynamic>?> getLorryReceipt(int lrId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lorry-receipts/$lrId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching lorry receipt: $e');
      return null;
    }
  }

  /// Delete lorry receipt
  static Future<bool> deleteLorryReceipt(int lrId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/lorry-receipts/$lrId'),
        headers: await _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting lorry receipt: $e');
      return false;
    }
  }

  // ==================== POD PHOTOS ====================

  /// Upload POD photos for a trip
  static Future<Map<String, dynamic>?> uploadPODPhotos({
    required int tripId,
    required List<String> imagePaths,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/trips/$tripId/pod-photos');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add image files
      for (String path in imagePaths) {
        final file = await http.MultipartFile.fromPath('files', path);
        request.files.add(file);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error uploading POD photos: $e');
      return null;
    }
  }

  /// Get POD photos for a trip
  static Future<List<String>> getPODPhotos(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId/pod-photos'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['podPhotos'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching POD photos: $e');
      return [];
    }
  }

  // ==================== LORRY RECEIPT (LR) ====================

  /// Get LR by trip ID
  static Future<Map<String, dynamic>?> getLRByTripId(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lorry-receipts/?trip_id=$tripId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> lrs = json.decode(response.body);
        // Return first LR for this trip (there should only be one)
        if (lrs.isNotEmpty) {
          return lrs.first as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching LR: $e');
      return null;
    }
  }

  /// Get LR by ID
  static Future<Map<String, dynamic>?> getLR(int lrId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lorry-receipts/$lrId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching LR: $e');
      return null;
    }
  }

  /// Create LR
  static Future<Map<String, dynamic>?> createLR(Map<String, dynamic> lrData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lorry-receipts/'),
        headers: await _getHeaders(),
        body: json.encode(lrData),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating LR: $e');
      return null;
    }
  }
}
