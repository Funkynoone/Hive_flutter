import 'package:flutter/foundation.dart';

class JobFilterState extends ChangeNotifier {
  // Job Specifications
  bool showService = false;
  bool showManager = false;
  bool showBar = false;
  bool showDelivery = false;
  bool showSommelier = false;
  bool showCleaning = false;
  bool showCook = false;

  // Contract Time
  bool showFullTime = false;
  bool showPartTime = false;
  bool showSeason = false;

  // Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (showService) count++;
    if (showManager) count++;
    if (showBar) count++;
    if (showDelivery) count++;
    if (showSommelier) count++;
    if (showCleaning) count++;
    if (showCook) count++;
    if (showFullTime) count++;
    if (showPartTime) count++;
    if (showSeason) count++;
    return count;
  }

  // Get active job specifications
  List<String> get activeJobSpecs {
    List<String> specs = [];
    if (showService) specs.add('Service');
    if (showManager) specs.add('Manager');
    if (showBar) specs.add('Bar');
    if (showDelivery) specs.add('Delivery');
    if (showSommelier) specs.add('Sommelier');
    if (showCleaning) specs.add('Cleaning');
    if (showCook) specs.add('Cook');
    return specs;
  }

  // Get active contract types
  List<String> get activeContractTypes {
    List<String> types = [];
    if (showFullTime) types.add('Full Time');
    if (showPartTime) types.add('Part Time');
    if (showSeason) types.add('Season');
    return types;
  }

  void toggleJobSpec(String spec) {
    switch (spec) {
      case 'Service':
        showService = !showService;
        break;
      case 'Manager':
        showManager = !showManager;
        break;
      case 'Cook':
        showCook = !showCook;
        break;
      case 'Cleaning':
        showCleaning = !showCleaning;
        break;
      case 'Delivery':
        showDelivery = !showDelivery;
        break;
      case 'Bar':
        showBar = !showBar;
        break;
      case 'Sommelier':
        showSommelier = !showSommelier;
        break;
    }
    notifyListeners();
  }

  void toggleContractType(String type) {
    switch (type) {
      case 'Full Time':
        showFullTime = !showFullTime;
        break;
      case 'Part Time':
        showPartTime = !showPartTime;
        break;
      case 'Season':
        showSeason = !showSeason;
        break;
    }
    notifyListeners();
  }

  void clearAll() {
    showService = false;
    showManager = false;
    showBar = false;
    showDelivery = false;
    showSommelier = false;
    showCleaning = false;
    showCook = false;
    showFullTime = false;
    showPartTime = false;
    showSeason = false;
    notifyListeners();
  }
}