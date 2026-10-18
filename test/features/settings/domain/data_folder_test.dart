import 'package:estudicards/features/settings/domain/data_folder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a folder called EstudiCards is used as it is', () {
    expect(
      dataFolderFor(r'C:\Users\ana\Documents\EstudiCards'),
      r'C:\Users\ana\Documents\EstudiCards',
    );
    expect(dataFolderFor(r'D:\estudicards\'), r'D:\estudicards');
  });

  test('any other folder gets an EstudiCards folder inside', () {
    expect(
      dataFolderFor(r'C:\Users\ana\Documents'),
      r'C:\Users\ana\Documents\EstudiCards',
    );
    expect(dataFolderFor(r'D:\'), r'D:\EstudiCards');
    expect(dataFolderFor('/home/ana/'), '/home/ana/EstudiCards');
  });

  test('the database keeps the name of earlier versions', () {
    expect(databaseFileName, 'estudicards.sqlite');
    expect(dataFolderName, 'EstudiCards');
  });
}
