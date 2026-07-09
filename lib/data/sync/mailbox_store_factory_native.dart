import 'dart:io';

import 'mailbox_store.dart';

MailboxStore? createFolderMailboxStore(String path) {
  if (path.startsWith('content://')) return AndroidSafMailboxStore(path);
  return FolderMailboxStore(Directory(path));
}
