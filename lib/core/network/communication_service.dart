import 'package:url_launcher/url_launcher.dart';

class CommunicationService {
  static Future<void> callPhone(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> sendSMS(String phone, String message) async {
    final Uri url = Uri(scheme: 'sms', path: phone, query: 'body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> openWhatsApp(String phone, String message) async {
    final String formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    final Uri url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
