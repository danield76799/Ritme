// Lees de bestandsgrootte van een box — gebruikt om te detecteren dat Hive
// bij het openen een beschadigde staart moest afkappen (corruptie-signaal).
export 'hive_repair_stub.dart' if (dart.library.io) 'hive_repair_io.dart';
