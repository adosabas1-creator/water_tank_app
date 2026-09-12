import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerService {
  static Future<Contact?> pickContact() async {
    final permission =
        await FlutterContacts.permissions.request(PermissionType.read);

    if (permission != PermissionStatus.granted) {
      return null;
    }

    return FlutterContacts.native.showPicker(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
      },
    );
  }
}
