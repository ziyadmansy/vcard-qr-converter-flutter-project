// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactItemCard extends StatelessWidget {
  final Contact contact;
  const ContactItemCard({
    super.key,
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(contact.displayName),
      subtitle: Text(contact.phones.first.number),
      leading: CircleAvatar(
        radius: 25,
        child: Text(
          contact.displayName[0],
        ),
      ),
    );
  }
}
