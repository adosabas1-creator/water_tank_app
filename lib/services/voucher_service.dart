import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/payment.dart';

class VoucherService {
  static String voucherTitle(String paymentType) {
    return paymentType == 'client_payment' ? 'سند قبض' : 'سند صرف';
  }

  static String accountTitle(String paymentType) {
    return paymentType == 'client_payment' ? 'العميل' : 'المورد';
  }

  static String voucherNumber(Payment payment) {
    final key = payment.paymentKey.trim().isNotEmpty
        ? payment.paymentKey.trim()
        : payment.syncId.trim();

    return key;
  }

  static String paymentMethodText(String? method) {
    switch (method) {
      case 'cash':
      case 'نقدي':
        return 'نقدي';
      case 'transfer':
      case 'تحويل':
        return 'تحويل بنكي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'hawala':
        return 'حوالة';
      case 'other':
      case 'أخرى':
        return 'أخرى';
      default:
        return method?.trim().isNotEmpty == true ? method!.trim() : 'غير محدد';
    }
  }

  static Future<Uint8List> buildPdf({
    required Payment payment,
    required String accountName,
    String? accountPhone,
    String? createdByName,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Cairo-Bold.ttf'),
    );

    final document = pw.Document();
    final title = voucherTitle(payment.paymentType);
    final accountLabel = accountTitle(payment.paymentType);

    final baseStyle = pw.TextStyle(
      font: regularFont,
      fontSize: 11,
    );

    final boldStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 11,
    );

    final titleStyle = pw.TextStyle(
      font: boldFont,
      fontSize: 24,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.DefaultTextStyle(
              style: baseStyle,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Water Tank App',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      title,
                      style: titleStyle,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        _row(
                          'رقم السند',
                          voucherNumber(payment),
                          boldStyle,
                          baseStyle,
                        ),
                        _row(
                          'التاريخ',
                          _dateOnly(payment.paymentDate),
                          boldStyle,
                          baseStyle,
                        ),
                        _row(
                          accountLabel,
                          accountName,
                          boldStyle,
                          baseStyle,
                        ),
                        if (accountPhone != null &&
                            accountPhone.trim().isNotEmpty)
                          _row(
                            'الهاتف',
                            accountPhone.trim(),
                            boldStyle,
                            baseStyle,
                          ),
                        _row(
                          'المبلغ',
                          '${payment.amount.toStringAsFixed(2)} ريال',
                          boldStyle,
                          baseStyle,
                        ),
                        _row(
                          'طريقة الدفع',
                          paymentMethodText(payment.paymentMethod),
                          boldStyle,
                          baseStyle,
                        ),
                        if (payment.referenceNumber != null &&
                            payment.referenceNumber!.trim().isNotEmpty)
                          _row(
                            'رقم الحوالة / التحويل',
                            payment.referenceNumber!.trim(),
                            boldStyle,
                            baseStyle,
                          ),
                        if (payment.notes != null &&
                            payment.notes!.trim().isNotEmpty)
                          _row(
                            'ملاحظات',
                            payment.notes!.trim(),
                            boldStyle,
                            baseStyle,
                          ),
                        if (createdByName != null &&
                            createdByName.trim().isNotEmpty)
                          _row(
                            'المستخدم',
                            createdByName.trim(),
                            boldStyle,
                            baseStyle,
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            'المستلم / المسلم',
                            style: boldStyle,
                          ),
                          pw.SizedBox(height: 35),
                          pw.Container(width: 140, height: 1),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            'التوقيع',
                            style: boldStyle,
                          ),
                          pw.SizedBox(height: 35),
                          pw.Container(width: 140, height: 1),
                        ],
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Center(
                    child: pw.Text(
                      'تم إنشاء السند بواسطة Water Tank App',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return document.save();
  }

  static Future<void> printVoucher({
    required Payment payment,
    required String accountName,
    String? accountPhone,
    String? createdByName,
  }) async {
    final bytes = await buildPdf(
      payment: payment,
      accountName: accountName,
      accountPhone: accountPhone,
      createdByName: createdByName,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareVoucher({
    required Payment payment,
    required String accountName,
    String? accountPhone,
    String? createdByName,
  }) async {
    final bytes = await buildPdf(
      payment: payment,
      accountName: accountName,
      accountPhone: accountPhone,
      createdByName: createdByName,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          '${voucherTitle(payment.paymentType)}_${voucherNumber(payment)}.pdf',
    );
  }

  static pw.Widget _row(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: labelStyle,
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }

  static String _dateOnly(String value) {
    final index = value.indexOf('T');
    return index > 0 ? value.substring(0, index) : value;
  }
}
