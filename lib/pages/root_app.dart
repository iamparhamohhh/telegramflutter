import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chats_page.dart';
import 'package:telegramflutter/pages/contact_page.dart';
import 'package:telegramflutter/pages/setting_page.dart';
import 'package:telegramflutter/theme/colors.dart';

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  int _pageIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: getFooter(),
      body: getBody(),
    );
  }

  Widget getBody() {
    return IndexedStack(
      index: _pageIndex,
      children: const [ContactPage(), ChatPage(), SettingPage()],
    );
  }

  Widget getFooter() {
    const List<IconData> iconItems = [
      Icons.account_circle,
      Icons.chat_bubble,
      Icons.settings,
    ];
    const List<String> textItems = ['Contacts', 'Chats', 'Settings'];

    return Container(
      height: 90,
      width: double.infinity,
      decoration: const BoxDecoration(color: greyColor),
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(iconItems.length, (index) {
            final bool isSelected = _pageIndex == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _pageIndex = index;
                });
              },
              child: Column(
                children: [
                  if (index == 1)
                    badges.Badge(
                      badgeContent: const Text(
                        '3',
                        style: TextStyle(color: white),
                      ),
                      child: Icon(
                        iconItems[index],
                        size: 30,
                        color: isSelected ? primary : white.withOpacity(0.5),
                      ),
                    )
                  else
                    Icon(
                      iconItems[index],
                      size: 30,
                      color: isSelected ? primary : white.withOpacity(0.5),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    textItems[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? primary : white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
