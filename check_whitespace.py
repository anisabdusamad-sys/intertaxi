import codecs

path = r'C:\Users\Anis\Desktop\Desktop\intertaxii\intertaxi\lib\screens\passenger_home_screen.dart'
content = codecs.open(path, encoding='utf-8').read()

# Find the start of the old _buildSearchResultsSection method
start_marker = '  /// Results header + scrollable driver list, rendered below the panel.'
start_idx = content.find(start_marker)
if start_idx == -1:
    print("ERROR: could not find start marker")
    raise SystemExit(1)

# Find the start of the next top-level class member (2-space indent prefix
# followed by /// or @override or Widget or void or Future) after this method.
# We search for the next occurrence of '\n  ///' or '\n  @override' or
# '\n  Widget' or '\n  void' or '\n  Future' after start_idx.

search_area = content[start_idx:]
# Find the end of _buildSearchResultsSection - it ends with a closing brace
# at 2-space indent, followed by a blank line and the next doc comment or method.

# Look for the end: we know _buildSearchResultsSection is followed by
# _focusMapOnRoute (or another method). Let's find the next '  ///' or '  @override'
# that appears after the method body.

# Simple approach: find the next method by looking for common patterns
# The method ends with '  }' at 2-space indent (class member level)
# We look for the pattern: closing brace of method + next doc comment

# Look for the next '  /// ' after the start
next_methods = [
    '\n  /// ',      # Doc comment for next method
    '\n  @override', # Override annotation
    '\n  Widget ',   # Widget return type
    '\n  void ',     # void return type
    '\n  Future<',  # Future return type
]

# Find the earliest occurrence of any of these patterns after start_idx+10
earliest_end = len(content)
for pattern in next_methods:
    pos = content.find(pattern, start_idx + 10)
    if pos != -1 and pos < earliest_end:
        earliest_end = pos

if earliest_end == len(content):
    print("ERROR: could not find end of method")
else:
    end_idx = earliest_end
    # The old method spans from start_idx to end_idx
    old_method = content[start_idx:end_idx]
    print(f"Found old method from char {start_idx} to {end_idx}")
    print(f"Old method length: {len(old_method)} chars")
    print(f"Old method starts with: {repr(old_method[:80])}")
    print(f"Old method ends with: {repr(old_method[-80:])}")


