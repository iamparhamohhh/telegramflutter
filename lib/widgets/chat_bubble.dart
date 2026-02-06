import 'package:flutter/material.dart';
import 'package:telegramflutter/theme/colors.dart';

class CustomBubbleChat extends StatelessWidget {
  final bool isMe;
  final String message;
  final String time;
  final bool isLast;

  const CustomBubbleChat({
    super.key,
    required this.isMe,
    required this.message,
    required this.time,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isLast) ...[SizedBox(width: 4)],
          if (!isMe && !isLast) ...[SizedBox(width: 38)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Color(0xFF2B5278) : greyColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 18 : (isLast ? 4 : 18)),
                  topRight: Radius.circular(isMe ? (isLast ? 4 : 18) : 18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(fontSize: 16, color: white, height: 1.3),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: white.withOpacity(0.6),
                        ),
                      ),
                      if (isMe) ...[
                        SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 16,
                          color: Color(0xFF37AEE2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe && isLast) ...[SizedBox(width: 4)],
          if (isMe && !isLast) ...[SizedBox(width: 38)],
        ],
      ),
    );
  }
}
