import 'package:cts_underground_mining_assessment/core/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildPdfFileName follows UMEA report filename convention', () {
    expect(
      FileUtils.buildPdfFileName(
        documentNumber: '20260420-0001',
        customer: 'Moraine Underground',
        machineOrSerial: 'Rock Scaler RS-1001',
        inspectionDate: DateTime(2026, 4, 20),
      ),
      'CTS_UMEA_Moraine_Underground_Rock_Scaler_RS-1001_20260420_20260420-0001.pdf',
    );
  });
}
