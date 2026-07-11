import 'package:cts_underground_mining_assessment/core/underground_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template exposes the required identity and report sections', () {
    expect(
      UndergroundTemplate.templateKey,
      'underground_mining_rebuild_life_extension',
    );
    expect(UndergroundTemplate.templateVersion, '1.0.0');
    expect(
      UndergroundTemplate.reportCompanyName,
      'COMBINED TECHNICAL SERVICES',
    );
    expect(
      UndergroundTemplate.reportTitle,
      'UNDERGROUND MINING EQUIPMENT REBUILD ASSESSMENT & LIFE EXTENSION REPORT',
    );

    expect(UndergroundTemplate.sections, hasLength(16));
    expect(
      UndergroundTemplate.sections.map((section) => section.title),
      containsAll(<String>[
        'SECTION 1 - MACHINE IDENTIFICATION',
        'SECTION 2 - STRUCTURAL INSPECTION',
        'SECTION 3 - ENGINE ASSESSMENT',
        'SECTION 4 - TRANSMISSION & DRIVELINE',
        'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
        'SECTION 6 - ELECTRICAL SYSTEM',
        'SECTION 7 - BRAKING SYSTEM',
        'SECTION 8 - UNDERCARRIAGE / RUNNING GEAR',
        'SECTION 9A - OPERATOR STATION & ERGONOMICS ASSESSMENT',
        'SECTION 9B - MACHINE SPECIFIC SYSTEMS',
        'SECTION 10 - CONDITION MONITORING RESULTS',
        'SECTION 11 - LIFE EXTENSION ASSESSMENT',
        'SECTION 12 - REBUILD RECOMMENDATIONS',
        'SECTION 13 - ESTIMATED REBUILD COST FORECAST',
        'SECTION 14 - PHOTOGRAPHIC EVIDENCE',
        'FINAL CTS RECOMMENDATION & SIGNOFF',
      ]),
    );
  });

  test('template includes required option sets and score fields', () {
    expect(
      UndergroundTemplate.purposeOptions,
      containsAll(<String>[
        'Condition Assessment',
        'Life Extension Program',
        'Rebuild Assessment',
        'Pre-Purchase Inspection',
        'Reliability Audit',
        'Component Failure Investigation',
      ]),
    );
    expect(
      UndergroundTemplate.machineTypes,
      containsAll(<String>['Rock Scaler', 'Jumbo', 'Utility Vehicle', 'Other']),
    );
    expect(UndergroundTemplate.globalRatingOptions, <String>[
      'Good',
      'Fair',
      'Poor',
      'Critical / Out of Service',
      'N/A',
      'Not Inspected',
    ]);
    expect(UndergroundTemplate.assetStatusOptions, <String>[
      'Excellent',
      'Good',
      'Fair',
      'Poor',
      'Immediate Rebuild Required',
    ]);
    expect(
      UndergroundTemplate.finalRecommendationOptions,
      containsAll(<String>[
        'Continue Operating',
        'Monitor Monthly',
        'Schedule Major Component Rebuild',
        'Complete Machine Rebuild',
        'Replacement More Economical Than Rebuild',
      ]),
    );
    expect(
      UndergroundTemplate.healthScoreFields.map((score) => score.label),
      containsAll(<String>[
        'Structural Integrity',
        'Engine Condition',
        'Hydraulic System',
        'Transmission & Drivetrain',
        'Electrical System',
        'Axles & Differentials',
        'Braking System',
        'Undercarriage & Suspension',
        'Operator Station',
        'Overall Asset Health',
      ]),
    );
  });
}
