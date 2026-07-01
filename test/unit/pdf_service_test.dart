import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:cts_underground_mining_assessment/features/pdf_report/pdf_report_models.dart';
import 'package:cts_underground_mining_assessment/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List photoOne;
  late Uint8List photoTwo;
  late Uint8List signatureBytes;

  setUpAll(() async {
    photoOne = await File('assets/demo/sample_photo_1.jpg').readAsBytes();
    photoTwo = await File('assets/demo/sample_photo_2.jpg').readAsBytes();
    signatureBytes = photoOne;
  });

  InspectionReportData buildReport({
    InspectionReportBranding branding = const InspectionReportBranding(),
  }) {
    return InspectionReportData(
      documentNumber: '20260418-0001',
      customer: 'Moraine Underground',
      workOrderNumber: 'WO-7788',
      customerReference: 'PO-4421',
      assetName: 'Rock Scaler RS-1001',
      siteLocation: 'East Decline Service Bay',
      technicianName: 'Alex Technician',
      servicingShop: 'CTS Edmonton',
      inspectionDateTime: DateTime(2026, 4, 18, 9, 30),
      createdAt: DateTime(2026, 4, 18, 9, 12),
      completedAt: DateTime(2026, 4, 18, 12, 5),
      emailedAt: DateTime(2026, 4, 18, 12, 15),
      status: InspectionReportStatus.emailed,
      finalTechComments:
          'Machine inspected offline. Hydraulic hose replacement recommended on next shutdown.',
      criticalAcknowledged: true,
      signature: InspectionReportSignature(
        bytes: signatureBytes,
        signerName: 'Alex Technician',
        signedAt: DateTime(2026, 4, 18, 12, 00),
      ),
      sections: [
        InspectionReportSection(
          key: 'machine_identification',
          title: 'SECTION 1 - MACHINE IDENTIFICATION',
          subtitle: 'Inspection header and as-found photos.',
          items: [
            InspectionReportItem(
              label: 'Customer',
              value: 'Moraine Underground',
              helperText: 'Mandatory header field.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Machine wide shot',
                  sectionTitle: 'SECTION 1 - MACHINE IDENTIFICATION',
                  itemLabel: 'Customer',
                  capturedAt: DateTime(2026, 4, 18, 9, 15),
                ),
              ],
            ),
          ],
        ),
        InspectionReportSection(
          key: 'hydraulic_system_assessment',
          title: 'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
          items: [
            InspectionReportItem(
              label: 'Hose Condition',
              value: 'Minor abrasion and cover wear',
              conditionRating: ReportConditionRating.monitor,
              comment:
                  'Monitor abrasion around boom hose bundle. Keep under review.',
              helperText: 'Flagged items require a comment and a photo.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoTwo,
                  caption: 'Boom hose abrasion',
                  sectionTitle: 'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
                  itemLabel: 'Hose Condition',
                  capturedAt: DateTime(2026, 4, 18, 10, 5),
                ),
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Nameplate and tank area',
                  sectionTitle: 'Fluid & Tank Service',
                  itemLabel: 'Tank Integrity',
                  capturedAt: DateTime(2026, 4, 18, 10, 6),
                ),
              ],
            ),
            InspectionReportItem(
              label: 'ISO Cleanliness',
              value: 'Contamination trend elevated',
              conditionRating: ReportConditionRating.unsatisfactory,
              comment:
                  'Sample indicates contamination. Plan filtration service.',
              photos: [
                InspectionReportPhoto(
                  bytes: photoTwo,
                  caption: 'Oil sample',
                  sectionTitle: 'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
                  itemLabel: 'ISO Cleanliness',
                  capturedAt: DateTime(2026, 4, 18, 10, 20),
                ),
              ],
            ),
          ],
        ),
        InspectionReportSection(
          key: 'braking_system',
          title: 'SECTION 7 - BRAKING SYSTEM',
          items: [
            InspectionReportItem(
              label: 'Service Brakes',
              value: 'Critical stopping performance issue',
              conditionRating: ReportConditionRating.critical,
              comment:
                  'LOTO required. Repair service brake system before start-up.',
              helperText:
                  'Poor service brake results require critical handling.',
              tags: const ['Service Brakes', 'LOTO'],
              photos: [
                InspectionReportPhoto(
                  bytes: photoOne,
                  caption: 'Brake test result',
                  sectionTitle: 'SECTION 7 - BRAKING SYSTEM',
                  itemLabel: 'Service Brakes',
                  capturedAt: DateTime(2026, 4, 18, 10, 45),
                ),
              ],
            ),
          ],
        ),
      ],
      actionItems: [
        const InspectionReportActionItem(
          title: 'Replace contaminated hydraulic filter set',
          description: 'Schedule service for filtration replacement and flush.',
          partsRequired: 'Hydraulic oil, return filter, breather',
          isAutoGenerated: true,
          conditionRating: ReportConditionRating.unsatisfactory,
        ),
        const InspectionReportActionItem(
          title: 'Repair service brake system',
          description: 'Complete brake diagnostic and repair before restart.',
          partsRequired: 'Brake valve kit, test tooling',
          isAutoGenerated: true,
          conditionRating: ReportConditionRating.critical,
        ),
      ],
      branding: branding,
    );
  }

  test(
    'buildReportFileName follows UMEA customer machine date document format',
    () {
      final data = buildReport();

      final fileName = PdfService.buildReportFileName(data);

      expect(
        fileName,
        'CTS_UMEA_Moraine_Underground_Rock_Scaler_RS-1001_20260418_20260418-0001.pdf',
      );
    },
  );

  test(
    'generateInspectionReportBytes renders report content and critical warning text',
    () async {
      final service = PdfService(compress: false);
      final data = buildReport();

      final bytes = await service.generateInspectionReportBytes(data);
      final pdfText = latin1.decode(bytes);

      expect(bytes, isNotEmpty);
      expect(pdfText, contains(PdfService.reportTitle));
      expect(pdfText, contains(UndergroundTemplate.reportTitle));
      expect(pdfText, contains('Template'));
      expect(pdfText, contains('version'));
      expect(pdfText, contains('1.0.0'));
      expect(pdfText, contains('USD'));
      expect(pdfText, contains('Lockout/Tagout'));
      expect(pdfText, contains('WO-7788'));
      expect(pdfText, contains('PO-4421'));
      expect(pdfText, contains('Rock'));
      expect(pdfText, contains('Scaler'));
      expect(pdfText, contains('RS-1001'));
      expect(pdfText, contains('Private'));
      expect(pdfText, contains('confidential'));
      expect(pdfText, contains('Alex'));
    },
  );

  test('generateInspectionReportBytes adds logo image when present', () async {
    final service = PdfService(compress: false);
    final withoutLogo = await service.generateInspectionReportBytes(
      buildReport(branding: const InspectionReportBranding()),
      includeLogoAsset: false,
    );
    final withExplicitLogo = await service.generateInspectionReportBytes(
      buildReport(branding: InspectionReportBranding(logoBytes: photoTwo)),
      includeLogoAsset: true,
    );

    expect(
      withExplicitLogo.lengthInBytes,
      greaterThan(withoutLogo.lengthInBytes),
    );
  });

  test('generateInspectionReportFile writes a non-empty pdf to disk', () async {
    final service = PdfService(compress: false);
    final tempDir = await Directory.systemTemp.createTemp(
      'cts_pdf_service_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = await service.generateInspectionReportFile(
      buildReport(),
      outputDirectory: tempDir,
    );

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
    expect(
      file.path,
      contains('CTS_UMEA_Moraine_Underground_Rock_Scaler_RS-1001_20260418_'),
    );
  });
}
