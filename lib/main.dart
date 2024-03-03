import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_gutter/flutter_gutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vcard_qr_converter/utils/constants.dart';
import 'package:vcard_qr_converter/widgets/contact_item_card.dart';

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(
        title: appName,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Contact? selectedContact;

  final globalKey = GlobalKey();

  void download(
    List<int> bytes, {
    String? downloadName,
  }) {
    // Encode our file in base64
    final base64 = base64Encode(bytes);
    // Create the link with the file
    final anchor =
        AnchorElement(href: 'data:application/octet-stream;base64,$base64')
          ..target = 'blank';
    // add the name
    if (downloadName != null) {
      anchor.download = downloadName;
    }
    // trigger download
    document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: size.width,
                height: size.height * 0.1,
                child: selectedContact == null
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Center(
                          child: Text(
                            'No contact selected',
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ContactItemCard(
                              contact: selectedContact!,
                            ),
                          ),
                          const GutterSmall(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                selectedContact = null;
                              });
                            },
                            icon: const Icon(
                              Icons.clear,
                            ),
                          ),
                        ],
                      ),
              ),
              const Gutter(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50.0,
                      child: ElevatedButton(
                        onPressed: () async {
                          // get file
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: false,
                            allowedExtensions: ['vcf'],
                          );

                          if (result != null && result.files.isNotEmpty) {
                            final fileBytes = result.files.first.bytes;
                            final fileName = result.files.first.name;

                            print('File Name: $fileName');

                            String convertedValue = utf8.decode(fileBytes!);
                            print('File Content: $convertedValue');

                            selectedContact = Contact.fromVCard(convertedValue);
                            setState(() {});
                          }
                        },
                        child: const Text(
                          'Pick VCF File',
                        ),
                      ),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const Gutter(),
                    Expanded(
                      child: SizedBox(
                        height: 50.0,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Request contact permission
                            if (await FlutterContacts.requestPermission()) {
                              selectedContact =
                                  await FlutterContacts.openExternalPick();

                              setState(() {});
                            }
                          },
                          child: const Text(
                            'Pick Contact',
                          ),
                        ),
                      ),
                    )
                  ],
                ],
              ),
              const GutterLarge(),
              const Divider(),
              if (selectedContact != null) ...[
                Text(
                  'Successfully generated QR Code!\n${selectedContact?.displayName ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gutter(),
                RepaintBoundary(
                  key: globalKey,
                  child: QrImageView(
                    backgroundColor: Colors.white,
                    data: selectedContact?.toVCard() ?? '',
                    size: kIsWeb ? size.width * 0.25 : size.width * 0.5,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.blue,
                    ),
                    errorStateBuilder: (cxt, err) {
                      return Center(
                        child: Text(
                          'Uh oh! Something went wrong, please pick another contact\n${err?.toString()}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                const Gutter(),
                SizedBox(
                  width: size.width,
                  height: 50.0,
                  child: ElevatedButton(
                    onPressed: () async {
                      RenderRepaintBoundary? boundary =
                          globalKey.currentContext!.findRenderObject()
                              as RenderRepaintBoundary?;
                      ui.Image image = await boundary!.toImage();
                      ByteData? byteData = await image.toByteData(
                          format: ui.ImageByteFormat.png);
                      Uint8List pngBytes = byteData!.buffer.asUint8List();

                      if (kIsWeb) {
                        // final file = XFile.fromData(pngBytes);

                        download(
                          pngBytes,
                          downloadName:
                              '${selectedContact!.displayName}_${selectedContact!.phones.firstOrNull?.number ?? ''}.png',
                        );

                        // await Share.shareXFiles(
                        //   [
                        //     XFile(file.path),
                        //   ],
                        //   subject:
                        //       'Scan ${selectedContact!.displayName} Contact Card',
                        // );
                      } else {
                        final tempDir = await getExternalStorageDirectory();
                        final file = await io.File(
                          '${tempDir!.path}/${selectedContact!.displayName}_${selectedContact!.phones.firstOrNull?.number ?? ''}.png',
                        ).create();
                        await file.writeAsBytes(pngBytes);
                        await Share.shareXFiles(
                          [
                            XFile(file.path),
                          ],
                          subject:
                              'Scan ${selectedContact!.displayName} Contact Card',
                        );
                      }
                    },
                    child: const Text(
                      'Download QR Code',
                    ),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
