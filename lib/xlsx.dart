// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:archive/archive.dart';
import 'data.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _colLetter(int i) {
  var s = '';
  var n = i;
  while (true) {
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = n ~/ 26 - 1;
    if (n < 0) break;
  }
  return s;
}

List<int> buildXlsx(String sheetName, List<List<String>> rows) {
  final sheet = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      sheet.write('<c r="${_colLetter(c)}${r + 1}" t="inlineStr"><is><t xml:space="preserve">${_esc(rows[r][c])}</t></is></c>');
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';
  const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';
  final workbook = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets></workbook>';
  const workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '</Relationships>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = content.codeUnits;
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypes);
  add('_rels/.rels', rels);
  add('xl/workbook.xml', workbook);
  add('xl/_rels/workbook.xml.rels', workbookRels);
  add('xl/worksheets/sheet1.xml', sheet.toString());
  return ZipEncoder().encode(archive)!;
}

void _download(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadPersonalCredentialsReport(List<Worker> workers) {
  final rows = <List<String>>[
    ['Worker', 'Trade', 'Credential', 'Issuer', 'Type', 'Added', 'Expires', 'Status'],
    for (final w in workers)
      for (final c in w.creds)
        [
          w.name,
          w.trade,
          c.name,
          issuerOf(c.name),
          c.isBadge ? 'NCCER badge' : 'Other issuer',
          fmtDate(c.added),
          c.expiry == null ? '-' : fmtDate(c.expiry!),
          credStatusLabel(c),
        ],
  ];
  _download(buildXlsx('Personal credentials', rows), 'personal-credentials-report.xlsx');
}

void downloadRowsXlsx(String sheetName, List<List<String>> rows, String filename) {
  _download(buildXlsx(sheetName, rows), filename);
}
