import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String phone;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.phone,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());

  int _secondsRemaining = 27;
  Timer? _timer;
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    startTimer();
    for (var controller in _otpControllers) {
      controller.addListener(_checkOTPComplete);
    }
  }

  void _checkOTPComplete() {
    final isComplete = _otpControllers.every((controller) => controller.text.isNotEmpty);
    setState(() {
      _isButtonEnabled = isComplete;
    });

    // Auto-submit when all 4 digits are entered
    if (isComplete && !_isLoading) {
      _verifyOTP();
    }
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);

    final otp = _otpControllers.map((c) => c.text).join();

    try {
      final response = await ApiService.verifyOTP(widget.phone, otp);

      if (!mounted) return;

      if (response['success'] == true) {
        // Save login state - FastAPI returns data directly, not in 'data' wrapper
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', response['token']);
        await prefs.setString('refresh_token', response['refresh_token']);
        await prefs.setString('tenant_id', response['tenant_id']);
        await prefs.setString('user_id', response['user']['id'].toString());
        await prefs.setString('phone', response['user']['phone']);
        // Save business name (use business_name from response, fallback to user name)
        final businessName = response['business_name'] ?? response['user']['name'];
        await prefs.setString('user_name', businessName);
        await prefs.setString('user_role', response['user']['role']);
        // Save owner name if provided
        if (response['owner_name'] != null) {
          await prefs.setString('owner_name', response['owner_name']);
        }

        // Navigate to dashboard and remove all previous routes (login, OTP)
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      } else {
        // Show error and clear OTP
        ToastHelper.showSnackBarToast(context, 
          SnackBar(
            content: Text(response['message'] ?? 'Invalid OTP'),
            backgroundColor: Colors.red,
          ),
        );
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(
          content: Text('Network error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 27;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _resendOTP() async {
    if (!_canResend || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.verifyPhone(widget.phone);

      if (!mounted) return;

      if (response['success'] == true) {
        ToastHelper.showSnackBarToast(context, 
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        startTimer();
      } else {
        ToastHelper.showSnackBarToast(context, 
          SnackBar(
            content: Text(response['message'] ?? 'Failed to send OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showSnackBarToast(context, 
        const SnackBar(
          content: Text('Network error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      resizeToAvoidBottomInset: true, // IMPORTANT FIX
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.04),

            // ------------------ TOP LOGO + TITLE ------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping,
                  size: size.height * 0.06,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Transport",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width * 0.075,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: "Book",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size.width * 0.075,
                          fontWeight: FontWeight.w100,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: size.height * 0.03),

            // ------------------ CONTENT CARD (Scroll Fix) ------------------
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "OTP verification",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ------- SMS SENT TO ------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "SMS sent to ",
                            style: TextStyle(
                                fontSize: 14, color: AppColors.appBarTextColor),
                          ),
                          Text(
                            widget.phoneNumber,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.edit,
                              color: AppColors.primaryGreen,
                              size: 16,
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ------------------ OTP BOXES ------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            width: 58,
                            height: 58,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderActive,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 3) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 22),

                      // ------------------ TIMER ------------------
                      Text(
                        "Enter the OTP  00:${_secondsRemaining.toString().padLeft(2, '0')}s",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ------------------ RESEND OTP ------------------
                      TextButton(
                        onPressed:
                            _canResend && !_isLoading ? _resendOTP : null,
                        child: Text(
                          "Resend OTP",
                          style: TextStyle(
                            fontSize: 14,
                            color: _canResend
                                ? AppColors.primaryGreen
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ------------------ CONFIRM OTP BUTTON ------------------
                      ElevatedButton(
                        onPressed:
                            _isButtonEnabled && !_isLoading ? _verifyOTP : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isButtonEnabled
                              ? AppColors.buttonPrimary
                              : AppColors.buttonDisabled,
                          minimumSize: const Size(double.infinity, 52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: AppLoader(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                "Confirm OTP",
                                style: TextStyle(
                                  color: _isButtonEnabled
                                      ? Colors.white
                                      : AppColors.textDisabled,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),

                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}


