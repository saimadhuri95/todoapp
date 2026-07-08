import 'package:drift/drift.dart';

import 'open_connection_native.dart'
    if (dart.library.js_interop) 'open_connection_web.dart';

QueryExecutor openConnection() => openConnectionImpl();
