class UndergroundTemplateSection {
  const UndergroundTemplateSection({
    required this.key,
    required this.title,
    required this.items,
    this.sortOrder = 0,
  });

  final String key;
  final String title;
  final int sortOrder;
  final List<String> items;
}

class UndergroundHealthScoreField {
  const UndergroundHealthScoreField({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
  });

  final String key;
  final String label;
  final int min;
  final int max;
}

class UndergroundTemplate {
  const UndergroundTemplate._();

  static const String appName = 'CTS Underground Mining Equipment Assessment';
  static const String templateKey = 'underground_mining_rebuild_life_extension';
  static const String templateVersion = '1.0.0';
  static const String reportCompanyName = 'COMBINED TECHNICAL SERVICES';
  static const String reportTitle =
      'UNDERGROUND MINING EQUIPMENT REBUILD ASSESSMENT & LIFE EXTENSION REPORT';
  static const String reportFilePrefix = 'CTS_UMEA';
  static const String exportFilePrefix = 'CTS_InspectionBundle';
  static const String exportFileSuffix = 'UMEA';
  static const String currency = 'USD';

  static const List<String> purposeOptions = <String>[
    'Condition Assessment',
    'Life Extension Program',
    'Rebuild Assessment',
    'Pre-Purchase Inspection',
    'Reliability Audit',
    'Component Failure Investigation',
  ];

  static const List<String> machineTypes = <String>[
    'Rock Scaler',
    'Jumbo',
    'Utility Vehicle',
    'Other',
  ];

  static const List<String> globalRatingOptions = <String>[
    'Good',
    'Fair',
    'Poor',
    'N/A',
    'Not Inspected',
  ];

  static const List<String> assetStatusOptions = <String>[
    'Excellent',
    'Good',
    'Fair',
    'Poor',
    'Immediate Rebuild Required',
  ];

  static const List<String> finalRecommendationOptions = <String>[
    'Continue Operating',
    'Monitor Monthly',
    'Schedule Major Component Rebuild',
    'Complete Machine Rebuild',
    'Replacement More Economical Than Rebuild',
  ];

  static const List<String> actionPriorityOptions = <String>[
    'Priority 1 Immediate',
    'Priority 2 Next Shutdown / Schedule Repair',
    'Priority 3 Monitor',
  ];

  static const List<String> lifeExtensionPotentialOptions = <String>[
    'Less than 1 year',
    '1-2 years',
    '2-5 years',
    'Greater than 5 years',
  ];

  static const List<UndergroundHealthScoreField> healthScoreFields =
      <UndergroundHealthScoreField>[
        UndergroundHealthScoreField(
          key: 'structural_integrity',
          label: 'Structural Integrity',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'engine_condition',
          label: 'Engine Condition',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'hydraulic_system',
          label: 'Hydraulic System',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'transmission_drivetrain',
          label: 'Transmission & Drivetrain',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'electrical_system',
          label: 'Electrical System',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'axles_differentials',
          label: 'Axles & Differentials',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'braking_system',
          label: 'Braking System',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'undercarriage_suspension',
          label: 'Undercarriage & Suspension',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'operator_station',
          label: 'Operator Station',
          min: 0,
          max: 10,
        ),
        UndergroundHealthScoreField(
          key: 'overall_asset_health',
          label: 'Overall Asset Health',
          min: 0,
          max: 100,
        ),
      ];

  static const Map<String, List<String>> machineSpecificItems =
      <String, List<String>>{
        'Rock Scaler': <String>[
          'Scaler Boom',
          'Scaling Hammer',
          'Hydraulic Rotation',
          'Protective Canopy',
          'Feed Structure',
        ],
        'Jumbo': <String>[
          'Booms',
          'Feeds',
          'Rock Drills',
          'Water System',
          'Anti-Jamming System',
        ],
        'Utility Vehicle': <String>[
          'Deck Condition',
          'Lifting Systems',
          'Personnel Carrier Safety Equipment',
          'Service Crane',
          'Accessory Systems',
        ],
        'Other': <String>['Custom machine-specific item / notes'],
      };

  static const List<String> costForecastFields = <String>[
    'Component',
    'Repair Required',
    'Estimated Cost',
    'Estimated Downtime',
  ];

  static const List<UndergroundTemplateSection> sections =
      <UndergroundTemplateSection>[
        UndergroundTemplateSection(
          key: 'machine_identification',
          title: 'SECTION 1 - MACHINE IDENTIFICATION',
          sortOrder: 1,
          items: <String>[
            'OEM',
            'Model',
            'Serial Number',
            'Year',
            'Engine Model',
            'Transmission Model',
            'Axle Type',
            'Hydraulic Pump Models',
            'Current Hours',
            'Frame Hours',
            'Previous Rebuild Hours',
            'Nameplate / Asset ID Photo',
            'Comments',
          ],
        ),
        UndergroundTemplateSection(
          key: 'structural_inspection',
          title: 'SECTION 2 - STRUCTURAL INSPECTION',
          sortOrder: 2,
          items: <String>[
            'Main Frame',
            'Articulation Area',
            'Boom Structure',
            'Scaler Boom',
            'Drill Feed Structure',
            'Cab Structure',
            'Canopy',
            'ROPS/FOPS',
            'Weld Repairs',
            'Crack Detection',
            'Corrosion Assessment',
            'Mounting Points',
            'Pins & Bushings',
          ],
        ),
        UndergroundTemplateSection(
          key: 'engine_assessment',
          title: 'SECTION 3 - ENGINE ASSESSMENT',
          sortOrder: 3,
          items: <String>[
            'Engine Oil Analysis',
            'Compression Assessment',
            'Blow-by Assessment',
            'Cooling System',
            'Radiator',
            'Charge Air Cooler',
            'Turbocharger',
            'Exhaust System',
            'Fuel System',
            'ECM Fault Codes',
            'Engine Mounts',
            'Leaks',
            'Engine Remaining Life Estimate',
            'Condition Rating',
          ],
        ),
        UndergroundTemplateSection(
          key: 'transmission_driveline',
          title: 'SECTION 4 - TRANSMISSION & DRIVELINE',
          sortOrder: 4,
          items: <String>[
            'Transmission Operation',
            'Converter Condition',
            'Drive Shafts',
            'Universal Joints',
            'Differentials',
            'Axles',
            'Planetary Hubs',
            'Bearings',
            'Oil Condition',
            'Backlash Measurements',
            'Remaining Life Estimate',
          ],
        ),
        UndergroundTemplateSection(
          key: 'hydraulic_system_assessment',
          title: 'SECTION 5 - HYDRAULIC SYSTEM ASSESSMENT',
          sortOrder: 5,
          items: <String>[
            'Hydraulic Pumps',
            'Hydraulic Motors',
            'Control Valves',
            'Cylinders',
            'Accumulators',
            'Coolers',
            'Reservoir',
            'Filtration System',
            'Kidney Loop Filtration',
            'Oil Sampling',
            'ISO Cleanliness',
            'Hose Condition',
            'Tube Condition',
            'Pressure Testing',
            'Flow Testing',
            'Thermal Imaging',
            'Hydraulic Hose Inspection',
            'Hydraulic Tubing Inspection',
          ],
        ),
        UndergroundTemplateSection(
          key: 'electrical_system',
          title: 'SECTION 6 - ELECTRICAL SYSTEM',
          sortOrder: 6,
          items: <String>[
            'Alternator',
            'Starter',
            'Battery System',
            'Harnesses',
            'Lighting',
            'Instrumentation',
            'Control Modules',
            'Sensors',
            'Safety Systems',
            'Emergency Shutdown',
            'Fire Suppression Interface',
            'Comments',
          ],
        ),
        UndergroundTemplateSection(
          key: 'braking_system',
          title: 'SECTION 7 - BRAKING SYSTEM',
          sortOrder: 7,
          items: <String>[
            'Service Brakes',
            'Park Brakes',
            'Brake Accumulators',
            'Brake Pumps',
            'Brake Valves',
            'Brake Cooling',
            'Brake Testing Results',
            'Stopping Distance',
            'Leak Inspection',
          ],
        ),
        UndergroundTemplateSection(
          key: 'undercarriage_running_gear',
          title: 'SECTION 8 - UNDERCARRIAGE / RUNNING GEAR',
          sortOrder: 8,
          items: <String>[
            'Tyres',
            'Rims',
            'Wheel Bearings',
            'Suspension',
            'Steering Components',
            'Articulation Bearings',
            'King Pins',
            'Hub Assemblies',
            'Steering Cylinder Mounts',
            'Steering Stops',
            'Frame Alignment',
            'Wheel End Leak Inspection',
          ],
        ),
        UndergroundTemplateSection(
          key: 'operator_station_ergonomics',
          title: 'SECTION 9A - OPERATOR STATION & ERGONOMICS ASSESSMENT',
          sortOrder: 9,
          items: <String>[
            'Cab Condition',
            'Operator Seat Condition',
            'Seat Suspension',
            'Seat Belt Condition',
            'Seat Adjustment Functions',
            'Seat Mounting Security',
            'Operator Posture Assessment',
            'Control Layout Accessibility',
            'Joystick Condition',
            'Joystick Ergonomics',
            'Foot Pedal Condition',
            'Pedal Effort',
            'Pedal Placement',
            'Hand Control Functionality',
            'Reach Envelope Assessment',
            'Visibility Forward',
            'Visibility Rearward',
            'Visibility to Work Area',
            'Camera Systems',
            'Mirror Condition',
            'Windshield Condition',
            'Wiper Function',
            'Cab Noise Levels',
            'Cab Vibration Levels',
            'HVAC System Performance',
            'Dust Control System',
            'Pressurization System',
            'Cab Air Filtration',
            'Operator Fatigue Risk Assessment',
            'Ingress/Egress Access',
            'Steps & Handrails',
            'Emergency Escape Access',
            'Display & Instrument Visibility',
            'Warning Alarm Audibility',
            'Radio/Communications System',
            'Lighting Ergonomics',
            'Storage Compartments',
            'Operator Comfort Assessment',
          ],
        ),
        UndergroundTemplateSection(
          key: 'machine_specific_systems',
          title: 'SECTION 9B - MACHINE SPECIFIC SYSTEMS',
          sortOrder: 10,
          items: <String>[
            'Rock Scaler Systems',
            'Jumbo Systems',
            'Utility Vehicle Systems',
            'Other Custom Machine-Specific Items',
          ],
        ),
        UndergroundTemplateSection(
          key: 'condition_monitoring_results',
          title: 'SECTION 10 - CONDITION MONITORING RESULTS',
          sortOrder: 11,
          items: <String>[
            'Oil Analysis Results',
            'Vibration Analysis Results',
            'Thermal Imaging Results',
            'Contamination Levels',
            'Wear Debris Analysis',
            'Fluid Cleanliness Trends',
          ],
        ),
        UndergroundTemplateSection(
          key: 'life_extension_assessment',
          title: 'SECTION 11 - LIFE EXTENSION ASSESSMENT',
          sortOrder: 12,
          items: <String>[
            'Engine',
            'Transmission',
            'Axles',
            'Hydraulic Pumps',
            'Hydraulic Motors',
            'Cylinders',
            'Boom Structure',
            'Frame',
            'Electrical Systems',
            'Expected Remaining Service Life',
            'Life Extension Potential',
          ],
        ),
        UndergroundTemplateSection(
          key: 'rebuild_recommendations',
          title: 'SECTION 12 - REBUILD RECOMMENDATIONS',
          sortOrder: 13,
          items: <String>[
            'Priority 1 Components - Immediate Replacement Required',
            'Priority 2 Components - Schedule During Next Shutdown',
            'Priority 3 Components - Monitor',
          ],
        ),
        UndergroundTemplateSection(
          key: 'estimated_rebuild_cost_forecast',
          title: 'SECTION 13 - ESTIMATED REBUILD COST FORECAST',
          sortOrder: 14,
          items: costForecastFields,
        ),
        UndergroundTemplateSection(
          key: 'photographic_evidence',
          title: 'SECTION 14 - PHOTOGRAPHIC EVIDENCE',
          sortOrder: 15,
          items: <String>[
            'Photo No.',
            'Location',
            'Observation',
            'Recommended Action',
            'Section / Item Link',
            'Caption',
            'Timestamp',
          ],
        ),
        UndergroundTemplateSection(
          key: 'final_recommendation_signoff',
          title: 'FINAL CTS RECOMMENDATION & SIGNOFF',
          sortOrder: 16,
          items: <String>[
            'Final CTS Recommendation',
            'CTS Inspector Typed Name',
            'CTS Inspector Drawn Signature',
            'Customer Representative Name',
            'Customer Representative Signature',
            'Customer Unavailable / Declined Note',
          ],
        ),
      ];

  static UndergroundTemplateSection sectionByKey(String key) {
    return sections.firstWhere(
      (UndergroundTemplateSection section) => section.key == key,
    );
  }

  static String sectionTitleFor(String key) => sectionByKey(key).title;
}
