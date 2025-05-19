// escolhe a implementação certa conforme a plataforma
export 'download_util_stub.dart'
    if (dart.library.html) 'download_util_web.dart';
