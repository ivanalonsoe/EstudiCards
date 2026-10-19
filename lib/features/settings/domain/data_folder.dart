// Where the app keeps its data on Windows (T5.11, decided with the owner):
// a folder the user chooses, called `EstudiCards`, with the database, the
// card images and the automatic backups inside.

/// The name of the folder with the app's data.
const dataFolderName = 'EstudiCards';

/// The database file inside the data folder: the name earlier versions
/// used (`drift_flutter` adds `.sqlite` to the database name).
const databaseFileName = 'estudicards.sqlite';

/// The data folder for the folder the user chose: the chosen folder if it
/// is already called `EstudiCards` (in any case), or a new `EstudiCards`
/// folder inside it.
String dataFolderFor(String chosenPath) {
  final separator = chosenPath.contains(r'\') ? r'\' : '/';
  var path = chosenPath;
  while (path.length > 1 && (path.endsWith(r'\') || path.endsWith('/'))) {
    path = path.substring(0, path.length - 1);
  }
  final name = path.split(RegExp(r'[\\/]')).last;
  return name.toLowerCase() == dataFolderName.toLowerCase()
      ? path
      : '$path$separator$dataFolderName';
}
