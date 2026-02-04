import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:telegramflutter/json/chat_json.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/chat_bubble.dart';

class ChatDetailPage extends StatefulWidget {
  final String name;
  final String img;

  const ChatDetailPage({super.key, required this.name, required this.img});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        child: getAppBar(),
        preferredSize: Size.fromHeight(60),
      ),
      bottomNavigationBar: getBottomBar(),
      body: getBody(),
    );
  }

  Widget getAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: greyColor,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 17,
              color: white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'last seen recently',
            style: TextStyle(fontSize: 12, color: white.withOpacity(0.4)),
          ),
        ],
      ),
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(Icons.arrow_back_ios, color: primary),
      ),
      actions: [CircleAvatar(backgroundImage: NetworkImage(widget.img))],
    );
  }

  Widget getBottomBar() {
    var size = MediaQuery.of(context).size;
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(color: greyColor),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(FontAwesomeIcons.paperclip, color: primary, size: 21),
            Container(
              width: size.width * 0.76,
              height: 32,
              decoration: BoxDecoration(
                color: white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: TextField(
                  style: TextStyle(color: white),
                  cursorColor: primary,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    suffixIcon: Icon(
                      FontAwesomeIcons.faceSmile,
                      color: primary,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),
            Icon(FontAwesomeIcons.microphone, color: primary, size: 28),
          ],
        ),
      ),
    );
  }

  Widget getBody() {
    return ListView(
      padding: EdgeInsets.only(top: 20, bottom: 80),
      children: List.generate(messages.length, (index) {
        return CustomBubbleChat(
          isMe: messages[index]['isMe'],
          message: messages[index]['message'],
          time: messages[index]['time'],
          isLast: messages[index]['isLast'],
        );
      }),
    );
  }
}
