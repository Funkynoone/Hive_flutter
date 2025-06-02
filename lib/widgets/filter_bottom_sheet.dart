import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job_filter_state.dart';

class FilterBottomSheet extends StatefulWidget {
  final JobFilterState filterState;
  final DraggableScrollableController? controller;

  const FilterBottomSheet({
    super.key,
    required this.filterState,
    this.controller,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late DraggableScrollableController _controller;

  final Map<String, IconData> jobIcons = {
    'Service': Icons.room_service,
    'Manager': Icons.manage_accounts,
    'Cook': Icons.restaurant,
    'Cleaning': Icons.cleaning_services,
    'Delivery': Icons.delivery_dining,
    'Bar': Icons.local_bar,
    'Sommelier': Icons.wine_bar,
  };

  final Map<String, IconData> contractIcons = {
    'Full Time': Icons.work,
    'Part Time': Icons.work_outline,
    'Season': Icons.date_range,
  };

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DraggableScrollableController();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.12, 0.75],
      builder: (context, scrollController) {
        return AnimatedBuilder(
          animation: widget.filterState,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  _buildHandle(),
                  // Header
                  _buildHeader(),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildJobSpecsSection(),
                          const SizedBox(height: 24),
                          _buildContractSection(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final activeCount = widget.filterState.activeFilterCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (activeCount > 0)
            TextButton(
              onPressed: widget.filterState.clearAll,
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }

  Widget _buildJobSpecsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Specifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: jobIcons.entries.map((entry) {
            final isSelected = _isJobSpecSelected(entry.key);
            return FilterChip(
              avatar: Icon(
                entry.value,
                size: 18,
                color: isSelected ? Colors.white : Colors.blue,
              ),
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (_) => widget.filterState.toggleJobSpec(entry.key),
              backgroundColor: Colors.blue.shade50,
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContractSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contract Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: contractIcons.entries.map((entry) {
            final isSelected = _isContractSelected(entry.key);
            return FilterChip(
              avatar: Icon(
                entry.value,
                size: 18,
                color: isSelected ? Colors.white : Colors.green,
              ),
              label: Text(entry.key),
              selected: isSelected,
              onSelected: (_) => widget.filterState.toggleContractType(entry.key),
              backgroundColor: Colors.green.shade50,
              selectedColor: Colors.green,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.filterState.clearAll,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Collapse the sheet after applying
              _controller.animateTo(
                0.12,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  bool _isJobSpecSelected(String spec) {
    switch (spec) {
      case 'Service': return widget.filterState.showService;
      case 'Manager': return widget.filterState.showManager;
      case 'Cook': return widget.filterState.showCook;
      case 'Cleaning': return widget.filterState.showCleaning;
      case 'Delivery': return widget.filterState.showDelivery;
      case 'Bar': return widget.filterState.showBar;
      case 'Sommelier': return widget.filterState.showSommelier;
      default: return false;
    }
  }

  bool _isContractSelected(String type) {
    switch (type) {
      case 'Full Time': return widget.filterState.showFullTime;
      case 'Part Time': return widget.filterState.showPartTime;
      case 'Season': return widget.filterState.showSeason;
      default: return false;
    }
  }
}