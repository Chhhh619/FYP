import 'package:flutter/material.dart';
import 'package:fyp/ch/record_transaction.dart';

class PersistentAddButton extends StatefulWidget {
  final ScrollController? scrollController;

  const PersistentAddButton({super.key, this.scrollController});

  @override
  _PersistentAddButtonState createState() => _PersistentAddButtonState();
}

class _PersistentAddButtonState extends State<PersistentAddButton> {
  bool _isScrollingDown = false;
  double _lastScrollPosition = 0.0;
  static const double _scrollThreshold = 5.0;

  @override
  void initState() {
    super.initState();
    print('=== PersistentAddButton initState called ===');

    _setupScrollListener();
  }

  void _setupScrollListener() {
    final controller = widget.scrollController;
    if (controller == null) {
      print('No scroll controller provided - button will remain static');
      return;
    }

    print('Setting up scroll listener for controller: ${controller.hashCode}');

    // Use a post frame callback to ensure the controller is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check if controller is already attached to prevent the error
      try {
        if (controller.hasClients) {
          print('ScrollController has clients, adding listener');
          controller.addListener(_scrollListener);
          _lastScrollPosition = controller.offset;
          print('Initial scroll position: $_lastScrollPosition');
        } else {
          print('ScrollController has no clients, waiting...');
          // Try again after a short delay
          _retrySetupListener(controller, 0);
        }
      } catch (e) {
        print('Error during initial setup: $e');
        _retrySetupListener(controller, 0);
      }
    });
  }

  void _retrySetupListener(ScrollController controller, int attempt) {
    if (attempt >= 5) {
      print('Max retry attempts reached, giving up on scroll listener');
      return;
    }

    Future.delayed(Duration(milliseconds: 100 * (attempt + 1)), () {
      if (!mounted) return;

      try {
        if (controller.hasClients) {
          print('ScrollController now has clients, adding listener (attempt ${attempt + 1})');
          controller.addListener(_scrollListener);
          _lastScrollPosition = controller.offset;
        } else {
          print('ScrollController still has no clients (attempt ${attempt + 1})');
          _retrySetupListener(controller, attempt + 1);
        }
      } catch (e) {
        print('Error on retry attempt ${attempt + 1}: $e');
        _retrySetupListener(controller, attempt + 1);
      }
    });
  }

  @override
  void didUpdateWidget(PersistentAddButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the scroll controller changed, update listeners
    if (oldWidget.scrollController != widget.scrollController) {
      print('ScrollController changed, updating listeners...');

      // Remove old listener safely
      if (oldWidget.scrollController != null) {
        try {
          if (oldWidget.scrollController!.hasClients) {
            oldWidget.scrollController!.removeListener(_scrollListener);
            print('Removed old scroll listener');
          }
        } catch (e) {
          print('Error removing old listener: $e');
        }
      }

      // Setup new listener
      _setupScrollListener();
    }
  }

  @override
  void dispose() {
    print('=== PersistentAddButton dispose called ===');

    if (widget.scrollController != null) {
      try {
        if (widget.scrollController!.hasClients) {
          widget.scrollController!.removeListener(_scrollListener);
          print('Removed scroll listener');
        }
      } catch (e) {
        print('Error removing listener during dispose: $e');
      }
    }

    super.dispose();
  }

  void _scrollListener() {
    print('🔥 SCROLL LISTENER CALLED! 🔥');

    final controller = widget.scrollController;
    if (controller == null) return;

    try {
      if (!controller.hasClients) {
        print('❌ ScrollController has no clients in listener!');
        return;
      }

      final currentScrollPosition = controller.offset;
      final scrollDifference = currentScrollPosition - _lastScrollPosition;

      print('Current scroll position: $currentScrollPosition');
      print('Last scroll position: $_lastScrollPosition');
      print('Scroll difference: $scrollDifference');

      final isScrollingDown = scrollDifference > _scrollThreshold && currentScrollPosition > 20;
      final isScrollingUp = scrollDifference < -_scrollThreshold;

      print('Is scrolling down: $isScrollingDown');
      print('Is scrolling up: $isScrollingUp');
      print('Current button state (_isScrollingDown): $_isScrollingDown');

      if (isScrollingDown && !_isScrollingDown) {
        print('✅ Changing to COLLAPSED state');
        if (mounted) {
          setState(() {
            _isScrollingDown = true;
          });
        }
      } else if (isScrollingUp && _isScrollingDown) {
        print('✅ Changing to EXPANDED state');
        if (mounted) {
          setState(() {
            _isScrollingDown = false;
          });
        }
      }

      _lastScrollPosition = currentScrollPosition;
    } catch (e) {
      print('Error in scroll listener: $e');
      // If we get an error, the controller might be detached
      // Remove this listener to prevent further errors
      try {
        controller.removeListener(_scrollListener);
        print('Removed problematic listener');
      } catch (removeError) {
        print('Error removing listener: $removeError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('PersistentAddButton build called, _isScrollingDown: $_isScrollingDown');

    // Additional debug info
    if (widget.scrollController != null) {
      print('ScrollController exists in build (${widget.scrollController.hashCode}), hasClients: ${widget.scrollController!.hasClients}');
      if (widget.scrollController!.hasClients) {
        try {
          print('Current scroll position in build: ${widget.scrollController!.offset}');
        } catch (e) {
          print('Error getting scroll position: $e');
        }
      }
    } else {
      print('No scroll controller provided - button remains static');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isScrollingDown ? 56.0 : 120.0,
      height: 56.0,
      child: FloatingActionButton(
        onPressed: () {
          print('FloatingActionButton pressed');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordTransactionPage(),
            ),
          );
        },
        backgroundColor: Colors.teal,
        elevation: 4.0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: _isScrollingDown
              ? const Icon(
              Icons.add,
              color: Colors.white,
              size: 30,
              key: ValueKey('icon')
          )
              : FittedBox(
            key: const ValueKey('textRow'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, color: Colors.white, size: 24),
                  SizedBox(width: 6),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}