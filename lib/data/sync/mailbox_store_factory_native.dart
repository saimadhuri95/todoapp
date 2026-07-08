import 'dart:io';

import 'mailbox_store.dart';

MailboxStore? createFolderMailboxStore(String path) =>
    FolderMailboxStore(Directory(path));
