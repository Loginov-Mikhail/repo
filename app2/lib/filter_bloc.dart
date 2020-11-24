part of "main.dart";

/*
*******************************************
***************** Events ******************
*******************************************

FILTER PANEL:
- Author/title filter changed => FILTER
- Places filter changed => FILTER (permission for Address Book if My Places)
- Language filter changed => FILTER
- Genre filter changed => FILTER
- Filter panel opened => FILTER
- Filter panel minimized => FILTER
- Filter panel closed => FILTER

TRIPLE BUTTON
- Map button pressed => FILTER
- List button pressed => FILTER
- Set view => FILTER

MAP VIEW
- Map move => FILTER
- Tap on Marker => FILTER

DETAILS
- Search button pressed => FILTER

*******************************************
***************** States ******************
*******************************************

FILTER => Map scale and position
FILTER => Book filter changed

*/

enum QueryType { books, places }

enum FilterType { wish, title, author, contacts, place, genre, language }

enum FilterGroup { book, genre, language, place }

class Filter extends Equatable {
  final FilterType type;
  final String value;
  final Book book;
  final Place place;
  final bool selected;

  @override
  List<Object> get props => [type, value, selected];

  const Filter(
      {@required this.type, this.value, this.book, this.place, this.selected});

  FilterGroup get group {
    switch (type) {
      case FilterType.author:
      case FilterType.title:
      case FilterType.wish:
        return FilterGroup.book;

      case FilterType.genre:
        return FilterGroup.genre;

      case FilterType.language:
        return FilterGroup.language;

      case FilterType.place:
      case FilterType.contacts:
        return FilterGroup.place;
    }
    //TODO: report in the crashalytics
    return null;
  }

  Filter copyWith({
    FilterType type,
    String value,
    String book,
    bool selected,
  }) {
    return Filter(
      type: type ?? this.type,
      value: value ?? this.value,
      book: book ?? this.book,
      place: place ?? this.place,
      selected: selected ?? this.selected,
    );
  }
}

String up(String geohash) {
  int len = geohash.length;

  if (len >= 1) {
    int lastChar = geohash.codeUnitAt(len - 1);
    return geohash.substring(0, len - 1) + String.fromCharCode(lastChar + 1);
  } else {
    return geohash;
  }
}

class MarkerData extends Equatable {
  final String geohash;
  final LatLng position;
  final List<Point> points;
  final int size;

  MarkerData({this.geohash, this.position, this.size, this.points});

  @override
  List<Object> get props => [geohash, position, size];
}

enum Panel { hiden, minimized, open, full }

enum ViewType { map, camera, list, details }

class FilterState extends Equatable {
  // Current filters
  final List<Filter> filters;
  // List of the ISBNs to filter the books
  final List<String> isbns;
  // If input of genres and language allowed
  final bool genreInput;
  final bool languageInput;
  // Ids of places from my address book
  final List<String> favorite;

  // Current view (map, list, details, camera) and panel open/close position
  final ViewType view;
  // Position of search/camera panel
  final Panel panel;
  // Current filter froup for detailed filter (panel.full)
  final FilterGroup group;
  // Coordinates and bounds of the map camera
  final LatLng center;
  final LatLngBounds bounds;
  // Current geohashes on the map
  final Set<String> geohashes;

  // List of books for the list view
  final List<Book> books;
  // Currently selected book for details view
  final Book selected;
  // Corrent markers for map view
  final Set<MarkerData> markers;
  // Corrent markers for map view
  final List<Filter> suggestions;

  // Places near the current location
  final List<Place> places;

  @override
  List<Object> get props => [
        filters,
        isbns,
        genreInput,
        languageInput,
        favorite,
        panel,
        group,
        center,
        bounds,
        geohashes,
        view,
        books,
        selected,
        markers,
        suggestions,
        places
      ];

  const FilterState(
      {this.filters = const [
        Filter(type: FilterType.wish, selected: false),
        Filter(type: FilterType.contacts, selected: false),
      ],
      this.genreInput = true,
      this.languageInput = true,
      this.favorite,
      this.isbns = const [],
      this.panel = Panel.minimized,
      this.group,
      this.center = const LatLng(49.8397, 24.0297),
      this.bounds,
      this.geohashes = const {'u8c5d'},
      this.view = ViewType.map,
      this.books,
      this.selected,
      this.markers,
      this.suggestions = const [],
      this.places});

  FilterState copyWith(
      {List<Filter> filters,
      bool genreInput,
      bool languageInput,
      List<String> favorite,
      List<String> isbns,
      Panel panel,
      FilterGroup group,
      LatLng center,
      LatLngBounds bounds,
      ViewType view,
      Set<String> geohashes,
      List<Book> books,
      Book selected,
      Set<MarkerData> markers,
      List<Filter> suggestions,
      List<Place> places}) {
    return FilterState(
      filters: filters ?? this.filters,
      genreInput: genreInput ?? this.genreInput,
      languageInput: languageInput ?? this.languageInput,
      favorite: favorite ?? this.favorite,
      isbns: isbns ?? this.isbns,
      panel: panel ?? this.panel,
      group: group ?? this.group,
      center: center ?? this.center,
      bounds: bounds ?? this.bounds,
      view: view ?? this.view,
      geohashes: geohashes ?? this.geohashes,
      books: books ?? this.books,
      selected: selected ?? this.selected,
      markers: markers ?? this.markers,
      suggestions: suggestions ?? this.suggestions,
      places: places ?? this.places,
    );
  }

  List<Filter> getFilters({FilterGroup group, FilterType type}) {
    assert(group != null || type != null,
        'Filter type or group has to be defined');
    if (group != null)
      return filters.where((f) => f.group == group).toList();
    else if (type != null) return filters.where((f) => f.type == type).toList();
    return [];
  }

  List<Filter> get compact {
    // Return all filters 3 or below
    if (filters.length <= 3) return filters;

    List<Filter> selected = filters.where((f) => f.selected).toList();
    return selected;
  }

  QueryType get select {
    // For list view always select books
    if (view == ViewType.list)
      return QueryType.books;

    // For map view with precise query select books
    else if (view == ViewType.map &&
        (filters.any((f) =>
                f.type == FilterType.title || f.type == FilterType.author) ||
            // TODO: Change || to && once statistics are available in places and clusters
            filters.any((f) => f.type == FilterType.genre) ||
            filters.any((f) => f.type == FilterType.language) ||
            filters.any((f) => f.type == FilterType.wish && f.selected)))
      return QueryType.books;

    // Else select places
    else
      return QueryType.places;
  }

  // Return set of hashes for the current map view
  Set<String> hashesFor(LatLng position, LatLngBounds bounds) {
    GeoHasher gc = GeoHasher();
    String ne =
        gc.encode(bounds.northeast.longitude, bounds.northeast.latitude);
    String sw =
        gc.encode(bounds.southwest.longitude, bounds.southwest.latitude);
    String nw =
        gc.encode(bounds.southwest.longitude, bounds.northeast.latitude);
    String se =
        gc.encode(bounds.northeast.longitude, bounds.southwest.latitude);
    String center = gc.encode(position.longitude, position.latitude);

    // Find longest common starting substring for center and corners
    int level = max(max(lcp(center, ne), lcp(center, sw)),
        max(lcp(center, nw), lcp(center, se)));

    return [
      ne.substring(0, level),
      sw.substring(0, level),
      nw.substring(0, level),
      se.substring(0, level)
    ].toSet();
  }

  Future<List<Book>> booksFor(String geohash) async {
    String low = (geohash + '000000000').substring(0, 9);
    String high = (geohash + 'zzzzzzzzz').substring(0, 9);

    QuerySnapshot bookSnap;

    Query query;

    if (isbns == null || isbns.length == 0) {
      // Query by conditions
      query = FirebaseFirestore.instance
          .collection('books')
          .where('location.geohash', isGreaterThanOrEqualTo: low)
          .where('location.geohash', isLessThan: high);

      bool multiple = false;

      // Add author(s) to the query if present
      List<String> authors = filters
          .where((f) => f.type == FilterType.author)
          .map((a) => a.value)
          .toList();

      // Firestore only support up to 10 values in the list for the query
      if (authors.length > 10) {
        authors = authors.take(10).toList();
        print('EXCEPTION: more than 10 authors in a query');
        // TODO: Report an exception to analyse why it happens
      }

      if (authors.length > 1) {
        query = query.where('author', whereIn: authors);
        multiple = true;
      } else if (authors.length == 1) {
        query = query.where('author', isEqualTo: authors.first);
      }

      // Add place(s) to the query if present
      List<String> places = filters
          .where((f) => f.type == FilterType.place)
          .map((p) => p.place.id)
          .toList();

      // Firestore only support up to 10 values in the list for the query
      if (places.length > 10) {
        places = places.take(10).toList();
        print('EXCEPTION: more than 10 places in a query');
        // TODO: Report an exception to analyse why it happens
      }

      if (places.length > 1) {
        if (multiple) {
          print('EXCEPTION: Already multiple query. Places filters ignored.');
          // TODO: Report an exception
        } else {
          query = query.where('bookplace', whereIn: places);
          multiple = true;
        }
      } else if (places.length == 1) {
        query = query.where('bookplace', isEqualTo: places.first);
      }

      // Add genre(s) to the query if present
      List<String> genres = filters
          .where((f) => f.type == FilterType.genre)
          .map((g) => g.value)
          .toList();

      // Firestore only support up to 10 values in the list for the query
      if (genres.length > 10) {
        genres = genres.take(10).toList();
        print('EXCEPTION: more than 10 genres in a query');
        // TODO: Report an exception to analyse why it happens
      }

      if (genres.length > 1) {
        if (multiple) {
          print('EXCEPTION: Already multiple query. Genres filters ignored.');
          // TODO: Report an exception
        } else {
          query = query.where('genre', whereIn: genres);
          multiple = true;
        }
      } else if (genres.length == 1) {
        query = query.where('bookplace', isEqualTo: genres.first);
      }

      // Add genre(s) to the query if present
      List<String> langs = filters
          .where((f) => f.type == FilterType.language)
          .map((l) => l.value)
          .toList();

      // Firestore only support up to 10 values in the list for the query
      if (langs.length > 10) {
        langs = langs.take(10).toList();
        print('EXCEPTION: more than 10 languages in a query');
        // TODO: Report an exception to analyse why it happens
      }

      if (langs.length > 1) {
        if (multiple) {
          print(
              'EXCEPTION: Already multiple query. Languages filters ignored.');
          // TODO: Report an exception
        } else {
          query = query.where('language', whereIn: langs);
          multiple = true;
        }
      } else if (langs.length == 1) {
        query = query.where('language', isEqualTo: langs.first);
      }
    } else {
      if (isbns.length > 10) {
        print('EXCEPTION: number of ISBNs in query more than 10.');
        // TODO: Report exception in analytic
      }

      // Query by list of books (ISBN)
      query = FirebaseFirestore.instance
          .collection('books')
          .where('isbn', whereIn: isbns.take(10).toList());
    }

    query = query.limit(2000);

    bookSnap = await query.get();

    // Group all books for geohash areas one level down
    List<Book> books =
        bookSnap.docs.map((doc) => Book.fromJson(doc.id, doc.data())).toList();

    print('!!!DEBUG: booksFor reads ${books.length} books');

    return books;
  }

  Future<List<Place>> placesFor(String geohash) async {
    String low = (geohash + '000000000').substring(0, 9);
    String high = (geohash + 'zzzzzzzzz').substring(0, 9);

    QuerySnapshot placeSnap = await FirebaseFirestore.instance
        .collection('bookplaces')
        .where('location.geohash', isGreaterThanOrEqualTo: low)
        .where('location.geohash', isLessThan: high)
        .limit(2000)
        .get();

    // Group all books for geohash areas one level down
    List<Place> places = placeSnap.docs
        .map((doc) => Place.fromJson(doc.id, doc.data()))
        .toList();

    print('!!!DEBUG: placesFor reads ${places.length} places');

    return places;
  }

  // Group points (Books or Places) into clusters based on the geo-hash
  Future<Set<MarkerData>> markersFor(
      {List<Point> points, LatLngBounds bounds, Set<String> hashes}) async {
    // Two levels down compare to hashes of the state
    int level = min(hashes.first.length + 2, 9);

    Set<MarkerData> markers = Set();

    if (points != null && points.length > 0) {
      // Group points which are visible on the screen based on geohashes
      // 2 level down
      Map<String, List<Point>> clusters = groupBy(
          points.where((p) => bounds.contains(p.location)),
          (p) => p.geohash.substring(0, level));

      await Future.forEach(clusters.keys, (key) async {
        List<Point> value = clusters[key];
        // Calculate position for the marker via average geo-hash code
        // for positions of individual books
        double lat = 0.0, lng = 0.0;
        value.forEach((p) {
          lat += p.location.latitude;
          lng += p.location.longitude;
        });

        lat /= value.length;
        lng /= value.length;

        print('!!!DEBUG Value for hash $key = ${value.length}');

        int count = 0;
        if (value.first is Book)
          count = value.length;
        else
          value.forEach((p) {
            count += (p is Place) ? p.count ?? 1 : 1;
          });

        markers.add(MarkerData(
            geohash: key,
            position: LatLng(lat, lng),
            size: count,
            points: value));
      });
    }

    print(
        '!!!DEBUG markersFor: ${markers.length} SIZES: ${markers.map((m) => m.size).join(', ')}');

    return markers;
  }
}

// Return length of longest common prefix
int lcp(String s1, String s2) {
  for (int i = 0; i <= min(s1.length, s2.length); i++)
    if (s1.codeUnitAt(i) != s2.codeUnitAt(i)) return i;
  return min(s1.length, s2.length);
}

double distanceBetween(LatLng p1, LatLng p2) {
  double lat1 = p1.latitude;
  double lon1 = p1.longitude;
  double lat2 = p2.latitude;
  double lon2 = p2.longitude;

  double R = 6378.137; // Radius of earth in KM
  double dLat = lat2 * pi / 180 - lat1 * pi / 180;
  double dLon = lon2 * pi / 180 - lon1 * pi / 180;
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  double d = R * c;
  return d * 1000; // Meters
}

String distanceString(LatLng p1, LatLng p2) {
  double d = distanceBetween(p1, p2);
  return d < 1000
      ? d.toStringAsFixed(0) + " m"
      : (d / 1000).toStringAsFixed(0) + " km";
}

class FilterCubit extends Cubit<FilterState> {
  GoogleMapController _mapController;
  SnappingSheetController _snappingControler;
  TextEditingController _searchController;

  FilterCubit() : super(FilterState()) {
    List<Book> books = [];
    List<Place> places = [];
    Set<MarkerData> markers = {};
    LatLng center = const LatLng(49.8397, 24.0297);
    LatLngBounds bounds = LatLngBounds(
        southwest: const LatLng(49.7397, 23.9297),
        northeast: const LatLng(49.9397, 24.1297));
    Set<String> geohashes = const {'u8c5d'};
    Future.forEach(geohashes, (hash) async {
      places.addAll(await state.placesFor(hash));
      markers.addAll(await state.markersFor(points: places, hashes: geohashes));
    }).then((value) {
      emit(state.copyWith(
        geohashes: geohashes,
        center: center,
        bounds: bounds,
        places: places,
        markers: markers,
        view: ViewType.map,
      ));
    });
  }

  @override
  Future<void> close() async {
    _searchController.removeListener(_onSearchChanged);
    super.close();
  }

/*
  double screenInKm() {
    return 156543.03392 *
        cos(state.center.latitude * pi / 180) /
        pow(2, state.zoom) *
        600.0 /
        1000;
  }
*/

  List<Filter> toggle(List<Filter> filters, FilterType type, bool selected) {
    return filters.map((f) {
      if (f.type == type)
        return f.copyWith(selected: selected);
      else
        return f;
    }).toList();
  }

  Future<List<Filter>> findTitleSugestions(String query) async {
    if (query.length < 4) return const <Filter>[];

    var lowercase = query.toLowerCase();

    List<Book> books = await searchByText(lowercase);

    // TODO: Check it for long query in case widget are not mounted already

    // If no books returned return empty list
    if (books == null) return const <Filter>[];

    print('!!!DEBUG: Catalog query return ${books?.length} records');

    // If author match use FilterType.author, otherwise FilterType.title
    return books
        //  .where((b) =>
        //      b.title.toLowerCase().contains(lowercase) ||
        //      b.authors.join().toLowerCase().contains(lowercase))
        .map((b) {
          String matchAuthor = b.authors.firstWhere(
              (a) => lowercase
                  .split(' ')
                  .every((word) => a.toLowerCase().contains(word)),
              orElse: () => null);

          if (matchAuthor != null)
            return Filter(
                type: FilterType.author, selected: false, value: matchAuthor);
          else
            return Filter(
                type: FilterType.title,
                selected: false,
                value: b.title,
                book: b);
        })
        .toSet()
        .toList();
  }

  static List<Filter> findGenreSugestions(String query) {
    List<String> keys;

    if (query.length == 0) {
      keys = genres.keys.take(15).toList();
    } else {
      keys = genres.keys
          .where(
              (key) => genres[key].toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    return keys
        .map((key) =>
            Filter(type: FilterType.genre, selected: false, value: key))
        .toList(growable: false);
  }

  Future<List<Filter>> findPlaceSugestions(String query) async {
    // TODO: If access to address book is allowed (contacts is not null)
    //       add all contacts to the list with it's distance.

    // Query bookplaces in a radius of 5 km (same hash length 5) to current
    // location. Sort it by distance ascending (closest places first).

    // TODO: Take care about locations near equator and 0/180 longitude.
    List<Place> places = state.places;

    // Query places if it's empty
    // TODO: Make a procedure for that
    if (places == null || places.length == 0) {
      places = [];
      await Future.forEach(state.geohashes, (hash) async {
        places.addAll(await state.placesFor(hash));
      });

      places.sort((a, b) => (distanceBetween(a.location, state.center) -
              distanceBetween(b.location, state.center))
          .round());

      emit(state.copyWith(places: places));
    }

    if (query.length == 0) {
      print('!!!DEBUG length 0');
      places = places.take(15).toList();
    } else if (query.length > 0) {
      places = places.where((p) {
        return p.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }

    // No need to sort as places already sorted by distance
    return places
        .map((p) => Filter(
            type: FilterType.place, value: p.name, selected: false, place: p))
        .toList(growable: false);
  }

  List<Filter> findLanguageSugestions(String query) {
    List<String> keys;

    if (query.length == 0) {
      keys = mainLanguages.toList();
    } else {
      keys = languages.keys
          .where((key) =>
              key.toLowerCase().contains(query.toLowerCase()) ||
              languages[key].toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    List<String> selectedLaguages = state
        .getFilters(type: FilterType.language)
        .map((f) => f.value)
        .toList();

    // Remove languages which are already selected
    if (selectedLaguages.length > 0)
      keys = keys.where((k) => !selectedLaguages.contains(k)).toList();

    return keys
        .map((key) =>
            Filter(type: FilterType.language, selected: false, value: key))
        .toList(growable: false);
  }

  Future<List<Filter>> findSugestions(String query, FilterGroup group) async {
    if (group == FilterGroup.book)
      return findTitleSugestions(query);
    else if (group == FilterGroup.genre)
      return findGenreSugestions(query);
    else if (group == FilterGroup.place)
      return findPlaceSugestions(query);
    else if (group == FilterGroup.language)
      return findLanguageSugestions(query);
    else
      return [];
  }

  Future<void> scanContacts() async {
    // Get all contacts on device
    Iterable<Contact> addressBook = await ContactsService.getContacts();

    print('!!!DEBUG ${addressBook.length} contacts found');

    List<String> all = [];
    List<String> places = [];

    // Search each contact in Biblosphere
    await Future.forEach(addressBook, (c) async {
      // Get all contacts (phones/emails) for the person
      List<String> contacts = [
        ...c.phones.map((p) => p.value),
        ...c.emails.map((e) => e.value)
      ];

      // Look for the book places with these contacts
      // TODO: Only first 10 contacts for the same person are taken
      QuerySnapshot placeSnap = await FirebaseFirestore.instance
          .collection('bookplaces')
          .where('contacts', arrayContainsAny: contacts.take(10).toList())
          .get();

      // If places are found link it in both direction: from user
      // to place and from place to user
      if (placeSnap.docs.length > 0) {
        // List of book places ids
        List<String> ids = placeSnap.docs.map((d) => d.id).toList();

        // Add to places of this user
        places.addAll(ids);

        // Update link from the place to the user
        // Add current user to found bookplaces
        await Future.forEach(ids, (id) async {
          await FirebaseFirestore.instance
              .collection('bookplaces')
              .doc(id)
              .update({
            'users':
                FieldValue.arrayUnion([FirebaseAuth.instance.currentUser.uid])
          });
        });
      }

      // Extend list of all contacts
      all.addAll(contacts);
    });

    // Update user record if any information are there
    Map<String, dynamic> data = {};
    if (all.length > 0) data['contacts'] = FieldValue.arrayUnion(all);

    if (places.length > 0) data['places'] = FieldValue.arrayUnion(places);

    // Update found contacts to the user record
    if (data.length > 0)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser.uid)
          .update(data);

    // TODO: Inform user with snackbar if new users found from address book

    // Emit state with updated places if any
    if (places.length > 0)
      emit(state.copyWith(
        favorite: places,
      ));
  }

  // FILTER PANEL:
  // - Author/title filter changed => FILTER
  // - Places filter changed => FILTER (permission for Address Book if My Places)
  // - Language filter changed => FILTER
  // - Genre filter changed => FILTER
  void deleteFilter(Filter filter) async {
    // Block removing wish filter and contacts filter
    List<Filter> filters = state.filters;

    // Do not remove WISH and CONTACT. Just unselect.
    if (filter.type == FilterType.wish || filter.type == FilterType.contacts) {
      filters = toggle(filters, FilterType.wish, false);
    } else {
      filters = filters.where((f) => f != filter).toList();
    }

    emit(state.copyWith(filters: filters));
  }

  // FILTER PANEL:
  // - Author/title filter changed => FILTER
  // - Places filter changed => FILTER (permission for Address Book if My Places)
  // - Language filter changed => FILTER
  // - Genre filter changed => FILTER
  void addFilter(Filter filter) async {
    List<Filter> filters = state.filters;

    // Do nothing if filter already there
    if (filters.contains(filter)) return;

    if (filter.type == FilterType.title) {
      // If title filter add unselect wish filter
      filters = toggle(filters, FilterType.wish, false);
      // If title filter add drop genres filters
      filters = filters.where((f) => f.type != FilterType.genre).toList();
    } else if (filter.type == FilterType.place) {
      // If place filter add unselect contacts filter
      filters = toggle(filters, FilterType.contacts, false);
    } else if (filter.type == FilterType.genre) {
      // If genre filter add drop title filters
      filters = filters.where((f) => f.type != FilterType.title).toList();
    } else if (filter.type == FilterType.author &&
        filters.any((f) => f.type == FilterType.author)) {
      // If more than 1 author drop genres filters if more than 1 value
      if (filters.where((f) => f.type == FilterType.genre).length > 1)
        filters = filters.where((f) => f.type != FilterType.genre).toList();

      // If more than 1 author drop language filters if more than 1 value
      if (filters.where((f) => f.type == FilterType.language).length > 1)
        filters = filters.where((f) => f.type != FilterType.language).toList();
    }

    // Remove this filter from suggestions
    List<Filter> suggestions = state.suggestions
        .where((f) => f.type != filter.type || f.value != filter.value)
        .toList();

    filters = [...filters, filter]
      ..sort((a, b) => a.type.index.compareTo(b.type.index));

    emit(state.copyWith(filters: filters, suggestions: suggestions));
  }

  // FILTER PANEL:
  // - Author/title filter changed => FILTER
  // - Places filter changed => FILTER (permission for Address Book if My Places)
  // - Language filter changed => FILTER
  // - Genre filter changed => FILTER
  void toggleFilter(FilterType type, Filter filter) async {
    print('!!!DEBUG Toggle filter ${filter.type}');

    // Only toggle wish and contacts filter
    if (filter.type != FilterType.contacts && filter.type != FilterType.wish)
      return;

    // If contacts filter selected we have to check/request contacts permission
    if (filter.type == FilterType.contacts && !filter.selected) {
      if (!await Permission.contacts.isGranted) {
        // Initiate contacts for a first time then permission is granted
        if (await Permission.contacts.request().isGranted) {
          print('!!!DEBUG CONTACTS permission granted for a first time');
          // Async procedure, no wait
          scanContacts();
        } else {
          // Return without toggle if contacts permission is not granted
          return;
        }
      }
      // Either the permission was already granted before or the user just granted it.
      print('!!!DEBUG CONTACTS permission checked');
    }

    List<Filter> filters = state.filters;

    // Drop all places filters if contacts is selected
    if (filter.type == FilterType.contacts && !filter.selected)
      filters = filters.where((f) => f.type != FilterType.place).toList();

    // Drop all title filters if wish is selected
    if (filter.type == FilterType.wish && !filter.selected)
      filters = filters.where((f) => f.type != FilterType.title).toList();

    filters = toggle(filters, filter.type, !filter.selected);

    emit(state.copyWith(
      filters: filters,
    ));
  }

  // FILTER PANEL:
  // - Button with group icon or tap on group line to edit details
  void searchEditComplete() async {
    _searchController.text = '';
    _snappingControler.snapToPosition(_snappingControler.snapPositions.last);

    List<Book> books = [];
    List<Place> places = [];
    Set<MarkerData> markers = Set();

    // Make markers based on BOOKS
    if (state.select == QueryType.books) {
      print('!!!DEBUG Filtered markers based on BOOKS');
      // Add books only for missing areas
      await Future.forEach(state.geohashes, (hash) async {
        books.addAll(await state.booksFor(hash));
      });

      // Sort books based on distance to center of screen
      books.sort((a, b) => (distanceBetween(a.location, state.center) -
              distanceBetween(b.location, state.center))
          .round());

      // Calculate markers based on the books
      markers = await state.markersFor(
          points: books, bounds: state.bounds, hashes: state.geohashes);

      // Make markers based on PLACES
    } else if (state.select == QueryType.places) {
      print('!!!DEBUG Filtered markers based on PLACES');
      // Add places only for missing areas
      await Future.forEach(state.geohashes, (hash) async {
        places.addAll(await state.placesFor(hash));
      });

      // Sort places based on distance to center of screen
      places.sort((a, b) => (distanceBetween(a.location, state.center) -
              distanceBetween(b.location, state.center))
          .round());

      // Calculate markers based on the places
      markers = await state.markersFor(
          points: places, bounds: state.bounds, hashes: state.geohashes);
    }

    // Emit state with updated markers
    emit(state.copyWith(books: books, places: places, markers: markers));
  }

  // FILTER PANEL:
  // - Button with group icon or tap on group line to edit details
  void groupSelectedForSearch(FilterGroup group) async {
    _searchController.text = '';
    _snappingControler.snapToPosition(
      SnapPosition(
          positionPixel: 280.0,
          snappingCurve: Curves.elasticOut,
          snappingDuration: Duration(milliseconds: 750)),
    );
    emit(state.copyWith(group: group, panel: Panel.full));

    List<Filter> suggestions = await findSugestions('', group);
    emit(state.copyWith(suggestions: suggestions));
  }

  // FILTER PANEL:
  // - Filter panel opened => FILTER
  void panelOpened() async {
    print('!!!DEBUG PANEL OPEN');

    // TODO: Load near by book places and keep it in the state object
    emit(state.copyWith(
      panel: Panel.open,
    ));
  }

  // FILTER PANEL:
  // - Filter panel minimized => FILTER
  void panelMinimized() {
    print('!!!DEBUG PANEL MINIMIZED');
    emit(state.copyWith(
      panel: Panel.minimized,
    ));
  }

  // FILTER PANEL:
  // - Filter panel closed => FILTER
  void panelHiden() {
    print('!!!DEBUG PANEL HIDDEN');
    emit(state.copyWith(
      panel: Panel.hiden,
    ));
  }

  // TRIPLE BUTTON
  // - Map button pressed (selected) => FILTER
  void mapButtonPressed() async {
    Position loc = await Geolocator.getCurrentPosition();

    print('!!!DEBUG New location ${LatLng(loc.latitude, loc.longitude)}');

    // TODO: Calculate zoom based on the book availability at a location

    if (_mapController != null)
//      _controller.moveCamera(CameraUpdate.newCameraPosition(CameraPosition(
//          target: LatLng(loc.latitude, loc.longitude), zoom: 10.0)));

      _mapController.moveCamera(
          CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)));

    // TODO: Check if zoom reset is a good thing. Do we need to
    //       auto-calculate zoom to always contain some book search results.

    // TODO: query books/places based on new location and current filters
  }

  // TRIPLE BUTTON
  // - List button pressed (selected) => FILTER
  void listButtonPressed() {
    // TODO: Which function is appropriate for list view button?
  }

  // TRIPLE BUTTON
  // - Set view => FILTER
  void setView(ViewType view) async {
    if (view == ViewType.list) {
      List<Book> books = [];
      if (state.select == QueryType.books)
        // Use preselected books
        books = state.books;
      else if (state.select == QueryType.places) {
        await Future.forEach(state.geohashes, (hash) async {
          books.addAll(await state.booksFor(hash));
        });

        books.sort((a, b) => (distanceBetween(a.location, state.center) -
                distanceBetween(b.location, state.center))
            .round());
      }

      print('!!!DEBUG books sorted around ${state.center}');

      emit(state.copyWith(
        books: books,
        view: ViewType.list,
      ));
    } else {
      emit(state.copyWith(
        view: view,
      ));
    }
  }

  // MAP VIEW
  // - Set controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  // MAP VIEW
  // - Set controller
  void setSnappingController(SnappingSheetController controller) {
    _snappingControler = controller;
  }

  // Function to identify that typing is other. To minimize number
  // of queries to DB
  Timer _debounce;
  int _debouncetime = 500;

  _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce.cancel();
    _debounce = Timer(Duration(milliseconds: _debouncetime), () async {
      if (_searchController.text != "") {
        // Perform your search only if typing is over
        print('!!!DEBUG text from search field: ${_searchController.text}');
        List<Filter> suggestions =
            await findSugestions(_searchController.text, state.group);

        emit(state.copyWith(suggestions: suggestions));
      }
    });
  }

  // MAP VIEW
  // - Set controller
  void setSearchController(TextEditingController controller) {
    if (_searchController == null) {
      _searchController = controller;
      _searchController.addListener(_onSearchChanged);
    }
  }

  // MAP VIEW
  // - Map move => FILTER
  void mapMoved(CameraPosition position, LatLngBounds bounds) async {
    print('!!!DEBUG mapMoved: starting hashes ${state.geohashes.join(',')}');

    // Recalculate geo-hashes from camera position and bounds

    Set<String> hashes = state.hashesFor(
        position != null ? position.target : state.center, bounds);

    print('!!!DEBUG mapMoved: new hashes ${hashes.join(',')}');

    // Old and new levels of geo hashes
    int oldLevel = state.geohashes.first.length;
    int newLevel = hashes.first.length;

    // Find which goe-hashes are apeared and which one are gone
    Set<String> extraHashes;
    Set<String> oddHashes;

    if (oldLevel == newLevel) {
      extraHashes = hashes.difference(state.geohashes);
      oddHashes = state.geohashes.difference(hashes);
    } else {
      extraHashes = hashes;
      // Do not remove the old hash if one of new hashes are inside
      oddHashes = state.geohashes
          .where((h1) =>
              h1.length > newLevel || hashes.every((h2) => !h2.startsWith(h1)))
          .toSet();
    }

    print('!!!DEBUG new hashes: ${extraHashes.join(', ')}');
    print('!!!DEBUG odd hashes: ${oddHashes.join(', ')}');

    List<Book> books = state.books ?? [];
    List<Place> places = state.places ?? [];
    Set<MarkerData> markers = state.markers ?? Set();

    // Make markers based on BOOKS
    if (state.select == QueryType.books) {
      // Add books only for missing areas
      await Future.forEach(extraHashes, (hash) async {
        books.addAll(await state.booksFor(hash));
      });

      // Remove books from odd hashes and duplicates
      books = books
          .where((b) => !oddHashes.contains(b.geohash.substring(0, oldLevel)))
          .toSet()
          .toList();

      // Sort books based on distance to center of screen
      books.sort((a, b) => (distanceBetween(a.location, state.center) -
              distanceBetween(b.location, state.center))
          .round());

      // Calculate markers based on the books
      markers =
          await state.markersFor(points: books, bounds: bounds, hashes: hashes);

      // Make markers based on PLACES
    } else if (state.select == QueryType.places) {
      print('!!!DEBUG Markers based on PLACES');
      // Add places only for missing areas
      await Future.forEach(extraHashes, (hash) async {
        places.addAll(await state.placesFor(hash));
      });

      // Remove places from odd hashes and duplicates
      places = places
          .where((p) =>
              extraHashes.contains(p.geohash.substring(0, newLevel)) ||
              !oddHashes.contains(p.geohash.substring(0, oldLevel)))
          .toSet()
          .toList();

      // Sort places based on distance to center of screen
      places.sort((a, b) => (distanceBetween(a.location, state.center) -
              distanceBetween(b.location, state.center))
          .round());

      // Calculate markers based on the places
      markers = await state.markersFor(
          points: places, bounds: bounds, hashes: hashes);
    }

    // Emit state with updated markers
    // Refresh suggestions if map moved once detailed place filters are open
    emit(state.copyWith(
        center: position != null ? position.target : state.center,
        bounds: bounds != null ? bounds : state.bounds,
        geohashes: hashes,
        books: books,
        places: places,
        suggestions:
            (state.panel == Panel.full && state.group == FilterGroup.place)
                ? await findSugestions('', state.group)
                : null,
        markers: markers));
  }

  LatLngBounds boundsFromPoints(List<Point> points) {
    assert(points.isNotEmpty);

    double north = points.first.location.latitude;
    double south = points.first.location.latitude;

    for (var i = 0; i < points.length; i++) {
      if (points[i].location.latitude > north)
        north = points[i].location.latitude;
      else if (points[i].location.latitude < south)
        south = points[i].location.latitude;
    }

    List<double> lng = points.map((p) => p.location.longitude).toList();
    lng.sort();

    double gap = lng.first - lng.last + 360.0;
    double west = lng.first, east = lng.last;

    for (var i = 1; i < lng.length - 1; i++) {
      if (lng[i] - lng[i - 1] > gap) {
        gap = lng[i] - lng[i - 1];
        east = lng[i - 1];
        west = lng[i];
      }
    }

    return LatLngBounds(
        northeast: LatLng(north, east), southwest: LatLng(south, west));
  }

  // MAP VIEW
  // - Tap on Marker => FILTER
  void markerPressed(MarkerData marker) {
    print('!!!DEBUG Marker pressed ${marker.position} size: ${marker.size} ');
    print('!!!DEBUG Marker points ${marker.points.first.runtimeType}');
    if (marker.points.length == 1 && marker.points.first is Book) {
      // Open detailes screen if marker is for one book
      // Hide panel
      _snappingControler.snapToPosition(_snappingControler.snapPositions.first);
      emit(state.copyWith(
        selected: (marker.points.first as Book),
        view: ViewType.details,
        center: marker.position,
      ));
    } else if (marker.points.length > 1 && marker.points.first is Book) {
      List<Book> books = List<Book>.from(marker.points);
      books.sort((a, b) => (distanceBetween(a.location, marker.position) -
              distanceBetween(b.location, marker.position))
          .round());
      // Zoom in if marker has too many books
      emit(state.copyWith(
        books: books,
        view: ViewType.list,
        center: marker.position,
      ));
    } else if (marker.points.length == 1 && marker.points.first is Place) {
      // Set filter by place id
      // Get books for this place (filters)
      // Change view to LIST
    } else if (marker.points.length >= 1 && marker.points.first is Place) {
      // Zoom to the places
      LatLngBounds bounds = boundsFromPoints(marker.points);
      _mapController.moveCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    }
  }

  // LIST VIEW
  // - Select book from the list
  void selectBook({Book book}) async {
    print('!!!DEBUG Book selected ${book.title}');
    // Hide panel
    _snappingControler.snapToPosition(_snappingControler.snapPositions.first);

    emit(state.copyWith(
      selected: book,
      view: ViewType.details,
    ));
  }

  // DETAILS
  // - Search button pressed => FILTER
  void searchBookPressed(Book book) async {
    // NOT WORKING NOW!!!!!!!!!!!!!!!

    // TODO: Set filter for given book, so only this book is displayed
    //       probably zoom out to contains more copies of this book.

    List<Book> books;
    Set<MarkerData> markers;
    await Future.forEach(state.geohashes, (hash) async {
      books.addAll(await state.booksFor(hash));
      // TODO: Add places as well???
    });

    markers = await state.markersFor(
        points: books, hashes: state.geohashes, bounds: state.bounds);

    emit(state.copyWith(
      books: books,
      markers: markers,
      view: ViewType.map,
    ));
  }

  // DETAILS
  // - Close button pressed => FILTER
  void detailsClosed() async {
    // TODO: Restore previous view MAP or LIST

    emit(state.copyWith(
      view: ViewType.list,
    ));
  }
}
