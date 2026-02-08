import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:telegramflutter/json/contact_json.dart';
import 'package:telegramflutter/theme/colors.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        child: getAppBar(),
        preferredSize: Size.fromHeight(60),
      ),
      body: getBody(),
    );
  }

  Widget getAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: greyColor,
      title: Text(
        "Contacts",
        style: TextStyle(
          fontSize: 20,
          color: white,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        onPressed: null,
        icon: Text(
          "Sort",
          style: TextStyle(
            fontSize: 16,
            color: primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      actions: [
        IconButton(onPressed: null, icon: Icon(LineIcons.plus, color: primary)),
      ],
    );
  }

  Widget getBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: 68,
            decoration: BoxDecoration(color: greyColor),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      style: TextStyle(color: white),
                      cursorColor: primary,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          LineIcons.search,
                          color: white.withOpacity(0.3),
                        ),
                        hintText: "Search",
                        hintStyle: TextStyle(
                          color: white.withOpacity(0.3),
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
          getSectionIcons(),
          getContactLists(),
        ],
      ),
    );
  }

  Widget getSectionIcons() {
    List icons = [
      {"icon": LineIcons.mapMarker, "label": "Find People Nearby"},
      {"icon": LineIcons.userPlus, "label": "Invite Friends"},
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        children: List.generate(icons.length, (index) {
          return Column(
            children: [
              Row(
                children: [
                  Icon(icons[index]['icon'], color: primary, size: 28),
                  SizedBox(width: 20),
                  Text(
                    icons[index]['label'],
                    style: TextStyle(
                      fontSize: 16,
                      color: primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Divider(thickness: 1, color: white.withOpacity(0.15)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget getContactLists() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        children: List.generate(contactData.length, (index) {
          return Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(contactData[index]['img']),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactData[index]['name'],
                        style: TextStyle(
                          fontSize: 17,
                          color: white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        contactData[index]['is_online']
                            ? "online"
                            : contactData[index]['seen'],
                        style: TextStyle(
                          fontSize: 13,
                          color: contactData[index]['is_online']
                              ? primary
                              : white.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Divider(thickness: 1, color: white.withOpacity(0.15)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
