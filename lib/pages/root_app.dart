import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chats_page.dart';
import 'package:telegramflutter/pages/contacts_page.dart';
import 'package:telegramflutter/pages/setting_page.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  int _pageIndex = 0;
  final TelegramService _telegramService = TelegramService();
  StreamSubscription<int>? _unreadSub;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    _totalUnread = _telegramService.totalUnreadCount;
    _unreadSub = _telegramService.unreadCountStream.listen((count) {
      if (mounted) setState(() => _totalUnread = count);
    });
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      bottomNavigationBar: getFooter(),
      body: getBody(),
    );
  }

  Widget getBody() {
    return IndexedStack(
      index: _pageIndex,
      children: const [ContactsPage(), ChatPage(), SettingPage()],
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
      decoration: BoxDecoration(color: context.surface),
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
                  if (index == 1 && _totalUnread > 0)
                    badges.Badge(
                      badgeContent: Text(
                        _totalUnread > 99 ? '99+' : _totalUnread.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      child: Icon(
                        iconItems[index],
                        size: 30,
                        color: isSelected
                            ? primary
                            : context.onSurfaceSecondary,
                      ),
                    )
                  else
                    Icon(
                      iconItems[index],
                      size: 30,
                      color: isSelected ? primary : context.onSurfaceSecondary,
                    ),
                  const SizedBox(height: 3),
                  Text(
                    textItems[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? primary : context.onSurfaceSecondary,
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
