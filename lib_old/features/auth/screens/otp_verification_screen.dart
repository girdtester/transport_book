import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../../utils/app_colors.dart';
import '../../../services/api_service.dart';

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
        await prefs.setString('user_name', response['user']['name']);
        await prefs.setString('user_role', response['user']['role']);

        // Navigate to dashboard
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
        }
      } else {
        // Show error and clear OTP
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        startTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to send OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(
          children: [
            // Logo and Title
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 40,
                    color: Color(0xFF2E8B57),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'TMS Prime',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // OTP Verification Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'OTP verification',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Phone Number with Edit Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SMS sent to ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.phoneNumber,
                          style: const TextStyle(
                            color: Color(0xFF2E8B57),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFF2E8B57),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // OTP Input Boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.borderActive,
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.borderActive,
                                  width: 2,
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
                    const SizedBox(height: 24),
                    // Timer
                    Text(
                      'Enter the OTP  00:${_secondsRemaining.toString().padLeft(2, '0')}s',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Resend OTP
                    Center(
                      child: TextButton(
                        onPressed: _canResend && !_isLoading ? _resendOTP : null,
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: _canResend ? const Color(0xFF2E8B57) : Colors.grey,
                            fontSize: 14,
                            fontWeight: _canResend ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Confirm OTP Button
                    ElevatedButton(
                      onPressed: _isButtonEnabled && !_isLoading ? _verifyOTP : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isButtonEnabled
                            ? AppColors.buttonPrimary
                            : AppColors.buttonDisabled,
                        minimumSize: const Size(double.infinity, 56),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.buttonDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Confirm OTP',
                              style: TextStyle(
                                color: _isButtonEnabled
                                    ? AppColors.textWhite
                                    : AppColors.textDisabled,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
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
