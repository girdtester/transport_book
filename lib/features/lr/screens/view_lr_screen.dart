import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../utils/app_colors.dart';
import 'package:transport_book_app/utils/toast_helper.dart';
import 'package:transport_book_app/utils/app_loader.dart';

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
  bool _isGeneratingPdf = false;
  Map<String, dynamic>? _lrData;

  @override
  void initState() {
    super.initState();
    _loadLRDetails();
  }

  // Generate PDF for LR
  Future<Uint8List> _generateLRPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'LORRY RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // LR Details Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('LR Number: ${_lrData?['lrNumber'] ?? 'N/A'}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('LR Date: ${_lrData?['lrDate'] ?? 'N/A'}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Status: ${_lrData?['status'] ?? 'N/A'}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Company Details
              pw.Text('COMPANY DETAILS',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Text(_lrData?['companyName'] ?? 'N/A'),
              pw.Text('GST: ${_lrData?['companyGst'] ?? 'N/A'}'),
              pw.Text('${_lrData?['companyAddressLine1'] ?? ''} ${_lrData?['companyAddressLine2'] ?? ''}'),
              pw.Text('${_lrData?['companyState'] ?? ''} - ${_lrData?['companyPincode'] ?? ''}'),
              pw.Text('Mobile: ${_lrData?['companyMobile'] ?? 'N/A'}'),
              pw.SizedBox(height: 15),

              // Consignor and Consignee
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CONSIGNOR (FROM)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 5),
                        pw.Text(_lrData?['consignorName'] ?? 'N/A'),
                        pw.Text('GST: ${_lrData?['consignorGst'] ?? 'N/A'}'),
                        pw.Text('${_lrData?['consignorAddressLine1'] ?? ''}'),
                        pw.Text('${_lrData?['consignorState'] ?? ''} - ${_lrData?['consignorPincode'] ?? ''}'),
                        pw.Text('Mobile: ${_lrData?['consignorMobile'] ?? 'N/A'}'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CONSIGNEE (TO)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 5),
                        pw.Text(_lrData?['consigneeName'] ?? 'N/A'),
                        pw.Text('GST: ${_lrData?['consigneeGst'] ?? 'N/A'}'),
                        pw.Text('${_lrData?['consigneeAddressLine1'] ?? ''}'),
                        pw.Text('${_lrData?['consigneeState'] ?? ''} - ${_lrData?['consigneePincode'] ?? ''}'),
                        pw.Text('Mobile: ${_lrData?['consigneeMobile'] ?? 'N/A'}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Goods Details
              pw.Text('GOODS DETAILS',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Material: ${_lrData?['materialDescription'] ?? 'N/A'}')),
                  pw.Expanded(child: pw.Text('Packages: ${_lrData?['totalPackages'] ?? 'N/A'}')),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Actual Weight: ${_lrData?['actualWeight'] ?? 'N/A'} kg')),
                  pw.Expanded(child: pw.Text('Charged Weight: ${_lrData?['chargedWeight'] ?? 'N/A'} kg')),
                ],
              ),
              pw.Text('Declared Value: ₹${_lrData?['declaredValue'] ?? '0'}'),
              pw.SizedBox(height: 15),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Charges
              pw.Text('CHARGES',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Freight Amount:'),
                  pw.Text('₹${_lrData?['freightAmount'] ?? '0'}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GST Amount:'),
                  pw.Text('₹${_lrData?['gstAmount'] ?? '0'}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Other Charges:'),
                  pw.Text('₹${_lrData?['otherCharges'] ?? '0'}'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('₹${_lrData?['totalAmount'] ?? '0'}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 15),

              // Payment Terms
              pw.Row(
                children: [
                  pw.Text('Payment Terms: ${_lrData?['paymentTerms'] ?? 'N/A'}'),
                  pw.SizedBox(width: 30),
                  pw.Text('Paid By: ${_lrData?['paidBy'] ?? 'N/A'}'),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              pw.Center(
                child: pw.Text(
                  'This is a computer generated document.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Download PDF
  Future<void> _downloadPdf() async {
    if (_lrData == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await _generateLRPdf();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/LR_${_lrData!['lrNumber'] ?? widget.lrId}.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        ToastHelper.showSnackBarToast(context,
          SnackBar(
            content: Text('PDF saved to ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showSnackBarToast(context,
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // Share PDF
  Future<void> _sharePdf() async {
    if (_lrData == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await _generateLRPdf();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/LR_${_lrData!['lrNumber'] ?? widget.lrId}.pdf');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lorry Receipt - ${_lrData!['lrNumber'] ?? ''}',
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showSnackBarToast(context,
          SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
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
          ToastHelper.showSnackBarToast(context, 
            SnackBar(content: Text('Failed to load LR details: ${response.statusCode}')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error loading LR details: $e');
      if (mounted) {
        ToastHelper.showSnackBarToast(context, 
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
          ? const Center(child: AppLoader())
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
                    ],
                  ),
                ),
      bottomNavigationBar: _lrData != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _downloadPdf,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _sharePdf,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
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


