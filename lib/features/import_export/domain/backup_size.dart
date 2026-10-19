// The size limits of a JSON file by kind, and the size of a backup worked
// out before writing it (T5.10).
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';

/// Whether a file of [bytes] is too big to read. Before reading it ([kind]
/// null) only the backup limit applies; once its kind is known, a shared
/// project or deck has the smaller [maxJsonFileBytes].
bool exchangeTooLarge(int bytes, {ExchangeKind? kind}) =>
    bytes >
    (kind == null || kind == ExchangeKind.backup
        ? maxBackupFileBytes
        : maxJsonFileBytes);

/// What each image adds besides its base64 text: `{"mime":"image/jpeg",
/// "data":""}` and the comma.
const _imageOverhead = 40;

/// The size of a backup whose JSON without images takes [textBytes] and
/// whose images are files of [imageSizes] bytes. Base64 writes every 3
/// bytes as 4 characters, rounding up.
int estimatedBackupBytes({
  required int textBytes,
  required Iterable<int> imageSizes,
}) => imageSizes.fold(
  textBytes,
  (sum, size) => sum + (size + 2) ~/ 3 * 4 + _imageOverhead,
);
