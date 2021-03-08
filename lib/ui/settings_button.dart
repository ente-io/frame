import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photos/ui/password_entry_page.dart';
import 'package:photos/ui/settings_page.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: Icon(
          Icons.settings,
          color: Colors.white.withOpacity(0.4),
        ),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
        onPressed: () async {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return PasswordEntryPage();
                // return SettingsPage();
              },
            ),
          );
        },
      ),
    );
  }
}
