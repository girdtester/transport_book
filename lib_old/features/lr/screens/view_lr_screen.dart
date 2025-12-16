import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../utils/app_colors.dart';

class ViewLRScreen extends StatefulWidget {
  final int lrId;

  const ViewLRScreen({
    super.key,
    required this.lrId,
  });

  @override
  State<ViewLRScreen> createState() => _ViewLRScreenState();
}

class _ViewLRScreenState extends State<ViewLRScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _lrData;

  @override
  void initState() {
    super.initState();
    _loadLRDetails();
  }

  Future<void> _loadLRDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/lorry-receipts/${widget.lrId}'),
        headers: await AuthStorage.getAuthHeaders(),
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _lrData = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load LR details: ${response.statusCode}')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error loading LR details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading LR details: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LR Details #${widget.lrId}'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lrData == null
              ? const Center(child: Text('No data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('LR Information', [
                        _buildInfoRow('LR Number', _lrData!['lrNumber'] ?? 'N/A'),
                        _buildInfoRow('LR Date', _lrData!['lrDate'] ?? 'N/A'),
                        _buildInfoRow('Status', _lrData!['status'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Company Details', [
                        _buildInfoRow('Name', _lrData!['companyName'] ?? 'N/A'),
                        _buildInfoRow('GST', _lrData!['companyGst'] ?? 'N/A'),
                        _buildInfoRow('PAN', _lrData!['companyPan'] ?? 'N/A'),
                        _buildInfoRow('Address',
                          '${_lrData!['companyAddressLine1'] ?? ''}\n${_lrData!['companyAddressLine2'] ?? ''}'.trim()),
                        _buildInfoRow('State', _lrData!['companyState'] ?? 'N/A'),
                        _buildInfoRow('Pincode', _lrData!['companyPincode'] ?? 'N/A'),
                        _buildInfoRow('Mobile', _lrData!['companyMobile'] ?? 'N/A'),
                        _buildInfoRow('Email', _lrData!['companyEmail'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Consignor (From)', [
                        _buildInfoRow('Name', _lrData!['consignorName'] ?? 'N/A'),
                        _buildInfoRow('GST', _lrData!['consignorGst'] ?? 'N/A'),
                        _buildInfoRow('Address',
                          '${_lrData!['consignorAddressLine1'] ?? ''}\n${_lrData!['consignorAddressLine2'] ?? ''}'.trim()),
                        _buildInfoRow('State', _lrData!['consignorState'] ?? 'N/A'),
                        _buildInfoRow('Pincode', _lrData!['consignorPincode'] ?? 'N/A'),
                        _buildInfoRow('Mobile', _lrData!['consignorMobile'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Consignee (To)', [
                        _buildInfoRow('Name', _lrData!['consigneeName'] ?? 'N/A'),
                        _buildInfoRow('GST', _lrData!['consigneeGst'] ?? 'N/A'),
                        _buildInfoRow('Address',
                          '${_lrData!['consigneeAddressLine1'] ?? ''}\n${_lrData!['consigneeAddressLine2'] ?? ''}'.trim()),
                        _buildInfoRow('State', _lrData!['consigneeState'] ?? 'N/A'),
                        _buildInfoRow('Pincode', _lrData!['consigneePincode'] ?? 'N/A'),
                        _buildInfoRow('Mobile', _lrData!['consigneeMobile'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Goods Details', [
                        _buildInfoRow('Material', _lrData!['materialDescription'] ?? 'N/A'),
                        _buildInfoRow('Total Packages', _lrData!['totalPackages']?.toString() ?? 'N/A'),
                        _buildInfoRow('Actual Weight', _lrData!['actualWeight'] ?? 'N/A'),
                        _buildInfoRow('Charged Weight', _lrData!['chargedWeight'] ?? 'N/A'),
                        _buildInfoRow('Declared Value', _lrData!['declaredValue'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Charges', [
                        _buildInfoRow('Freight Amount', '₹${_lrData!['freightAmount'] ?? '0'}'),
                        _buildInfoRow('GST Amount', '₹${_lrData!['gstAmount'] ?? '0'}'),
                        _buildInfoRow('Other Charges', '₹${_lrData!['otherCharges'] ?? '0'}'),
                        _buildInfoRow('Total Amount', '₹${_lrData!['totalAmount'] ?? '0'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                      const SizedBox(height: 16),
                      _buildSection('Payment & Delivery', [
                        _buildInfoRow('Payment Terms', _lrData!['paymentTerms'] ?? 'N/A'),
                        _buildInfoRow('Paid By', _lrData!['paidBy'] ?? 'N/A'),
                        _buildInfoRow('Delivery Instructions', _lrData!['deliveryInstructions'] ?? 'N/A'),
                        _buildInfoRow('Remarks', _lrData!['remarks'] ?? 'N/A'),
                      ]),
                      const SizedBox(height: 24),
                      if (_lrData!['pdfUrl'] != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Open PDF
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PDF viewing not implemented yet')),
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('View PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: style ?? const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
